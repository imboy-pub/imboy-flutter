import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/page/search/search_result_expiry.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/message.dart' show MessageService;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_schema.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/offline_message_payload.dart';
import 'package:imboy/modules/messaging/public.dart' show burnExpiresAtMs;

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// L-02 · 客户端删除、自毁与缓存防复活 —— 生命周期收敛门
///
/// 断言合同（control/local-gates.json#LOCAL-CARD-L-02）：
/// - L-02:LOCAL:01 原文不会因历史拉取或晚到回调重新出现
/// - L-02:LOCAL:02 退出/换账号后旧副本不可访问
///
/// 副本面与既有清理链（复用，不新建机制）：
/// - 本地消息副本：ChatBurnService.expireBurnMessage / findLatestVisibleMessageModel，
///   与 loadNewerMessages 分页清理链同一过期判据 isBurnExpiredAt。
/// - 搜索副本：MessageSearchResult.isVisibleAt / expiresAtMs（只收紧不放宽）；
///   本地 FTS 随 repo.delete 清空（message_fts_transaction_test 已锁定）。
/// - 引用快照副本：OfflineMessagePayload.redactQuoteForStoredSource /
///   deniedReplyUpdate / checkReplySource。
/// - 通知副本：服务端推送正文恒常量（notification_payload_rules_test C1 锁定），
///   登出经 AccountLocalDataService.clear → cancelAccount 全清，不重复断言。
/// - 缓存副本：会话末条 subtitle 经 updateConversationLastMessageAfterBurnHidden
///   重算；账号隔离经 AccountPreferences（account_preferences_test 已锁定基础
///   隔离，此处补墓碑账本保留期过期过滤与迟到回调负例）。

/// 合成 C2C 会话（uid=100 / peer=200）；测试内多处构造共用一份字段。
ConversationModel c2cConv({int id = 0, String lastMsgId = ''}) =>
    ConversationModel(
      id: id,
      peerId: '200',
      avatar: '',
      title: 'peer',
      subtitle: '',
      type: 'C2C',
      msgType: 'text',
      lastMsgId: lastMsgId,
      unreadNum: 0,
    );

/// 本地 FTS 副本命中计数（C2C 表）。
Future<int> ftsMatchCount(Database db, String word) async => (await db.rawQuery(
  'SELECT rowid FROM msg_c2c_fts WHERE msg_c2c_fts MATCH ?',
  [word],
)).length;

/// 按测试默认字段插入 C2C 文本消息（偏离默认时显式传参）。
Future<void> insertC2c(
  MessageRepo repo, {
  required String id,
  required int autoId,
  required String uk3,
  required Map<String, dynamic> payload,
  required int createdAt,
  int isAuthor = 0,
  int fromId = 200,
  int status = IMBoyMessageStatus.delivered,
}) => repo.insert(
  MessageModel(
    id,
    autoId: autoId,
    type: 'C2C',
    status: status,
    fromId: fromId,
    toId: 100,
    payload: payload,
    createdAt: createdAt,
    isAuthor: isAuthor,
    conversationUk3: uk3,
    msgType: 'text',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L-02:LOCAL:01 原文不会因历史拉取或晚到回调重新出现', () {
    group('本地消息副本：阅后即焚清理链（真实 ffi SQLite）', () {
      late Database db;

      setUp(() async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
      });

      tearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });

      /// 构造 C2C 会话并插入两条消息：一条已读到期的阅后即焚 + 一条普通文本。
      /// 返回 (conversation rowId, uk3)。
      Future<(int, String)> seedBurnedAndNormalMessages({
        required String burnId,
        required String normalId,
        required int burnReadAtMs,
      }) async {
        final uk3 = c2cConv().uk3;
        final inserted = await ConversationRepo().insert(
          c2cConv(lastMsgId: burnId),
        );
        final repo = MessageRepo(tableName: MessageRepo.c2cTable);
        await insertC2c(
          repo,
          id: burnId,
          autoId: 1,
          uk3: uk3,
          status: IMBoyMessageStatus.seen,
          payload: {
            'text': 'burn-original-text',
            'burn': true,
            'burn_after_ms': 5000,
            'burn_read_at': burnReadAtMs,
          },
          createdAt: burnReadAtMs - 60000,
        );
        await insertC2c(
          repo,
          id: normalId,
          autoId: 2,
          uk3: uk3,
          payload: {'text': 'normal-keep-text'},
          createdAt: burnReadAtMs + 1000,
        );
        await repo.waitForFtsReindexForTest();
        return (inserted, uk3);
      }

      test('已读到期焚毁：清理链出库、写墓碑、清搜索副本、会话末条不再显示原文', () async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final (convId, _) = await seedBurnedAndNormalMessages(
          burnId: 'bm-expire-1',
          normalId: 'nm-1',
          // 已读时间早已超过 burn_after_ms=5000 → 已过期
          burnReadAtMs: nowMs - 6000,
        );
        const burn = ChatBurnService();
        final prefs = AccountPreferences.capture();
        final repo = MessageRepo(tableName: MessageRepo.c2cTable);

        // 前置：消息在库、搜索副本已索引原文
        expect(await repo.find('bm-expire-1'), isNotNull);
        expect(await ftsMatchCount(db, 'burn_original_text'), 1);

        final removed = <String>[];
        await burn.expireBurnMessage(
          chatService: null,
          conversation: c2cConv(id: convId, lastMsgId: 'bm-expire-1'),
          messageId: 'bm-expire-1',
          preferences: prefs,
          isCurrent: () => true,
          onRemoveMessage: (_, message) async {
            removed.add(message.id);
            return true;
          },
        );

        // 1) 本地消息副本：行已出库
        expect(await repo.find('bm-expire-1'), isNull);
        // 2) 搜索副本（本地 FTS）：随 repo.delete 一并清除
        expect(await ftsMatchCount(db, 'burn_original_text'), 0);
        // 3) 墓碑账本：删除事实在保留期内可查询
        expect(
          await ChatBurnService.isMessageDeleted('bm-expire-1', prefs),
          isTrue,
        );
        // 4) 缓存副本（会话末条）：subtitle 收敛到剩余的普通消息，不残留原文
        final conv = await ConversationRepo().findById(convId);
        expect(conv, isNotNull);
        expect(conv!.lastMsgId, 'nm-1');
        expect(conv.subtitle, 'normal-keep-text');
        expect(conv.subtitle, isNot(contains('burn-original-text')));
        // 5) 会话末条可见性过滤：墓碑行/过期行不参与
        final latest = await burn.findLatestVisibleMessageModel(
          repo,
          c2cConv(id: convId),
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
        expect(latest?.id, 'nm-1');
        // 阅后即焚分支不走 onRemoveMessage（直接出库）
        expect(removed, isEmpty);
      });

      test('迟到重投（历史拉取写回同 id 同 payload）：发送方/已读接收方均被既有清理链再次摘除', () async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final (convId, _) = await seedBurnedAndNormalMessages(
          burnId: 'bm-redeliver-1',
          normalId: 'nm-2',
          burnReadAtMs: nowMs - 6000,
        );
        const burn = ChatBurnService();
        final prefs = AccountPreferences.capture();
        final repo = MessageRepo(tableName: MessageRepo.c2cTable);
        final conv = c2cConv(id: convId, lastMsgId: 'bm-redeliver-1');
        await burn.expireBurnMessage(
          chatService: null,
          conversation: conv,
          messageId: 'bm-redeliver-1',
          preferences: prefs,
          isCurrent: () => true,
          onRemoveMessage: (_, _) async => true,
        );
        expect(await repo.find('bm-redeliver-1'), isNull);

        // —— 迟到重投：与已焚毁版本同 id 同 payload 直接写回（历史拉取 fresh-insert
        // 的库层效果）。接收方 payload 携带已读时间戳（本机已读时已落库）。
        await insertC2c(
          repo,
          id: 'bm-redeliver-1',
          autoId: 3,
          uk3: 'synthetic-redeliver',
          payload: {
            'text': 'burn-original-text',
            'burn': true,
            'burn_after_ms': 5000,
            'burn_read_at': nowMs - 6000,
          },
          createdAt: nowMs - 66000,
        );
        await repo.waitForFtsReindexForTest();
        final redelivered = await repo.find('bm-redeliver-1');
        expect(redelivered, isNotNull);

        // 既有清理链判据（与 loadNewerMessages 分页清理同一函数）判定已过期，
        // 下一次分页/刷新经过时会再次摘除 —— 链收敛，原文不会存活。
        expect(
          burn.isBurnExpired(
            redelivered!.payloadMap,
            DateTime.now().millisecondsSinceEpoch,
            fallbackStartMs: redelivered.isAuthor == 1
                ? redelivered.createdAt
                : 0,
          ),
          isTrue,
        );
        await burn.expireBurnMessage(
          chatService: null,
          conversation: conv,
          messageId: 'bm-redeliver-1',
          preferences: prefs,
          isCurrent: () => true,
          onRemoveMessage: (_, _) async => true,
        );
        expect(await repo.find('bm-redeliver-1'), isNull);
        expect(await ftsMatchCount(db, 'burn_original_text'), 0);
        expect(
          await ChatBurnService.isMessageDeleted('bm-redeliver-1', prefs),
          isTrue,
        );

        // —— 发送方迟到重投：无已读时间戳，但 isAuthor=1 时以 createdAt 起算，
        // 重投即过期，同样被清理链摘除（BUG#139 语义）。
        await insertC2c(
          repo,
          id: 'bm-redeliver-2',
          autoId: 4,
          uk3: 'synthetic-redeliver',
          payload: {
            'text': 'sender-burn-text',
            'burn': true,
            'burn_after_ms': 5000,
          },
          createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
          isAuthor: 1,
          fromId: 100,
        );
        await repo.waitForFtsReindexForTest();
        final senderRow = await repo.find('bm-redeliver-2');
        expect(
          burn.isBurnExpired(
            senderRow!.payloadMap,
            DateTime.now().millisecondsSinceEpoch,
            fallbackStartMs: senderRow.createdAt,
          ),
          isTrue,
          reason: '发送方阅后即焚以发送时间起算，迟到重投必须立即判过期',
        );
      });

      test('接收方未读阅后即焚：无已读时间不焚烧也不伪造期限（迟到重投保持未读语义）', () async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final unreadPayload = {
          'text': 'unread-burn-text',
          'burn': true,
          'burn_after_ms': 5000,
          // 无 burn_read_at：接收方未读，无倒计时起点
        };
        expect(
          burnExpiresAtMs(unreadPayload),
          isNull,
          reason: '未读接收方不得伪造绝对期限（已读起点缺失时无 countdown）',
        );
        expect(
          ChatBurnService().isBurnExpired(
            unreadPayload,
            nowMs,
            fallbackStartMs: 0,
          ),
          isFalse,
        );
        // 落库验证：未读消息在库里保持可读（未焚毁才谈得上销毁）
        final repo = MessageRepo(tableName: MessageRepo.c2cTable);
        await insertC2c(
          repo,
          id: 'bm-unread-1',
          autoId: 5,
          uk3: 'synthetic-unread',
          payload: unreadPayload,
          createdAt: nowMs - 1000,
        );
        expect(await repo.find('bm-unread-1'), isNotNull);
      });

      test(
        'burn 墓碑行不是正文：findLatestVisibleMessageModel 跳过 burn_deleted 行',
        () async {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final uk3 = c2cConv().uk3;
          final repo = MessageRepo(tableName: MessageRepo.c2cTable);
          await insertC2c(
            repo,
            id: 'tomb-1',
            autoId: 6,
            uk3: uk3,
            payload: {'text': 'tombstone-carrying-text', 'burn_deleted': true},
            createdAt: nowMs - 1000,
          );
          await insertC2c(
            repo,
            id: 'tomb-2',
            autoId: 7,
            uk3: uk3,
            payload: {'text': 'live-after-tombstone'},
            createdAt: nowMs - 500,
          );
          await repo.waitForFtsReindexForTest();
          final latest = await ChatBurnService().findLatestVisibleMessageModel(
            repo,
            c2cConv(),
            nowMs: nowMs,
          );
          expect(latest?.id, 'tomb-2', reason: '墓碑行只携带删除事实，不得作为会话末条正文复活');
        },
      );

      group('入站 fresh-insert 墓账本守卫（message.dart §5-A 协调者例外授权修复）', () {
        Map<String, dynamic> inboundFrame(String id, String text) => {
          'id': id,
          'type': 'C2C',
          'from': '200',
          'to': '100',
          'msg_type': 'text',
          'payload': {'text': text},
          'created_at': DateTime.now().millisecondsSinceEpoch,
        };

        test('墓账本已命中：重投同 id 不插入、FTS 不含原文、墓账本保持、按已处理回 ACK', () async {
          const burn = ChatBurnService();
          final prefs = AccountPreferences.capture();
          await burn.recordDeletedMessageId('guard-hit-1', prefs);

          final consumed = await MessageService.instance.persistInboundMessage(
            inboundFrame('guard-hit-1', 'resurrect-attempt-text'),
          );

          expect(consumed, isTrue, reason: '已处理语义：上游照常 ACK，阻断服务端重投');
          final repo = MessageRepo(tableName: MessageRepo.c2cTable);
          expect(
            await repo.find('guard-hit-1'),
            isNull,
            reason: '墓账本命中的消息不得重新入库（防复活守卫）',
          );
          expect(await ftsMatchCount(db, 'resurrect_attempt_text'), 0);
          expect(
            await ChatBurnService.isMessageDeleted('guard-hit-1', prefs),
            isTrue,
            reason: '墓账本保持：删除事实不因重投被抹除',
          );
        });

        test('墓账本未命中：守卫放行，同一帧继续走正常入站链（对照）', () async {
          // 未命中（无墓碑）时守卫必须放行。用缺 payload 的帧让链路在守卫
          // 之后的既有 payload==null 早退处结束 —— 单测密闭（完整入站链的
          // 落库+FTS 同步由上方 repo 层用例与既有仓级测试覆盖：守卫命中/未
          // 命中之外零代码改动，git diff 仅 +14 行）。
          final proceeded = await MessageService.instance.persistInboundMessage(
            {...inboundFrame('guard-miss-1', 'irrelevant'), 'payload': null},
          );

          expect(
            proceeded,
            isFalse,
            reason:
                'false 必须来自既有 payload 校验：若守卫误拦截（墓账本'
                '未命中却返回 true），此断言即失败',
          );
          final repo = MessageRepo(tableName: MessageRepo.c2cTable);
          expect(await repo.find('guard-miss-1'), isNull);
        });
      });
    });

    group('搜索副本：远端结果与本地事实收敛（晚到回调只能收紧期限）', () {
      MessageSearchResult result({
        Map<String, dynamic>? payload,
        int? status,
        int? knownExpiresAtMs,
        int? isAuthor,
        String fromId = '200',
      }) {
        return MessageSearchResult(
          id: 'sr-1',
          content: 'searchable-text',
          fromId: fromId,
          toId: '100',
          type: 'C2C',
          createdAt: 1700000000000,
          payload: payload ?? {'text': 'searchable-text'},
          status: status ?? IMBoyMessageStatus.delivered,
          isAuthor: isAuthor,
          knownExpiresAtMs: knownExpiresAtMs,
        );
      }

      test('burn_deleted / 撤回状态区间 / 已过期期限：isVisibleAt 全部拒绝', () {
        final nowMs = 1700000100000;
        expect(
          result(payload: {'text': 'x', 'burn_deleted': true})
              .isVisibleAt(nowMs, '100'),
          isFalse,
          reason: '焚毁墓碑行对搜索不可见',
        );
        expect(
          result(status: IMBoyMessageStatus.peerRevoked)
              .isVisibleAt(nowMs, '100'),
          isFalse,
          reason: '撤回状态区间 30..39 对搜索不可见',
        );
        expect(
          result(
            payload: {
              'text': 'x',
              'burn': true,
              'burn_after_ms': 5000,
              'burn_read_at': 1700000000000,
            },
            isAuthor: 0,
          ).isVisibleAt(nowMs, '100'),
          isFalse,
          reason: '已读期限（已读+5000ms）已过 → 不可见',
        );
      });

      test('晚到回调只能收紧不能放宽已观察到的期限', () {
        expect(
          result(
            payload: {
              'text': 'x',
              'burn': true,
              'burn_after_ms': 6500,
              'burn_read_at': 0,
            },
            knownExpiresAtMs: 16000,
          ).expiresAtMs('100'),
          16000,
          reason: '未读接收方无 payload 期限时保留服务端绝对期限',
        );
        expect(
          result(
            payload: {
              'text': 'x',
              'burn': true,
              'burn_after_ms': 5000,
              'burn_read_at': 1700000000000,
            },
            knownExpiresAtMs: 1700000000000 + 4000,
          ).expiresAtMs('100'),
          1700000000000 + 4000,
          reason: '晚到 payload 的期限晚于已观察期限 → 不得放宽',
        );
        expect(
          result(
            payload: {
              'text': 'x',
              'burn': true,
              'burn_after_ms': 3000,
              'burn_read_at': 1700000000000,
            },
            knownExpiresAtMs: 1700000000000 + 9000,
          ).expiresAtMs('100'),
          1700000000000 + 3000,
          reason: 'payload 期限更早 → 取更早者（收紧方向）',
        );
      });

      test('发送方本人视角：无已读时间以发送时间起算；接收方视角不补造期限', () {
        final createdAt = 1700000000000;
        final payload = {'text': 'x', 'burn': true, 'burn_after_ms': 5000};
        expect(
          result(payload: payload, isAuthor: 1).expiresAtMs('100'),
          createdAt + 5000,
          reason: '发送方以 createdAt 起算（BUG#139）',
        );
        expect(
          result(payload: payload, isAuthor: 0).expiresAtMs('100'),
          isNull,
          reason: '接收方未读：不能补造期限，更不能因此判可见倒计时',
        );
      });
    });

    group('引用快照副本：撤回/拒答后迟到回调不复活被引原文', () {
      late Database db;

      setUp(() async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
      });

      tearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });

      Future<void> insertSourceRow({
        required String id,
        required int status,
      }) async {
        await db.insert(MessageRepoSchema.c2cTable, {
          'id': id,
          'type': 'C2C',
          'status': status,
          'conversation_uk3': 'synthetic-quote',
          'msg_type': 'text',
          'payload': '{"text":"quoted-source-body"}',
        });
      }

      Map<String, dynamic> quotePayload({required String sourceId}) => {
        'text': 'reply-body',
        'quote_msg': {'id': sourceId, 'text': 'quoted-source-body'},
        'quote_msg_author_name': '源作者',
      };

      test('被引原消息已撤回：入库前剥离引用快照（迟到正文不复活被引原文）', () async {
        await insertSourceRow(id: 'src-revoked-1', status: 30);
        final redacted = await OfflineMessagePayload.redactQuoteForStoredSource(
          db,
          quotePayload(sourceId: 'src-revoked-1'),
          'synthetic-quote',
        );
        expect(redacted.containsKey('quote_msg'), isFalse);
        expect(redacted.containsKey('quote_msg_author_name'), isFalse);
        expect(redacted['text'], 'reply-body');
      });

      test('被引原消息未撤回：快照保留（不过度清洗）', () async {
        await insertSourceRow(id: 'src-live-1', status: 20);
        final kept = await OfflineMessagePayload.redactQuoteForStoredSource(
          db,
          quotePayload(sourceId: 'src-live-1'),
          'synthetic-quote',
        );
        expect((kept['quote_msg'] as Map)['id'], 'src-live-1');
      });

      test('无本地库时可核验性缺失即剥离快照（不猜）', () async {
        final redacted = await OfflineMessagePayload.redactQuoteForStoredSource(
          null,
          quotePayload(sourceId: 'src-any'),
          'synthetic-quote',
        );
        expect(redacted.containsKey('quote_msg'), isFalse);
      });

      test('拒答信封（reply_source_id=null）：剥离已存快照；伪造快照（id 不符）同样剥离', () {
        final stored = <String, Object?>{
          'type': 'C2C',
          'msg_type': 'quote',
          'from_id': '200',
          'to_id': '100',
          'payload': jsonEncode(quotePayload(sourceId: 'src-denied-1')),
        };
        // 服务端显式拒答：reply_source_id 置 null → 存量快照必须剥离
        final update = OfflineMessagePayload.deniedReplyUpdate(stored, {
          'reply_source_id': null,
          'msg_type': 'quote',
          'from': '200',
          'to': '100',
        });
        expect(update, isNot(isEmpty));
        final stripped =
            jsonDecode(update['payload']! as String) as Map<String, dynamic>;
        expect(stripped.containsKey('quote_msg'), isFalse);

        // 拒答信封外层为空（不含该键）→ 不产生更新
        expect(
          OfflineMessagePayload.deniedReplyUpdate(stored, {
            'msg_type': 'quote',
            'from': '200',
            'to': '100',
          }),
          isEmpty,
        );

        // 迟到伪造：信封声明的来源 id 与快照不一致 → 剥离伪造快照
        final forged = OfflineMessagePayload.checkReplySource(
          quotePayload(sourceId: 'src-forged'),
          {'reply_source_id': 'src-authoritative'},
          OfflineMessagePayload.replySourceWireKey,
        );
        expect(forged.containsKey('quote_msg'), isFalse);

        // 一致的合法快照保留
        final legit = OfflineMessagePayload.checkReplySource(
          quotePayload(sourceId: 'src-authoritative'),
          {'reply_source_id': 'src-authoritative'},
          OfflineMessagePayload.replySourceWireKey,
        );
        expect((legit['quote_msg'] as Map)['id'], 'src-authoritative');
      });
    });

    group('后台/刷新：SearchResultExpiry 恢复前台重核验，过期结果不滞留', () {
      test('已知期限已过：schedule 立即触发 onExpired（不再等下一个整点）', () async {
        var fired = 0;
        final expiry = SearchResultExpiry(() => fired += 1, nowMs: () => 1000);
        addTearDown(expiry.dispose);
        expiry.schedule([900]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(fired, 1, reason: '已过期结果的回调必须立即执行');
      });

      test('无可判定期限（接收方未读）：不排计时器，不伪造倒计时', () async {
        var fired = 0;
        final expiry = SearchResultExpiry(() => fired += 1, nowMs: () => 1000);
        addTearDown(expiry.dispose);
        expiry.schedule(const [null, null]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(fired, 0, reason: '未知期限不得凭空产生销毁回调');
      });

      test('dispose 后回调不触发', () async {
        var fired = 0;
        final expiry = SearchResultExpiry(() => fired += 1, nowMs: () => 1000);
        expiry.schedule([1100]);
        expiry.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(fired, 0);
      });

      test('恢复前台（resumed）：重核验回调触发，防止后台期间过期结果滞留', () {
        var expired = 0;
        var resumed = 0;
        final expiry = SearchResultExpiry(
          () => expired += 1,
          onResume: () => resumed += 1,
          nowMs: () => 1000,
        );
        addTearDown(expiry.dispose);
        expiry.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(resumed, 1, reason: 'resume 必须触发重核验');
        expect(expired, 0, reason: '提供 onResume 时 resume 不应复用 expired 回调');
        expiry.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(resumed, 1, reason: 'paused 不触发重核验（计数不得变化）');
      });

      test('未提供 onResume 时 resume 退化为过期重核验（既有合同）', () {
        var expired = 0;
        final expiry = SearchResultExpiry(
          () => expired += 1,
          nowMs: () => 1000,
        );
        addTearDown(expiry.dispose);
        expiry.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(expired, 1);
      });
    });
  });

  group('L-02:LOCAL:02 退出/换账号后旧副本不可访问', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: 'acc-a'});
      await StorageService.init();
    });

    test('墓碑账本按账号隔离：换账号后旧账号删除事实不可读，迟到写入不落任何账号', () async {
      const burn = ChatBurnService();
      final a = AccountPreferences.capture();
      await burn.recordDeletedMessageId('msg-a', a);
      expect(
        await ChatBurnService.isMessageDeleted('msg-a', a),
        isTrue,
        reason: '本账号内保留期内的删除事实可查询',
      );

      // 换账号：B 会话内 A 的删除事实不可读
      await StorageService.to.setString(Keys.currentUid, 'acc-b');
      final b = AccountPreferences.capture();
      expect(
        await ChatBurnService.isMessageDeleted('msg-a', b),
        isFalse,
        reason: '旧账号的墓碑对新账号不可访问',
      );

      // 迟到回调：A 的陈旧 preferences 不再把写入落进任何账号账本
      await burn.recordDeletedMessageId('late-a', a);
      final aScoped = StorageService.to.getStringList(
        a.owner.preferenceKey(ChatBurnService.deletedMessageIdsKey),
      );
      expect(
        aScoped!.where((entry) => entry.startsWith('late-a')),
        isEmpty,
        reason: '会话失效后的迟到销毁回调不得重建账本数据',
      );

      // B 正常记账；A 的过期清理不得触碰 B 的账本
      await burn.recordDeletedMessageId('msg-b', b);
      await burn.cleanupDeletedMessageIds(a);
      expect(await ChatBurnService.isMessageDeleted('msg-b', b), isTrue);
    });

    test('墓碑保留期过期过滤：超过 24h 的删除事实不再可查询，清理只摘过期项', () async {
      const burn = ChatBurnService();
      final prefs = AccountPreferences.capture();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.writeList(ChatBurnService.deletedMessageIdsKey, [
        'old-id:${nowMs - ChatBurnService.deletedMessageRetentionMs - 60000}',
        'fresh-id:$nowMs',
      ]);

      expect(
        await ChatBurnService.isMessageDeleted('old-id', prefs),
        isFalse,
        reason: '保留期外不再用墓碑拦截重投（24h 后交回服务端权威事实）',
      );
      expect(await ChatBurnService.isMessageDeleted('fresh-id', prefs), isTrue);

      await burn.cleanupDeletedMessageIds(prefs);
      final remaining = StorageService.to.getStringList(
        prefs.owner.preferenceKey(ChatBurnService.deletedMessageIdsKey),
      );
      expect(remaining, hasLength(1));
      expect(remaining!.first, startsWith('fresh-id:'));
    });

    test('账号切换后的旧账号数据指纹不再匹配新会话（storageDigest 隔离）', () {
      final a = AccountPreferences.capture();
      final aKey = a.owner.preferenceKey(ChatBurnService.deletedMessageIdsKey);
      // 换账号（同端点同环境不同 uid）
      StorageService.to.setString(Keys.currentUid, 'acc-b');
      final b = AccountPreferences.capture();
      expect(
        b.owner.preferenceKey(ChatBurnService.deletedMessageIdsKey),
        isNot(aKey),
        reason: '不同账号的墓碑账本物理上是不同 key，退出/换账号后旧副本不可经新会话读取',
      );
      expect(a.isCurrent, isFalse, reason: '旧会话快照立即失效');
    });
  });
}
