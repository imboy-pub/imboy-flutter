// ADR 02 §4 / ADR 05 §4.2：发送侧必须通过 Protocol Registry，
// 并在双写期同时生成 v1 与 v2 metadata。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';

class _RecordingProtocol implements E2eeSessionProtocol {
  _RecordingProtocol(this._suite);

  final ProtocolSuite _suite;
  String? plaintext;
  List<RecipientDevice>? recipients;
  E2eeContext? context;

  @override
  ProtocolSuite get suite => _suite;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    this.plaintext = plaintext;
    this.recipients = recipients;
    this.context = context;
    return const E2eeCiphertext('ciphertext', {'session_id': 'session-1'});
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async => throw UnimplementedError();

  @override
  Future<void> clearAll() async {}
}

void main() {
  group('E2eeOutboundRouter', () {
    late _RecordingProtocol protocol;

    setUp(() {
      E2eeProtocolRegistry.resetForTest();
      protocol = _RecordingProtocol(ProtocolSuite.megolm);
      E2eeProtocolRegistry.register(protocol);
    });

    tearDown(E2eeProtocolRegistry.resetForTest);

    test('根据已选套件通过 Registry 调用协议 encrypt', () async {
      const recipient = RecipientDevice(
        deviceId: 'device-1',
        keyId: '',
        publicKey: '',
      );
      const context = E2eeContext(peerUid: 'peer-1', scope: 'c2c');

      final encrypted = await E2eeOutboundRouter.encrypt(
        suite: ProtocolSuite.megolm,
        plaintext: '{"text":"hello"}',
        recipients: const [recipient],
        context: context,
        createdAtMs: 123456,
      );

      expect(encrypted.ciphertext, 'ciphertext');
      expect(protocol.plaintext, '{"text":"hello"}');
      expect(protocol.recipients, const [recipient]);
      expect(protocol.context, same(context));
    });

    test('生成 ADR 05 双写信封并保留协议私有字段', () async {
      final encrypted = await E2eeOutboundRouter.encrypt(
        suite: ProtocolSuite.megolm,
        plaintext: 'hello',
        recipients: const [],
        context: const E2eeContext(gid: 'group-1', scope: 'c2g'),
        createdAtMs: 123456,
      );

      expect(encrypted.metadata, {
        'session_id': 'session-1',
        'e2ee': true,
        'e2ee_ver': 2,
        'e2ee_suite': 'MEGOLM.V1',
        'meta_version': 2,
        'protocol': 'megolm',
        'version': 1,
        'cipher': 'curve25519+ed25519+aes-256-gcm',
        'created_at': 123456,
      });
    });

    test('已选套件与 Registry 实现的三元组不一致时拒绝加密', () async {
      const mismatchedSuite = ProtocolSuite(
        'megolm',
        2,
        'curve25519+ed25519+chacha20-poly1305',
      );

      expect(
        () => E2eeOutboundRouter.encrypt(
          suite: mismatchedSuite,
          plaintext: 'hello',
          recipients: const [],
          context: const E2eeContext(gid: 'group-1', scope: 'c2g'),
          createdAtMs: 123456,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('suite mismatch'),
          ),
        ),
      );
    });
  });
}
