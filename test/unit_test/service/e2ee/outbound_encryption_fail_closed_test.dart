import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';

void main() {
  const service = ChatNetworkService();

  test(
    'required encryption with null result must reject instead of fallback',
    () {
      expect(
        () => service.requireEncryptedResultForTest(null),
        throwsA(
          isA<E2eeSecurityException>().having(
            (error) => error.reason,
            'reason',
            'encryption_required_not_applied',
          ),
        ),
      );
    },
  );

  test('encrypted result is passed through unchanged', () {
    final result = <String, dynamic>{
      'e2ee': <String, dynamic>{'meta_version': 3},
      'payload': 'ciphertext',
    };

    expect(service.requireEncryptedResultForTest(result), same(result));
  });
}
