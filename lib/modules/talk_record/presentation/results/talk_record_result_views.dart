/// 面聊记录（talk_record）结果域共享视图件（T21）。
///
/// 从导出/移交/删除页拆出的展示件与通用模式：
/// - 清理状态卡（五态 + pending/none；与「记录已删除」分离展示，
///   排队≠字节已删除；受治理保护≠异常文案，UI-SPEC §4/DESIGN §6）；
/// - 结果页通用模式（操作成功/失败/等待三态 + 逐操作返回按钮）；
/// - 导出格式分段（C-F1）、独立副本确认行、移交候选选择列表、
///   保留查看开关区。
/// 本文件只做展示，不持有状态；横幅/头像/卡片底色复用 T18 基础件。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart'
    show TalkRecordExportDisableReason;
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_views.dart'
    show
        TalkRecordAvatarBadge,
        TalkRecordShareFeedbackBanner,
        talkRecordShareCardDecoration;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

// ---------------------------------------------------------------------------
// 清理状态卡（§10.4 五态；与删除标题分离）
// ---------------------------------------------------------------------------

/// 清理状态标题（五态 + pending/none/unknown 如实映射）。
String talkRecordCleanupTitle(TalkRecordCleanupStatus status) =>
    switch (status) {
      TalkRecordCleanupStatus.pending => t.talkRecord.cleanupPendingTitle,
      TalkRecordCleanupStatus.blockedRetention =>
        t.talkRecord.cleanupBlockedRetentionTitle,
      TalkRecordCleanupStatus.blockedHold =>
        t.talkRecord.cleanupBlockedHoldTitle,
      TalkRecordCleanupStatus.retainedByOtherReference =>
        t.talkRecord.cleanupRetainedTitle,
      TalkRecordCleanupStatus.failed => t.talkRecord.cleanupFailedTitle,
      TalkRecordCleanupStatus.complete => t.talkRecord.cleanupCompleteTitle,
      TalkRecordCleanupStatus.none => t.talkRecord.cleanupNoneTitle,
      TalkRecordCleanupStatus.unknown => t.talkRecord.cleanupUnknownTitle,
    };

/// 清理状态正文（受治理保护≠异常；failed 可重试；排队≠字节已删除）。
String talkRecordCleanupBody(TalkRecordCleanupStatus status) =>
    switch (status) {
      TalkRecordCleanupStatus.pending => t.talkRecord.cleanupPendingBody,
      TalkRecordCleanupStatus.blockedRetention =>
        t.talkRecord.cleanupBlockedRetentionBody,
      TalkRecordCleanupStatus.blockedHold =>
        t.talkRecord.cleanupBlockedHoldBody,
      TalkRecordCleanupStatus.retainedByOtherReference =>
        t.talkRecord.cleanupRetainedBody,
      TalkRecordCleanupStatus.failed => t.talkRecord.cleanupFailedBody,
      TalkRecordCleanupStatus.complete => t.talkRecord.cleanupCompleteBody,
      TalkRecordCleanupStatus.none => t.talkRecord.cleanupNoneBody,
      TalkRecordCleanupStatus.unknown => t.talkRecord.cleanupUnknownBody,
    };

/// 清理状态语义色（failed=警示；blocked/retained=中性保护提示；
/// complete=成功；pending/none/unknown=中性）。
Color talkRecordCleanupColor(
  TalkRecordCleanupStatus status,
  Brightness brightness,
) {
  if (status == TalkRecordCleanupStatus.failed) {
    return AppColors.getIosOrange(brightness);
  }
  if (status == TalkRecordCleanupStatus.complete) {
    return AppColors.getIosGreen(brightness);
  }
  return brightness == Brightness.dark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;
}

/// 清理状态卡：独立于「记录已删除」标题展示（UI-SPEC §4 冻结：不将排队
/// 成功冒充字节已删除；下方独立展示附件清理状态）。
class TalkRecordCleanupStatusCard extends StatelessWidget {
  const TalkRecordCleanupStatusCard({super.key, required this.status});

  final TalkRecordCleanupStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = talkRecordCleanupColor(status, brightness);
    return Container(
      key: ValueKey('talk_record_cleanup_status_card_${status.wireName}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.deleteCleanupSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Row(
            children: [
              Icon(
                status == TalkRecordCleanupStatus.complete
                    ? CupertinoIcons.checkmark_seal
                    : status == TalkRecordCleanupStatus.failed
                    ? CupertinoIcons.exclamationmark_triangle
                    : CupertinoIcons.clock,
                size: AppSpacing.xLarge,
                color: color,
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  talkRecordCleanupTitle(status),
                  // C-F3：标题可换行。
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            talkRecordCleanupBody(status),
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 结果页通用模式（成功/失败/等待三态 + 逐操作返回按钮）
// ---------------------------------------------------------------------------

/// 结果三态语义。
enum TalkRecordResultTone { success, failure, waiting }

class TalkRecordOperationResultView extends StatelessWidget {
  const TalkRecordOperationResultView({
    super.key,
    required this.tone,
    required this.title,
    required this.body,
    this.detailLines = const [],
    this.actions = const [],
  });

  final TalkRecordResultTone tone;
  final String title;
  final String body;
  final List<String> detailLines;
  final List<TalkRecordResultAction> actions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = switch (tone) {
      TalkRecordResultTone.success => AppColors.getIosGreen(brightness),
      TalkRecordResultTone.failure => AppColors.getIosOrange(brightness),
      TalkRecordResultTone.waiting =>
        brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
    };
    final icon = switch (tone) {
      TalkRecordResultTone.success => CupertinoIcons.checkmark_seal,
      TalkRecordResultTone.failure => CupertinoIcons.exclamationmark_triangle,
      TalkRecordResultTone.waiting => CupertinoIcons.clock,
    };
    return Center(
      key: ValueKey('talk_record_result_view_$tone'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: AppSpacing.xxxLarge + 8, color: color),
            const SizedBox(height: AppSpacing.medium),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              body,
              textAlign: TextAlign.center,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            for (final line in detailLines) ...[
              const SizedBox(height: AppSpacing.tiny),
              Text(
                line,
                textAlign: TextAlign.center,
                maxLines: null,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.large),
            // 逐操作按钮（返回详情/返回列表/重新生成等）。
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.small),
                child: action.build(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// 结果动作（每操作一个按钮；主/次与破坏性样式）。
class TalkRecordResultAction {
  const TalkRecordResultAction({
    required this.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final Key key;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;

  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (primary) {
      return SizedBox(
        // C-F2：主操作 ≥48 + primaryDark 实底白字。
        height: 48,
        width: double.infinity,
        child: CupertinoButton(
          key: key,
          minimumSize: const Size.fromHeight(48),
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(8),
          onPressed: onPressed,
          child: Text(
            label,
            style: context.textStyle(
              FontSizeType.body,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      );
    }
    return CupertinoButton(
      key: key,
      // C-F4：触达 ≥44。
      minimumSize: const Size(120, 44),
      onPressed: onPressed,
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.body,
          fontWeight: FontWeight.w600,
          color: destructive
              ? AppColors.getIosRed(brightness)
              : AppColors.primaryDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 导出格式分段（C-F1）与独立副本确认行
// ---------------------------------------------------------------------------

/// txt/md 二选一分段（选中态 primaryDark 实底 + 白字 w600，对齐 T16/T18）。
class TalkRecordExportFormatSegment extends StatelessWidget {
  const TalkRecordExportFormatSegment({
    super.key,
    required this.current,
    required this.enabled,
    required this.onSelect,
  });

  final TalkRecordExportFormat current;
  final bool enabled;
  final ValueChanged<TalkRecordExportFormat> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('talk_record_export_format_segment'),
      height: AppSpacing.xxxLarge,
      child: Row(
        children: [
          for (final (i, format) in [
            TalkRecordExportFormat.txt,
            TalkRecordExportFormat.md,
          ].indexed)
            Expanded(
              child: _FormatSegment(
                format: format,
                selected: enabled && current == format,
                enabled: enabled,
                borderRadius: BorderRadius.horizontal(
                  left: i == 0 ? const Radius.circular(8) : Radius.zero,
                  right: i == 1 ? const Radius.circular(8) : Radius.zero,
                ),
                onTap: enabled ? () => onSelect(format) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _FormatSegment extends StatelessWidget {
  const _FormatSegment({
    required this.format,
    required this.selected,
    required this.enabled,
    required this.borderRadius,
    required this.onTap,
  });

  final TalkRecordExportFormat format;
  final bool selected;
  final bool enabled;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final unselectedBg = brightness == Brightness.dark
        ? AppColors.darkSurfaceGrouped
        : AppColors.lightSurfaceGrouped;
    final disabledFg = brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final label = format == TalkRecordExportFormat.md
        ? t.talkRecord.exportFormatMd
        : t.talkRecord.exportFormatTxt;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        key: ValueKey('talk_record_export_format_${format.wireName}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: selected
              ? const ValueKey('talk_record_export_format_selected')
              : null,
          height: AppSpacing.xxxLarge,
          decoration: BoxDecoration(
            // C-F1：primaryDark(#1565C0) 实底 + 白字 w600（5.75:1）。
            color: selected ? AppColors.primaryDark : unselectedBg,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.normal,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? AppColors.onPrimary
                  : (enabled
                        ? (brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary)
                        : disabledFg),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「独立副本无法收回」主动确认行（未确认不允许生成，UI-SPEC §2）。
class TalkRecordIndependentCopySection extends StatelessWidget {
  const TalkRecordIndependentCopySection({
    super.key,
    required this.acked,
    required this.onChanged,
  });

  final bool acked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_export_independent_copy_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.exportIndependentCopyTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            t.talkRecord.exportIndependentCopyBody,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.body,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          GestureDetector(
            key: const ValueKey('talk_record_export_ack_row'),
            behavior: HitTestBehavior.opaque,
            // C-F4：触达 ≥44。
            onTap: () => onChanged(!acked),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  CupertinoCheckbox(
                    key: ValueKey('talk_record_export_ack_checkbox_$acked'),
                    value: acked,
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      t.talkRecord.exportIndependentCopyAck,
                      maxLines: null,
                      style: context.textStyle(
                        FontSizeType.body,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 移交候选选择 / 保留查看开关
// ---------------------------------------------------------------------------

/// 移交候选选择列表（fixture 候选；目标合法性由服务端裁决，§9）。
class TalkRecordTransferCandidateList extends StatelessWidget {
  const TalkRecordTransferCandidateList({
    super.key,
    required this.candidates,
    required this.selectedUserId,
    required this.onSelect,
  });

  final List<TalkRecordShareCandidateModel> candidates;
  final String selectedUserId;
  final void Function(TalkRecordShareCandidateModel) onSelect;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (candidates.isEmpty) {
      return Padding(
        key: const ValueKey('talk_record_transfer_candidates_empty'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.regular),
        child: Text(
          t.talkRecord.transferCandidateEmpty,
          maxLines: null,
          style: context.textStyle(
            FontSizeType.footnote,
            color: brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('talk_record_transfer_candidates'),
      children: [
        for (final candidate in candidates)
          GestureDetector(
            key: ValueKey('talk_record_transfer_candidate_${candidate.userId}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(candidate),
            child: ConstrainedBox(
              // C-F4：触达 ≥44。
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  TalkRecordAvatarBadge(label: candidate.displayName),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Text(
                      candidate.displayName,
                      // C-F3：长姓名换行。
                      maxLines: null,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (candidate.userId == selectedUserId)
                    Icon(
                      key: const ValueKey(
                        'talk_record_transfer_candidate_check',
                      ),
                      CupertinoIcons.check_mark,
                      size: AppSpacing.xLarge,
                      color: AppColors.primaryDark,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 原责任人是否保留查看开关（默认不保留，UI-SPEC §2 冻结）。
class TalkRecordKeepViewerSection extends StatelessWidget {
  const TalkRecordKeepViewerSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_transfer_keep_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.transferKeepSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.talkRecord.transferKeepViewer,
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              CupertinoSwitch(
                key: const ValueKey('talk_record_transfer_keep_switch'),
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            value
                ? t.talkRecord.transferKeepOnHint
                : t.talkRecord.transferKeepDefaultHint,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 导出禁用原因文案映射（能力优先于策略）。
String talkRecordExportDisableReasonText(
  TalkRecordExportDisableReason reason,
) => switch (reason) {
  TalkRecordExportDisableReason.noGrant => t.talkRecord.exportBlockedNoGrant,
  TalkRecordExportDisableReason.organizationPolicy =>
    t.talkRecord.exportBlockedOrgPolicy,
  TalkRecordExportDisableReason.instancePolicy =>
    t.talkRecord.exportBlockedInstancePolicy,
  TalkRecordExportDisableReason.policyUnknown =>
    t.talkRecord.exportBlockedUnknown,
};

/// 结果域反馈横幅（复用 T18 横幅形态的便捷别名）。
typedef TalkRecordResultsBanner = TalkRecordShareFeedbackBanner;
