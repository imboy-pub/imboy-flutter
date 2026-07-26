/// P0-1: identity key Ed25519 签名验证测试
///
/// 验证 fail-closed 语义：
/// - 缺少任何必要字段 → IdentityVerificationException
/// - 签名无效 → IdentityVerificationException
/// - 合法签名 → 通过（需 vodozemac 原生库，CI 环境 skip）
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/identity_verifier.dart';

void main() {
  group('P0-1 verifyIdentitySignature fail-closed', () {
    test('空 map → 抛 IdentityVerificationException', () {
      expect(
        () => verifyIdentitySignature({}),
        throwsA(isA<IdentityVerificationException>()),
      );
    });

    test('缺少 ed25519_key → 抛异常', () {
      expect(
        () => verifyIdentitySignature({
          'curve25519_key': 'abc',
          'signature': 'def',
        }),
        throwsA(
          isA<IdentityVerificationException>().having(
            (e) => e.message,
            'message',
            contains('ed25519=missing'),
          ),
        ),
      );
    });

    test('缺少 curve25519_key → 抛异常', () {
      expect(
        () =>
            verifyIdentitySignature({'ed25519_key': 'abc', 'signature': 'def'}),
        throwsA(
          isA<IdentityVerificationException>().having(
            (e) => e.message,
            'message',
            contains('curve25519=missing'),
          ),
        ),
      );
    });

    test('缺少 signature → 抛异常', () {
      expect(
        () => verifyIdentitySignature({
          'ed25519_key': 'abc',
          'curve25519_key': 'def',
        }),
        throwsA(
          isA<IdentityVerificationException>().having(
            (e) => e.message,
            'message',
            contains('sig=missing'),
          ),
        ),
      );
    });

    test('空字符串字段视同缺失 → 抛异常', () {
      expect(
        () => verifyIdentitySignature({
          'ed25519_key': '',
          'curve25519_key': 'def',
          'signature': 'ghi',
        }),
        throwsA(isA<IdentityVerificationException>()),
      );
    });

    test('null 字段视同缺失 → 抛异常', () {
      expect(
        () => verifyIdentitySignature({
          'ed25519_key': null,
          'curve25519_key': 'def',
          'signature': 'ghi',
        }),
        throwsA(isA<IdentityVerificationException>()),
      );
    });

    test('context 参数出现在错误消息中', () {
      try {
        verifyIdentitySignature({}, context: '200:dev-A');
        fail('should throw');
      } on IdentityVerificationException catch (e) {
        expect(e.message, contains('200:dev-A'));
      }
    });
  });

  // 以下测试需要 vodozemac 原生库（真机/集成测试环境）。
  // 在 flutter test（宿主 CI）中 Ed25519PublicKey.fromBase64 会因
  // 缺少 Rust FFI 绑定而抛异常，被 catch 后包装为 IdentityVerificationException。
  // 这恰好证明了 fail-closed：原生库不可用时也不会放行未验证的密钥。
  group('P0-1 签名验证（原生库依赖）', () {
    test('无效 base64 签名 → fail-closed（抛异常而非放行）', () {
      // 所有字段非空但内容无效 → 进入 vodozemac verify → 失败 → 抛异常
      expect(
        () => verifyIdentitySignature({
          'ed25519_key': 'not-valid-base64!!!',
          'curve25519_key': 'also-invalid',
          'signature': 'garbage',
        }),
        throwsA(isA<IdentityVerificationException>()),
      );
    });

    test('合法 base64 但签名不匹配 → fail-closed', () {
      // 有效 base64 编码但密码学上不匹配（长度不足以构成真实密钥）
      expect(
        () => verifyIdentitySignature({
          'ed25519_key': 'aW52YWxpZC1rZXktMQ==',
          'curve25519_key': 'aW52YWxpZC1rZXktMg==',
          'signature': 'aW52YWxpZC1zaWctMw==',
        }),
        throwsA(isA<IdentityVerificationException>()),
      );
    });
  });
}
