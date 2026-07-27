/// E2EE-020 — Device Manifest Model, Codec and Signature Verification Tests.
///
/// Ref: 16-supersedes-03-04-06-device-trust.md §4
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/device_manifest.dart';

void main() {
  group('DeviceManifest', () {
    late String ed25519Pub;
    late String curve25519Pub;
    late String Function(String) signerFn;
    late String accountPub;
    late String Function(String) accountSignerFn;

    setUpAll(() async {
      // Initialize vodozemac Rust library first
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
