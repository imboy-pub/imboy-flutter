/// 面聊记录准备页分区组件（T10）：保存到行、处理方式降级区、企业协作
/// 折叠区、已告知确认行、权限拒绝/引擎占位面板。
///
/// 从 talk_record_prepare_page.dart 拆出（文件 <800 行约束）；视觉契约
/// （C-F1/C-F2/C-F3、44/48/67pt 触达）与页面注释一致，见页面文件头。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart'
    show kTalkRecordSaveLocationPath;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_entry_context.dart';
import 'talk_record_participant_picker.dart';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import 'talk_record_prepare_page.dart' show TalkRecordProcessingAvailability;
import 'talk_record_providers.dart';
import 'talk_record_services.dart';

// ---------------------------------------------------------------------------
// 通用小组件
// ---------------------------------------------------------------------------

class TalkRecordPrepareSectionCard extends StatelessWidget {
  const TalkRecordPrepareSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class TalkRecordPrepareFieldLabel extends StatelessWidget {
  const TalkRecordPrepareFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      text,
      style: context.textStyle(
        FontSizeType.footnote,
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 保存到行
// ---------------------------------------------------------------------------

class TalkRecordSaveToRow extends StatelessWidget {
  const TalkRecordSaveToRow({super.key, required this.saveTo});

  final TalkRecordEntryContext saveTo;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isOrg = saveTo.isOrganization;
    final name = isOrg
        ? (saveTo.organizationName.isNotEmpty
              ? saveTo.organizationName
              : t.talkRecord.contextOrgFallback)
        : t.talkRecord.contextPersonal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 触达 ≥44pt。携带当前有效保存到（保存位置页据此标记当前选择；
      // 不携带会误回落 personal——widget 测试发现的真缺陷）。
      onTap: () {
        final query = saveTo
            .toQuery()
            .entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        context.push('$kTalkRecordSaveLocationPath?$query');
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(
              isOrg ? CupertinoIcons.building_2_fill : CupertinoIcons.person_2,
              size: AppSpacing.xLarge,
              color: AppColors.getIosBlue(brightness),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: context.textStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (isOrg && saveTo.hasWorkspace) ...[
                    const SizedBox(height: 2),
                    Text(
                      saveTo.workspaceName,
                      // C-F3：可换行。
                      style: context.textStyle(
                        FontSizeType.normal,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              t.talkRecord.saveToChangeAction,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.primaryDark,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: AppSpacing.medium + 2,
              color: AppColors.getIosSeparator(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 处理方式（capabilities 降级）
// ---------------------------------------------------------------------------

class TalkRecordProcessingSection extends StatelessWidget {
  const TalkRecordProcessingSection({
    super.key,
    required this.availability,
    required this.selected,
    required this.loadingCapabilities,
    required this.onSelect,
  });

  final TalkRecordProcessingAvailability availability;
  final TalkRecordProcessingMode selected;
  final bool loadingCapabilities;
  final ValueChanged<TalkRecordProcessingMode> onSelect;

  String _label(TalkRecordProcessingMode mode) {
    return switch (mode) {
      TalkRecordProcessingMode.transcribe => t.talkRecord.processingTranscribe,
      TalkRecordProcessingMode.summarize => t.talkRecord.processingSummarize,
      _ => t.talkRecord.processingRecordOnly,
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final reasonText = switch (availability.reasonKey) {
      'processingReasonUnavailable' => t.talkRecord.processingReasonUnavailable,
      'processingReasonQuota' => t.talkRecord.processingReasonQuota,
      'processingReasonLoadFailed' =>
        loadingCapabilities ? null : t.talkRecord.processingReasonLoadFailed,
      _ => null,
    };

    return TalkRecordPrepareSectionCard(
      children: [
        TalkRecordPrepareFieldLabel(t.talkRecord.processingSectionTitle),
        const SizedBox(height: AppSpacing.small),
        // 降级为单档时禁选（如实展示唯一选项，不渲染假开关）。
        if (availability.modes.length == 1)
          _SingleModeTile(label: _label(availability.modes.first))
        else
          SizedBox(
            height: AppSpacing.xxxLarge,
            child: Row(
              children: [
                for (final (i, mode) in availability.modes.indexed)
                  Expanded(
                    child: _ModeSegment(
                      label: _label(mode),
                      selected: selected == mode,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? const Radius.circular(8) : Radius.zero,
                        right: i == availability.modes.length - 1
                            ? const Radius.circular(8)
                            : Radius.zero,
                      ),
                      onTap: () => onSelect(mode),
                    ),
                  ),
              ],
            ),
          ),
        if (reasonText != null) ...[
          const SizedBox(height: AppSpacing.small),
          // C-F3：降级原因可换行（禁单行截断）。
          Text(
            reasonText,
            key: const ValueKey('talk_record_processing_reason'),
            style: context.textStyle(
              FontSizeType.small,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
        if (availability.modes.length == 1 &&
            availability.reasonKey == null) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            t.talkRecord.processingRecordOnlyHint,
            style: context.textStyle(
              FontSizeType.small,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SingleModeTile extends StatelessWidget {
  const _SingleModeTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: AppSpacing.xxxLarge,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurfaceGrouped
            : AppColors.lightSurfaceGrouped,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.medium,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.borderRadius = BorderRadius.zero,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // C-F1：选中态白字 on primaryDark(#1565C0) = 5.75:1（≥4.5）。
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: AppSpacing.xxxLarge,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryDark
              : (brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface),
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
                : (brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 企业协作信息折叠区（选填参与者）
// ---------------------------------------------------------------------------

class TalkRecordCollabSection extends ConsumerStatefulWidget {
  const TalkRecordCollabSection({
    super.key,
    required this.organizationId,
    this.workspaceId = '',
    required this.participants,
    required this.onToggleParticipant,
    this.onReplaceParticipants,
  });

  final EntityId organizationId;
  final EntityId workspaceId;
  final List<TalkRecordParticipantSelection> participants;
  final ValueChanged<TalkRecordParticipantSelection> onToggleParticipant;
  final ValueChanged<List<TalkRecordParticipantSelection>>?
  onReplaceParticipants;

  @override
  ConsumerState<TalkRecordCollabSection> createState() =>
      _TalkRecordCollabSectionState();
}

class _TalkRecordCollabSectionState
    extends ConsumerState<TalkRecordCollabSection> {
  bool _expanded = false, _choosing = false;

  Future<void> _choose() async {
    if (_choosing) return;
    final epoch = ref.read(talkRecordAuthEpochProvider);
    final original = List.of(widget.participants);
    final entry = TalkRecordEntryContext(
      scope: TalkRecordScope.organization,
      organizationId: widget.organizationId,
      workspaceId: widget.workspaceId,
    );
    setState(() => _choosing = true);
    try {
      final chosen = await showTalkRecordParticipantPicker(
        context,
        entryContext: entry,
        selected: original
            .map(
              (item) => TalkRecordParticipantInput(
                userId: item.userId,
                displayName: item.displayName,
              ),
            )
            .toList(growable: false),
      );
      if (!mounted ||
          chosen == null ||
          epoch != ref.read(talkRecordAuthEpochProvider) ||
          entry.organizationId != widget.organizationId ||
          entry.workspaceId != widget.workspaceId) {
        return;
      }
      final next = chosen
          .map(
            (item) => TalkRecordParticipantSelection(
              userId: item.userId,
              displayName: item.displayName,
            ),
          )
          .toList(growable: false);
      final replace = widget.onReplaceParticipants;
      if (replace != null) {
        replace(next);
      } else {
        for (final item in original.where((item) => !next.contains(item))) {
          widget.onToggleParticipant(item);
        }
        for (final item in next.where((item) => !original.contains(item))) {
          widget.onToggleParticipant(item);
        }
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      talkRecordAuthEpochProvider,
      (_, _) => setState(() => _expanded = false),
    );
    final brightness = Theme.of(context).brightness;
    final directory = ref.watch(talkRecordParticipantDirectoryProvider);
    return TalkRecordPrepareSectionCard(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.talkRecord.collabSectionTitle,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w600,
                        color: (brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                      ),
                    ),
                    Text(
                      widget.participants.isEmpty
                          ? t.talkRecord.collabSectionSubtitle
                          : t.talkRecord.collabParticipantsCount(
                              count: widget.participants.length,
                            ),
                      style: context.textStyle(
                        FontSizeType.normal,
                        color: (brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.small),
          TalkRecordPrepareFieldLabel(t.talkRecord.collabParticipantsLabel),
          if (!directory.isAvailable)
            Text(
              t.talkRecord.collabParticipantsUnavailable,
              key: const ValueKey('talk_record_participants_unavailable'),
            )
          else
            CupertinoButton(
              key: const ValueKey('talk_record_participants_choose'),
              onPressed: _choosing ? null : _choose,
              child: Text(
                widget.participants.isEmpty
                    ? t.talkRecord.collabParticipantsEmpty
                    : t.talkRecord.collabParticipantsCount(
                        count: widget.participants.length,
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 已告知确认（67px 触达区）
// ---------------------------------------------------------------------------

class TalkRecordNoticeRow extends StatelessWidget {
  const TalkRecordNoticeRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 原型 label 触达区 67px：整行可点 + minHeight 67（CONTRACT-FREEZE
    // T04 触达约束的页面级对齐）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        key: const ValueKey('talk_record_notice_row'),
        constraints: const BoxConstraints(minHeight: 67),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: AppSpacing.xLarge + 8,
              height: AppSpacing.xLarge + 8,
              child: Center(
                child: Icon(
                  value
                      ? CupertinoIcons.checkmark_square_fill
                      : CupertinoIcons.square,
                  size: AppSpacing.xLarge + 2,
                  color: value
                      ? AppColors.primaryDark
                      : AppColors.getIosSeparator(brightness),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                t.talkRecord.noticeCheckbox,
                // C-F3：确认文案可换行（大字号下不截断）。
                style: context.textStyle(
                  FontSizeType.normal,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 权限拒绝 / 引擎占位面板
// ---------------------------------------------------------------------------

class TalkRecordMicDeniedPanel extends StatelessWidget {
  const TalkRecordMicDeniedPanel({
    super.key,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_mic_denied_panel'),
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.talkRecord.micDeniedTitle,
            style: context.textStyle(
              FontSizeType.normal,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          // C-F3：说明可换行。
          Text(
            t.talkRecord.micDeniedMessage,
            style: context.textStyle(
              FontSizeType.normal,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Row(
            children: [
              CupertinoButton(
                key: const ValueKey('talk_record_mic_retry'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                ),
                minimumSize: const Size(44, 44),
                onPressed: onRetry,
                child: Text(t.talkRecord.micRetry),
              ),
              const SizedBox(width: AppSpacing.small),
              CupertinoButton(
                key: const ValueKey('talk_record_mic_settings'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                ),
                minimumSize: const Size(44, 44),
                onPressed: () => onOpenSettings(),
                child: Text(t.talkRecord.micOpenSettings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TalkRecordInfoPanel extends StatelessWidget {
  const TalkRecordInfoPanel({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_recording_unavailable_panel'),
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.textStyle(
              FontSizeType.normal,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          // C-F3：说明可换行。
          Text(
            message,
            style: context.textStyle(
              FontSizeType.normal,
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
