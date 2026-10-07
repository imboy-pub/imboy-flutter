import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_s2c.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline read sync failures propagate on every retry of the same frame',
    () async {
      final frame = <String, dynamic>{
        'id': 'offline_failed_read_sync_probe',
        'type': 'S2C',
        'action': 'message_read_sync',
        'payload': {
          'conversation_type': 'C2C',
          'peer': '995012',
          'msg_ids': ['116835000000000001'],
        },
      };
      // No application ProviderContainer is installed: the real handler fails.
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          MessageS2CService.switchS2C(frame, propagateErrors: true),
          throwsA(isA<AssertionError>()),
        );
      }
    },
  );
}
