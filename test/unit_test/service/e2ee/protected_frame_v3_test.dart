/// S2.1 Protected Frame v3 — Canonical CBOR + ProtectedFrameV3 单元测试
///
/// ADR 15 §3: protected_header 使用 RFC 8949 deterministic CBOR 编码
/// ADR 15 §8: PF3-01..10 验收测试
///
/// 本测试覆盖：
/// - canonical CBOR 编码确定性（同输入 → 同字节）
/// - header_hash = SHA-256(canonical_cbor(protected_header))
/// - inner/outer header 比对
/// - 篡改检测（PF3-01）
/// - 资源边界（PF3-08）
/// - 未知字段拒绝策略
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

void main() {
  group('CanonicalCbor', () {
    test('encodes flat map deterministically (sorted keys, shortest ints)', () {
      final header = {
        'v': 3,
        'message_id': 'msg-001',
        'scope': 'c2c',
        'conversation_id': 'conv-abc',
        'sender_uid': '100',
        'sender_did': 'dev-1',
        'destination': '200',
        'message_type': 'text',
        'action': 'message',
        'created_at_ms': 1753500000000,
        'protocol': 'olm',
        'protocol_version': 1,
        'session_ref': 'sess-xyz',
        'epoch_or_counter': 42,
        'content_encoding': 'cbor',
      };

      final bytes1 = CanonicalCbor.encode(header);
      final bytes2 = CanonicalCbor.encode(header);

      // 同输入 → 同字节（确定性）
      expect(bytes1, equals(bytes2));

      // 不同插入顺序 → 同字节（canonical sorting）
      final headerReordered = {
        'content_encoding': 'cbor',
        'v': 3,
        'action': 'message',
        'message_id': 'msg-001',
        'scope': 'c2c',
        'epoch_or_counter': 42,
        'conversation_id': 'conv-abc',
        'sender_uid': '100',
        'sender_did': 'dev-1',
        'destination': '200',
        'message_type': 'text',
        'created_at_ms': 1753500000000,
        'protocol': 'olm',
        'protocol_version': 1,
        'session_ref': 'sess-xyz',
      };
      final bytes3 = CanonicalCbor.encode(headerReordered);
      expect(bytes1, equals(bytes3));
    });

    test('uses shortest integer encoding', () {
      // 小整数用 1 字节 major type 0
      final small = CanonicalCbor.encode({'a': 0});
      // 0x a1(map1) 61(text1) 61 'a' 00(uint 0)
      expect(small.length, equals(4));

      // 23 以内用单字节
      final twenty3 = CanonicalCbor.encode({'a': 23});
      expect(twenty3.length, equals(4));

      // 24 需要额外字节
      final twenty4 = CanonicalCbor.encode({'a': 24});
      expect(twenty4.length, equals(5));
    });

    test('decode roundtrip preserves values', () {
      final original = {
        'v': 3,
        'message_id': 'test-123',
        'created_at_ms': 1753500000000,
        'epoch_or_counter': 0,
      };
      final bytes = CanonicalCbor.encode(original);
      final decoded = CanonicalCbor.decode(bytes);
      expect(decoded, equals(original));
    });

    test('rejects indefinite-length encoding', () {
      // 0x9F = array indefinite length
      final bad = Uint8List.fromList([0x9F, 0x01, 0x02, 0xFF]);
      expect(
        () => CanonicalCbor.decode(bad),
        throwsA(isA<CborParseException>()),
      );
    });

    test('rejects non-shortest integer', () {
      // 0x18 0x05 = uint 5 in 2 bytes (non-shortest, should be 0x05)
      final bad = Uint8List.fromList([
        0xA1, // map(1)
        0x61, 0x61, // text(1) "a"
        0x18, 0x05, // uint(1byte) 5 — non-shortest
      ]);
      expect(
        () => CanonicalCbor.decode(bad),
        throwsA(isA<CborParseException>()),
      );
    });

    test('rejects duplicate map keys', () {
      // map(2) with key "a" twice
      final bad = Uint8List.fromList([
        0xA2, // map(2)
        0x61, 0x61, // "a"
        0x01, // 1
        0x61, 0x61, // "a" again
        0x02, // 2
      ]);
      expect(
        () => CanonicalCbor.decode(bad),
        throwsA(isA<CborParseException>()),
      );
    });

    test('enforces max nesting depth', () {
      // 构造超过 16 层嵌套
      dynamic nested = 'leaf';
      for (var i = 0; i < 17; i++) {
        nested = {'level$i': nested};
      }
      expect(
        () => CanonicalCbor.encode(nested as Map<String, dynamic>),
        throwsA(isA<CborParseException>()),
      );
    });

    test('enforces max map entries (128)', () {
      final bigMap = <String, dynamic>{};
      for (var i = 0; i < 129; i++) {
        bigMap['key$i'] = i;
      }
      expect(
        () => CanonicalCbor.encode(bigMap),
        throwsA(isA<CborParseException>()),
      );
    });
  });

  group('ProtectedFrameV3', () {
    final testContext = FrameContext(
      messageId: 'msg-001',
      scope: FrameScope.c2c,
      conversationId: 'conv-abc',
      senderUid: '100',
      senderDid: 'dev-1',
      destination: '200',
      messageType: 'text',
      action: 'message',
      createdAtMs: 1753500000000,
      protocol: 'olm',
      protocolVersion: 1,
      sessionRef: 'sess-xyz',
      epochOrCounter: 42,
    );

    test('buildProtectedHeader produces all required fields', () {
      final header = ProtectedFrameV3.buildProtectedHeader(testContext);
      expect(header['v'], equals(3));
      expect(header['message_id'], equals('msg-001'));
      expect(header['scope'], equals('c2c'));
      expect(header['conversation_id'], equals('conv-abc'));
      expect(header['sender_uid'], equals('100'));
      expect(header['sender_did'], equals('dev-1'));
      expect(header['destination'], equals('200'));
      expect(header['message_type'], equals('text'));
      expect(header['action'], equals('message'));
      expect(header['created_at_ms'], equals(1753500000000));
      expect(header['protocol'], equals('olm'));
      expect(header['protocol_version'], equals(1));
      expect(header['session_ref'], equals('sess-xyz'));
      expect(header['epoch_or_counter'], equals(42));
      expect(header['content_encoding'], equals('cbor'));
    });

    test('headerHash is SHA-256 of canonical CBOR', () {
      final header = ProtectedFrameV3.buildProtectedHeader(testContext);
      final canonicalBytes = CanonicalCbor.encode(header);
      final expectedHash = sha256.convert(canonicalBytes).bytes;

      final hash = ProtectedFrameV3.computeHeaderHash(testContext);
      expect(hash, equals(expectedHash));
    });

    test('encodeOuterEnvelope produces valid structure', () {
      final envelope = ProtectedFrameV3.encodeOuterEnvelope(
        context: testContext,
        ciphertext: Uint8List.fromList(utf8.encode('fake-ciphertext')),
        protocolMetadata: {'session_id': 'sess-xyz'},
      );

      expect(envelope['meta_version'], equals(3));
      expect(envelope['protected_header'], isA<String>()); // base64url
      expect(envelope['header_hash'], isA<String>()); // base64url
      expect(envelope['ciphertext'], isA<String>()); // base64url
      expect(envelope['protocol_metadata'], equals({'session_id': 'sess-xyz'}));

      // protected_header 解码后是 canonical CBOR bytes
      final headerBytes = base64Url.decode(
        envelope['protected_header'] as String,
      );
      final decodedHeader = CanonicalCbor.decode(
        Uint8List.fromList(headerBytes),
      );
      expect(decodedHeader['v'], equals(3));
      expect(decodedHeader['message_id'], equals('msg-001'));
    });

    test('verifyOuterEnvelope accepts valid envelope', () {
      final envelope = ProtectedFrameV3.encodeOuterEnvelope(
        context: testContext,
        ciphertext: Uint8List.fromList(utf8.encode('fake-ciphertext')),
        protocolMetadata: {},
      );

      // 验证不应抛异常
      final result = ProtectedFrameV3.verifyOuterEnvelope(envelope);
      expect(result.isValid, isTrue);
    });

    test('PF3-01: tampering header_hash is rejected', () {
      final envelope = ProtectedFrameV3.encodeOuterEnvelope(
        context: testContext,
        ciphertext: Uint8List.fromList(utf8.encode('fake')),
        protocolMetadata: {},
      );

      // 篡改 header_hash
      final tampered = Map<String, dynamic>.from(envelope);
      tampered['header_hash'] = base64Url.encode(List.filled(32, 0));

      final result = ProtectedFrameV3.verifyOuterEnvelope(tampered);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('header_hash'));
    });

    test('PF3-01: tampering protected_header bytes is rejected', () {
      final envelope = ProtectedFrameV3.encodeOuterEnvelope(
        context: testContext,
        ciphertext: Uint8List.fromList(utf8.encode('fake')),
        protocolMetadata: {},
      );

      // 篡改 protected_header（修改一个字节）
      final headerBytes = base64Url.decode(
        envelope['protected_header'] as String,
      );
      headerBytes[headerBytes.length - 1] ^= 0xFF;
      final tampered = Map<String, dynamic>.from(envelope);
      tampered['protected_header'] = base64Url.encode(headerBytes);

      final result = ProtectedFrameV3.verifyOuterEnvelope(tampered);
      expect(result.isValid, isFalse);
    });

    test('PF3-03: context mismatch detected on inner/outer compare', () {
      final outerContext = testContext;
      final innerContext = FrameContext(
        messageId: 'msg-001',
        scope: FrameScope.c2c,
        conversationId: 'conv-abc',
        senderUid: '100',
        senderDid: 'dev-1',
        destination: '999', // 篡改目标
        messageType: 'text',
        action: 'message',
        createdAtMs: 1753500000000,
        protocol: 'olm',
        protocolVersion: 1,
        sessionRef: 'sess-xyz',
        epochOrCounter: 42,
      );

      final mismatch = ProtectedFrameV3.compareHeaders(
        outerContext: outerContext,
        innerContext: innerContext,
      );
      expect(mismatch, isNotNull);
      expect(mismatch, contains('destination'));
    });

    test('PF3-05: non-canonical encoding rejected', () {
      // 手动构造一个 key 未排序的 CBOR map
      // map(2): "b"=1, "a"=2 (应该是 "a" 在前)
      final nonCanonical = Uint8List.fromList([
        0xA2, // map(2)
        0x61, 0x62, // "b"
        0x01, // 1
        0x61, 0x61, // "a"
        0x02, // 2
      ]);
      expect(
        () => CanonicalCbor.decode(nonCanonical, strict: true),
        throwsA(isA<CborParseException>()),
      );
    });

    test('PF3-08: oversized envelope rejected before crypto', () {
      // 模拟超过 10 MiB 的信封
      final oversized = {
        'meta_version': 3,
        'protected_header': base64Url.encode(List.filled(1024, 0x41)),
        'header_hash': base64Url.encode(List.filled(32, 0)),
        'ciphertext': base64Url.encode(List.filled(11 * 1024 * 1024, 0x42)),
        'protocol_metadata': <String, dynamic>{},
      };

      expect(
        () => ProtectedFrameV3.validateEnvelopeBounds(oversized),
        throwsA(isA<FrameBoundsException>()),
      );
    });

    test('PF3-08: oversized header rejected (> 8 KiB)', () {
      final bigHeader = {
        'meta_version': 3,
        'protected_header': base64Url.encode(List.filled(9 * 1024, 0x41)),
        'header_hash': base64Url.encode(List.filled(32, 0)),
        'ciphertext': base64Url.encode(List.filled(100, 0x42)),
        'protocol_metadata': <String, dynamic>{},
      };

      expect(
        () => ProtectedFrameV3.validateEnvelopeBounds(bigHeader),
        throwsA(isA<FrameBoundsException>()),
      );
    });

    test('meta_version != 3 rejected', () {
      final envelope = {
        'meta_version': 2,
        'protected_header': '',
        'header_hash': '',
        'ciphertext': '',
        'protocol_metadata': <String, dynamic>{},
      };

      final result = ProtectedFrameV3.verifyOuterEnvelope(envelope);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('meta_version'));
    });
  });
}
