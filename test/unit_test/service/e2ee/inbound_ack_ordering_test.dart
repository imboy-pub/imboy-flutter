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
}
