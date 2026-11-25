// 服务端操作拒绝帧（message_revoke_error / message_edit_error）客户端闭环
//
// 契约（plan-v2.2 wave2，对应 J18.d 拒绝分支）：
//   - 后端 msg_c2c_logic.erl / msg_c2g_logic.erl 对超窗/fail-closed 的撤回、
//     编辑请求下发 {reply, ErrorMsg}：id = 客户端操作帧自身 id（与
//     MessageRetry 队列 key 同源）、payload.original_msg_id = 原消息 id、
//     payload.error = 拒绝原因文案。
//   - 客户端发送方在 *_ack 到达前不做乐观写库（气泡转已撤回/已编辑均在
//     MessageActions 的 ack 分支落库），故失败闭环 = 停止重试 + 用户提示，
//     原消息行无需回滚。
//   - error 帧不是 *_ACK：ws_ack_forward_policy 的 isAckSwallowedByTransport
//     对 *_ERROR 天然放行（不扩例外集），帧照常转发 MessageService——
//     integration_test/chat/j18d_edit_window_test.dart 依赖该管道监听
//     message_edit_error。
//
// 拆分说明（ratchet APP-02）：本文件原 989 行超 800 上限，按业务域拆为
// error 帧闭环契约（本文件）与 FL-02 LOCAL 系列（ws_fl02_local_recovery_test.dart），
// 共享基建在 ws_action_error_handling_support.dart。用例逐字等价。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/ws_ack_forward_policy.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'ws_action_error_handling_support.dart';

final WsActionTestEnv env = WsActionTestEnv();

// 原 main() 顶层符号在新文件中的等价重建（下方用例文本逐字保持不变）
MessageRetry get retry => env.retry;
WebSocketService bootedService() => env.bootedService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(env.setUpAll);
  setUp(env.setUp);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  group('传输层放行契约（ws_ack_forward_policy 不吞 *_ERROR）', () {
    test('*_ERROR 不属于 *_ACK 吞没规则，ACK 规则本身不变', () {
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE_ERROR'), isFalse);
      expect(isAckSwallowedByTransport('MESSAGE_EDIT_ERROR'), isFalse);
      // 对照：既有吞没/放行语义不变（REVOKE/EDIT ACK 均在例外集内放行）
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE_ACK'), isFalse);
      expect(isAckSwallowedByTransport('MESSAGE_EDIT_ACK'), isFalse);
      expect(isAckSwallowedByTransport('CLIENT_ACK_CONFIRM'), isTrue);
      expect(isAckSwallowedByTransport('SOME_OTHER_ACK'), isTrue);
    });

    test('message_edit_error 继续转发 MessageService（J18.d 监听管道）', () async {
      final svc = bootedService();
      final forwarded = AppEventBus.on<WebSocketMessageReceivedEvent>()
          .firstWhere((event) => event.data['action'] == 'message_edit_error');
      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_edit_error',
            opMsgId: 'op00000000000000fwd1',
            type: 'C2C',
            originalMsgId: 'orig00000000000000fwd1',
          ),
        ),
      );
      final event = await forwarded.timeout(const Duration(seconds: 3));
      expect(event.type, 'C2C');
      expect(
        event.data['payload']['original_msg_id'],
        'orig00000000000000fwd1',
      );
    });
  });

  group('error 帧停止重试（MessageRetry 队列条目移除）', () {
    test('message_revoke_error 移除对应操作帧的重试条目', () async {
      final svc = bootedService();
      const opId = 'rev00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_revoke_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000rev1',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });

    test('message_edit_error 移除对应操作帧的重试条目', () async {
      final svc = bootedService();
      const opId = 'edt00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000edt1',
            errorText: '超过编辑时间限制',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });

    test('C2G 类型的 message_edit_error 同样停止重试', () async {
      final svc = bootedService();
      const opId = 'c2g00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2G');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2G',
            originalMsgId: 'orig00000000000000c2g1',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });
  });

  group('本地状态保持与会话一致性', () {
    test('error 帧不修改原消息行，移除事件携带当前会话身份', () async {
      final svc = bootedService();
      const originalId = 'orig00000000000000keep1';
      const opId = 'kep00000000000000stop1';
      await wsInsertMsg(originalId, status: IMBoyMessageStatus.sent);

      final removals = <RemoveFromRetryQueueRequestedEvent>[];
      final removalReceived = Completer<void>();
      final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .listen((event) {
            removals.add(event);
            if (event.messageId == opId && !removalReceived.isCompleted) {
              removalReceived.complete();
            }
          });
      addTearDown(subscription.cancel);

      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: originalId,
          ),
        ),
      );
      await removalReceived.future.timeout(const Duration(seconds: 3));

      // 本地无乐观写库：error 帧不得碰原消息行（原文展示即"恢复"）
      final msg = await MessageRepo(tableName: MessageRepo.c2cTable)
          .find(originalId);
      expect(msg, isNotNull);
      expect(msg!.status, IMBoyMessageStatus.sent);
      expect(msg.payload['text'], 'hi');

      // 移除事件与 MessageRetry 消费侧的会话校验（_isRemovalSessionCurrent）
      // 对齐，否则停重试会被静默拒绝
      expect(removals, hasLength(1));
      expect(removals.single.messageId, opId);
      expect(removals.single.reason, 'ws_action_error');
      expect(removals.single.ownerUid, '100');
      expect(
        removals.single.sessionGeneration,
        UserRepoLocal.to.sessionGeneration,
      );
    });
  });

  group('容错', () {
    test('未知 request_id 的 error 帧不崩溃、队列保持为空', () async {
      final svc = bootedService();
      const unknownId = 'unk00000000000000err1';
      const malformedId = 'unk00000000000000err2';

      final removals = <RemoveFromRetryQueueRequestedEvent>[];
      final removalsDone = Completer<void>();
      final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .listen((event) {
            removals.add(event);
            if (!removalsDone.isCompleted &&
                removals.any((event) => event.messageId == unknownId) &&
                removals.any((event) => event.messageId == malformedId)) {
              removalsDone.complete();
            }
          });
      addTearDown(subscription.cancel);

      // 队列里没有该 id；payload 缺 error 字段（后端 C2G 编辑 error 不带 content）
      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_edit_error',
            opMsgId: unknownId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000unk1',
            errorText: null,
          ),
        ),
      );
      // payload 非 Map 的畸形变体同样不得抛出
      svc.handleV2BinaryForTest(
        wsS2cFrame(
          wsActionErrorFrame(
            action: 'message_revoke_error',
            opMsgId: malformedId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000unk1',
            payloadOverride: 'not-a-map',
          ),
        ),
      );
      // 两帧都要等待 SQLite FFI 事务完成，固定轮次的事件循环让步不足以同步。
      await removalsDone.future.timeout(const Duration(seconds: 3));

      expect(retry.getRetryInfo(unknownId), isNull);
      expect(removals, hasLength(2));
      expect(
        removals.map((event) => event.messageId),
        unorderedEquals([unknownId, malformedId]),
      );
      for (final event in removals) {
        expect(event.reason, 'ws_action_error');
        expect(event.ownerUid, '100');
        expect(event.sessionGeneration, UserRepoLocal.to.sessionGeneration);
      }
      expect(retry.getRetryInfo(malformedId), isNull);
    });
  });
}
