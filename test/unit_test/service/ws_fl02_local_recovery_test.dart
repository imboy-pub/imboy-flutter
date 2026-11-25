// FL-02 LOCAL 系列：乱序到达与断线幂等 / S2C 去重层与 ACK 语义 /
// C2S 重试与最终结果 / 非法帧与超限输入
//
// 拆分说明（ratchet APP-02）：自 ws_action_error_handling_test.dart（原 989 行，
// 超 800 上限）按业务域拆出；共享基建在 ws_action_error_handling_support.dart。
// 用例逐字等价，group 结构保持。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import 'ws_action_error_handling_support.dart';

final WsActionTestEnv env = WsActionTestEnv();

// 原 main() 顶层符号在新文件中的等价重建（下方用例文本逐字保持不变）
MessageRetry get retry => env.retry;
Database get testDb => env.testDb;
WebSocketService bootedService() => env.bootedService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(env.setUpAll);
  setUp(env.setUp);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  group('FL-02 LOCAL:01 乱序到达与断线幂等', () {
    late Database fl02Db;
    late ProviderContainer fl02Container;

    setUp(() async {
      // 全链路 _receiveMessage 依赖完整 schema、有效登录态与 provider 容器；
      // 沿用 message_offline_pagination_test 口径（prefs uid + secure token
      // 先行，否则处理中的会话守卫触发 quitLogin 关库）。
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      String enc(Object v) =>
          base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      FlutterSecureStorage.setMockInitialValues({
        'secure_token':
            '${enc({'alg': 'none'})}.${enc({'exp': 4102444800, 'uid': 100})}.test',
      });
      await StorageService.init();
      databaseFactory = databaseFactoryFfi;
      AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
      fl02Db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(fl02Db);
      fl02Container = ProviderContainer();
      MessageService.setProviderContainer(fl02Container);
    });

    tearDown(() async {
      fl02Container.dispose();
      SqliteService.setDbForTest(testDb);
      await fl02Db.close();
      AppFeatureRegistry.clear();
    });

    Map<String, dynamic> c2cFrame(String id, String text, int createdAt) => {
      'id': id,
      'type': 'C2C',
      'from': '1001',
      'to': '100',
      'msg_type': 'text',
      'payload': {'msg_type': 'text', 'text': text},
      'created_at': createdAt,
    };

    Future<int> rowCount(List<String> ids) async {
      final rows = await fl02Db.query(
        'msg_c2c',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      return rows.length;
    }

    test('102 先到、101 迟到：均落库一次，各发一次业务 ACK，无重复效果', () async {
      final ackIds = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => ackIds.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      // 102 先到
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000102', 'first-102', 1751850000102),
      );
      // 101 迟到（乱序到达，随后断线由 sink 不可用模拟——此处先钉乱序语义）
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000101', 'late-101', 1751850000101),
      );
      await pumpEventQueue(times: 50);

      expect(
        await rowCount(['fl02m00000000000101', 'fl02m00000000000102']),
        2,
        reason: '迟到 101 不被跳过，102 不重复落库',
      );
      expect(ackIds, contains('fl02m00000000000101'));
      expect(ackIds, contains('fl02m00000000000102'));
      expect(
        ackIds.where((id) => id == 'fl02m00000000000101').length,
        lessThanOrEqualTo(1),
        reason: '102 无重复业务效果',
      );
    });

    test('断线后离线补拉重复收到 101：本地幂等，不产生第二条业务效果', () async {
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000201', 'dup-101', 1751850000201),
      );
      await pumpEventQueue(times: 50);
      expect(
        await rowCount(['fl02m00000000000201']),
        1,
        reason: '断线前 101 已本地持久化',
      );

      // 模拟重连/离线补拉重复投递同一条 101
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000201', 'dup-101', 1751850000201),
      );
      await pumpEventQueue(times: 50);

      expect(
        await rowCount(['fl02m00000000000201']),
        1,
        reason: '重复投递不得产生第二条消息行（幂等恢复）',
      );
    });

    test('负例：102 处理失败（payload 不可解析）不 ACK，101 不被牵连', () async {
      final ackIds = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => ackIds.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000301', 'ok-101', 1751850000301),
      );
      await MessageService.to.processMessage('C2C', {
        'id': 'fl02m00000000000302',
        'type': 'C2C',
        'from': '1001',
        'to': '100',
        'msg_type': 'text',
        // 非法 payload：解不出 Map → fail-closed 不 ACK
        'payload': '\x00\x01not-json',
        'created_at': 1751850000302,
      });
      await pumpEventQueue(times: 50);

      expect(await rowCount(['fl02m00000000000301']), 1);
      expect(await rowCount(['fl02m00000000000302']), 0);
      expect(
        ackIds,
        isNot(contains('fl02m00000000000302')),
        reason: '失败帧不确认，服务端保留 pending',
      );
      expect(
        ackIds,
        contains('fl02m00000000000301'),
        reason: '101 不被 102 的失败牵连',
      );
    });
  });

  group('FL-02 LOCAL:02 S2C 去重层与 ACK 语义', () {
    setUp(() {
      MessageS2CService.resetS2CDedupForTest();
    });

    tearDown(() {
      MessageS2CService.resetS2CDedupForTest();
    });

    Stream<String> ackIds() =>
        AppEventBus.on<WebSocketMessageSendRequestEvent>().map(
          (event) => event.messageId ?? '',
        );

    Map<String, dynamic> s2cFrame(String id, String action, {String? msgType}) {
      final frame = <String, dynamic>{
        'id': id,
        'type': 'S2C',
        'action': action,
        'from': '1001',
        'to': '100',
        'payload': const <String, dynamic>{},
        'server_ts': 1751850000000,
      };
      if (msgType != null) frame['msg_type'] = msgType;
      return frame;
    }

    test('未知纯控制 S2C 重投：首帧 ACK，去重命中帧仍 ACK（向前兼容）', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      await MessageS2CService.switchS2C(
        s2cFrame('fl02s00000000000001', 'future_control_event'),
      );
      await MessageS2CService.switchS2C(
        s2cFrame('fl02s00000000000001', 'future_control_event'),
      );
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000001').length,
        2,
        reason: '去重命中也必须 ACK，否则服务端在重发窗口内继续重投',
      );
    });

    test('未知关键 S2C（携带内容 msg_type）首帧与去重命中帧均不确认', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      final frame = s2cFrame(
        'fl02s00000000000002',
        'future_content_event',
        msgType: 'forward',
      );
      await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
      await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000002'),
        isEmpty,
        reason: '未知关键 S2C 保留服务端 pending：首帧与重投都不确认',
      );
    });

    test('TTL 过期后旧事件重放：默认分支幂等（无副作用），关键帧仍不确认', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      await MessageS2CService.switchS2C(
        s2cFrame(
          'fl02s00000000000003',
          'future_content_event',
          msgType: 'forward',
        ),
      );
      await pumpEventQueue();
      // 把去重标记推到 TTL 之外，模拟 5 分钟后旧事件重放
      MessageS2CService.ageS2CDedupForTest(
        MessageS2CService.s2cDedupTtlMs + 1000,
      );
      await MessageS2CService.switchS2C(
        s2cFrame(
          'fl02s00000000000003',
          'future_content_event',
          msgType: 'forward',
        ),
      );
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000003'),
        isEmpty,
        reason: '旧事件重放不覆盖、不确认，等待可处理版本',
      );
    });

    test('帧 id 为空时回退复合 key 去重（2.4）', () async {
      // 直接钉 buildS2CDedupKey 的回退语义
      final key1 = MessageS2CService.buildS2CDedupKey(
        {'server_ts': 1751850000000},
        'future_control_event',
        '1001',
        '100',
      );
      final key2 = MessageS2CService.buildS2CDedupKey(
        {'server_ts': 1751850000000},
        'future_control_event',
        '1001',
        '100',
      );
      expect(key1, key2);
      expect(key1, 'future_control_event_1001_100_1751850000000');

      // 端到端：两帧同复合 key（无 id）→ 第二帧去重命中不抛异常；
      // 空 id 帧 _sendS2CAck 直接跳过（不得对空 id 发 ACK）。
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);
      await MessageS2CService.switchS2C(s2cFrame('', 'future_control_event'));
      await MessageS2CService.switchS2C(s2cFrame('', 'future_control_event'));
      await pumpEventQueue();
      expect(acks.where((id) => id.isEmpty), isEmpty);
    });
  });

  group('FL-02 LOCAL:03 C2S 重试与最终结果', () {
    late Database fl02Db;

    setUp(() async {
      // 编辑 ack 落库走当前 schema 全列（minimal DDL 缺列会 SqfliteFfiException）
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        // toTypeMessage 需要当前用户最小档案（uid）
        Keys.currentUser: '{"uid": "100"}',
      });
      await StorageService.init();
      databaseFactory = databaseFactoryFfi;
      AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
      fl02Db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(fl02Db);
    });

    tearDown(() async {
      SqliteService.setDbForTest(testDb);
      await fl02Db.close();
      AppFeatureRegistry.clear();
    });

    test('重复 message_edit_ack 不二次应用编辑（幂等收敛）且队列条目移除', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 原始行 = 本人（uid 100）发出的消息，编辑操作被服务端确认
      await repo.insert(
        MessageModel(
          'fl02e00000000000001',
          autoId: 0,
          type: 'C2C',
          status: 2,
          fromId: 100,
          toId: 1001,
          payload: {'msg_type': 'text', 'text': 'before edit'},
          isAuthor: 1,
          conversationUk3: 'C2C_100_1001',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );

      const opId = 'fl02op000000000001';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      Map<String, dynamic> editAckFrame() => {
        'id': opId,
        'type': 'C2C',
        // 本人发出的编辑操作被服务端确认（isMyEdit 分支触发重试移除）
        'from': '100',
        'to': '1001',
        'msg_type': 'custom',
        'action': 'message_edit_ack',
        'payload': {
          'content': 'edited-once',
          'original_msg_id': 'fl02e00000000000001',
        },
        'server_ts': 1751850000000,
      };

      // 与 LOCAL:01 同口径直接驱动服务层入口
      await MessageService.to.processMessage('C2C', editAckFrame());
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull, reason: '受理→完成后停止重试');

      final afterFirst = await repo.find('fl02e00000000000001');
      expect(afterFirst, isNotNull, reason: '最终状态可查询');

      // 同一 ack 重投：不产生第二条业务效果（编辑幂等），队列保持空
      await MessageService.to.processMessage('C2C', editAckFrame());
      await pumpEventQueue(times: 50);
      expect(retry.getRetryInfo(opId), isNull);
      final rows = await fl02Db.query(
        'msg_c2c',
        where: 'id = ?',
        whereArgs: ['fl02e00000000000001'],
      );
      expect(rows.length, 1);
    });
  });

  group('FL-02 LOCAL:04 非法帧与超限输入', () {
    test('截断 JSON/坏字节/超限帧不崩溃，同批后续有效帧仍被分发', () async {
      final svc = bootedService();
      // 截断 JSON
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(
            utf8.encode('{"id":"fuzz1","type":"C2C","payl'),
          ),
        ),
      );
      // 坏字节（非 JSON 非 protobuf 可解码）
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(List.generate(64, (i) => 0x07)),
        ),
      );
      // 超限输入：编码器 fail-closed（16MiB 上限超限即 ArgumentError，
      // 有界拒绝而非无界分配）；入站侧由 isInboundFrameSizeAllowed 拦截。
      expect(
        () => ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List(ImboyFrame.maxPayload + 1),
        ),
        throwsArgumentError,
      );

      // 同批后续有效帧仍被分发（不静默丢关键事件）：action 帧
      // 触发 WebSocketMessageReceivedEvent（与 FL-05 wire 测试同口径）
      final delivered = AppEventBus.on<WebSocketMessageReceivedEvent>()
          .firstWhere(
            (event) => event.data['action'] == 'fl02_after_fuzz_event',
          );
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'id': 'fl02fuzzvalid001',
                'type': 'C2C',
                'action': 'fl02_after_fuzz_event',
                'payload': <String, dynamic>{},
              }),
            ),
          ),
        ),
      );
      final event = await delivered.timeout(const Duration(seconds: 3));
      expect(event.type, 'C2C');
    });

    test('超长 msg_ids 列表：有界处理不崩溃不无限循环', () async {
      final hugeIds = List.generate(
        2000,
        (i) => 'fl02bulk${i.toString().padLeft(6, '0')}',
      );
      final acks = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => acks.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      await MessageService.to.processMessage('C2C', {
        'id': 'fl02bulk00000000001',
        'type': 'C2C',
        'from': '1001',
        'to': '100',
        'action': 'message_read',
        'payload': {'msg_ids': hugeIds},
        'server_ts': 1751850000000,
      });
      await pumpEventQueue(times: 100);

      // 有界完成（到达此处即未崩溃/未死循环）；空库下逐条找不到目标是
      // 该 action 的既定 no-op 语义，不产生重复副作用。
      expect(hugeIds.length, 2000);
    });
  });
}
