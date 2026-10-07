import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/offline_message_payload.dart';

void main() {
  test('ciphertext and PFv3 empty payload remain unchanged', () {
    for (final cipher in ['nonce.ciphertext', '']) {
      final decoded = OfflineMessagePayload.decode({
        'payload': cipher,
        'e2ee': {'protocol': 'pfv3'},
      }, trustedArchive: false);
      expect(decoded.rawCipher, cipher);
      expect(decoded.payload, isEmpty);
    }
  });

  test(
    'JSON plaintext preserves content; non-object values preserve raw bytes',
    () {
      final plaintext = OfflineMessagePayload.decode({
        'payload': '{"text":"hello"}',
      }, trustedArchive: false);
      expect(plaintext.payload, {'text': 'hello'});
      expect(plaintext.rawCipher, isNull);
      for (final raw in ['42', '[1,2]', 'null']) {
        expect(
          OfflineMessagePayload.decode({
            'payload': raw,
          }, trustedArchive: false).rawCipher,
          raw,
        );
      }
    },
  );

  test('untrusted envelope cannot inject archive sequence or mutate input', () {
    final metadata = {'protocol': 'megolm', '_archive_conv_seq': 999};
    final decoded = OfflineMessagePayload.decode({
      'e2ee': metadata,
      'conv_seq': 7,
    }, trustedArchive: false);
    expect(decoded.encryption, {'protocol': 'megolm'});
    expect(metadata['_archive_conv_seq'], 999);
  });

  test('only trusted positive envelope sequence is adopted', () {
    for (final sequence in [7, '7', 0, -1, 'bad', null]) {
      final decoded = OfflineMessagePayload.decode({
        'e2ee': {'protocol': 'megolm', '_archive_conv_seq': 999},
        'conv_seq': sequence,
      }, trustedArchive: true);
      expect(
        (decoded.encryption as Map)['_archive_conv_seq'],
        sequence == 7 || sequence == '7' ? 7 : null,
      );
    }
  });
}
