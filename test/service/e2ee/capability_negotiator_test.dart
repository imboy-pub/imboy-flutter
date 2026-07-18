// ADR 04 §9 守护测试：协商算法纯函数（取交集 + SECURITY_RANK）。
// 签名验证以注入回调模拟（真实 Ed25519 canonical 格式待架构确认）。
import 'package:flutter_test/flutter_test.dart';
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
}
