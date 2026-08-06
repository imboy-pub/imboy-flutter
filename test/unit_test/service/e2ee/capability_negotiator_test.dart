// ADR 04 §9 守护测试：协商算法纯函数（取交集 + SECURITY_RANK）。
// 签名验证以注入回调模拟（真实 Ed25519 canonical 格式待架构确认）。
import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/device_manifest.dart';
import 'package:imboy/service/e2ee/capability_negotiator.dart';

PeerCapability _peer(String deviceId, List<String> protocols) => PeerCapability(
  deviceId: deviceId,
  signingKey: 'ed25519:$deviceId',
  protocols: protocols,
  protocolsSig: 'sig:$deviceId',
  capabilitiesTs: 1721300000000,
);

bool _sigOk(PeerCapability _) => true;
bool _sigBad(PeerCapability _) => false;

void main() {
  group('negotiateOneDevice（ADR 04 §4）', () {
    test('cap_negotiate_highest_common: 双方 {olm,megolm} → olm', () {
      final r = CapabilityNegotiator.negotiateOneDevice(
        {'olm', 'megolm'},
        _peer('d1', ['olm', 'megolm']),
        verifySignature: _sigOk,
      );
      expect(r, 'olm');
    });

    test(
      'cap_negotiate_fallback_chain: 我{olm,megolm} 对端{megolm,rsa-oaep} → megolm',
      () {
        final r = CapabilityNegotiator.negotiateOneDevice(
          {'olm', 'megolm'},
          _peer('d1', ['megolm', 'rsa-oaep']),
          verifySignature: _sigOk,
        );
        expect(r, 'megolm'); // 不跨级跳 rsa-oaep
      },
    );

    test(
      'cap_negotiate_sender_limited（有交集）: 我{rsa-oaep} 对端{megolm,rsa-oaep} → rsa-oaep',
      () {
        final r = CapabilityNegotiator.negotiateOneDevice(
          {'rsa-oaep'},
          _peer('d1', ['megolm', 'rsa-oaep']),
          verifySignature: _sigOk,
        );
        expect(r, 'rsa-oaep');
      },
    );

    test('cap_negotiate_no_common: 我{olm,megolm} 对端{rsa-oaep} → null（不降级）', () {
      final r = CapabilityNegotiator.negotiateOneDevice(
        {'olm', 'megolm'},
        _peer('d1', ['rsa-oaep']),
        verifySignature: _sigOk,
      );
      expect(r, isNull);
    });

    test('安全级别由 securityRank 决定，不受 protocols 列表顺序影响（防重排）', () {
      final r = CapabilityNegotiator.negotiateOneDevice(
        {'olm', 'megolm'},
        _peer('d1', ['megolm', 'olm']), // 列表把 megolm 放前面
        verifySignature: _sigOk,
      );
      expect(r, 'olm'); // 仍选 olm（rank 高）
    });

    test('cap_sig_tampered_rejected: 签名校验失败抛 CapVerificationFailed', () {
      expect(
        () => CapabilityNegotiator.negotiateOneDevice(
          {'olm', 'megolm'},
          _peer('d1', ['olm']),
          verifySignature: _sigBad,
        ),
        throwsA(isA<CapVerificationFailed>()),
      );
    });
  });

  group('negotiatePeer 多设备 fan-out（ADR 04 §4.3/§5）', () {
    test(
      'cap_multi_device_mixed_fanout: 3 设备分别 olm/megolm/rsa-oaep → 各自套件',
      () {
        final plan = CapabilityNegotiator.negotiatePeer(
          {'olm', 'megolm', 'rsa-oaep'},
          [
            _peer('D1', ['olm', 'megolm']),
            _peer('D2', ['megolm']),
            _peer('D3', ['rsa-oaep']),
          ],
          verifySignature: _sigOk,
        );
        expect(plan['D1']!.outcome, NegotiationOutcome.ok);
        expect(plan['D1']!.suite, 'olm');
        expect(plan['D2']!.suite, 'megolm');
        expect(plan['D3']!.suite, 'rsa-oaep');
      },
    );

    test('签名失败的设备标记 unsupported，不中断其他设备', () {
      bool verify(PeerCapability p) => p.deviceId != 'BAD';
      final plan = CapabilityNegotiator.negotiatePeer(
        {'olm', 'megolm'},
        [
          _peer('GOOD', ['olm']),
          _peer('BAD', ['olm']),
        ],
        verifySignature: verify,
      );
      expect(plan['GOOD']!.outcome, NegotiationOutcome.ok);
      expect(plan['GOOD']!.suite, 'olm');
      expect(plan['BAD']!.outcome, NegotiationOutcome.unsupported);
      expect(plan['BAD']!.suite, isNull);
    });

    test('无交集设备标记 noCommonSuite（不降级明文）', () {
      final plan = CapabilityNegotiator.negotiatePeer(
        {'olm', 'megolm'},
        [
          _peer('OLD', ['rsa-oaep']),
        ],
        verifySignature: _sigOk,
      );
      expect(plan['OLD']!.outcome, NegotiationOutcome.noCommonSuite);
      expect(plan['OLD']!.suite, isNull);
    });
  });

  group('DeviceManifest Capability Negotiation (E2EE-021)', () {
    late String ed25519Pub;
    late String curve25519Pub;
    late String Function(String) signerFn;

    setUpAll(() async {
      // Initialize vodozemac Rust library
      await vod.init(libraryPath: '../spikes/e2ee-group/rust/target/release/');

      final account = vod.Account();
      ed25519Pub = account.identityKeys.ed25519.toBase64();
      curve25519Pub = account.identityKeys.curve25519.toBase64();

      signerFn = (message) {
        final sig = account.sign(message);
        return sig.toBase64();
      };
    });

    DeviceManifest buildSignedManifest(
      String deviceId,
      Set<String> capabilities,
    ) {
      final manifest = DeviceManifest(
        manifestVersion: 1,
        uid: 'user-100',
        deviceId: deviceId,
        deviceGeneration: 1,
        identityVersion: 1,
        ed25519: ed25519Pub,
        curve25519: curve25519Pub,
        capabilities: capabilities,
        createdAtMs: 1753500000000,
        expiresAtMs: 1753503600000,
      );
      return manifest.signDevice(signerFn);
    }

    test(
      'negotiateWithManifest chooses highest mutual suite on valid manifest',
      () {
        final m = buildSignedManifest('d1', {'olm', 'megolm'});
        final suite = CapabilityNegotiator.negotiateWithManifest({
          'olm',
          'megolm',
        }, m);
        expect(suite, equals('olm'));
      },
    );

    test(
      'negotiateWithManifest returns null (noCommonSuite) when no intersection exists',
      () {
        final m = buildSignedManifest('d1', {'rsa-oaep'});
        final suite = CapabilityNegotiator.negotiateWithManifest({
          'olm',
          'megolm',
        }, m);
        expect(suite, isNull);
      },
    );

    test(
      'negotiateWithManifest throws CapVerificationFailed on tampered manifest capabilities',
      () {
        final m = buildSignedManifest('d1', {'olm', 'megolm'});
        // Tamper capabilities in the signed manifest
        final tampered = m.copyWith(capabilities: {'olm'});

        expect(
          () => CapabilityNegotiator.negotiateWithManifest({
            'olm',
            'megolm',
          }, tampered),
          throwsA(isA<CapVerificationFailed>()),
        );
      },
    );

    test(
      'negotiatePeerWithManifests negotiates mixed results and filters out tampered device',
      () {
        final mGood = buildSignedManifest('GOOD', {'olm'});
        final mBad = buildSignedManifest('BAD', {'olm'});
        final mNoCommon = buildSignedManifest('NO_COMMON', {'rsa-oaep'});

        // Tamper the bad manifest
        final mBadTampered = mBad.copyWith(deviceId: 'BAD-FORGED');

        final plan = CapabilityNegotiator.negotiatePeerWithManifests(
          {'olm', 'megolm'},
          [mGood, mBadTampered, mNoCommon],
        );

        // Good device: ok + olm
        expect(plan['GOOD']!.outcome, equals(NegotiationOutcome.ok));
        expect(plan['GOOD']!.suite, equals('olm'));

        // Tampered device: unsupported
        expect(
          plan['BAD-FORGED']!.outcome,
          equals(NegotiationOutcome.unsupported),
        );
        expect(plan['BAD-FORGED']!.suite, isNull);

        // No common device: noCommonSuite
        expect(
          plan['NO_COMMON']!.outcome,
          equals(NegotiationOutcome.noCommonSuite),
        );
        expect(plan['NO_COMMON']!.suite, isNull);
      },
    );
  });
}
