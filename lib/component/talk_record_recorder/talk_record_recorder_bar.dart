/// 面聊记录（talk_record）T09 —— 录音条组件（展开面板 + 持久收起条）。
///
/// 契约源：UI-SPEC.md §1（触达区≥44pt、主操作≥48pt、计时等宽数字、
/// AppColors/AppSpacing/FontSizeType 映射）、§2 录音行（计时/状态/本机
/// 分段/重点列表）、§4 状态语言；DESIGN.md §5.2（中断持久显示原因、
/// 恢复必须用户点击）、§5.3（空间不足/写入失败明确告知，不显示保存
/// 成功）、§5.4（结束前确认「结束并保存」）。
///
/// 组件不请求麦克风权限（无权限副作用）：权限状态由 [micPermission]
/// 注入，denied 时仅呈现引导；不自动结束（收起 ≠ 停止）。
library;

import 'package:flutter/material.dart';

import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_recorder_strings.dart';

/// 麦克风权限视图状态（注入；组件自身不触发权限请求）。
enum TalkRecordMicPermission { unknown, granted, denied }

/// 组件级度量与字号 token。
///
/// 40pt 计时是 UI-SPEC §1 冻结值；`FontSizeType` 现无 40 档且主题文件
/// 不在 T09 可写范围，先以模块 token 落地，集成期（T10+）迁入
/// `FontSizeType` 后删除本常量。
class TalkRecordRecorderMetrics {
  TalkRecordRecorderMetrics._();

  /// 计时 40pt（UI-SPEC §1）。
  static const double timerFontSize = 40.0;

  /// 触达区最小边（UI-SPEC §1：≥44pt）。
  static const double minTouchTarget = 44.0;

  /// 主操作最小边（UI-SPEC §1：≥48pt）。
  static const double minPrimaryTarget = 48.0;
}

/// 面聊录音条：展开面板 / 收起持久条切换（收起不自动结束）。
class TalkRecordRecorderBar extends StatefulWidget {
  const TalkRecordRecorderBar({
    super.key,
    required this.controller,
    this.micPermission = TalkRecordMicPermission.granted,
    this.initiallyCollapsed = false,
    this.onEnded,
    this.onExpandToggle,
  });

  final TalkRecordRecorderService controller;
  final TalkRecordMicPermission micPermission;

  /// 初始是否收起（退出录音页保留全局录音条场景）。
  final bool initiallyCollapsed;

  /// 结束完成回调（保存流程由宿主页接管；组件只呈现结果）。
  final ValueChanged<TalkRecordSessionResult>? onEnded;

  final ValueChanged<bool>? onExpandToggle;

  @override
  State<TalkRecordRecorderBar> createState() => _TalkRecordRecorderBarState();
}

class _TalkRecordRecorderBarState extends State<TalkRecordRecorderBar> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    widget.onExpandToggle?.call(!_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.micPermission == TalkRecordMicPermission.denied) {
      return const TalkRecordMicPermissionView();
    }
    return StreamBuilder<TalkRecordRecorderSnapshot>(
      initialData: widget.controller.snapshot,
      stream: widget.controller.snapshots,
      builder: (context, snap) {
        final data = snap.data ?? widget.controller.snapshot;
        if (_collapsed && data.phase != TalkRecordRecorderPhase.ended) {
          return _CollapsedBar(snapshot: data, onTap: _toggle);
        }
        return _ExpandedPanel(
          snapshot: data,
          controller: widget.controller,
          onCollapse: _toggle,
          onEnded: widget.onEnded,
        );
      },
    );
  }
}

/// 收起态：持久录音条（不自动结束；点击展开）。
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.snapshot, required this.onTap});

  final TalkRecordRecorderSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recording = snapshot.phase == TalkRecordRecorderPhase.recording;
    return Material(
      key: const ValueKey('trr_collapsed_bar'),
      color: AppColors.tagBackground,
      borderRadius: BorderRadius.circular(AppSpacing.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.medium),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: TalkRecordRecorderMetrics.minTouchTarget,
          ),
          child: Padding(
            padding: AppSpacing.symmetricRegular,
            child: Row(
              children: [
                _StatusDot(recording: recording),
                AppSpacing.horizontalSmall,
                Text(
                  recording
                      ? TalkRecordRecorderStrings.recording
                      : TalkRecordRecorderStrings.paused,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const Spacer(),
                Text(
                  TalkRecordRecorderStrings.formatDuration(
                    snapshot.effectiveDurationMs,
                  ),
                  style: context
                      .textStyle(
                        FontSizeType.large,
                        fontWeight: FontWeight.w600,
                      )
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                AppSpacing.horizontalSmall,
                Icon(
                  Icons.expand_less,
                  size: AppSpacing.xLarge,
                  color: AppColors.slateText,
                  semanticLabel: TalkRecordRecorderStrings.expandHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 展开态面板。
class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.snapshot,
    required this.controller,
    required this.onCollapse,
    this.onEnded,
  });

  final TalkRecordRecorderSnapshot snapshot;
  final TalkRecordRecorderService controller;
  final VoidCallback onCollapse;
  final ValueChanged<TalkRecordSessionResult>? onEnded;

  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TalkRecordRecorderStrings.endConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(TalkRecordRecorderStrings.endConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(TalkRecordRecorderStrings.endConfirmOk),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await controller.end();
    onEnded?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(AppSpacing.medium),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRow(
            snapshot: snapshot,
            bodyColor: bodyColor,
            onCollapse: onCollapse,
          ),
          AppSpacing.verticalSmall,
          _TimerText(durationMs: snapshot.effectiveDurationMs),
          AppSpacing.verticalSmall,
          _LevelIndicator(decibels: snapshot.decibels),
          if (snapshot.limitWarn != TalkRecordLimitWarn.none &&
              phase != TalkRecordRecorderPhase.ended)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.small),
              child: _WarnBanner(
                text: snapshot.limitWarn == TalkRecordLimitWarn.duration
                    ? TalkRecordRecorderStrings.approachingDurationLimit
                    : TalkRecordRecorderStrings.approachingBytesLimit,
              ),
            ),
          if (phase == TalkRecordRecorderPhase.interrupted)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.small),
              child: _InterruptBanner(
                snapshot: snapshot,
                onResume: () => controller.userResumeAfterInterruption(),
              ),
            ),
          if (phase == TalkRecordRecorderPhase.ended)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.small),
              child: _EndBanner(snapshot: snapshot),
            ),
          AppSpacing.verticalMedium,
          _ControlsRow(
            snapshot: snapshot,
            controller: controller,
            onEnd: () => _confirmEnd(context),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.snapshot,
    required this.bodyColor,
    required this.onCollapse,
  });

  final TalkRecordRecorderSnapshot snapshot;
  final Color? bodyColor;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final String status;
    switch (phase) {
      case TalkRecordRecorderPhase.recording:
        status = TalkRecordRecorderStrings.recording;
      case TalkRecordRecorderPhase.paused:
        status = TalkRecordRecorderStrings.paused;
      case TalkRecordRecorderPhase.interrupted:
        status = TalkRecordRecorderStrings.interruptedMessage(
          snapshot.interruptReason,
        );
      case TalkRecordRecorderPhase.ended:
        // 结束结果由 _EndBanner 唯一呈现，避免重复文案。
        status = '';
      case TalkRecordRecorderPhase.idle:
      case TalkRecordRecorderPhase.failed:
        status = '';
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            status,
            style: context.textStyle(
              FontSizeType.footnote,
              color: phase == TalkRecordRecorderPhase.interrupted
                  ? Theme.of(context).colorScheme.error
                  : AppColors.slateText,
            ),
          ),
        ),
        Text(
          '${TalkRecordRecorderStrings.segmentStatus} ${snapshot.segmentCount}',
          style: context.textStyle(
            FontSizeType.footnote,
            color: AppColors.slateText,
          ),
        ),
        if (snapshot.markCount > 0) ...[
          AppSpacing.horizontalTiny,
          Text(
            '${snapshot.markCount} ${TalkRecordRecorderStrings.markCountLabel}',
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.slateText,
            ),
          ),
        ],
        AppSpacing.horizontalSmall,
        _SmallAction(
          tooltip: TalkRecordRecorderStrings.collapseButton,
          icon: Icons.expand_more,
          actionKey: const ValueKey('trr_btn_collapse'),
          onTap: onCollapse,
        ),
      ],
    );
  }
}

class _TimerText extends StatelessWidget {
  const _TimerText({required this.durationMs});

  final int durationMs;

  @override
  Widget build(BuildContext context) {
    // 40pt 为 UI-SPEC §1 冻结值；FontSizeType 无 40 档且主题文件不在本
    // 任务可写范围，字号走模块 token（Metrics），颜色/粗细走主题。
    final base = context.textStyle(
      FontSizeType.extraLargeTitle,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
    return Text(
      TalkRecordRecorderStrings.formatDuration(durationMs),
      style: base.copyWith(
        fontSize: TalkRecordRecorderMetrics.timerFontSize,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 真实输入电平（平台不支持时呈现占位，不伪造波形）。
class _LevelIndicator extends StatelessWidget {
  const _LevelIndicator({required this.decibels});

  final double? decibels;

  double? get _normalized {
    final db = decibels;
    if (db == null) return null;
    return ((db + 60) / 60).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final level = _normalized;
    const bars = 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(bars, (i) {
        final active = level != null && level * bars > i;
        return Container(
          width: AppSpacing.small,
          height: AppSpacing.tiny + (i.isEven ? 0 : AppSpacing.tiny),
          margin: EdgeInsets.only(right: AppSpacing.tiny),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.slateMuted,
            borderRadius: BorderRadius.circular(AppSpacing.tiny),
          ),
        );
      }),
    );
  }
}

class _InterruptBanner extends StatelessWidget {
  const _InterruptBanner({required this.snapshot, required this.onResume});

  final TalkRecordRecorderSnapshot snapshot;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            TalkRecordRecorderStrings.interruptedMessage(
              snapshot.interruptReason,
            ),
            style: context.textStyle(
              FontSizeType.footnote,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        AppSpacing.horizontalSmall,
        SizedBox(
          height: TalkRecordRecorderMetrics.minPrimaryTarget,
          child: FilledButton(
            onPressed: onResume,
            child: Text(TalkRecordRecorderStrings.interruptedResume),
          ),
        ),
      ],
    );
  }
}

class _WarnBanner extends StatelessWidget {
  const _WarnBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textStyle(
        FontSizeType.footnote,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _EndBanner extends StatelessWidget {
  const _EndBanner({required this.snapshot});

  final TalkRecordRecorderSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (!snapshot.savedCleanly) {
      text = switch (snapshot.endReason) {
        TalkRecordEndReason.diskFull =>
          TalkRecordRecorderStrings.diskFullBanner,
        TalkRecordEndReason.engineFailure =>
          TalkRecordRecorderStrings.engineFailureBanner,
        _ => TalkRecordRecorderStrings.writeFailureBanner,
      };
    } else {
      text = switch (snapshot.endReason) {
        TalkRecordEndReason.durationLimit =>
          TalkRecordRecorderStrings.durationLimitBanner,
        TalkRecordEndReason.bytesLimit =>
          TalkRecordRecorderStrings.bytesLimitBanner,
        _ => TalkRecordRecorderStrings.savedCleanly,
      };
    }
    return Text(
      text,
      style: context.textStyle(
        FontSizeType.footnote,
        color: snapshot.savedCleanly
            ? AppColors.slateText
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.snapshot,
    required this.controller,
    required this.onEnd,
  });

  final TalkRecordRecorderSnapshot snapshot;
  final TalkRecordRecorderService controller;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final active =
        phase == TalkRecordRecorderPhase.recording ||
        phase == TalkRecordRecorderPhase.paused ||
        phase == TalkRecordRecorderPhase.interrupted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SmallAction(
          tooltip: TalkRecordRecorderStrings.markButton,
          icon: Icons.flag_outlined,
          label: TalkRecordRecorderStrings.markButton,
          actionKey: const ValueKey('trr_btn_mark'),
          enabled: active,
          onTap: () => controller.addMark(),
        ),
        if (phase == TalkRecordRecorderPhase.recording)
          _PrimaryAction(
            label: TalkRecordRecorderStrings.pauseButton,
            icon: Icons.pause,
            actionKey: const ValueKey('trr_btn_pause'),
            onPressed: () => controller.pause(),
          )
        else if (phase == TalkRecordRecorderPhase.paused)
          // 中断态的恢复入口只在中断横幅（唯一 CTA，DESIGN §5.2）。
          _PrimaryAction(
            label: TalkRecordRecorderStrings.resumeButton,
            icon: Icons.play_arrow,
            actionKey: const ValueKey('trr_btn_resume'),
            onPressed: () => controller.resume(),
          ),
        _PrimaryAction(
          label: TalkRecordRecorderStrings.endButton,
          icon: Icons.stop,
          actionKey: const ValueKey('trr_btn_end'),
          onPressed: active ? onEnd : null,
        ),
      ],
    );
  }
}

/// 主操作按钮（≥48pt，UI-SPEC §1）。整个图标+文字区域为同一触达区。
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.actionKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled
        ? Theme.of(context).colorScheme.error
        : AppColors.slateMuted;
    return Semantics(
      key: actionKey,
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.small),
        child: SizedBox(
          width: TalkRecordRecorderMetrics.minPrimaryTarget,
          height:
              TalkRecordRecorderMetrics.minPrimaryTarget + AppSpacing.medium,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSpacing.xLarge, color: fg),
              AppSpacing.verticalTiny,
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: enabled
                      ? Theme.of(context).textTheme.bodySmall?.color
                      : AppColors.slateMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 次操作（触达区≥44pt，UI-SPEC §1）。
class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.actionKey,
    this.label,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Key actionKey;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: actionKey,
      button: true,
      enabled: enabled,
      label: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.small),
        child: SizedBox(
          width: TalkRecordRecorderMetrics.minTouchTarget,
          height: TalkRecordRecorderMetrics.minTouchTarget + AppSpacing.small,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppSpacing.regular + AppSpacing.small,
                color: enabled ? AppColors.slateText : AppColors.slateMuted,
              ),
              if (label != null) ...[
                AppSpacing.verticalTiny,
                Text(
                  label!,
                  style: context.textStyle(
                    FontSizeType.caption2,
                    color: enabled
                        ? Theme.of(context).textTheme.bodySmall?.color
                        : AppColors.slateMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 录音状态点。
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.tiny + AppSpacing.tiny,
      height: AppSpacing.tiny + AppSpacing.tiny,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: recording
            ? Theme.of(context).colorScheme.error
            : AppColors.slateMuted,
      ),
    );
  }
}

/// 无麦克风权限视图：仅引导，不请求权限（无权限副作用）。
class TalkRecordMicPermissionView extends StatelessWidget {
  const TalkRecordMicPermissionView({super.key, this.onOpenSettings});

  /// 打开系统设置回调（由宿主接平台通道；组件自身不触发）。
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(AppSpacing.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TalkRecordRecorderStrings.micPermissionDenied,
              style: context.textStyle(
                FontSizeType.normal,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          if (onOpenSettings != null)
            SizedBox(
              height: TalkRecordRecorderMetrics.minPrimaryTarget,
              child: FilledButton.tonal(
                onPressed: onOpenSettings,
                child: Text(TalkRecordRecorderStrings.openSettings),
              ),
            ),
        ],
      ),
    );
  }
}
