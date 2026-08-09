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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
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
    user_id_sum INTEGER NOT NULL DEFAULT 0,
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
      final msgIds = await repo.batchInsertOfflineMessages(shaped);

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
      final msgIds = await repo.batchInsertOfflineMessages(shaped);
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

      await repo.batchInsertOfflineMessages(shaped);
      await repo.batchInsertOfflineMessages(shaped);

      final List<Map<String, Object?>> all = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM msg_c2c',
      );
      expect(
        (all.single['c'] as int?) ?? -1,
        1,
        reason: 'msg_id 去重：重复拉取不得重复落库',
      );
    });
  });
}
