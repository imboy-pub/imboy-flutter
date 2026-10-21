/// 面聊记录详情摘要区（T16）：摘要降级态、AI 草稿标注、过时标记、
/// 讨论重点/待办草稿（每条关联原文片段，tap 定位播放器+原文）、
/// 共享补充笔记（editor 可编辑/viewer 只读）。
///
/// 契约源：UI-SPEC §2「详情」+ §4 状态文案 + DESIGN.md §4/§5：
/// - 摘要「AI 整理草稿 · 使用前请核对」；过时「原文或署名已更新，
///   摘要可能过时」；
/// - 模型未配置/无权限/空内容各用不同文案，不伪造摘要（§5）；
/// - 共享笔记明确「随记录共享」，不叫「我的私密笔记」（§4）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 摘要 tab 内容（滚动容器由宿主提供）。
class TalkRecordSummarySection extends ConsumerStatefulWidget {
  const TalkRecordSummarySection({
    super.key,
    required this.record,
    required this.summary,
    required this.segments,
    required this.canEditNotes,
    required this.onJumpToSegment,
  });

  final TalkRecordModel record;
  final TalkRecordSummaryModel? summary;
  final List<TalkRecordSegmentModel> segments;
  final bool canEditNotes;

  /// decision/action 关联片段点击：详情页切原文页签并定位（播放器+滚动）。
  final void Function(TalkRecordSegmentModel segment) onJumpToSegment;

  @override
  ConsumerState<TalkRecordSummarySection> createState() =>
      _TalkRecordSummarySectionState();
}

class _TalkRecordSummarySectionState
    extends ConsumerState<TalkRecordSummarySection> {
  final TextEditingController _notesController = TextEditingController();
  bool _notesEditing = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.record.notes;
  }

  @override
  void didUpdateWidget(TalkRecordSummarySection old) {
    super.didUpdateWidget(old);
    if (old.record.notes != widget.record.notes && !_notesEditing) {
      _notesController.text = widget.record.notes;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(talkRecordDetailProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryBlock(
          record: widget.record,
          summary: widget.summary,
          segments: widget.segments,
          onJumpToSegment: widget.onJumpToSegment,
        ),
        const SizedBox(height: AppSpacing.medium),
        _NotesCard(
          controller: _notesController,
          editing: _notesEditing,
          canEdit: widget.canEditNotes,
          notesPhase: detail.notesPhase,
          onEdit: () => setState(() => _notesEditing = true),
          onCancel: () {
            _notesController.text = widget.record.notes;
            setState(() => _notesEditing = false);
          },
          onSave: () async {
            final ok = await ref
                .read(talkRecordDetailProvider.notifier)
                .saveNotes(_notesController.text);
            if (ok && mounted) setState(() => _notesEditing = false);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 摘要主体（降级矩阵）
// ---------------------------------------------------------------------------

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.record,
    required this.summary,
    required this.segments,
    required this.onJumpToSegment,
  });

  final TalkRecordModel record;
  final TalkRecordSummaryModel? summary;
  final List<TalkRecordSegmentModel> segments;
  final void Function(TalkRecordSegmentModel segment) onJumpToSegment;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final s = summary;
    final body = switch (_mode(record, s)) {
      _SummaryMode.staleBannerContent => _content(context, s!),
      _SummaryMode.content => _content(context, s!),
      _SummaryMode.queued => _hint(
        context,
        icon: CupertinoIcons.clock,
        text: t.talkRecord.summaryQueued,
      ),
      _SummaryMode.running => _hint(
        context,
        icon: CupertinoIcons.hourglass,
        text: t.talkRecord.summaryRunning,
      ),
      _SummaryMode.notRequested => _hint(
        context,
        icon: CupertinoIcons.doc_text,
        text: record.transcriptStatus == TalkRecordProcessingStatus.ready
            ? t.talkRecord.summaryNotGenerated
            : t.talkRecord.summaryNoSource,
      ),
      _SummaryMode.unavailable => _hint(
        context,
        icon: CupertinoIcons.nosign,
        text: t.talkRecord.summaryUnavailable,
      ),
      _SummaryMode.failed => _hint(
        context,
        icon: CupertinoIcons.exclamationmark_triangle,
        text: t.talkRecord.summaryFailed,
        warn: true,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.talkRecord.summarySectionTitle,
                style: context.textStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              // AI 草稿标注：不因状态不同而消失（确认后除外——V1 未做确认流）。
              _DraftBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          body,
        ],
      ),
    );
  }

  _SummaryMode _mode(TalkRecordModel r, TalkRecordSummaryModel? s) {
    if (s == null) return _SummaryMode.notRequested;
    switch (r.summaryStatus) {
      case TalkRecordProcessingStatus.queued:
        return _SummaryMode.queued;
      case TalkRecordProcessingStatus.running:
        return _SummaryMode.running;
      case TalkRecordProcessingStatus.failed:
        return _SummaryMode.failed;
      case TalkRecordProcessingStatus.unavailable:
        return _SummaryMode.unavailable;
      case TalkRecordProcessingStatus.notRequested:
      case TalkRecordProcessingStatus.noSpeech:
      case TalkRecordProcessingStatus.unknown:
        return s.hasContent ? _SummaryMode.content : _SummaryMode.notRequested;
      case TalkRecordProcessingStatus.ready:
        return s.status == TalkRecordSummaryStatus.stale
            ? _SummaryMode.staleBannerContent
            : _SummaryMode.content;
    }
  }

  Widget _content(BuildContext context, TalkRecordSummaryModel s) {
    final brightness = Theme.of(context).brightness;
    final stale = s.status == TalkRecordSummaryStatus.stale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Container(
              key: const ValueKey('talk_record_summary_stale_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.small),
              decoration: BoxDecoration(
                color: AppColors.getIosOrange(brightness).withValues(
                  alpha: brightness == Brightness.dark ? 0.24 : 0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.talkRecord.summaryStaleBanner,
                // C-F3：过时标记可换行。
                maxLines: null,
                style: context.textStyle(
                  FontSizeType.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getIosOrange(brightness),
                ),
              ),
            ),
          ),
        // C-F3：摘要正文可换行。
        Text(
          s.overview,
          maxLines: null,
          style: context.textStyle(
            FontSizeType.body,
            color: brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        if (s.decisions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.medium),
          _ItemList(
            titleKey: const ValueKey('talk_record_summary_decisions'),
            title: t.talkRecord.summaryDecisionsTitle,
            items: s.decisions,
            segments: segments,
            onJumpToSegment: onJumpToSegment,
          ),
        ],
        if (s.actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.medium),
          _ItemList(
            titleKey: const ValueKey('talk_record_summary_actions'),
            title: t.talkRecord.summaryActionsTitle,
            items: s.actions,
            segments: segments,
            onJumpToSegment: onJumpToSegment,
          ),
        ],
      ],
    );
  }

  Widget _hint(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool warn = false,
  }) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: AppSpacing.medium + 4,
          color: warn
              ? AppColors.getIosOrange(brightness)
              : (brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          // C-F3：提示可换行。
          child: Text(
            text,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.normal,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

enum _SummaryMode {
  content,
  staleBannerContent,
  queued,
  running,
  notRequested,
  unavailable,
  failed,
}

class _DraftBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_summary_draft_badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(
          alpha: brightness == Brightness.dark ? 0.28 : 0.1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.talkRecord.summaryDraftBadge,
        style: context.textStyle(
          FontSizeType.caption2,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.titleKey,
    required this.title,
    required this.items,
    required this.segments,
    required this.onJumpToSegment,
  });

  final Key titleKey;
  final String title;
  final List<TalkRecordSummaryItem> items;
  final List<TalkRecordSegmentModel> segments;
  final void Function(TalkRecordSegmentModel segment) onJumpToSegment;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          key: titleKey,
          style: context.textStyle(
            FontSizeType.footnote,
            fontWeight: FontWeight.w600,
            color: brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.tiny),
        for (final item in items)
          _ItemRow(
            item: item,
            segments: segments,
            onJumpToSegment: onJumpToSegment,
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.segments,
    required this.onJumpToSegment,
  });

  final TalkRecordSummaryItem item;
  final List<TalkRecordSegmentModel> segments;
  final void Function(TalkRecordSegmentModel segment) onJumpToSegment;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final linked = _firstLinkedSegment();
    final unresolved = item.assignee.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.tiny,
        bottom: AppSpacing.tiny,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                // C-F3：条目文本可换行；负责人/日期未指定不编造（§11.2）。
                child: Text(
                  unresolved
                      ? '${item.text} · ${t.talkRecord.summaryAssigneeUnset}'
                      : '${item.text} → ${item.assignee}',
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
          if (linked != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.medium + 2),
              child: GestureDetector(
                key: ValueKey('talk_record_summary_item_jump_${linked.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onJumpToSegment(linked),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.link,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.talkRecord.summaryJumpToSource,
                        style: context.textStyle(
                          FontSizeType.caption2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TalkRecordSegmentModel? _firstLinkedSegment() {
    for (final id in item.segmentIds) {
      for (final s in segments) {
        if (s.id == id) return s;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// 共享补充笔记
// ---------------------------------------------------------------------------

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.controller,
    required this.editing,
    required this.canEdit,
    required this.notesPhase,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool editing;
  final bool canEdit;
  final TalkRecordNotesPhase notesPhase;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_notes_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.talkRecord.notesTitle,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (canEdit && !editing)
                CupertinoButton(
                  key: const ValueKey('talk_record_notes_edit'),
                  minimumSize: Size(44, 32),
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                  child: Text(t.talkRecord.notesEditAction),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          // 随记录共享（不是个人私密笔记，§4）。
          Text(
            canEdit
                ? t.talkRecord.notesSharedHint
                : t.talkRecord.notesReadonlyHint,
            // C-F3：提示可换行。
            maxLines: null,
            style: context.textStyle(
              FontSizeType.caption2,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          if (editing) ...[
            CupertinoTextField(
              key: const ValueKey('talk_record_notes_field'),
              controller: controller,
              minLines: 3,
              maxLines: 8,
              placeholder: t.talkRecord.notesPlaceholder,
            ),
          ] else
            Text(
              controller.text.isEmpty
                  ? t.talkRecord.notesEmpty
                  : controller.text,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.body,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          if (editing) ...[
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    key: const ValueKey('talk_record_notes_cancel'),
                    onPressed: onCancel,
                    child: Text(t.talkRecord.notesCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  // C-F2：保存主按钮 ≥48pt、primaryDark 底白字。
                  child: SizedBox(
                    height: AppSpacing.xxxLarge,
                    child: CupertinoButton(
                      key: const ValueKey('talk_record_notes_save'),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.primaryDark,
                      padding: EdgeInsets.zero,
                      onPressed: onSave,
                      child: Text(
                        t.talkRecord.notesSave,
                        style: context.textStyle(
                          FontSizeType.normal,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (notesPhase == TalkRecordNotesPhase.saved)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.talkRecord.notesSavedHint,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          if (notesPhase == TalkRecordNotesPhase.conflict)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.talkRecord.notesConflictHint,
                maxLines: null,
                style: context.textStyle(
                  FontSizeType.caption2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getIosOrange(brightness),
                ),
              ),
            ),
          if (notesPhase == TalkRecordNotesPhase.failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.talkRecord.notesFailedHint,
                maxLines: null,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: AppColors.getIosOrange(brightness),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
