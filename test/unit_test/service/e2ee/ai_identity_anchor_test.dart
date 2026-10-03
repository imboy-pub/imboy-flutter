// C06（run-20261003-094804）：AI 独立签名身份锚——合成 fixture 测试。
//
// ⚠️ AiIdentityAnchor 未接线生产（等待 D-02）；生产身份源仍是
// DeploymentScopedPeerIdentitySource（派生指纹，version=0）。本文件用
// vodozemac 真实 ed25519 能力（Account 生成密钥/签名 + Ed25519PublicKey
// 验签）验证锚结构本身的密码学正确性，作为 C09 identity-transparency
// profile 的 AI 域输入合同。
//
// 负例矩阵原则：任何篡改（字段、域分离、版本、验签钥）都必须让
// verifyServerSignature() 返回 false 或构造期抛错——fail-closed，绝不
// 出现「篡改后仍验签通过」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/ai_identity_anchor.dart';

import '../../vodozemac_native_lib.dart';

void main() {
  late vod.Account serverAccount;
  late String serverPub;
  late vod.Account agentAccount;
  late String agentPub;

  setUpAll(() async {
    await ensureVodozemac();
    serverAccount = vod.Account();
    serverPub = serverAccount.identityKeys.ed25519.toBase64();
    agentAccount = vod.Account();
    agentPub = agentAccount.identityKeys.ed25519.toBase64();
  });

  AiIdentityAnchor buildAnchor({
    String agentUid = '456',
    String deploymentId = 'deploy-1',
    String? agentEd25519,
    int identityVersion = 1,
    String? serverEd25519,
    int issuedAt = 1760000000000,
    int anchorVersion = kAiIdentityAnchorStructVersion,
  }) {
    return AiIdentityAnchor(
      agentUid: agentUid,
      deploymentId: deploymentId,
      agentEd25519: agentEd25519 ?? agentPub,
      identityVersion: identityVersion,
      serverEd25519: serverEd25519 ?? serverPub,
      issuedAt: issuedAt,
      anchorVersion: anchorVersion,
    );
  }

  /// 组装已签名锚（合成 fixture 的标准路径）。
  AiIdentityAnchor sign(AiIdentityAnchor unsigned, {vod.Account? signer}) {
    final sig = (signer ?? serverAccount).sign(unsigned.canonicalString());
    return unsigned.withServerSignature(sig.toBase64());
  }

  group('AiIdentityAnchor — 合成 fixture 正通道', () {
    test('合法锚：部署签名验签通过；指纹稳定且与主体逐字节绑定', () {
      final signed = sign(buildAnchor());
      expect(signed.serverSignature, isNotEmpty);
      expect(signed.verifyServerSignature(), isTrue);
      // 同一主体两次组装 → 指纹一致；canonical 确定性
      expect(signed.anchorFingerprint, sign(buildAnchor()).anchorFingerprint);
      expect(signed.canonicalBytes(), buildAnchor().canonicalBytes());
    });

    test('canonical 编码：ASCII 字典序、末字段无尾随换行、域分离在位', () {
      final text = buildAnchor().canonicalString();
      expect(text.contains('domain=$kAiIdentityAnchorDomain\n'), isTrue);
      expect(text.endsWith('\n'), isFalse);
      // 字段按 ASCII 字典序（spot check 相邻对）
      expect(
        text.indexOf('agent_ed25519='),
        lessThan(text.indexOf('agent_uid=')),
      );
      expect(
        text.indexOf('server_ed25519='),
        greaterThan(text.indexOf('issued_at=')),
      );
    });

    test('toPeerIdentity：锚 → 五元组身份维映射（D-02 接线目标形状）', () {
      final signed = sign(buildAnchor(identityVersion: 7));
      final identity = signed.toPeerIdentity();
      expect(identity.fingerprint, signed.anchorFingerprint);
      expect(identity.version, 7);
      // 与派生指纹不同：独立锚必然使旧（派生）确认失效
      expect(identity.fingerprint, isNot(contains('imboy.ai-peer.v1|')));
    });

    test('未签名锚（serverSignature 空）→ 验签恒 false（中间态不可放行）', () {
      expect(buildAnchor().verifyServerSignature(), isFalse);
    });
  });

  group('AiIdentityAnchor — 篡改负例（全部 fail-closed）', () {
    test('任一主体字段篡改 → 验签失败', () {
      final base = sign(buildAnchor());
      expect(base.verifyServerSignature(), isTrue);

      // agent 换身份密钥
      final otherAgent = vod.Account();
      expect(
        sign(
          buildAnchor(agentEd25519: otherAgent.identityKeys.ed25519.toBase64()),
        ).canonicalString(),
        isNot(base.canonicalString()),
      );
      // 逐字段篡改（用原签名配篡改后的主体）
      final tamperedCases = <String, AiIdentityAnchor>{
        'agent_uid': AiIdentityAnchor(
          agentUid: '999',
          deploymentId: base.deploymentId,
          agentEd25519: base.agentEd25519,
          identityVersion: base.identityVersion,
          serverEd25519: base.serverEd25519,
          issuedAt: base.issuedAt,
          serverSignature: base.serverSignature,
        ),
        'deployment_id': AiIdentityAnchor(
          agentUid: base.agentUid,
          deploymentId: 'deploy-EVIL',
          agentEd25519: base.agentEd25519,
          identityVersion: base.identityVersion,
          serverEd25519: base.serverEd25519,
          issuedAt: base.issuedAt,
          serverSignature: base.serverSignature,
        ),
        'agent_ed25519': AiIdentityAnchor(
          agentUid: base.agentUid,
          deploymentId: base.deploymentId,
          agentEd25519: otherAgent.identityKeys.ed25519.toBase64(),
          identityVersion: base.identityVersion,
          serverEd25519: base.serverEd25519,
          issuedAt: base.issuedAt,
          serverSignature: base.serverSignature,
        ),
        'identity_version 回退': AiIdentityAnchor(
          agentUid: base.agentUid,
          deploymentId: base.deploymentId,
          agentEd25519: base.agentEd25519,
          identityVersion: 0,
          serverEd25519: base.serverEd25519,
          issuedAt: base.issuedAt,
          serverSignature: base.serverSignature,
        ),
        'issued_at 重放旧时间戳': AiIdentityAnchor(
          agentUid: base.agentUid,
          deploymentId: base.deploymentId,
          agentEd25519: base.agentEd25519,
          identityVersion: base.identityVersion,
          serverEd25519: base.serverEd25519,
          issuedAt: 1,
          serverSignature: base.serverSignature,
        ),
        'anchor_version 前跳': AiIdentityAnchor(
          agentUid: base.agentUid,
          deploymentId: base.deploymentId,
          agentEd25519: base.agentEd25519,
          identityVersion: base.identityVersion,
          serverEd25519: base.serverEd25519,
          issuedAt: base.issuedAt,
          anchorVersion: kAiIdentityAnchorStructVersion + 1,
          serverSignature: base.serverSignature,
        ),
      };
      for (final entry in tamperedCases.entries) {
        expect(
          entry.value.verifyServerSignature(),
          isFalse,
          reason: '篡改 ${entry.key} 后旧签名必须失效',
        );
        // 篡改同时必然改变指纹（旧五元组确认失效的机制保证）
        expect(
          entry.value.anchorFingerprint,
          isNot(base.anchorFingerprint),
          reason: '篡改 ${entry.key} 后指纹必须变化',
        );
      }
    });

    test('域分离负例：同一签名不能验过其它签名域的锚', () {
      final signed = sign(buildAnchor());
      // domain 是常量参与 canonical；伪造“其它域”等价于 domain 不同 →
      // canonical 必然不同 → 同一签名必败。这里以 trust-event 域字符串
      // 拼出同长 canonical 做演示性对抗（真实跨域重放即此形态）。
      final forgedMessage = signed.canonicalString().replaceAll(
        'domain=$kAiIdentityAnchorDomain',
        'domain=imboy.trust-event.v1',
      );
      expect(forgedMessage == signed.canonicalString(), isFalse);
      final sig = vod.Ed25519Signature.fromBase64(signed.serverSignature);
      expect(
        () =>
            vod.Ed25519PublicKey.fromBase64(signed.serverEd25519)
                .verify(message: forgedMessage, signature: sig),
        throwsA(anything),
      );
    });

    test('验签钥不匹配（攻击者自签锚 + 诚实部署公钥）→ 验签失败', () {
      final evilSigner = vod.Account();
      final evilPub = evilSigner.identityKeys.ed25519.toBase64();
      // 攻击者自签锚：主体里的 server_ed25519 也换成攻击者自己的公钥
      // （完整的自签伪造形态——不是只偷换签名）。
      final evilSigned = sign(
        buildAnchor(serverEd25519: evilPub),
        signer: evilSigner,
      );
      // evilSigned 自带 evil 公钥时能自证——证明“锚自描述”不能替代目录：
      // 部署公钥的分发/固定是 D-02/C09 的接线前提（如实记录，见设计说明）。
      expect(evilSigned.verifyServerSignature(), isTrue);
      // 但用诚实部署公钥交叉验签必败：
      final cross = AiIdentityAnchor(
        agentUid: evilSigned.agentUid,
        deploymentId: evilSigned.deploymentId,
        agentEd25519: evilSigned.agentEd25519,
        identityVersion: evilSigned.identityVersion,
        serverEd25519: serverPub,
        issuedAt: evilSigned.issuedAt,
        serverSignature: evilSigned.serverSignature,
      );
      expect(cross.verifyServerSignature(), isFalse);
    });

    test('坏签名（非 base64 / 非 64 字节）→ false 不抛', () {
      final a = buildAnchor().withServerSignature('not-base64!!!');
      expect(a.verifyServerSignature(), isFalse);
      final b = buildAnchor().withServerSignature('AAAA');
      expect(b.verifyServerSignature(), isFalse);
    });

    test('坏公钥 → false 不抛', () {
      final signed = sign(buildAnchor());
      final bad = AiIdentityAnchor(
        agentUid: signed.agentUid,
        deploymentId: signed.deploymentId,
        agentEd25519: signed.agentEd25519,
        identityVersion: signed.identityVersion,
        serverEd25519: 'garbage',
        issuedAt: signed.issuedAt,
        serverSignature: signed.serverSignature,
      );
      expect(bad.verifyServerSignature(), isFalse);
    });

    test('canonical 字段含换行 → 构造期 fail-closed 抛 ArgumentError', () {
      expect(
        () => buildAnchor(agentUid: '456\n999').canonicalBytes(),
        throwsArgumentError,
      );
      expect(
        () => buildAnchor(deploymentId: 'a\r\nb').canonicalBytes(),
        throwsArgumentError,
      );
      expect(
        () => buildAnchor(agentEd25519: 'AAA\nBBB').canonicalBytes(),
        throwsArgumentError,
      );
    });
  });

  group('AiIdentityAnchor — 与五元组门的合同对齐（C09 输入）', () {
    test('锚指纹变化 → AiPeerIdentity 指纹变化（旧确认五元组必然失配）', () {
      final v1 = sign(buildAnchor(identityVersion: 1)).toPeerIdentity();
      final v2 = sign(buildAnchor(identityVersion: 2)).toPeerIdentity();
      expect(v1.fingerprint, isNot(v2.fingerprint));
      expect(v1.version, isNot(v2.version));
    });

    test('部署变化 → 锚指纹变化（跨部署旧确认不可迁移）', () {
      final a = sign(buildAnchor(deploymentId: 'deploy-1')).anchorFingerprint;
      final b = sign(buildAnchor(deploymentId: 'deploy-2')).anchorFingerprint;
      expect(a, isNot(b));
    });
  });
}
