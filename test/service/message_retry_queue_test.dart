import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';

void main() {
  group('MessageRetry queue behavior', () {
    late MessageRetry retry;

    setUp(() {
      retry = MessageRetry.instance;
      retry.clearRetryQueue();
    });

    tearDown(() {
      retry.dispose();
    });

    test('normalizes queue message type', () {
      retry.addToRetryQueue('msg_type_1', 'msg_c2c');
      retry.addToRetryQueue('msg_type_2', 'c2g');

      expect(retry.getRetryInfo('msg_type_1')?.type, 'C2C');
      expect(retry.getRetryInfo('msg_type_2')?.type, 'C2G');
    });

    test('duplicate enqueue keeps existing retry state', () {
      retry.addToRetryQueue('msg_dup', 'c2c');
      final original = retry.getRetryInfo('msg_dup');
      expect(original, isNotNull);

      original!.retryCount = 2;
      original.lastRetryTime = 12345;

      retry.addToRetryQueue('msg_dup', 'c2g');
      final after = retry.getRetryInfo('msg_dup');

      expect(retry.retryQueueSize, 1);
      expect(after, isNotNull);
      expect(after!.type, 'C2C');
      expect(after.retryCount, 2);
      expect(after.lastRetryTime, 12345);
    });

    test('remove event drops message from retry queue', () async {
      retry.addToRetryQueue('msg_rm', 'C2C');
      expect(retry.getRetryInfo('msg_rm'), isNotNull);

      AppEventBus.fire(
        const RemoveFromRetryQueueRequestedEvent(
          messageId: 'msg_rm',
          messageType: 'C2C',
          reason: 'test',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 60));
      expect(retry.getRetryInfo('msg_rm'), isNull);
    });
  });
}
