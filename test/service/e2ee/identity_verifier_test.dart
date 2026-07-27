/// P0-1: identity key Ed25519 签名验证测试
///
/// 验证 fail-closed 语义：
/// - 缺少任何必要字段 → IdentityVerificationException
/// - 签名无效 → IdentityVerificationException
/// - 合法签名 → 通过（需 vodozemac 原生库，CI 环境 skip）
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/device_manifest.dart';
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

  group('E2EE-022 Client-Side Identity Manifest and Cross-Binding Verification', () {
    late String ed25519Pub;
    late String curve25519Pub;
    late String Function(String) signerFn;
    late String accountPub;
    late String Function(String) accountSignerFn;

    setUpAll(() async {
      // Initialize vodozemac Rust library
      await vod.init(libraryPath: '../spikes/e2ee-group/rust/target/release/');

      // Setup actual Ed25519 keys via vodozemac for device manifest
      final account = vod.Account();
      final keys = account.identityKeys;
      ed25519Pub = keys.ed25519.toBase64();
      curve25519Pub = keys.curve25519.toBase64();

      signerFn = (message) {
        final sig = account.sign(message);
        return sig.toBase64();
      };

      // Setup actual Master Account signing key
      final masterAccount = vod.Account();
      accountPub = masterAccount.identityKeys.ed25519.toBase64();
      accountSignerFn = (message) {
        final sig = masterAccount.sign(message);
        return sig.toBase64();
      };
    });

    DeviceManifest buildSignedManifest() {
      final manifest = DeviceManifest(
        manifestVersion: 1,
        uid: 'user-100',
        deviceId: 'device-abc',
        deviceGeneration: 1,
        identityVersion: 1,
        ed25519: ed25519Pub,
        curve25519: curve25519Pub,
        capabilities: const {'olm'},
        createdAtMs: 1753500000000,
        expiresAtMs: 1753503600000,
      );
      final signedDevice = manifest.signDevice(signerFn);
      return signedDevice.copyWith(
        accountSignature: accountSignerFn(
          base64Url.encode(signedDevice.canonicalBytes()),
        ),
      );
    }

    Map<String, dynamic> buildValidIdentity() {
      final sig = signerFn(curve25519Pub);
      return {
        'ed25519_key': ed25519Pub,
        'curve25519_key': curve25519Pub,
        'signature': sig,
      };
    }

    test('verifyDeviceManifest passes on a valid signed manifest', () {
      final manifest = buildSignedManifest();
      expect(
        () => verifyDeviceManifest(manifest, peerMasterKey: accountPub),
        returnsNormally,
      );
    });

    test('verifyDeviceManifest fails when device_signature is tampered', () {
      final manifest = buildSignedManifest();
      final tampered = manifest.copyWith(uid: 'user-forged');

      expect(
        () => verifyDeviceManifest(tampered, peerMasterKey: accountPub),
        throwsA(
          isA<IdentityVerificationException>().having(
            (e) => e.message,
            'message',
            contains('device_signature 验证失败'),
          ),
        ),
      );
    });

    test('verifyDeviceManifest fails when account_signature is tampered', () {
      final manifest = buildSignedManifest();
      final tampered = manifest.copyWith(
        accountSignature: 'forged-signature==',
      );

      expect(
        () => verifyDeviceManifest(tampered, peerMasterKey: accountPub),
        throwsA(
          isA<IdentityVerificationException>().having(
            (e) => e.message,
            'message',
            contains('account_signature 验证失败'),
          ),
        ),
      );
    });

    test(
      'verifyIdentityWithManifest passes when identity keys and manifest match perfectly',
      () {
        final identity = buildValidIdentity();
        final manifest = buildSignedManifest();

        expect(
          () => verifyIdentityWithManifest(
            identity,
            manifest,
            peerMasterKey: accountPub,
          ),
          returnsNormally,
        );
      },
    );

    test(
      'verifyIdentityWithManifest fails when ed25519_key is mismatched (Cross-Binding Guard)',
      () {
        final manifest = buildSignedManifest();

        // Create a valid, self-signed identity using a completely separate account
        final separateAccount = vod.Account();
        final separateEd25519 = separateAccount.identityKeys.ed25519.toBase64();
        final separateCurve25519 = separateAccount.identityKeys.curve25519
            .toBase64();
        final sig = separateAccount.sign(separateCurve25519).toBase64();

        final mismatchedIdentity = {
          'ed25519_key': separateEd25519,
          'curve25519_key': separateCurve25519,
          'signature': sig,
        };

        expect(
          () => verifyIdentityWithManifest(
            mismatchedIdentity,
            manifest,
            peerMasterKey: accountPub,
          ),
          throwsA(
            isA<IdentityVerificationException>().having(
              (e) => e.message,
              'message',
              contains('ed25519 密钥交叉绑定不一致'),
            ),
          ),
        );
      },
    );

    test(
      'verifyIdentityWithManifest fails when curve25519_key is mismatched (Cross-Binding Guard)',
      () {
        final manifest = buildSignedManifest();

        // Mismatch the identity curve25519_key, but sign it with the manifest's ed25519 key
        // so that it passes the self-signature verifyIdentitySignature check first.
        final otherCurve = base64Url.encode(Uint8List(32));
        final sig = signerFn(otherCurve);

        final mismatchedIdentity = {
          'ed25519_key': ed25519Pub,
          'curve25519_key': otherCurve,
          'signature': sig,
        };

        expect(
          () => verifyIdentityWithManifest(
            mismatchedIdentity,
            manifest,
            peerMasterKey: accountPub,
          ),
          throwsA(
            isA<IdentityVerificationException>().having(
              (e) => e.message,
              'message',
              contains('curve25519 密钥交叉绑定不一致'),
            ),
          ),
        );
      },
    );
  });
}
