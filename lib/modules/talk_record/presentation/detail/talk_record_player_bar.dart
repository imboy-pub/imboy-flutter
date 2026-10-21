/// 面聊记录详情固定迷你播放器（T16）。
///
/// 契约源：UI-SPEC §2「详情」+ DESIGN.md §4：
/// - 进度条触达区 ≥44pt（视觉轨道可细）；播放/暂停 ≥44pt；
/// - 「回到播放位置」入口：播放进度离开用户阅读锚点时出现（原文流
///   不被强制滚动抢位，DESIGN §4）；
/// - 时间等宽数字（tabular figures）；
/// - 无回放能力/票据失败如实禁用（不假装可播）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 固定迷你播放器条（详情页/发言人页底部 bottomWidget 挂载）。
class TalkRecordPlayerBar extends ConsumerWidget {
  const TalkRecordPlayerBar({
    super.key,
    this.onReturnToPlayback,
    this.returnEntryVisible = false,
  });

  /// 「回到播放位置」点击回调（宿主滚动原文到播放中片段；null=无原文
  /// 视图的页面，如发言人页，不渲染该入口）。
  final VoidCallback? onReturnToPlayback;

  /// 播放位置是否已离开用户阅读锚点（由原文流维护并上报）。
  final bool returnEntryVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(talkRecordPlayerProvider);
    final brightness = Theme.of(context).brightness;

    if (player.recordId.isEmpty) return const SizedBox.shrink();

    final disabled = player.unavailable;
    final duration = player.durationMs > 0 ? player.durationMs : 0;
    final safeDuration = duration > 0 ? duration : 1;
    final progress = (player.positionMs.clamp(0, safeDuration)) / safeDuration;

    return Container(
      key: const ValueKey('talk_record_player_bar'),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: brightness == Brightness.dark
                ? AppColors.darkTextSecondary.withValues(alpha: 0.2)
                : AppColors.lightTextSecondary.withValues(alpha: 0.15),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (returnEntryVisible && !disabled && onReturnToPlayback != null)
              _ReturnToPlaybackEntry(onTap: onReturnToPlayback!),
            if (disabled)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                // C-F3：禁用说明可换行，不截断。
                child: Text(
                  player.failure
                      ? t.talkRecord.playbackTicketFailed
                      : t.talkRecord.playbackUnavailable,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              )
            else if (player.failure)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.talkRecord.playbackTicketFailed,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.getIosOrange(brightness),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('talk_record_playback_retry'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size(44, 32),
                      onPressed: () =>
                          ref.read(talkRecordPlayerProvider.notifier).play(),
                      child: Text(t.talkRecord.loadFailedAction),
                    ),
                  ],
                ),
              ),
            // 进度条：触达区整条 ≥44pt，视觉轨道 4pt。
            _ProgressTrack(
              progress: progress,
              enabled: !disabled,
              positionMs: player.positionMs,
              durationMs: duration,
              onScrub: (ms) =>
                  ref.read(talkRecordPlayerProvider.notifier).scrubTo(ms),
            ),
            Row(
              children: [
                _PlayButton(
                  playing: player.playing,
                  enabled: !disabled,
                  onTap: () =>
                      ref.read(talkRecordPlayerProvider.notifier).toggle(),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(child: _TimeLabel(positionMs: player.positionMs)),
                Text(
                  talkRecordFormatDuration(duration),
                  style: context.textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnToPlaybackEntry extends StatelessWidget {
  const _ReturnToPlaybackEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('talk_record_return_to_playback'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        // C-F4：触达 ≥44pt。
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.location_fill,
              size: AppSpacing.medium + 4,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Semantics(
                button: true,
                label: t.talkRecord.returnToPlayback,
                child: Text(
                  t.talkRecord.returnToPlayback,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.progress,
    required this.enabled,
    required this.positionMs,
    required this.durationMs,
    required this.onScrub,
  });

  final double progress;
  final bool enabled;
  final int positionMs;
  final int durationMs;
  final ValueChanged<int> onScrub;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Semantics(
      label: t.talkRecord.playbackProgressLabel(
        position: talkRecordFormatDuration(positionMs),
        duration: talkRecordFormatDuration(durationMs),
      ),
      value: '${(progress * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          return GestureDetector(
            key: const ValueKey('talk_record_player_progress'),
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled && trackWidth > 0
                ? (d) => onScrub(
                    ((d.localPosition.dx / trackWidth) * durationMs)
                        .round()
                        .clamp(0, durationMs),
                  )
                : null,
            child: ConstrainedBox(
              // C-F4：进度条触达区整条 ≥44pt（视觉轨道 4pt 在 Stack 内）。
              constraints: const BoxConstraints(minHeight: 44),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextSecondary.withValues(alpha: 0.25)
                          : AppColors.lightTextSecondary.withValues(
                              alpha: 0.18,
                            ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: enabled
                            ? AppColors.primaryDark
                            : AppColors.lightTextSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.enabled,
    required this.onTap,
  });

  final bool playing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing
          ? t.talkRecord.playbackPauseLabel
          : t.talkRecord.playbackPlayLabel,
      child: GestureDetector(
        key: ValueKey(
          playing ? 'talk_record_player_pause' : 'talk_record_player_play',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            size: AppSpacing.xLarge,
            color: enabled
                ? AppColors.primaryDark
                : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.positionMs});

  final int positionMs;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      talkRecordFormatDuration(positionMs),
      style: context
          .textStyle(
            FontSizeType.subheadline,
            fontWeight: FontWeight.w600,
            color: brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            // 等宽数字：计时行宽不跳动（UI-SPEC §1；字体不含 tabular 图集时
            // 由平台回退，不影响语义）。
          )
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
