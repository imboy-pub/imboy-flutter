/// 面聊记录详情页（T16）。
///
/// 契约源：UI-SPEC §2「详情」+ §3 角色表 + §4 状态文案；DESIGN §4：
/// - 可见范围概述 + 角色态徽章（只读不只靠颜色，显示角色文字）；
/// - 摘要/原文页签（C-F1：选中态 primaryDark 底 + 白字）；
/// - 固定迷你播放器（进度触达 ≥44、播放/暂停、时间、回到播放位置）；
/// - 讨论重点/待办草稿（AI 草稿标注 + 过时标记）；共享补充笔记
///   （editor 可编辑/viewer 只读）；
/// - 仅录音/无语音/转写失败/摘要过时真实降级（不渲染虚构正文）；
/// - 更多操作：分享/导出/删除按角色与能力出现（UI-SPEC §3；实际操作
///   留 T17/T19/T20，入口诚实标注待接入）。
library;

import 'dart:async';

import 'talk_record_participants_page.dart';
import '../ai/talk_record_ai_processing_panel.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_player_bar.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_summary_section.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_transcript_view.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

enum _DetailTab { summary, transcript }

/// 详情页。
class TalkRecordDetailPage extends ConsumerStatefulWidget {
  const TalkRecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordDetailPage> createState() =>
      _TalkRecordDetailPageState();
}

class _TalkRecordDetailPageState extends ConsumerState<TalkRecordDetailPage> {
  final GlobalKey<TalkRecordTranscriptViewState> _transcriptKey =
      GlobalKey<TalkRecordTranscriptViewState>();

  _DetailTab _tab = _DetailTab.summary;
  bool _anchorMismatch = false;
  final _aiKey = GlobalKey<TalkRecordAiProcessingPanelState>();
  StreamSubscription<dynamic>? _localeSubscription;
  TalkRecordPlayerNotifier? _playerNotifier;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  Future<void> _bind() async {
    ref
        .read(talkRecordDetailProvider.notifier)
        .bind(widget.recordId, force: true);
    ref.read(talkRecordSegmentsProvider.notifier).bind(widget.recordId);
    ref.read(talkRecordSpeakersProvider.notifier).bind(widget.recordId);
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    // 受控回放会话不跨页面残留（预取量最小化 + 撤权边界）。
    _playerNotifier?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(talkRecordDetailProvider);
    final record = detail.record;
    _playerNotifier = ref.read(talkRecordPlayerProvider.notifier);
    if (record != null) {
      // attach 会改写 provider 状态，必须推迟到帧后（build 内禁止修改）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _playerNotifier?.attach(
          recordId: record.id,
          durationMs: record.durationMs,
          playbackAllowed: record.capabilitiesForActor.playback,
          useParts:
              record.mediaStatus == TalkRecordMediaStatus.assembling ||
              record.mediaStatus == TalkRecordMediaStatus.retryableFailed,
        );
      });
    }

    // 未加载完成沿用中性占位；已加载但无标题的老数据按创建时间显示
    // 时间戳命名（20261105-152101 式），不显示无信息量的「未命名」。
    final title = record == null
        ? t.talkRecord.untitledRecord
        : (record.title.isNotEmpty
              ? record.title
              : talkRecordStampTitle(record.createdAt));
    // 更多入口仅在存在可用操作时出现（UI-SPEC §3：viewer/editor 不显示
    // 分享管理与删除；无任何能力时隐藏入口而非空菜单）。
    final caps = record?.capabilitiesForActor;
    final hasAnyAction =
        caps != null && (caps.share || caps.export || caps.delete);

    return IosPageTemplate(
      title: title,
      actions: record == null || !hasAnyAction
          ? null
          : [_MoreEntry(record: record)],
      contentMaxWidth: ResourcePageLayout.maxWidth,
      body: _buildBody(detail),
      bottomWidget: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResourcePageLayout.maxWidth,
          ),
          child: TalkRecordPlayerBar(
            returnEntryVisible:
                _anchorMismatch && _tab == _DetailTab.transcript,
            onReturnToPlayback: () =>
                _transcriptKey.currentState?.jumpToPlayingSegment(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(TalkRecordDetailState detail) {
    if (detail.phase == TalkRecordDetailPhase.loading ||
        detail.phase == TalkRecordDetailPhase.idle) {
      return const ShimmerList();
    }
    final record = detail.record;
    if (detail.phase == TalkRecordDetailPhase.failed || record == null) {
      return _FailedView(onRetry: _bind);
    }
    final segments = ref.watch(talkRecordSegmentsProvider);
    final speakers = ref.watch(talkRecordSpeakersProvider);
    final player = ref.watch(talkRecordPlayerProvider);
    final role = talkRecordActorRoleOf(record.capabilitiesForActor);
    final canEdit = role != TalkRecordActorRole.viewer;

    return Column(
      children: [
        _OverviewCard(record: record, role: role),
        if (canEdit && record.mediaStatus == TalkRecordMediaStatus.available)
          TalkRecordAiProcessingPanel(key: _aiKey, recordId: record.id),
        _TabBar(current: _tab, onSelect: (tab) => setState(() => _tab = tab)),
        if (_tab == _DetailTab.transcript)
          Padding(
            padding: AppSpacing.pageHorizontal,
            child: _SpeakersEntry(recordId: record.id),
          ),
        Expanded(
          child: _tab == _DetailTab.transcript
              ? TalkRecordTranscriptView(
                  key: _transcriptKey,
                  mode: _transcriptMode(record),
                  segments: segments.segments,
                  speakers: speakers.speakers,
                  marks: detail.marks,
                  query: segments.query,
                  canEdit: canEdit,
                  playingPositionMs: player.loaded || player.playing
                      ? player.positionMs
                      : -1,
                  playerActive: player.loaded || player.playing,
                  onQueryChanged: (q) =>
                      ref.read(talkRecordSegmentsProvider.notifier).setQuery(q),
                  onListenFrom: (ms) => _seekPlayer(ms),
                  onEditSegment: (s) => _pushSegmentEdit(s),
                  onRetryTranscribe: () =>
                      _aiKey.currentState?.start('transcribe'),
                  onAnchorMismatchChanged: (m) {
                    if (m != _anchorMismatch) {
                      setState(() => _anchorMismatch = m);
                    }
                  },
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.regular),
                  child: TalkRecordSummarySection(
                    record: record,
                    summary: detail.summary,
                    segments: segments.segments,
                    canEditNotes: canEdit,
                    onJumpToSegment: _jumpToSegmentFromSummary,
                  ),
                ),
        ),
      ],
    );
  }

  TalkRecordTranscriptMode _transcriptMode(TalkRecordModel record) {
    switch (record.transcriptStatus) {
      case TalkRecordProcessingStatus.noSpeech:
        return TalkRecordTranscriptMode.noSpeech;
      case TalkRecordProcessingStatus.failed:
        return TalkRecordTranscriptMode.failed;
      case TalkRecordProcessingStatus.queued:
      case TalkRecordProcessingStatus.running:
        return TalkRecordTranscriptMode.processing;
      case TalkRecordProcessingStatus.ready:
        return TalkRecordTranscriptMode.normal;
      default:
        return TalkRecordTranscriptMode.recordOnly;
    }
  }

  Future<void> _seekPlayer(int positionMs) async {
    await ref.read(talkRecordPlayerProvider.notifier).seekTo(positionMs);
  }

  void _pushSegmentEdit(TalkRecordSegmentModel segment) {
    context.push(
      '$kTalkRecordDetailPath/${widget.recordId}/segment/${segment.id}',
    );
  }

  /// 摘要条目关联片段：切原文页签 + 定位播放器 + 滚动到片段（显式跳转，
  /// 更新阅读锚点）。
  Future<void> _jumpToSegmentFromSummary(TalkRecordSegmentModel segment) async {
    setState(() => _tab = _DetailTab.transcript);
    await _seekPlayer(segment.startMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transcriptKey.currentState?.jumpToPlayingSegment();
    });
  }
}

// ---------------------------------------------------------------------------
// 轻量概述（可见范围、角色、时长/状态与参与者）
// ---------------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.record, required this.role});

  final TalkRecordModel record;
  final TalkRecordActorRole role;

  String get _roleText => switch (role) {
    TalkRecordActorRole.owner => t.talkRecord.roleOwner,
    TalkRecordActorRole.editor => t.talkRecord.roleEditor,
    TalkRecordActorRole.viewer => t.talkRecord.roleViewer,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final status = talkRecordStatusText(record);
    return Container(
      key: const ValueKey('talk_record_overview_card'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // C-F3：标记组 Wrap 换行；角色不只靠颜色，显示角色文字。
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetadataLabel(
                key: const ValueKey('talk_record_role_badge'),
                text: _roleText,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              _MetadataLabel(
                key: const ValueKey('talk_record_visibility_badge'),
                text: talkRecordVisibilityText(record),
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              if (status != null)
                _MetadataLabel(
                  key: const ValueKey('talk_record_status_badge'),
                  text: status,
                  color:
                      record.mediaStatus ==
                              TalkRecordMediaStatus.retryableFailed ||
                          record.transcriptStatus ==
                              TalkRecordProcessingStatus.failed
                      ? AppColors.getIosOrange(brightness)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              _MetadataLabel(
                key: const ValueKey('talk_record_duration_badge'),
                text:
                    '${t.talkRecord.durationLabel} '
                    '${talkRecordFormatDuration(record.durationMs)}',
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CupertinoButton(
              key: const ValueKey('talk_record_participants_entry'),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) =>
                      TalkRecordParticipantsPage(recordId: record.id),
                ),
              ),
              child: Text(
                t.talkRecord.collabParticipantsLabel,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.getIosBlue(brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakersEntry extends StatelessWidget {
  const _SpeakersEntry({required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return CellPressable(
      key: const ValueKey('talk_record_speakers_entry'),
      onTap: () => context.push('$kTalkRecordDetailPath/$recordId/speakers'),
      child: ConstrainedBox(
        // C-F4：触达 ≥44pt。
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.person_2,
              size: AppSpacing.xLarge,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                t.talkRecord.speakersEntry,
                style: context.textStyle(
                  FontSizeType.footnote,
                  fontWeight: FontWeight.w400,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: AppSpacing.medium + 4,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataLabel extends StatelessWidget {
  const _MetadataLabel({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textStyle(FontSizeType.footnote, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// 页签（C-F1）
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelect});

  final _DetailTab current;
  final ValueChanged<_DetailTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('talk_record_detail_tabs'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResourcePageLayout.maxWidth / 2,
            minHeight: AppSpacing.xxxLarge,
          ),
          child: Row(
            children: [
              for (final (i, tab) in [
                _DetailTab.summary,
                _DetailTab.transcript,
              ].indexed)
                Expanded(
                  child: _TabSegment(
                    label: tab == _DetailTab.summary
                        ? t.talkRecord.tabSummary
                        : t.talkRecord.tabTranscript,
                    selected: current == tab,
                    borderRadius: BorderRadius.horizontal(
                      left: i == 0 ? const Radius.circular(8) : Radius.zero,
                      right: i == 1 ? const Radius.circular(8) : Radius.zero,
                    ),
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.selected,
    required this.borderRadius,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final unselectedBg = brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final unselectedFg = brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    return CellPressable(
      key: ValueKey('talk_record_tab_${label.hashCode}'),
      onTap: onTap,
      child: Semantics(
        selected: selected,
        child: Container(
          // C-F1：选中态 primaryDark(#1565C0) 实底 + 白字 w600（5.75:1，
          // 明暗两态同款；对齐 T10 分段方案，不复刻原型对比缺陷）。
          key: selected
              ? const ValueKey('talk_record_tab_selected_container')
              : null,
          constraints: const BoxConstraints(minHeight: AppSpacing.xxxLarge),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryDark : unselectedBg,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.normal,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onPrimary : unselectedFg,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 更多操作（按角色与能力出现）
// ---------------------------------------------------------------------------

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({required this.record});

  final TalkRecordModel record;

  Future<void> _openSheet(BuildContext context) async {
    final caps = record.capabilitiesForActor;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        key: const ValueKey('talk_record_more_sheet'),
        title: Text(t.talkRecord.moreActionsTitle),
        actions: [
          // UI-SPEC §3：viewer/editor 不出现分享管理；非 owner 不出现删除。
          if (caps.share)
            CupertinoActionSheetAction(
              key: const ValueKey('talk_record_action_share'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _pendingIntegration(sheetContext, t.talkRecord.actionShare);
              },
              child: Text(t.talkRecord.actionShare),
            ),
          if (caps.export)
            CupertinoActionSheetAction(
              key: const ValueKey('talk_record_action_export'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _pendingIntegration(sheetContext, t.talkRecord.actionExport);
              },
              child: Text(t.talkRecord.actionExport),
            ),
          if (caps.delete)
            CupertinoActionSheetAction(
              key: const ValueKey('talk_record_action_delete'),
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _pendingIntegration(sheetContext, t.talkRecord.actionDelete);
              },
              child: Text(t.talkRecord.actionDelete),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(t.talkRecord.moreActionsCancel),
        ),
      ),
    );
  }

  void _pendingIntegration(BuildContext context, String action) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        key: const ValueKey('talk_record_action_pending_dialog'),
        title: Text(action),
        content: Text(t.talkRecord.actionPendingIntegration),
        actions: [
          CupertinoDialogAction(
            child: Text(t.talkRecord.moreActionsCancel),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return CupertinoButton(
      key: const ValueKey('talk_record_more_entry'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => _openSheet(context),
      child: Icon(
        CupertinoIcons.ellipsis_circle,
        semanticLabel: t.talkRecord.moreActionsTitle,
        size: AppSpacing.xLarge + 8,
        color: brightness == Brightness.dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 失败态
// ---------------------------------------------------------------------------

class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.talkRecord.loadFailedTitle,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.medium,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            key: const ValueKey('talk_record_detail_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
