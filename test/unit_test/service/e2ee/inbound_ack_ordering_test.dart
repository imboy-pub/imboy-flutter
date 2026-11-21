library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String originalDeviceId;

  setUp(() {
    originalDeviceId = init.deviceId;
    init.deviceId = 'ack-order-device';
  });

  tearDown(() {
    AckManager.to.dispose();
    init.deviceId = originalDeviceId;
  });

  test('action 处理成功后才发送 transport ACK', () async {
    const messageId = 'action-success-001';
    final ackFuture = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .where((event) => event.messageId == messageId)
        .first;

    await MessageService.to.processMessage('C2C', {
      'id': messageId,
      'type': 'C2C',
      'action': 'future-compatible-action',
    });

    final ack = await ackFuture.timeout(const Duration(seconds: 1));
    expect(ack.message, 'CLIENT_ACK,C2C,$messageId,ack-order-device');
  });

  test('action 持久化失败不得发送 transport ACK', () async {
    const messageId = 'action-failure-001';
    final ackCompleter = Completer<void>();
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .where((event) => event.messageId == messageId)
        .listen((_) => ackCompleter.complete());
    addTearDown(subscription.cancel);

    await MessageService.to.processMessage('C2C', {
      'id': messageId,
      'type': 'C2C',
      'from': 'peer-1',
      'action': 'message_reaction',
      'payload': {
        'original_msg_id': 'missing-db-row',
        'emoji': 'ok',
        'user_id': 'peer-1',
      },
    });

    await expectLater(
      ackCompleter.future.timeout(const Duration(milliseconds: 100)),
      throwsA(isA<TimeoutException>()),
    );
  });

  group('FL-02 LOCAL:04 未知 action 确认边界', () {
    test('未知纯控制 action（无内容 msg_type）维持向前兼容回 ACK', () async {
      const messageId = 'fl02-unknown-control-001';
      final ackFuture = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .where((event) => event.messageId == messageId)
          .first;

      await MessageService.to.processMessage('C2C', {
        'id': messageId,
        'type': 'C2C',
        'action': 'future-compatible-control',
      });

      final ack = await ackFuture.timeout(const Duration(seconds: 1));
      expect(ack.message, 'CLIENT_ACK,C2C,$messageId,ack-order-device');
    });

    test('未知关键 action（携带内容 msg_type）不确认，保留服务端 pending', () async {
      // 历史事故形状：msg_type=forward + action=forward（服务端缺陷组合）。
      // 此前整条消息被 action 分发吞掉且照常回 ACK——收发双方都不知情。
      const messageId = 'fl02-unknown-content-001';
      final ackCompleter = Completer<void>();
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .where((event) => event.messageId == messageId)
          .listen((_) => ackCompleter.complete());
      addTearDown(subscription.cancel);

      await MessageService.to.processMessage('C2C', {
        'id': messageId,
        'type': 'C2C',
        'from': 'peer-1',
        'msg_type': 'forward',
        'action': 'forward',
        'payload': {'msg_type': 'forward', 'text': '被吞的内容'},
      });

      await expectLater(
        ackCompleter.future.timeout(const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()),
        reason: '未知关键 action 不得回 ACK（服务端保留 pending 待恢复）',
      );
    });
  });

  group('FL-02 LOCAL:03 流式 ephemeral 入口短路', () {
    test('stream_delta 同 id 多帧均触发事件、绕过接收去重、不回 ACK', () async {
      const streamId = 'fl02-stream-001';
      final deltas = <DataWrapperEvent<dynamic>>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>()
          .where((event) => event.dataType == 'stream_delta')
          .listen(deltas.add);
      addTearDown(subscription.cancel);
      final ackCompleter = Completer<void>();
      final ackSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .where((event) => event.messageId == streamId)
          .listen((_) => ackCompleter.complete());
      addTearDown(ackSubscription.cancel);

      Map<String, dynamic> frame(String chunk) => <String, dynamic>{
        'id': streamId,
        'type': 'C2C',
        'msg_type': 'stream_delta',
        'payload': {'stream_id': streamId, 'delta': chunk},
      };
      await MessageService.to.processMessage('C2C', frame('a'));
      await MessageService.to.processMessage('C2C', frame('b'));

      await pumpEventQueue();
      expect(deltas.length, 2, reason: '同 id 多帧不得被 _receiveMessage 去重丢弃');
      await expectLater(
        ackCompleter.future.timeout(const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()),
        reason: 'ephemeral 帧无 durable 业务效果，不产生业务 ACK',
      );
    });

    test('agent_task 过渡态帧同样入口短路（不落库语义）', () async {
      const taskId = 'fl02-agent-task-001';
      final events = <DataWrapperEvent<dynamic>>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>()
          .where((event) => event.dataType == 'agent_task')
          .listen(events.add);
      addTearDown(subscription.cancel);

      await MessageService.to.processMessage('C2C', {
        'id': taskId,
        'type': 'C2C',
        'msg_type': 'agent_task',
        'payload': {'task_id': taskId, 'status': 'running'},
      });

      await pumpEventQueue();
      expect(events.length, 1);
    });
  });
}
