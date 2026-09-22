/// Application 消息来源的展示面（FULL-05 / plan-full §3.3、§7）。
///
/// 会话 / 详情 / 审计三个面**共用同一判定与同一组件**（plan §3.3 要求
/// 「在会话/详情/通知/搜索/历史中一致」）：
///
/// - [HostedMessageBubbleDecoration.decorate]：会话气泡装饰——在企业托管消息
///   上叠加「应用代发 / 人工经应用」徽标 + 非 E2EE 标记（复用 GZ 期
///   `enterprise_oa` 的 `OaDelegatedBadge` / `OaNoE2eeMarker`，不重建）；
/// - [hostedMessageAuditLines]：审计/详情面**必须保留的事实键**（纯函数，
///   返回 label→value 行，测试可脱离 widget 直测）；
/// - [showHostedMessageAuditSheet]：详情/审计弹层。
///
/// 硬边界的组件层落法（与 `enterprise_message_origin.dart` 的分工）：
/// 判定在 domain（唯一入口），展示只做映射——**展示层不得自行解释来源**，
/// 也不得把企业托管消息渲染成「Human 直发的加密消息」。
///
/// 颜色/间距/字号一律走 AppColors / AppSpacing / AppRadius / FontSizeType，
/// 禁止硬编码。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_message_origin.dart';
import 'package:imboy/modules/enterprise_oa/public.dart'
    show OaDelegatedSenderLine, OaDelegatedSenderPresentation, OaNoE2eeMarker;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 会话气泡上的企业托管事实装饰。
class HostedMessageBubbleDecoration {
  const HostedMessageBubbleDecoration._();

  /// 把 [metadata]（聊天消息 metadata，企业托管消息含 payload 顶层 `origin`）
  /// 解析成事实并装饰 [child]。
  ///
  /// 普通 Human 消息（无 origin）原样返回 [child]——**零改动**，Human-Human
  /// E2EE 渲染链完全不变（INV-6）。
  static Widget decorate({
    required BuildContext context,
    required Map<String, dynamic>? metadata,
    required Widget child,
    String senderDisplayName = '',
  }) {
    final HostedMessageFacts facts = resolveHostedMessageFacts(
      payload: metadata,
      e2ee: _e2eeOf(metadata),
      senderDisplayName: senderDisplayName,
    );
    if (!facts.showsDelegationBadge && !facts.needsOriginWarning) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        HostedMessageFactsRow(facts: facts),
        AppSpacing.verticalTiny,
        child,
      ],
    );
  }
}

/// 企业托管事实行（徽标 + 非 E2EE 标记）。
class HostedMessageFactsRow extends StatelessWidget {
  const HostedMessageFactsRow({super.key, required this.facts});

  final HostedMessageFacts facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.tiny,
      runSpacing: AppSpacing.tiny / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 两个代发分支**用同一组件的不同文案**——GZ 期的 OaDelegatedBadge 把
        // 二者合并成一个「OA 代发」，FULL-05 必须把 application 与 human 拆开，
        // 故此处改用并列命名的 HostedSenderKindChip；GZ 的 OaNoE2eeMarker
        // 与 OaDelegatedSenderLine 仍在本模块复用（见下方审计面）。
        if (facts.isApplicationDelegated)
          const HostedSenderKindChip(human: false),
        if (facts.isHumanDelegated) const HostedSenderKindChip(human: true),
        if (facts.showsNoE2eeMarker) const OaNoE2eeMarker(),
        if (facts.needsOriginWarning) const HostedOriginWarningChip(),
      ],
    );
  }
}

/// 「人类经应用」/「应用代发」标签（与「Human 直发」在视觉上可区分）。
///
/// GZ 期的 `OaDelegatedBadge` 文案是「OA 代发」，对 `sender_kind=human`
/// （应用代已映射 Human 发送）语义不精确；本组件补上 human 分支，两者
/// 用不同文案与不同颜色，**任何一面都不会把两者混为一谈**。
class HostedSenderKindChip extends StatelessWidget {
  const HostedSenderKindChip({super.key, required this.human});

  /// true = `sender_kind=human`（人工经应用）；false = application 代发。
  final bool human;

  @override
  Widget build(BuildContext context) {
    final String label = human
        ? t.enterpriseApp.badgeHumanDelegated
        : t.enterpriseApp.badgeAppDelegated;
    final Color color = human ? AppColors.slateText : AppColors.tagAccent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny,
        vertical: AppSpacing.tiny / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.tiny,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 来源不一致 / 来源不可识别的可见提示（不静默吞掉）。
class HostedOriginWarningChip extends StatelessWidget {
  const HostedOriginWarningChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.exclamationmark_triangle,
          size: AppSizes.iconSizeXSmall,
          color: AppColors.warning,
        ),
        AppSpacing.horizontalTiny,
        Text(
          t.enterpriseApp.originMismatchTitle,
          style: context.textStyle(FontSizeType.tiny, color: AppColors.warning),
        ),
      ],
    );
  }
}

/// 审计/详情面的一行（label → value，均为本地化后的可见文本）。
class HostedAuditLine {
  const HostedAuditLine({required this.label, required this.value});

  final String label;
  final String value;
}

/// **审计/详情面的事实行**（纯函数，测试可脱离 widget 直测）。
///
/// 覆盖 [HostedAuditFacts.traceableFields] 的每一项，**不省略**：
/// 企业托管与否、sender 类型、Application origin、非 E2EE 事实、
/// 以及「双痕迹冲突」这一不一致标记本身。这是「详情/审计面必须保留 OA 代发
/// 与非 E2EE 的事实」的可测落点。
List<HostedAuditLine> hostedMessageAuditLines(HostedAuditFacts facts) {
  final String senderKindLabel = switch (facts.senderKind) {
    HostedSenderKind.application => t.enterpriseApp.originSenderApplication,
    HostedSenderKind.human => t.enterpriseApp.originSenderHuman,
    null => t.enterpriseApp.originUnrecognized,
  };
  final List<HostedAuditLine> lines = <HostedAuditLine>[
    HostedAuditLine(
      label: t.enterpriseApp.originTitle,
      value: facts.messageClass.isEnterpriseHosted
          ? t.enterpriseApp.originHosted
          : facts.messageClass.wireName,
    ),
  ];
  if (facts.messageClass.isEnterpriseHosted) {
    lines.add(
      HostedAuditLine(
        label: t.enterpriseApp.originLabelSender,
        value: senderKindLabel,
      ),
    );
    lines.add(
      HostedAuditLine(
        label: t.enterpriseApp.originTitle,
        value: t.enterpriseApp.originApplicationId(id: facts.applicationId),
      ),
    );
  }
  lines.add(
    HostedAuditLine(
      label: t.enterpriseApp.originLabelEncryption,
      // **非 E2EE 事实**：企业托管恒为非 E2EE；非托管则如实反映载荷。
      value: facts.isNonE2ee
          ? t.enterpriseApp.originNonE2ee
          : t.enterpriseApp.originE2ee,
    ),
  );
  if (facts.originContradictsE2ee) {
    lines.add(
      HostedAuditLine(
        label: t.enterpriseApp.originMismatchTitle,
        value: t.enterpriseApp.originMismatchHint,
      ),
    );
  }
  return lines;
}

/// 打开消息来源详情/审计弹层。
Future<void> showHostedMessageAuditSheet(
  BuildContext context, {
  required HostedMessageFacts facts,
}) {
  final List<HostedAuditLine> lines = hostedMessageAuditLines(facts.audit);
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.enterpriseApp.originTitle,
                    style: ctx.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(CupertinoIcons.xmark),
                  tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                ),
              ],
            ),
            if (facts.senderDisplayName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.small),
                child: facts.isEnterpriseHosted
                    // 复用广州期组件：主视图按 Human 显示名，附注保留代发 origin。
                    ? OaDelegatedSenderLine(
                        presentation: OaDelegatedSenderPresentation(
                          humanDisplayName: facts.senderDisplayName,
                          oaOrigin: facts.origin?.applicationId ?? '',
                        ),
                      )
                    : Text(
                        facts.senderDisplayName,
                        style: ctx.textStyle(FontSizeType.footnote),
                      ),
              ),
            ...lines.map(
              (HostedAuditLine line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.label,
                      style: ctx.textStyle(
                        FontSizeType.tiny,
                        color: AppColors.slateText,
                      ),
                    ),
                    Text(line.value, style: ctx.textStyle(FontSizeType.normal)),
                  ],
                ),
              ),
            ),
            if (facts.isEnterpriseHosted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: HostedMessageFactsRow(facts: facts),
              ),
          ],
        ),
      ),
    ),
  );
}

/// **通知面**的来源前缀（纯函数；空串 = 普通消息，通知文案零改动）。
///
/// plan §3.3 要求「会话/详情/通知/搜索/历史一致」；系统通知只有一行标题
/// 可用，故这里给的是**前缀**而不是整块组件——同一条判定、同一份文案，
/// 只是承载形态不同。
String hostedMessageNotificationPrefix(
  Map<String, dynamic>? payload, {
  Map<String, dynamic>? e2ee,
}) {
  final HostedMessageFacts facts = resolveHostedMessageFacts(
    payload: payload,
    e2ee: e2ee,
  );
  if (facts.isApplicationDelegated) {
    return '${t.enterpriseApp.badgeAppDelegated} · ';
  }
  if (facts.isHumanDelegated) {
    return '${t.enterpriseApp.badgeHumanDelegated} · ';
  }
  if (facts.needsOriginWarning) {
    return '${t.enterpriseApp.originMismatchTitle} · ';
  }
  return '';
}

/// 从聊天消息 metadata 取 e2ee 载荷（Map / JSON 字符串两种形态）。
Map<String, dynamic>? _e2eeOf(Map<String, dynamic>? metadata) {
  final dynamic raw = metadata?['e2ee'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}
