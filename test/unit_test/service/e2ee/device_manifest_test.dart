/// E2EE-020 — Device Manifest Model, Codec and Signature Verification Tests.
///
/// Ref: 16-supersedes-03-04-06-device-trust.md §4
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/device_manifest.dart';

import '../../vodozemac_native_lib.dart';

void main() {
  group('DeviceManifest', () {
    late String ed25519Pub;
    late String curve25519Pub;
    late String Function(String) signerFn;
    late String accountPub;
    late String Function(String) accountSignerFn;

    setUpAll(() async {
      // Initialize vodozemac Rust library first
      await ensureVodozemac();

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

    DeviceManifest buildValidManifest() {
      return DeviceManifest(
        manifestVersion: 1,
        uid: 'user-100',
        deviceId: 'device-abc',
        deviceGeneration: 2,
        identityVersion: 3,
        ed25519: ed25519Pub,
        curve25519: curve25519Pub,
        mlsCredential: 'mls-credential-bytes',
        capabilities: const {'olm', 'megolm'},
        createdAtMs: 1753500000000,
        expiresAtMs: 1753503600000,
        previousManifestHash: 'prev-hash-bytes',
      );
    }

    test(
      'toJson sorts capabilities lexicographically and toJson/fromJson works',
      () {
        final original = DeviceManifest(
          manifestVersion: 1,
          uid: 'user-100',
          deviceId: 'device-abc',
          deviceGeneration: 2,
          identityVersion: 3,
          ed25519: ed25519Pub,
          curve25519: curve25519Pub,
          capabilities: const {'megolm', 'olm'}, // out of alphabetical order
          createdAtMs: 1753500000000,
          expiresAtMs: 1753503600000,
        );

        final json = original.toJson();
        expect(json['capabilities'], equals(['megolm', 'olm']..sort()));

        final parsed = DeviceManifest.fromJson(json);
        expect(parsed.capabilities, equals({'olm', 'megolm'}));
        expect(parsed.uid, equals('user-100'));
        expect(parsed.deviceId, equals('device-abc'));
      },
    );

    test('canonicalBytes generates deterministic CBOR representation', () {
      final m1 = buildValidManifest();
      final m2 = buildValidManifest().copyWith(
        // Reordered map or extra fields are ignored in signatures except standard ones
        capabilities: const {'megolm', 'olm'},
      );

      final bytes1 = m1.canonicalBytes();
      final bytes2 = m2.canonicalBytes();

      expect(bytes1, equals(bytes2));
    });

    test(
      'signDevice and verifyDeviceSignature works with actual Ed25519 keys',
      () {
        final manifest = buildValidManifest();
        expect(manifest.deviceSignature, isNull);
        expect(manifest.verifyDeviceSignature(), isFalse);

        final signed = manifest.signDevice((msg) => signerFn(msg));
        expect(signed.deviceSignature, isNotNull);
        expect(signed.verifyDeviceSignature(), isTrue);
      },
    );

    test('verifyAccountSignature works with actual Master Account key', () {
      final manifest = buildValidManifest();
      final signedDevice = manifest.signDevice((msg) => signerFn(msg));

      final signedAccount = signedDevice.copyWith(
        accountSignature: accountSignerFn(
          base64Url.encode(signedDevice.canonicalBytes()),
        ),
      );

      expect(signedAccount.verifyAccountSignature(accountPub), isTrue);
      // Fails on incorrect public key
      expect(signedAccount.verifyAccountSignature(ed25519Pub), isFalse);
    });

    group('Systematic Tampering (Negative Cases)', () {
      late DeviceManifest signedManifest;

      setUp(() {
        final manifest = buildValidManifest();
        final signed = manifest.signDevice((msg) => signerFn(msg));
        signedManifest = signed.copyWith(
          accountSignature: accountSignerFn(
            base64Url.encode(signed.canonicalBytes()),
          ),
        );
        expect(signedManifest.verifyDeviceSignature(), isTrue);
        expect(signedManifest.verifyAccountSignature(accountPub), isTrue);
      });

      test('tampering manifest_version fails verification', () {
        final tampered = signedManifest.copyWith(manifestVersion: 2);
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering uid fails verification', () {
        final tampered = signedManifest.copyWith(uid: 'user-200');
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering device_id fails verification', () {
        final tampered = signedManifest.copyWith(deviceId: 'device-forged');
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering device_generation fails verification', () {
        final tampered = signedManifest.copyWith(deviceGeneration: 99);
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering identity_version fails verification', () {
        final tampered = signedManifest.copyWith(identityVersion: 99);
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering ed25519 key fails verification', () {
        final tampered = signedManifest.copyWith(ed25519: 'forgedKey==');
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering curve25519 key fails verification', () {
        final tampered = signedManifest.copyWith(curve25519: 'forgedKey==');
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering capabilities fails verification', () {
        final tampered = signedManifest.copyWith(capabilities: const {'olm'});
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering created_at_ms fails verification', () {
        final tampered = signedManifest.copyWith(createdAtMs: 100);
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering expires_at_ms fails verification', () {
        final tampered = signedManifest.copyWith(expiresAtMs: 100);
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });

      test('tampering previous_manifest_hash fails verification', () {
        final tampered = signedManifest.copyWith(
          previousManifestHash: 'forged-hash',
        );
        expect(tampered.verifyDeviceSignature(), isFalse);
        expect(tampered.verifyAccountSignature(accountPub), isFalse);
      });
    });

    group('Field Stripping from Wire JSON (C02 negative cases)', () {
      // C02 合同负例：从 wire JSON 删除任一被签名字段后，
      // 解析出的 manifest 必须通不过签名验证（fail-closed，不静默接受空壳）。
      late Map<String, dynamic> signedJson;

      setUp(() {
        final manifest = buildValidManifest();
        final signed = manifest.signDevice((msg) => signerFn(msg));
        signedJson = signed.toJson();
        // 基线：未篡改时验签必须通过
        expect(
          DeviceManifest.fromJson(signedJson).verifyDeviceSignature(),
          isTrue,
        );
      });

      test('stripping ed25519 from wire JSON fails verification', () {
        final stripped = Map<String, dynamic>.from(signedJson)
          ..remove('ed25519');
        final parsed = DeviceManifest.fromJson(stripped);
        expect(parsed.ed25519, isEmpty);
        expect(parsed.verifyDeviceSignature(), isFalse);
      });

      test('stripping capabilities from wire JSON fails verification', () {
        final stripped = Map<String, dynamic>.from(signedJson)
          ..remove('capabilities');
        final parsed = DeviceManifest.fromJson(stripped);
        expect(parsed.capabilities, isEmpty);
        expect(parsed.verifyDeviceSignature(), isFalse);
      });

      test('stripping uid from wire JSON fails verification', () {
        final stripped = Map<String, dynamic>.from(signedJson)..remove('uid');
        final parsed = DeviceManifest.fromJson(stripped);
        expect(parsed.uid, isEmpty);
        expect(parsed.verifyDeviceSignature(), isFalse);
      });

      test('stripping device_id from wire JSON fails verification', () {
        final stripped = Map<String, dynamic>.from(signedJson)
          ..remove('device_id');
        final parsed = DeviceManifest.fromJson(stripped);
        expect(parsed.deviceId, isEmpty);
        expect(parsed.verifyDeviceSignature(), isFalse);
      });
    });

    group('Forged Signature (C02 negative cases)', () {
      // C02 合同负例：伪签名 —— 攻击者用**自己的**设备密钥对同一 manifest
      // 内容签名，冒充对端设备。用 manifest 自带的 ed25519 验签必须失败。
      test(
        'device_signature forged by a different device key fails verification',
        () {
          final manifest = buildValidManifest();

          final attacker = vod.Account();
          final forgedSig = attacker.sign(
            base64Url.encode(manifest.canonicalBytes()),
          );

          final forged = manifest.copyWith(
            deviceSignature: forgedSig.toBase64(),
          );
          expect(forged.deviceSignature, isNotNull);
          expect(forged.verifyDeviceSignature(), isFalse);
        },
      );

      test('garbage (non-signature) device_signature fails verification', () {
        final manifest = buildValidManifest();
        final forged = manifest.copyWith(deviceSignature: 'AAAAAAAA');
        expect(forged.verifyDeviceSignature(), isFalse);
      });
    });

    group('Expiry Validation (C02 replay protection)', () {
      test('isExpiredAt: now >= expiresAtMs 视为过期（含边界与缺失=0）', () {
        final m = buildValidManifest().copyWith(expiresAtMs: 1000);
        expect(m.isExpiredAt(999), isFalse); // 未过期
        expect(m.isExpiredAt(1000), isTrue); // 边界：到期即过期
        expect(m.isExpiredAt(1001), isTrue); // 已过期
      });

      test(
        'expiresAtMs 缺失（fromJson 默认 0）→ isExpiredAt 恒为 true（fail-closed）',
        () {
          final json = buildValidManifest().toJson()..remove('expires_at_ms');
          final parsed = DeviceManifest.fromJson(json);
          expect(parsed.expiresAtMs, equals(0));
          expect(parsed.isExpiredAt(0), isTrue);
        },
      );

      test('ensureNotExpired: 未过期 → 通过（不抛）', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final m = buildValidManifest().copyWith(expiresAtMs: now + 3600000);
        expect(() => m.ensureNotExpired(nowMs: now), returnsNormally);
      });

      test('ensureNotExpired: 已过期（签名可能仍有效）→ 抛 ManifestValidityException', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final m = buildValidManifest().copyWith(expiresAtMs: now - 1);
        expect(
          () => m.ensureNotExpired(nowMs: now),
          throwsA(
            isA<ManifestValidityException>().having(
              (e) => e.message,
              'message',
              allOf(contains('expired'), contains('device-abc')),
            ),
          ),
        );
      });

      test('ensureNotExpired: expiresAtMs=0（缺失）→ 抛（不静默放行）', () {
        final m = buildValidManifest().copyWith(expiresAtMs: 0);
        expect(
          () =>
              m.ensureNotExpired(nowMs: DateTime.now().millisecondsSinceEpoch),
          throwsA(isA<ManifestValidityException>()),
        );
      });
    });

    group('Manifest Hash & Chain Link (C02 replay protection)', () {
      test('manifestHash 确定性：同内容一致，内容变化即变化', () {
        final m1 = buildValidManifest();
        final m2 = buildValidManifest();
        expect(m1.manifestHash(), equals(m2.manifestHash()));

        final changed = buildValidManifest().copyWith(identityVersion: 99);
        expect(changed.manifestHash(), isNot(equals(m1.manifestHash())));
      });

      test('ensureChainLinked：合法后继（previousManifestHash == 当前哈希）→ 通过', () {
        final current = buildValidManifest();
        final successor = current.copyWith(
          identityVersion: current.identityVersion + 1,
          previousManifestHash: current.manifestHash(),
        );
        expect(
          () => DeviceManifest.ensureChainLinked(
            successor,
            current.manifestHash(),
          ),
          returnsNormally,
        );
      });

      test('ensureChainLinked：同一 manifest 重投（幂等）→ 通过', () {
        final current = buildValidManifest();
        expect(
          () =>
              DeviceManifest.ensureChainLinked(current, current.manifestHash()),
          returnsNormally,
        );
      });

      test('ensureChainLinked：旧 manifest 重放 → 抛 ManifestValidityException', () {
        // 链：v0 ← v1 ← v2（当前已知 v2）。攻击者重放 v1：
        // v1.manifestHash() != v2 哈希 且 v1.previousManifestHash（=v0 哈希）!= v2 哈希。
        final v0 = buildValidManifest();
        final v1 = v0.copyWith(
          identityVersion: v0.identityVersion + 1,
          previousManifestHash: v0.manifestHash(),
        );
        final v2 = v1.copyWith(
          identityVersion: v1.identityVersion + 1,
          previousManifestHash: v1.manifestHash(),
        );

        expect(
          () => DeviceManifest.ensureChainLinked(v1, v2.manifestHash()),
          throwsA(
            isA<ManifestValidityException>().having(
              (e) => e.message,
              'message',
              allOf(contains('chain'), contains('replay')),
            ),
          ),
        );
      });

      test(
        'ensureChainLinked：previousManifestHash 为 null（genesis 冒充后继）→ 抛',
        () {
          final current = buildValidManifest();
          final genesis = buildValidManifest().copyWith(
            previousManifestHash: null,
          );
          // copyWith(null) 不生效（?? 语义保留旧值），用 fromJson 构造真正的 null
          final json = genesis.toJson()..remove('previous_manifest_hash');
          final parsed = DeviceManifest.fromJson(json);
          expect(parsed.previousManifestHash, isNull);

          expect(
            () => DeviceManifest.ensureChainLinked(
              parsed,
              current.manifestHash(),
            ),
            throwsA(isA<ManifestValidityException>()),
          );
        },
      );

      test('ensureChainLinked：断链（previousManifestHash 指向伪造值）→ 抛', () {
        final current = buildValidManifest();
        final forged = current.copyWith(previousManifestHash: 'forged-hash');
        expect(
          () =>
              DeviceManifest.ensureChainLinked(forged, current.manifestHash()),
          throwsA(isA<ManifestValidityException>()),
        );
      });
    });

    group('Key Validation Rules', () {
      test('validateKeys rejects invalid key lengths', () {
        // Valid 32-byte key mock
        final validKey32 = base64Url.encode(Uint8List(32));
        final invalidKey31 = base64Url.encode(Uint8List(31));

        // Passes on 32-byte keys
        expect(
          () => DeviceManifest.validateKeys(validKey32, validKey32),
          returnsNormally,
        );

        // Rejects if ed25519 is 31 bytes
        expect(
          () => DeviceManifest.validateKeys(invalidKey31, validKey32),
          throwsA(isA<FormatException>()),
        );

        // Rejects if curve25519 is 31 bytes
        expect(
          () => DeviceManifest.validateKeys(validKey32, invalidKey31),
          throwsA(isA<FormatException>()),
        );

        // Rejects on empty strings
        expect(
          () => DeviceManifest.validateKeys('', ''),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
