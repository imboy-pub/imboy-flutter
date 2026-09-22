/// 附件留存治理面板（FULL-05 / INT-22 的可见状态）。
///
/// 如实展示三态（留存期 / hold / purge）并给出**不可删除**与**purge 被挡原因**：
/// - hold/purge 标签取自 [AssetHoldState.labelKey] / [AssetPurgeState.labelKey]
///   对应文案（held 绝不显示成 none）；
/// - 治理记录不可删除由 [AssetRetentionRecord.isDeletableByClient] 恒 false
///   决定，UI **不提供**删除入口，只展示 [t.enterpriseApp.retentionNoDelete]；
/// - purge 被挡时按 [PurgeBlockedReason] 给出具体原因（不是笼统失败）。
///
/// 颜色/间距/字号一律走 token。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/domain/asset_retention_governance.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 附件留存治理面板（纯展示：状态由调用方取好后传入）。
class AssetRetentionPanel extends StatelessWidget {
  const AssetRetentionPanel({
    super.key,
    required this.record,
    this.now,
    this.onPurge,
    this.onHold,
    this.onReleaseHold,
    this.onExtend,
  });

  final AssetRetentionRecord record;

  /// 到期判定基准时间（测试注入固定时间；生产缺省用当前时间）。
  final DateTime? now;

  final VoidCallback? onPurge;
  final VoidCallback? onHold;
  final VoidCallback? onReleaseHold;
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final PurgeBlockedReason blocked = record.purgeBlockedReasonAt(
      now ?? DateTime.now(),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t.enterpriseApp.retentionTitle,
            style: context.textStyle(
              FontSizeType.medium,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.verticalSmall,
          _row(
            context,
            t.enterpriseApp.retentionUntil(
              time: record.retentionUntil.isEmpty ? '—' : record.retentionUntil,
            ),
            _holdLabel(context),
          ),
          if (record.isHeld && record.holdReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.enterpriseApp.holdReason(reason: record.holdReason),
                style: context.textStyle(
                  FontSizeType.tiny,
                  color: AppColors.slateText,
                ),
              ),
            ),
          AppSpacing.verticalSmall,
          _row(
            context,
            t.enterpriseApp.retentionExtendOnly,
            record.isPurged
                ? t.enterpriseApp.purgePurged
                : t.enterpriseApp.purgeLive,
          ),
          // 不可删除：设计上不存在该操作（不是权限不足）。
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
            child: Row(
              children: <Widget>[
                const Icon(
                  CupertinoIcons.lock,
                  size: AppSizes.iconSizeXSmall,
                  color: AppColors.slateText,
                ),
                AppSpacing.horizontalTiny,
                Expanded(
                  child: Text(
                    t.enterpriseApp.retentionNoDelete,
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: AppColors.slateText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // purge 被挡原因（具体到 hold / 未到期 / 已清除）。
          if (blocked != PurgeBlockedReason.none)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: _chip(context, purgeBlockedLabel(blocked)),
            ),
          AppSpacing.verticalSmall,
          _actions(context, blocked),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String left, String right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(left, style: context.textStyle(FontSizeType.footnote)),
        ),
        AppSpacing.horizontalTiny,
        Text(
          right,
          style: context.textStyle(
            FontSizeType.footnote,
            color: AppColors.slateText,
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.tiny / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.tiny,
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, PurgeBlockedReason blocked) {
    // 已清除是终态：不再展示任何写动作（回退在契约上不存在）。
    if (record.isPurged) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.small,
      children: <Widget>[
        if (onExtend != null)
          TextButton(
            onPressed: onExtend,
            child: Text(t.enterpriseApp.retentionExtendOnly),
          ),
        if (record.isHeld && onReleaseHold != null)
          TextButton(
            onPressed: onReleaseHold,
            child: Text(t.enterpriseApp.holdHeld),
          ),
        if (!record.isHeld && onHold != null)
          TextButton(onPressed: onHold, child: Text(t.enterpriseApp.holdNone)),
        if (onPurge != null && blocked == PurgeBlockedReason.none)
          TextButton(
            onPressed: onPurge,
            child: Text(t.enterpriseApp.purgeLive),
          ),
      ],
    );
  }

  String _holdLabel(BuildContext context) {
    switch (record.holdState) {
      case AssetHoldState.held:
        return t.enterpriseApp.holdHeld;
      case AssetHoldState.none:
        return t.enterpriseApp.holdNone;
    }
  }
}

/// purge 被挡原因 → 本地化文案（穷尽 switch）。
String purgeBlockedLabel(PurgeBlockedReason reason) {
  switch (reason) {
    case PurgeBlockedReason.holdActive:
      return t.enterpriseApp.purgeBlockedHold;
    case PurgeBlockedReason.retentionNotElapsed:
      return t.enterpriseApp.purgeBlockedRetention;
    case PurgeBlockedReason.alreadyPurged:
      return t.enterpriseApp.purgeBlockedPurged;
    case PurgeBlockedReason.none:
      return '';
  }
}
