/// 坐席会话动作辅助（§12.5.1 / CSM-02）
///
/// 纯 Dart 纯函数集合：转接目标过滤、关闭原因白名单/限长、消息
/// sender-actor 展示映射。全部可单测；文案（可解释层）不在本文件硬编码。
library;

import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

/// 转接目标候选：只列**同 Org** active customer_service identity，
/// 并排除当前经办身份自己（转给自己无意义）。
List<BusinessIdentity> csTransferTargets(
  List<BusinessIdentity> identities, {
  required EntityId organizationId,
  String excludeIdentityId = '',
}) {
  return identities
      .where(
        (i) =>
            i.organizationId == organizationId &&
            i.functionKey == kCsFunctionKey &&
            i.isActive &&
            i.id != excludeIdentityId,
      )
      .toList(growable: false);
}

/// 关闭原因清洗：剥离控制字符、去首尾空白、限长（默认 200 字符）。
///
/// 白名单语义：仅保留可见文本（含 CJK / 常用标点）；剥离后为空返回
/// null（调用方按「无 reason」提交）。服务端 reason 为 optional binary。
String? csSanitizeCloseReason(String? raw, {int maxLength = 200}) {
  if (raw == null) return null;
  // 剥离控制字符（保留空格；换行折叠为空格）
  final stripped = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
  if (stripped.isEmpty) return null;
  if (stripped.length <= maxLength) return stripped;
  return stripped.substring(0, maxLength);
}

/// 消息 sender-actor 展示（坐席侧视角）。
///
/// 布局方向：访客（contact 入站）在左；坐席（business_identity 出站）
/// 在右。展示名：坐席消息展示经办业务身份名（不是自然人好友，EB-D03/D05）；
/// 访客消息展示掩码客户名。
class CsSenderActorView {
  /// true = 坐席出站（右），false = 访客入站（左）。
  final bool isSeat;

  /// 展示名（访客已掩码；坐席为业务身份名或 wire 回落）。
  final String label;

  const CsSenderActorView({required this.isSeat, required this.label});
}

/// 由消息 DTO 映射展示（[contactMaskedName] 为调用方已掩码的客户名）。
CsSenderActorView csSenderActorView(
  EnterpriseMessage message, {
  required String contactMaskedName,
}) {
  if (message.senderType == EnterpriseSenderType.businessIdentity) {
    final name = message.senderBusinessIdentityName;
    return CsSenderActorView(
      isSeat: true,
      label: name.isEmpty
          ? EnterpriseSenderType.businessIdentity.wireName
          : name,
    );
  }
  return CsSenderActorView(isSeat: false, label: contactMaskedName);
}
