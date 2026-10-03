/// C06（run-20261003-094804）：AI 独立签名身份锚——**设计与 fixture 阶段**。
///
/// ⚠️ 未接线生产，等待 D-02。本文件定义 C09 identity-transparency profile
/// 所需的 AI 域身份锚数据结构与本地验签逻辑，**没有任何生产调用点**：
/// 生产身份源仍是 [DeploymentScopedPeerIdentitySource]（派生指纹，
/// version=0）。接线时机与验收条件见 `cards/C06/` 身份锚设计说明。
///
/// == 为什么需要独立锚（AI-ID=B 已接受的残留风险） ==
///
/// 当前五元组的身份维是 `SHA-256(deploymentId|targetUid)` 派生值——它绑定
/// 部署与账号，但**不是由任何密钥持有方签名的材料**：恶意服务端可以让同一
/// uid 在不同时刻对应任意后端主体，客户端无法察觉。AI-ID=B 决策已接受该
/// 风险（历史决策不撤销）；顶尖 profile（C09）要求 AI 对端身份由
/// **部署签名密钥**对 **agent 自有身份密钥** 签名背书，使身份变化必然
/// 导致验签失败 → 五元组失效 → 强制重新确认。
///
/// == 锚结构与信任模型 ==
///
/// - **agent 身份密钥对**（ed25519）：agent 的自有身份材料，公钥入锚；
/// - **服务端签名**：部署签名密钥（ed25519）对锚主体 canonical 字节的
///   签名。注意：该签名证明的是「部署背书该 agent 公钥」，不证明部署
///   本身可信——恶意部署仍可签自己的锚（与 compliance 双 wrap 同一
///   信任边界，根治在 C09 transparency 目录，不在本文件）；
/// - **域分离常量** `imboy.ai-identity-anchor.v1`：作为 canonical 首字段
///   参与签名，防止本锚签名被重放到 trust-event / fallback-key 等其它
///   签名域（反之亦然）；
/// - **anchor_version**：锚结构自身版本（当前 1）；与 identity_version
///   （agent 身份材料版本，对应五元组第 5 维）语义分离、都参与签名。
///
/// == canonical 编码 ==
///
/// 与 [trust_event_canonical] / fallback_key_signature 同一方案（项目不
/// 发明第三套编码）：`key=value\n`，ASCII 字典序，末字段无尾随换行，
/// 整数十进制、UTF-8。字段值含换行一律 fail-closed 拒绝构造。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/ai_plaintext_gate.dart';

/// 域分离常量：参与 canonical 与签名，防跨协议签名重放。
const String kAiIdentityAnchorDomain = 'imboy.ai-identity-anchor.v1';

/// 当前锚结构版本。结构变更（加/删/改字段语义）必须递增。
const int kAiIdentityAnchorStructVersion = 1;

/// fail-closed 拒收含 `\n`/`\r` 的 canonical 字段值（破坏单射，见
/// [AiIdentityAnchor.canonicalBytes]）。
void _rejectNewline(String name, String value) {
  if (value.contains('\n') || value.contains('\r')) {
    throw ArgumentError.value(
      value,
      name,
      'must not contain newline (breaks canonical)',
    );
  }
}

/// AI 独立签名身份锚（不可变）。
///
/// 主体字段全部参与 canonical 与签名；[serverSignature] 是对
/// [canonicalBytes] 的 ed25519 签名（base64），[serverEd25519] 是验签
/// 公钥（自描述：锚自带验签材料，接收端无需额外目录——目录化是 C09
/// transparency profile 的工作）。
class AiIdentityAnchor {
  const AiIdentityAnchor({
    required this.agentUid,
    required this.deploymentId,
    required this.agentEd25519,
    required this.identityVersion,
    required this.serverEd25519,
    required this.issuedAt,
    this.anchorVersion = kAiIdentityAnchorStructVersion,
    this.serverSignature = '',
  });

  /// agent 账号 ID（字符串化 TSID；与五元组 targetUid 同一命名空间）。
  final String agentUid;

  /// 部署身份（与 [AiPlaintextGate.deploymentIdResolver] 同源）。
  final String deploymentId;

  /// agent 身份密钥对 ed25519 公钥（base64，32 字节）。
  final String agentEd25519;

  /// agent 身份材料版本（对应五元组 identity_version；防回退/前跳重放）。
  final int identityVersion;

  /// 部署签名公钥（base64）。锚自描述验签材料。
  final String serverEd25519;

  /// 签发时刻（毫秒）。freshness 由调用方（C09 profile）按策略校验，
  /// 本结构只保证其参与签名。
  final int issuedAt;

  /// 锚结构版本（当前 1）。
  final int anchorVersion;

  /// 部署签名密钥对 [canonicalBytes] 的签名（base64）。空 = 未签名锚
  /// （仅 fixture 组装中间态，[verifyServerSignature] 恒 false）。
  final String serverSignature;

  /// 产出 canonical 字节流（不含 [serverSignature] 自身）。
  ///
  /// 字段序（ASCII 字典序，末字段无尾随换行）：
  /// agent_ed25519 < agent_uid < anchor_version < deployment_id < domain
  /// < identity_version < issued_at < server_ed25519
  Uint8List canonicalBytes() {
    _rejectNewline('agentUid', agentUid);
    _rejectNewline('deploymentId', deploymentId);
    _rejectNewline('agentEd25519', agentEd25519);
    _rejectNewline('serverEd25519', serverEd25519);
    final payload =
        'agent_ed25519=$agentEd25519\n'
        'agent_uid=$agentUid\n'
        'anchor_version=$anchorVersion\n'
        'deployment_id=$deploymentId\n'
        'domain=$kAiIdentityAnchorDomain\n'
        'identity_version=$identityVersion\n'
        'issued_at=$issuedAt\n'
        'server_ed25519=$serverEd25519';
    return Uint8List.fromList(utf8.encode(payload));
  }

  /// canonical 字符串（签名/验签的 message，ASCII 安全）。
  String canonicalString() => String.fromCharCodes(canonicalBytes());

  /// 锚指纹：SHA-256(canonical bytes) hex。
  ///
  /// 指纹与**被签主体**逐字节绑定——任一字段（含域分离常量、锚结构版本）
  /// 变化必然改变指纹。这是将来替换派生指纹、接入五元组第 4 维的取值
  /// （等待 D-02；接线后旧派生指纹确认自动失效、强制重新确认）。
  String get anchorFingerprint => sha256.convert(canonicalBytes()).toString();

  /// 用锚自带的部署公钥验签 [serverSignature]。
  ///
  /// fail-closed：签名缺失/格式坏/验签失败/公钥非法一律 false，不抛。
  bool verifyServerSignature() {
    if (serverSignature.isEmpty) return false;
    try {
      final pub = vod.Ed25519PublicKey.fromBase64(serverEd25519);
      final sig = vod.Ed25519Signature.fromBase64(serverSignature);
      pub.verify(message: canonicalString(), signature: sig);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 把锚映射为五元组身份维（[AiPeerIdentity]）。
  ///
  /// 这是 D-02 接线时的目标形状：锚验签通过后，以 [anchorFingerprint] 与
  /// [identityVersion] 喂给 AiPlaintextGate——锚任何变化 = 指纹变化 =
  /// 旧确认失效。当前**无生产调用点**，仅供 fixture 测试与 C09 合同对齐。
  AiPeerIdentity toPeerIdentity() =>
      AiPeerIdentity(fingerprint: anchorFingerprint, version: identityVersion);

  /// 返回换掉签名的新锚（fixture 组装用：先构造未签名主体、签名后回填）。
  AiIdentityAnchor withServerSignature(String signature) => AiIdentityAnchor(
    agentUid: agentUid,
    deploymentId: deploymentId,
    agentEd25519: agentEd25519,
    identityVersion: identityVersion,
    serverEd25519: serverEd25519,
    issuedAt: issuedAt,
    anchorVersion: anchorVersion,
    serverSignature: signature,
  );
}
