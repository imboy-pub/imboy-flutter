/// 面聊记录发言人校对页（T16）。
///
/// 契约源：UI-SPEC §2「发言人」+ BACKEND-API §4 speakers 端点：
/// - 匿名/人工标记来源 pill（人工标记 ≠ 本人认证，UI-SPEC §2/§3）；
/// - 试听片段入口（定位播放器到该说话人首个片段；本页同样挂播放器条）；
/// - 设置显示名（editor/owner）；认领自己（有访问权参与者；已有他人
///   认领 409 → 提示走 owner 人工纠正）；
/// - editor 可标记同事（人工标记 pill；候选来自 T10 参与者目录，目录
///   待接入时如实提示，不猜候选人）；
/// - 只作用于本记录；不默认建立声纹（DESIGN §3）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_player_bar.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart'
    show talkRecordParticipantDirectoryProvider;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 发言人校对页。
class TalkRecordSpeakersPage extends ConsumerStatefulWidget {
  const TalkRecordSpeakersPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordSpeakersPage> createState() =>
      _TalkRecordSpeakersPageState();
}

class _TalkRecordSpeakersPageState
    extends ConsumerState<TalkRecordSpeakersPage> {
  final TextEditingController _nameController = TextEditingController();
  StreamSubscription<dynamic>? _localeSubscription;
  TalkRecordPlayerNotifier? _playerNotifier;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(talkRecordSpeakersProvider.notifier)
          .bind(widget.recordId, force: true);
      // 片段用于「试听定位」（说话人首个片段时间点）。
      ref.read(talkRecordSegmentsProvider.notifier).bind(widget.recordId);
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _nameController.dispose();
    _playerNotifier?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(talkRecordDetailProvider);
    final speakers = ref.watch(talkRecordSpeakersProvider);
    final segments = ref.watch(talkRecordSegmentsProvider);
    final record = detail.record;
    _playerNotifier = ref.read(talkRecordPlayerProvider.notifier);
    if (record != null) {
      // attach 推迟到帧后（build 内禁止修改 provider 状态）。
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
    final canEdit =
        record != null &&
        talkRecordActorRoleOf(record.capabilitiesForActor) !=
            TalkRecordActorRole.viewer;

    return IosPageTemplate(
      title: t.talkRecord.speakersTitle,
      body:
          speakers.phase == TalkRecordSpeakersPhase.loading ||
              speakers.phase == TalkRecordSpeakersPhase.idle
          ? const ShimmerList()
          : speakers.phase == TalkRecordSpeakersPhase.failed
          ? _FailedSpeakers(
              onRetry: () =>
                  ref.read(talkRecordSpeakersProvider.notifier).reload(),
            )
          : _buildList(canEdit, speakers, segments.segments),
      bottomWidget: const TalkRecordPlayerBar(),
    );
  }

  Widget _buildList(
    bool canEdit,
    TalkRecordSpeakersState speakers,
    List<TalkRecordSegmentModel> segments,
  ) {
    final brightness = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.small),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t.talkRecord.speakersScopeHint,
              // C-F3：范围说明可换行。
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          if (speakers.claimConflict)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: _ClaimConflictBanner(),
            ),
          const SizedBox(height: AppSpacing.small),
          for (final speaker in speakers.speakers)
            _SpeakerRow(
              speaker: speaker,
              canEdit: canEdit,
              auditionMs: _firstSegmentMs(speaker, segments),
              onAudition: (ms) => _playerNotifier?.seekTo(ms),
              onSetName: () => _showSetNameDialog(speaker),
              onClaimSelf: () => _claimSelf(speaker),
              onMarkColleague: () => _showMarkColleagueSheet(speaker),
            ),
        ],
      ),
    );
  }

  int? _firstSegmentMs(
    TalkRecordSpeakerModel speaker,
    List<TalkRecordSegmentModel> segments,
  ) {
    final sorted = [...segments]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    for (final s in sorted) {
      if (s.speakerId == speaker.id) return s.startMs;
    }
    return null;
  }

  Future<void> _claimSelf(TalkRecordSpeakerModel speaker) async {
    await ref.read(talkRecordSpeakersProvider.notifier).claimSelf(speaker.id);
  }

  Future<void> _showSetNameDialog(TalkRecordSpeakerModel speaker) async {
    _nameController.text = speaker.displayName;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        key: const ValueKey('talk_record_speaker_rename_dialog'),
        title: Text(t.talkRecord.speakerSetNameTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.small),
          child: CupertinoTextField(
            key: const ValueKey('talk_record_speaker_name_field'),
            controller: _nameController,
            placeholder: speaker.localLabel,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(t.talkRecord.notesCancel),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(t.talkRecord.speakerSetNameConfirm),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(talkRecordSpeakersProvider.notifier)
          .setDisplayName(speaker.id, _nameController.text.trim());
    }
  }

  Future<void> _showMarkColleagueSheet(TalkRecordSpeakerModel speaker) async {
    final directory = ref.read(talkRecordParticipantDirectoryProvider);
    if (!directory.isAvailable) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          key: const ValueKey('talk_record_mark_colleague_unavailable'),
          title: Text(t.talkRecord.speakerMarkColleague),
          content: Text(t.talkRecord.speakerDirectoryUnavailable),
          actions: [
            CupertinoDialogAction(
              child: Text(t.talkRecord.moreActionsCancel),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
      return;
    }
    final candidates = await directory.search('', '');
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        key: const ValueKey('talk_record_mark_colleague_sheet'),
        title: Text(t.talkRecord.speakerMarkColleague),
        actions: [
          for (final option in candidates)
            CupertinoActionSheetAction(
              key: ValueKey('talk_record_mark_candidate_${option.userId}'),
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ref
                    .read(talkRecordSpeakersProvider.notifier)
                    .markColleague(speaker.id, option.userId);
              },
              child: Text(
                option.displayName.isNotEmpty
                    ? option.displayName
                    : option.userId,
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(t.talkRecord.moreActionsCancel),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 行
// ---------------------------------------------------------------------------

class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({
    required this.speaker,
    required this.canEdit,
    required this.auditionMs,
    required this.onAudition,
    required this.onSetName,
    required this.onClaimSelf,
    required this.onMarkColleague,
  });

  final TalkRecordSpeakerModel speaker;
  final bool canEdit;
  final int? auditionMs;
  final ValueChanged<int> onAudition;
  final VoidCallback onSetName;
  final VoidCallback onClaimSelf;
  final VoidCallback onMarkColleague;

  String get _displayName =>
      speaker.displayName.isNotEmpty ? speaker.displayName : speaker.localLabel;

  String get _sourceText => switch (speaker.identitySource) {
    TalkRecordSpeakerIdentitySource.manual => t.talkRecord.speakerManualPill,
    TalkRecordSpeakerIdentitySource.selfClaim =>
      t.talkRecord.speakerSelfClaimPill,
    _ => t.talkRecord.speakerAnonymousPill,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: ValueKey('talk_record_speaker_row_${speaker.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
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
                child: Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _displayName,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    _SourcePill(text: _sourceText, manual: _isManual),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          // C-F3：来源说明可换行（人工标记≠本人认证）。
          if (_isManual ||
              speaker.identitySource ==
                  TalkRecordSpeakerIdentitySource.selfClaim)
            Text(
              t.talkRecord.speakerSourceHint,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.caption2,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              if (auditionMs != null)
                _RowAction(
                  icon: CupertinoIcons.headphones,
                  label: t.talkRecord.speakerAudition,
                  key: ValueKey('talk_record_speaker_audition_${speaker.id}'),
                  onTap: () => onAudition(auditionMs!),
                ),
              // 认领自己：有记录访问权的现场参与者（服务端校验）。
              _RowAction(
                icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                label: t.talkRecord.speakerClaimSelf,
                key: ValueKey('talk_record_speaker_claim_${speaker.id}'),
                onTap: onClaimSelf,
              ),
              if (canEdit) ...[
                _RowAction(
                  icon: CupertinoIcons.pencil,
                  label: t.talkRecord.speakerSetName,
                  key: ValueKey('talk_record_speaker_rename_${speaker.id}'),
                  onTap: onSetName,
                ),
                _RowAction(
                  icon: CupertinoIcons.person_badge_plus,
                  label: t.talkRecord.speakerMarkColleague,
                  key: ValueKey('talk_record_speaker_mark_${speaker.id}'),
                  onTap: onMarkColleague,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool get _isManual =>
      speaker.identitySource == TalkRecordSpeakerIdentitySource.manual;
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.text, required this.manual});

  final String text;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = manual
        ? AppColors.primaryDark
        : (brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: brightness == Brightness.dark ? 0.24 : 0.08,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.textStyle(FontSizeType.caption2, color: color),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        // C-F4：行内动作触达 ≥44pt。
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(
              alpha: brightness == Brightness.dark ? 0.24 : 0.08,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppSpacing.medium + 4,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: AppSpacing.tiny + 2),
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimConflictBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_claim_conflict_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness)
            .withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.talkRecord.speakerClaimConflict,
        // C-F3：冲突说明可换行。
        maxLines: null,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: AppColors.getIosOrange(brightness),
        ),
      ),
    );
  }
}

class _FailedSpeakers extends StatelessWidget {
  const _FailedSpeakers({required this.onRetry});

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
            style: context.textStyle(
              FontSizeType.medium,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            key: const ValueKey('talk_record_speakers_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
