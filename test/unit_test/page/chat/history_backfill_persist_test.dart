/// BUG#119 闭环复现：history 拉回本地后 `pageForConversation` 仍 0 条。
///
/// 用后端 `msg_archive_repo:get_history` + `messaging_logic:encode_history_msg`
/// 的真实返回形状（msg_id/chat_type/conv_seq/msg_type/from/to/group_id/
/// e2ee/payload/created_at/server_ts）驱动整条落库链：
///
///   archiveRowToOfflineShape → MessageRepo.batchInsertOfflineMessages
///   → pageForConversation(uk3, 0, size)
///
/// 修复前该链任一环节抛异常被吞（syncHistoryBackfill 的 catch 只留一行
/// iPrint），UI 就永久「暂无数据」——即使消息其实已落库。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/offline_message_writer.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

/// 当前测试账号（与 C2C 行的 from 一致，使 isAuthor=true → peerId=toId）
const String _currentUid = '1817128709888507904';
const String _peerUid = '1825989847768576000';
const String _groupId = '1818608297223856128';

const String _msgC2cDDL = '''
  CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2C',
    action TEXT DEFAULT '',
    sender_did TEXT,
    conv_seq INTEGER,
    accepted_at INTEGER,
    CONSTRAINT uk_MsgId UNIQUE (id)
  )
''';

const String _msgC2gDDL = '''
  CREATE TABLE msg_c2g (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2G',
    action TEXT DEFAULT '',
    conv_seq INTEGER,
    accepted_at INTEGER,
    CONSTRAINT uk_MsgId UNIQUE (id)
  )
''';

const String _conversationDDL = '''
  CREATE TABLE conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    mention_unread INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
  )
''';

const String _contactDDL = '''
  CREATE TABLE contact (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    peer_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    tag TEXT DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    is_friend INTEGER NOT NULL DEFAULT 0,
    is_from INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER
  )
''';

const String _groupDDL = '''
  CREATE TABLE "group" (
    id INTEGER PRIMARY KEY,
    type INTEGER DEFAULT 1,
    join_limit INTEGER DEFAULT 2,
    content_limit INTEGER DEFAULT 2,
    owner_uid INTEGER NOT NULL,
    creator_uid INTEGER NOT NULL,
    member_max INTEGER NOT NULL DEFAULT 1000,
    member_count INTEGER NOT NULL DEFAULT 1,
    introduction TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    status INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    pinned_msg TEXT
  )
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _currentUid);

    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final ddl in [
      _msgC2cDDL,
      _msgC2gDDL,
      _conversationDDL,
      _contactDDL,
      _groupDDL,
    ]) {
      await db.execute(ddl);
    }
    SqliteService.setDbForTest(db);
    // _syncOfflineConversationsAndNotify 依赖注入的应用级容器
    MessageRepo.setProviderContainer(ProviderContainer());
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  /// 后端 encode_history_msg 之后的 C2C 归档行真实形状
  Map<String, dynamic> c2cHistoryRow({
    required int convSeq,
    required int from,
    required int to,
    required String payload,
  }) {
    return <String, dynamic>{
      'msg_id': 1817128709888508000 + convSeq, // TSID 十进制 int
      'chat_type': 'c2c',
      'conv_seq': convSeq,
      'msg_type': 'text',
      'from': from,
      'to': to,
      'e2ee': null,
      'payload': payload,
      'created_at': 1750000000000 + convSeq,
      'server_ts': 1750000000000 + convSeq,
    };
  }

  group('BUG#119 history 落库闭环', () {
    test('C2C history 行落库后 pageForConversation 能查到', () async {
      final rows = [
        c2cHistoryRow(
          convSeq: 1,
          from: int.parse(_currentUid),
          to: int.parse(_peerUid),
          payload: '{"text":"你好","msg_type":"text"}',
        ),
      ];
      final shaped = rows.map(archiveRowToOfflineShape).toList(growable: false);

      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2C'));
      final msgIds = await repo.batchInsertOfflineMessages(
        shaped,
        trustedArchive: true,
      );

      // 落库成功（与 A-24 契约一致：失败会抛，不会静默返回 null）
      expect(msgIds, isNotNull, reason: '整批插入失败会向上抛，不会返回 null');
      expect(msgIds, hasLength(1));

      // 与聊天页 loadMoreMessages 完全相同的查询（uk3 同源生成）
      final String uk3 = ConversationUk3Generator.generateSmart(
        type: 'C2C',
        currentUserId: _currentUid,
        peerId: _peerUid,
      );
      final items = await repo.pageForConversation(uk3, 0, 16);

      expect(
        items.length,
        1,
        reason: 'BUG#119：history 已落库但 pageForConversation 查 0 条',
      );
      expect(items.first.payload, isA<Map<String, dynamic>>());
      expect((items.first.payload as Map)['text'], '你好');
    });

    test('C2G history 行（to 为空、group_id 兜底）落库后能查到', () async {
      final rows = [
        <String, dynamic>{
          'msg_id': 1817128709888509000,
          'chat_type': 'c2g',
          'conv_seq': 1,
          'msg_type': 'text',
          'from': int.parse(_currentUid),
          // 后端 encode_history_msg：C2G 的 to_id 为 null → 不设置 to 键
          'group_id': int.parse(_groupId),
          'e2ee': null,
          'payload': '{"text":"群消息","msg_type":"text"}',
          'created_at': 1750000000000,
          'server_ts': 1750000000000,
        },
      ];
      final shaped = rows.map(archiveRowToOfflineShape).toList(growable: false);
      // 纯函数兜底：group_id 已被填进 to
      expect(shaped.single['to'], int.parse(_groupId));

      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2G'));
      final msgIds = await repo.batchInsertOfflineMessages(
        shaped,
        trustedArchive: true,
      );
      expect(msgIds, hasLength(1));

      final items = await repo.pageForConversation(
        'C2G_${_currentUid}_$_groupId',
        0,
        16,
      );
      expect(items.length, 1);
    });

    test('重复拉取同一页（游标未推进）不产生重复行', () async {
      final rows = [
        c2cHistoryRow(
          convSeq: 1,
          from: int.parse(_currentUid),
          to: int.parse(_peerUid),
          payload: '{"text":"去重","msg_type":"text"}',
        ),
      ];
      final shaped = rows.map(archiveRowToOfflineShape).toList(growable: false);
      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2C'));

      await repo.batchInsertOfflineMessages(shaped, trustedArchive: true);
      await repo.batchInsertOfflineMessages(shaped, trustedArchive: true);

      final List<Map<String, Object?>> all = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM msg_c2c',
      );
      expect(
        (all.single['c'] as int?) ?? -1,
        1,
        reason: 'msg_id 去重：重复拉取不得重复落库',
      );
    });

    test('只有 trustedArchive 路径把服务端 conv_seq 写入 E2EE 内部元数据', () async {
      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2G'));
      Map<String, dynamic> row(int id, int convSeq) => {
        'msg_id': id,
        'chat_type': 'c2g',
        'type': 'C2G',
        'conv_seq': convSeq,
        'msg_type': 'text',
        'from': int.parse(_currentUid),
        'to': int.parse(_groupId),
        'e2ee': {'protocol': 'megolm', 'gid': _groupId, '_archive_conv_seq': 1},
        'payload': 'ciphertext',
        'created_at': 1750000000000,
      };

      await repo.batchInsertOfflineMessages([
        row(1817128709888510000, 481),
      ], trustedArchive: true);
      await repo.batchInsertOfflineMessages([row(1817128709888510001, 999)]);

      final trusted = await repo.find('1817128709888510000');
      final untrusted = await repo.find('1817128709888510001');
      expect(trusted!.e2ee!['_archive_conv_seq'], 481);
      expect(untrusted!.e2ee!.containsKey('_archive_conv_seq'), isFalse);
    });

    test('可信 archive 仅在 Megolm 原始信封完全一致时升级失败占位', () async {
      const msgId = 1817128709888511000;
      final e2ee = {
        'protocol': 'megolm',
        'gid': _groupId,
        'session_id': 'session-a',
      };
      final raw = {
        'id': msgId,
        'from': int.parse(_currentUid),
        'to': int.parse(_groupId),
        'type': 'C2G',
        'msg_type': 'text',
        'payload': 'ciphertext-a',
        'e2ee': e2ee,
      };
      await db.insert(MessageRepo.c2gTable, {
        MessageRepo.id: msgId,
        MessageRepo.type: 'C2G',
        MessageRepo.from: int.parse(_currentUid),
        MessageRepo.to: int.parse(_groupId),
        MessageRepo.payload: jsonEncode({
          '_e2ee_failed': true,
          '_e2ee_raw': raw,
        }),
        MessageRepo.createdAt: 1750000000000,
        MessageRepo.isAuthor: 1,
        MessageRepo.topicId: 0,
        MessageRepo.conversationUk3: 'C2G_${_currentUid}_$_groupId',
        MessageRepo.status: 2,
        MessageRepo.msgType: 'text',
        MessageRepo.action: '',
        MessageRepo.e2ee: jsonEncode(e2ee),
      });

      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.batchInsertOfflineMessages([
        {...raw, 'msg_id': msgId, 'conv_seq': 481},
      ], trustedArchive: true);

      final repaired = await repo.find(msgId.toString());
      expect(repaired!.payload, 'ciphertext-a');
      expect(repaired.e2ee!['_archive_conv_seq'], 481);
    });

    test('可信 archive 与失败占位 ciphertext 不一致时保持原行', () async {
      const msgId = 1817128709888511001;
      final e2ee = {
        'protocol': 'megolm',
        'gid': _groupId,
        'session_id': 'session-a',
      };
      final raw = {
        'id': msgId,
        'from': int.parse(_currentUid),
        'to': int.parse(_groupId),
        'type': 'C2G',
        'msg_type': 'text',
        'payload': 'ciphertext-a',
        'e2ee': e2ee,
      };
      final placeholder = jsonEncode({'_e2ee_failed': true, '_e2ee_raw': raw});
      await db.insert(MessageRepo.c2gTable, {
        MessageRepo.id: msgId,
        MessageRepo.type: 'C2G',
        MessageRepo.from: int.parse(_currentUid),
        MessageRepo.to: int.parse(_groupId),
        MessageRepo.payload: placeholder,
        MessageRepo.createdAt: 1750000000000,
        MessageRepo.isAuthor: 1,
        MessageRepo.topicId: 0,
        MessageRepo.conversationUk3: 'C2G_${_currentUid}_$_groupId',
        MessageRepo.status: 2,
        MessageRepo.msgType: 'text',
        MessageRepo.action: '',
        MessageRepo.e2ee: jsonEncode(e2ee),
      });

      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.batchInsertOfflineMessages([
        {...raw, 'msg_id': msgId, 'payload': 'ciphertext-b', 'conv_seq': 481},
      ], trustedArchive: true);

      final unchanged = await repo.find(msgId.toString());
      expect(unchanged!.payload, isA<Map<String, dynamic>>());
      expect(unchanged.e2ee!.containsKey('_archive_conv_seq'), isFalse);
    });
  });

  /// R06：历史回填不回退会话摘要。
  ///
  /// 前提事实（W0 基线复核）：去重跳过路径已保护会话头；但投影本身
  /// 不区分历史导入与新投递——latest.createdAt 无条件覆盖 last_time。
  /// 本组用真实 SQLite 事务驱动 batchInsertOfflineMessages 验证投影语义。
  group('R06 历史回填不回退会话摘要', () {
    // 时间用真实毫秒量级（2025 年代）：ConversationModel.fromJson 的
    // legacy parseModelDateTime 启发式会把 <1e12 的值当秒 *1000（R21-B
    // 待迁移问题），用真实量级避免测试掺入无关行为。
    const int t100 = 1750000000000;
    const int t150 = 1750000050000;
    const int t200 = 1750000100000;
    const int t300 = 1750000150000;
    const int t500 = 1750000250000;
    const int t600 = 1750000300000;

    // 对方发来的文本消息（isAuthor=false，新投递会计未读）
    Map<String, dynamic> peerMsg(Object msgId, int createdAt, String text) =>
        <String, dynamic>{
          'msg_id': msgId,
          'type': 'C2C',
          'from': _peerUid,
          'to': _currentUid,
          'msg_type': 'text',
          'payload': {'text': text, 'msg_type': 'text'},
          'created_at': createdAt,
        };

    Future<Map<String, Object?>> readSingleConversation() async {
      final rows = await db.query('conversation');
      expect(rows, hasLength(1), reason: '测试前提：仅一个会话');
      return rows.single;
    }

    test('R06-1 已有新消息 B 后回填旧 A，会话头仍为 B', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 实时新投递 B（t=200）
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-b', t200, 'msgB'),
      ]);
      // 历史回填更旧的 A（t=100）
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-a', t100, 'msgA'),
      ], trustedArchive: true);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'r06-msg-b', reason: '旧历史不得覆盖会话头');
      expect(conv['last_time'], t200);
      expect(conv['subtitle'], 'msgB');
      // 历史导入不重复累加未读：仅实时 B 计 1
      expect(conv['unread_num'], 1);
    });

    test('R06-2 回填 A+B（B 已在库去重跳过），头仍为 B', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-b', t200, 'msgB'),
      ]);
      // 同一批历史导入：A 更旧 + B 与已落库行重复（去重跳过路径）
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-a', t100, 'msgA'),
        peerMsg('r06-msg-b', t200, 'msgB'),
      ], trustedArchive: true);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'r06-msg-b');
      expect(conv['last_time'], t200);
      expect(conv['subtitle'], 'msgB');
      expect(conv['unread_num'], 1);
      // B 恰好一行，去重未重复落库
      final count = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM msg_c2c WHERE id = 'r06-msg-b'",
      );
      expect(count.single['c'], 1);
    });

    test('R06-3 实时 B 与历史 A 交错到达，头始终最新且未读只计实时', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 历史先到（t=100）：初始化会话，头=A，未读为历史初始摘要 1
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-a', t100, 'msgA'),
      ], trustedArchive: true);
      // 实时 B（t=200）随后：头推进到 B，未读 +1 → 2
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-b', t200, 'msgB'),
      ]);
      // 晚到的历史 A'（t=150，新于 A 旧于 B）：不得推进头、不得计未读
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-msg-a2', t150, 'msgA2'),
      ], trustedArchive: true);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'r06-msg-b');
      expect(conv['last_time'], t200);
      expect(conv['subtitle'], 'msgB');
      expect(conv['unread_num'], 2, reason: '历史初始 1 + 实时 1，晚到历史不再加');
    });

    test('R06-4 多页限额后继续同步更旧页，头不回退、未读不累加', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 第 1 页（较新）：会话由历史初始化，头=m6
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-p1-m5', t500, 'p1m5'),
        peerMsg('r06-p1-m6', t600, 'p1m6'),
      ], trustedArchive: true);
      // 第 2 页（更旧）：整页都不得回退头/不得加未读
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-p2-m1', t100, 'p2m1'),
        peerMsg('r06-p2-m2', t150, 'p2m2'),
        peerMsg('r06-p2-m3', t300, 'p2m3'),
      ], trustedArchive: true);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'r06-p1-m6');
      expect(conv['last_time'], t600);
      expect(conv['subtitle'], 'p1m6');
      expect(conv['unread_num'], 2, reason: '仅第 1 页历史初始化计入');
    });

    test('R06-5 空会话由历史导入初始化正确摘要', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-init-a', t100, 'initA'),
        peerMsg('r06-init-b', t200, 'initB'),
      ], trustedArchive: true);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'r06-init-b');
      expect(conv['last_time'], t200);
      expect(conv['subtitle'], 'initB');
      expect(conv['msg_type'], 'text');
      expect(conv['unread_num'], 2, reason: '历史初始化的初始未读摘要');
      expect(conv['is_show'], 1);
    });

    test('R06-recompute 已回退会话头的有界权威重算', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await repo.batchInsertOfflineMessages([
        peerMsg('r06-rc-a', t100, 'rcA'),
        peerMsg('r06-rc-b', t200, 'rcB'),
      ]);
      // 人为把会话头回退到 stale 值（模拟历史 bug 已写坏的行）
      await db.execute(
        "UPDATE conversation SET last_msg_id = 'r06-rc-a', last_time = ?, "
        "subtitle = 'rcA' WHERE peer_id = ?",
        [t100, int.parse(_peerUid)],
      );

      final writer = OfflineMessageWriter(
        db: SqliteService.to,
        // recompute 不触发会话通知，容器不会被实际使用
        getContainer: ProviderContainer.new,
        activeConversation: () => null,
        resolveTable: MessageRepo.getTableName,
        indexMessage: (_) async {},
        // W8-B4：回调注入（recompute 路径不触去重分支，给真实现即可）
        backfillServerOrderFacts: (msgId, {convSeq, acceptedAt, txn}) =>
            MessageRepo(tableName: MessageRepo.c2cTable)
                .backfillServerOrderFacts(
                  msgId: msgId,
                  convSeq: convSeq,
                  acceptedAt: acceptedAt,
                  txn: txn,
                ),
      );
      final fixed = await writer.recomputeConversationHead(
        type: 'C2C',
        peerId: _peerUid,
      );

      expect(fixed, isNotNull);
      expect(fixed!.lastMsgId, 'r06-rc-b');
      expect(fixed.lastTime, t200);
      expect(fixed.subtitle, 'rcB');
      // 重算只修投影，不增加未读、不动消息行
      expect(fixed.unreadNum, 2);
      final msgCount = await db.rawQuery('SELECT COUNT(*) AS c FROM msg_c2c');
      expect(msgCount.single['c'], 2);
    });

    test('W8-B2 实时乱序批次：旧 created_at 新消息不回退头但未读 +1', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 会话头先由历史批次建立（t=200，初始未读摘要 1）
      await repo.batchInsertOfflineMessages([
        peerMsg('w8-b2-b', t200, 'msgB'),
      ], trustedArchive: true);
      // 实时批次（trustedArchive=false → historyImport=false）乱序投递
      // 更旧 created_at 的新消息 A（t=100）：消息行必须新落库，会话头
      // 不回退，但未读必须 +1（修复前 keep-head 分支直接 continue，
      // 这条未读被永久丢失）。
      await repo.batchInsertOfflineMessages([peerMsg('w8-b2-a', t100, 'msgA')]);

      final conv = await readSingleConversation();
      expect(conv['last_msg_id'], 'w8-b2-b', reason: '实时乱序不得回退会话头');
      expect(conv['last_time'], t200);
      expect(conv['subtitle'], 'msgB');
      expect(conv['unread_num'], 2, reason: '历史初始 1 + 实时乱序 1（W8-B2 修复）');
      final count = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM msg_c2c WHERE id = 'w8-b2-a'",
      );
      expect(count.single['c'], 1, reason: '乱序消息本身正常新落库');
    });
  });

  // W7（审查 P1-1）：accepted_at RFC3339 兜底分支改走 ApiTime.parseIsoZoned
  // 严格口径后的合同行为钉子——无 zone 串不猜设备本地时区。
  group('R07 parseServerOrderFacts accepted_at RFC3339 严格口径', () {
    test('无 zone 串与紧凑形态拒绝：accepted_at=NULL 不猜本地时区', () {
      // legacy DateTime.parse 会按设备本地时区解读此类串（非 null）；
      // 修复后必须返回 null（accepted_at 不落列，走低可信降级）。
      final noZone = OfflineMessageWriter.parseServerOrderFacts({
        'conv_seq': 7,
        'accepted_at': '2026-10-01T00:00:00',
      });
      expect(noZone.convSeq, 7);
      expect(noZone.acceptedAt, isNull, reason: '无 zone RFC3339 不猜本地时区，落 NULL');

      // 紧凑形态（DateTime.parse 原生接受）同样被严格正则拦截。
      final compact = OfflineMessageWriter.parseServerOrderFacts({
        'conv_seq': 8,
        'accepted_at': '20261001T000000Z',
      });
      expect(compact.acceptedAt, isNull, reason: '紧凑数字形态不静默接受');
    });

    test('带 zone 串仍接受：Z 与 +08:00 offset 归一到同一 UTC 毫秒', () {
      final expected = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;

      final zulu = OfflineMessageWriter.parseServerOrderFacts({
        'conv_seq': 9,
        'accepted_at': '2026-10-01T00:00:00Z',
      });
      expect(zulu.acceptedAt, expected);

      final offset = OfflineMessageWriter.parseServerOrderFacts({
        'conv_seq': 10,
        'accepted_at': '2026-10-01T08:00:00+08:00',
      });
      expect(offset.acceptedAt, expected, reason: '+08:00 offset 与 Z 指同一瞬间');
    });
  });

  // W8-A2：离线/归档写入侧 created_at（客户端原始发送时间）解析口径。
  // 修复前 rfc3339ToMillisecond 走裸 DateTime.parse——无 zone 串按设备
  // 本地时区解读（时区污染，P1 同款缺陷），解析抛异常虽被 catch 但依赖
  // try 兜底。修复后仅 ApiTime.parseIsoZoned 严格口径：无 zone 拒绝 → 0
  // （"无 created_at"既有哨兵，不伪造时间），带 zone 归一 UTC 毫秒。
  group('W8-A2 parseCreatedAt 严格口径（created_at 不猜时区）', () {
    test('带 Z 串归一为 UTC 毫秒', () {
      expect(
        OfflineMessageWriter.parseCreatedAt('2026-09-16T23:06:40.000Z'),
        DateTime.utc(2026, 9, 16, 23, 6, 40).millisecondsSinceEpoch,
      );
    });

    test('带 +08:00 offset 串与 Z 串归一到同一 UTC 毫秒', () {
      expect(
        OfflineMessageWriter.parseCreatedAt('2026-09-17T07:06:40+08:00'),
        DateTime.utc(2026, 9, 16, 23, 6, 40).millisecondsSinceEpoch,
        reason: '+08:00 offset 与 Z 指同一瞬间，与设备时区无关',
      );
    });

    test('无 zone 串拒绝（不猜设备本地时区）→ 0 走无 created_at 路径', () {
      // legacy DateTime.parse 会把该串按设备本地时区解读出非 0 值；
      // 修复后必须返回 0（该行走既有"无 created_at"路径，不伪造时间）。
      expect(OfflineMessageWriter.parseCreatedAt('2026-09-16T23:06:40'), 0);
    });

    test('null/非法串/紧凑形态 → 0；毫秒 int 与整数字符串直取', () {
      expect(OfflineMessageWriter.parseCreatedAt(null), 0);
      expect(OfflineMessageWriter.parseCreatedAt('garbage'), 0);
      expect(
        OfflineMessageWriter.parseCreatedAt('20260916T230640Z'),
        0,
        reason: '紧凑数字形态不静默接受',
      );
      expect(OfflineMessageWriter.parseCreatedAt(1750000000123), 1750000000123);
      expect(
        OfflineMessageWriter.parseCreatedAt('1750000000123'),
        1750000000123,
      );
    });
  });

  // W8-C2/C3：parseServerOrderFacts 权威序号/接受时刻的数值口径守卫。
  group('W8-C2/C3 parseServerOrderFacts 数值口径', () {
    test('conv_seq 非整 double 拒绝；可无损转 int 的 num 仍接受', () {
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'conv_seq': 1.5}).convSeq,
        isNull,
        reason: '1.5 截断成 1 属于伪造序号，与 ApiTime._parseIntLike 口径一致拒绝',
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'conv_seq': 2.0}).convSeq,
        2,
        reason: '2.0 可无损转 int，仍接受',
      );
    });

    test('accepted_at 非正数（0/负值/带符号串）拒绝，与 conv_seq 守卫对称', () {
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'accepted_at': 0})
            .acceptedAt,
        isNull,
        reason: '0=1970-01-01T00:00:00Z 不是合理的服务端接受时刻',
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'accepted_at': -5})
            .acceptedAt,
        isNull,
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'accepted_at': '0'})
            .acceptedAt,
        isNull,
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'accepted_at': '-5'})
            .acceptedAt,
        isNull,
        reason:
            '带符号串不匹配纯数字正则，经 parseEpochMillis 兜底解析为 -5，'
            '由终端兜底拒绝落列',
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({'accepted_at': 0.0})
            .acceptedAt,
        isNull,
        reason:
            '0.0 可无损转 int，经 parseEpochMillis 兜底解析为 0，'
            '同样拒绝落列',
      );
      expect(
        OfflineMessageWriter.parseServerOrderFacts({
          'accepted_at': 1750000000123,
        }).acceptedAt,
        1750000000123,
        reason: '正常正毫秒不受影响',
      );
    });
  });
}
