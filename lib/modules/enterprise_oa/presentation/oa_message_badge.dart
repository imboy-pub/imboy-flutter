/// OA 代发消息 UI 标签组件（EPGZ-06 W1 / plan §4.3、§7.2）
///
/// 纯展示 widget（零业务依赖），用于消息气泡上的代发事实呈现：
/// - [OaDelegatedBadge]：气泡内「OA 代发」徽标；
/// - [OaNoE2eeMarker]：非 E2EE 状态标记（企业托管 · 未端到端加密）；
/// - [OaDelegatedSenderLine]：sender 展示格式 = 指定 Human 显示名 +
///   OA origin（plan §4.3：主视图按 Human 展示，但代发事实可见）。
///
/// plan §4.3 硬性约束（组件层落法）：
/// - OA 代发消息**不得显示 E2EE 标识**（用 [OaNoE2eeMarker] 显式标注
///   非 E2EE，而非复用 Human-Human 的加密标识）；
/// - 普通消息的 E2EE 标识链路完全不变（本组件不触碰）；
/// - sender 按 Human 显示名展示，origin 附注可审计。
///
/// 颜色/间距/字号全部走 AppColors / AppSpacing / AppRadius /
/// FontSizeType token，禁止硬编码。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 代发 sender 展示的纯数据形态（供列表/详情/导出复用同一格式）。
class OaDelegatedSenderPresentation {
  const OaDelegatedSenderPresentation({
    required this.humanDisplayName,
    required this.oaOrigin,
  });

  /// 被指定代发名义的 Human 显示名（消息主视图按此展示）。
  final String humanDisplayName;

  /// 代发 Application 绑定的 OA origin（host 形态或完整 origin）。
  final String oaOrigin;

  /// 展示主文本：Human 显示名。
  String get primary => humanDisplayName;

  /// 展示附注文本键参数：origin（由 UI 层用 i18n 模板渲染，
  /// 模板形如「经 某origin域名 代发」，具体值取 [oaOrigin]）。
  String get originNote => oaOrigin;
}

/// 「OA 代发」徽标（气泡内小尺寸 chip）。
class OaDelegatedBadge extends StatelessWidget {
  const OaDelegatedBadge({super.key, this.compact = false});

  /// 紧凑形态：气泡信息行内使用（更小字号 + 更低内边距）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny + (compact ? 0 : AppSpacing.tiny / 2),
        vertical: AppSpacing.tiny / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.tagAccent.withValues(alpha: 0.14),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        t.enterpriseOa.badgeDelegated,
        style: context.textStyle(
          compact ? FontSizeType.tiny : FontSizeType.small,
          color: AppColors.tagAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 非 E2EE 状态标记：企业托管 · 未端到端加密。
///
/// 仅用于 OA 代发消息；Human-Human 消息的 E2EE 标识不受影响。
class OaNoE2eeMarker extends StatelessWidget {
  const OaNoE2eeMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.eye,
          size: AppSizes.iconSizeXSmall,
          color: AppColors.slateText,
        ),
        SizedBox(width: AppSpacing.tiny),
        Text(
          t.enterpriseOa.markerNoE2ee,
          style: context.textStyle(
            FontSizeType.tiny,
            color: AppColors.slateText,
          ),
        ),
      ],
    );
  }
}

/// 代发 sender 展示行：Human 显示名 + 「经 `<origin>` 代发」附注。
///
/// 详情页/审计视图使用；列表主视图可只用 [presentation.primary]
/// 的 Human 显示名（plan §4.3：主视图按 Human 展示，详情保留代发事实）。
class OaDelegatedSenderLine extends StatelessWidget {
  const OaDelegatedSenderLine({
    super.key,
    required this.presentation,
    this.showOriginNote = true,
  });

  final OaDelegatedSenderPresentation presentation;

  /// 是否展示 origin 附注（导出/审计场景必开；紧凑列表可关）。
  final bool showOriginNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            presentation.primary,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (showOriginNote) ...[
          SizedBox(width: AppSpacing.tiny),
          Flexible(
            child: Text(
              t.enterpriseOa.senderVia(origin: presentation.originNote),
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.tiny,
                color: AppColors.slateText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
