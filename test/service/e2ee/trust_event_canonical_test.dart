import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/trust_event_canonical.dart';

/// Golden 向量取自后端真实输出（imboy/src/logic/e2ee_trust_logic.erl
/// canonical_payload/1，同一确定性输入）：
///   erl -eval 'canonical_payload(#{...}) -> base64/sha256'
/// 见 docs/e2ee/v2/evidence/E2EE-014-C-codec.md。
const _goldenB64 =
    'YWN0b3JfZGV2aWNlX2dlbmVyYXRpb249MQphY3Rvcl91aWQ9MTAwCmV2ZW50X2lkPTNiMWUwYzRh'
    'LTVmMmQtNGExYi05YzNlLTdkOGYwYTFiMmMzZApleHBpcmVzX2F0PTE3MDAwMDAwNjAwMDAKZnJv'
    'bV9zdGF0ZT11bnZlcmlmaWVkCmlzc3VlZF9hdD0xNzAwMDAwMDAwMDAwCnRhcmdldF9kZXZpY2Vf'
    'aWQ9cGhvbmUtYgp0YXJnZXRfZWQyNTUxOT1aV1F0WWc9PQp0YXJnZXRfaWRlbnRpdHlfdmVyc2lv'
    'bj0xCnRhcmdldF91aWQ9MjAwCnRvX3N0YXRlPXZlcmlmaWVk';
const _goldenSha256Hex =
    'e8fb84b37ffc4e69beebea5665dcbc4997f146482fc4bb1bde0884b86940815b';

TrustEventCanonicalFields _goldenFields() => const TrustEventCanonicalFields(
  actorDeviceGeneration: 1,
  actorUid: 100,
  eventId: '3b1e0c4a-5f2d-4a1b-9c3e-7d8f0a1b2c3d',
  expiresAt: 1700000060000,
  fromState: 'unverified',
  issuedAt: 1700000000000,
  targetDeviceId: 'phone-b',
  targetEd25519: 'ZWQtYg==',
  targetIdentityVersion: 1,
  targetUid: 200,
  toState: 'verified',
);

void main() {
  group('TrustEventCanonicalFields.canonicalBytes', () {
    test('matches backend golden vector byte-for-byte', () {
      final bytes = _goldenFields().canonicalBytes();
      expect(base64.encode(bytes), _goldenB64);
      expect(sha256.convert(bytes).toString(), _goldenSha256Hex);
    });

    test('renders exactly 11 lines, no trailing newline', () {
      final text = utf8.decode(_goldenFields().canonicalBytes());
      expect(text.split('\n').length, 11);
      expect(text.endsWith('\n'), isFalse);
      expect(text.startsWith('actor_device_generation=1\n'), isTrue);
      expect(text.endsWith('\nto_state=verified'), isTrue);
    });

    test('fields are emitted in ASCII dictionary order', () {
      final lines = utf8.decode(_goldenFields().canonicalBytes()).split('\n');
      final keys = lines.map((l) => l.split('=').first).toList();
      final sorted = [...keys]..sort();
      expect(keys, sorted);
    });

    test('rejects event_id with newline (canonical injection guard)', () {
      final fields = const TrustEventCanonicalFields(
        actorDeviceGeneration: 1,
        actorUid: 100,
        eventId: 'evt\n1',
        expiresAt: 1700000060000,
        fromState: 'unverified',
        issuedAt: 1700000000000,
        targetDeviceId: 'phone-b',
        targetEd25519: 'ZWQtYg==',
        targetIdentityVersion: 1,
        targetUid: 200,
        toState: 'verified',
      );
      expect(fields.canonicalBytes, throwsArgumentError);
    });

    test('rejects event_id longer than 64 chars', () {
      final fields = TrustEventCanonicalFields(
        actorDeviceGeneration: 1,
        actorUid: 100,
        eventId: 'a' * 65,
        expiresAt: 1700000060000,
        fromState: 'unverified',
        issuedAt: 1700000000000,
        targetDeviceId: 'phone-b',
        targetEd25519: 'ZWQtYg==',
        targetIdentityVersion: 1,
        targetUid: 200,
        toState: 'verified',
      );
      expect(fields.canonicalBytes, throwsArgumentError);
    });
  });

  group('TrustEventCanonicalFields.sign', () {
    test('signer receives exact canonical bytes; result base64-encoded', () {
      late final Uint8List seen;
      final sig = _goldenFields().sign((msg) {
        seen = Uint8List.fromList(msg);
        return List<int>.filled(64, 7); // fake 64-byte signature
      });
      // 证明签名器覆盖的正是 golden 字节（wire 契约的可验证部分）。
      expect(base64.encode(seen), _goldenB64);
      expect(sig, base64.encode(List<int>.filled(64, 7)));
    });
  });
}
