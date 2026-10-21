/// 面聊记录全局录音条：跨页面常驻的协调器单一状态投影。
/// 收起/离开页面不停止录音；默认控制接暂停/继续/结束并保存。
/// 可注入 actions 供宿主扩展；归属始终显示最初保存空间。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/talk_record_recorder/talk_record_recorder_strings.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';
import 'talk_record_ui_helpers.dart';

/// 状态文案（UI-SPEC §4：暂停不计入录音时长；中断需手动继续）。
String talkRecordBarStatusText(TalkRecordCaptureBarPhase phase) {
  return switch (phase) {
    TalkRecordCaptureBarPhase.recording => t.talkRecord.barRecording,
    TalkRecordCaptureBarPhase.paused => t.talkRecord.barPaused,
    TalkRecordCaptureBarPhase.interrupted => t.talkRecord.barInterrupted,
  };
}

/// 原归属标注文案（个人/企业名；不猜未提供的名字）。
String talkRecordBarOriginLabel(TalkRecordEntryContext origin) {
  if (!origin.isOrganization) return t.talkRecord.barOriginPersonal;
  return origin.organizationName.isNotEmpty
      ? origin.organizationName
      : t.talkRecord.barOriginOrgFallback;
}

/// 全局持久录音条。
///
/// [currentContext] 为当前页面上下文：与录音条原归属（originContext）
/// 跨个人/企业时展示「来自 X」标注（DESIGN §5.5 跨空间规则）。
/// [actions] 可覆盖控制区；默认使用真实协调器。
class TalkRecordGlobalRecordingBar extends ConsumerWidget {
  const TalkRecordGlobalRecordingBar({
    super.key,
    required this.currentContext,
    this.actions = const [],
    this.applicationHost = false,
    this.modalContext,
  });

  final TalkRecordEntryContext currentContext;

  /// 宿主注入的录音控制；空则使用默认协调器控制。
  final List<Widget> actions;
  final bool applicationHost;
  final BuildContext? Function()? modalContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!applicationHost && TalkRecordRecordingHostScope.present(context)) {
      return const SizedBox.shrink();
    }
    ref.watch(talkRecordRecordingRuntimeProvider);
    final capture = ref.watch(talkRecordActiveCaptureProvider);
    if (!capture.visible) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final isRecording = capture.phase == TalkRecordCaptureBarPhase.recording;
    final crossSpace =
        capture.originContext.scope != currentContext.scope ||
        capture.originContext.organizationId != currentContext.organizationId;

    return Semantics(
      label: talkRecordBarStatusText(capture.phase),
      child: GestureDetector(
        // 触达 ≥44pt：条体 minHeight 56。
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final popupContext = modalContext == null ? context : modalContext!();
          if (popupContext == null) return;
          showCupertinoModalPopup<void>(
            context: popupContext,
            builder: (_) => _RecordingDetailSheet(actions: actions),
          );
        },
        child: Container(
          key: const ValueKey('talk_record_recording_bar'),
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.small,
            AppSpacing.regular,
            0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.small,
          ),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecording
                  ? AppColors.getIosRed(brightness).withValues(alpha: 0.5)
                  : AppColors.getIosSeparator(brightness),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.small),
                child: isRecording
                    ? _RecordingDot(color: AppColors.getIosRed(brightness))
                    : Icon(
                        capture.phase == TalkRecordCaptureBarPhase.paused
                            ? CupertinoIcons.pause_circle
                            : CupertinoIcons.exclamationmark_triangle,
                        size: AppSpacing.xLarge,
                        color: AppColors.getIosOrange(brightness),
                      ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capture.title.isNotEmpty
                          ? capture.title
                          : t.talkRecord.untitledRecord,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.normal,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // C-F3：状态/归属/时长用 Wrap，自然换行不截断。
                    Wrap(
                      spacing: AppSpacing.small,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          talkRecordBarStatusText(capture.phase),
                          style: context.textStyle(
                            FontSizeType.small,
                            color: brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (crossSpace || applicationHost)
                          Text(
                            '${t.talkRecord.barOriginPrefix} '
                            '${talkRecordBarOriginLabel(capture.originContext)}',
                            style: context.textStyle(
                              FontSizeType.small,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        Text(
                          talkRecordFormatDuration(capture.positionMs),
                          style: context.textStyle(
                            FontSizeType.small,
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
              Icon(
                CupertinoIcons.chevron_up,
                size: AppSpacing.medium + 2,
                color: AppColors.getIosSeparator(brightness),
                semanticLabel: t.talkRecord.barExpandHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 录音条详情面板（状态 + 归属 + 时长 + 控制区）。
class _RecordingDetailSheet extends ConsumerWidget {
  const _RecordingDetailSheet({required this.actions});

  /// 由打开录音条的 Bar 透传（T09 控制注入位）。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capture = ref.watch(talkRecordActiveCaptureProvider);
    if (!capture.visible) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;

    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                capture.title.isNotEmpty
                    ? capture.title
                    : t.talkRecord.untitledRecord,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              // C-F3：说明逐条可换行，无 maxLines 截断。
              Text(
                talkRecordBarStatusText(capture.phase),
                style: context.textStyle(
                  FontSizeType.medium,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                '${t.talkRecord.barOriginPrefix} '
                '${talkRecordBarOriginLabel(capture.originContext)}',
                style: context.textStyle(
                  FontSizeType.normal,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                talkRecordFormatDuration(capture.positionMs),
                style: context.textStyle(
                  FontSizeType.extraLarge,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              if (actions.isEmpty)
                const _RuntimeRecordingControls()
              else
                ...actions,
              const SizedBox(height: AppSpacing.medium),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.common.buttonClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 录音红点（颜色只作辅助；状态语义由并排文字承载，UI-SPEC §1）。
class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Controls resolve the same app-lifetime coordinator; no page owns a recorder.
class _RuntimeRecordingControls extends ConsumerStatefulWidget {
  const _RuntimeRecordingControls();
  @override
  ConsumerState<_RuntimeRecordingControls> createState() =>
      _RuntimeRecordingControlsState();
}

class _RuntimeRecordingControlsState
    extends ConsumerState<_RuntimeRecordingControls> {
  bool _pending = false;
  bool _failed = false;
  bool? _saved;

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await operation();
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _end() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(TalkRecordRecorderStrings.endConfirmTitle),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TalkRecordRecorderStrings.endConfirmCancel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(TalkRecordRecorderStrings.endConfirmOk),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final runtime = await ref.read(talkRecordRecordingRuntimeProvider.future);
      final result = await runtime.end();
      if (mounted) setState(() => _saved = result.savedCleanly);
      ref.invalidate(talkRecordListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(talkRecordActiveCaptureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_failed) Text(t.common.error),
        if (_saved != null)
          Text(
            _saved!
                ? TalkRecordRecorderStrings.savedCleanly
                : TalkRecordRecorderStrings.savedWithFailure,
          )
        else ...[
          CupertinoButton(
            onPressed: _pending
                ? null
                : () => _run(() async {
                    final runtime = await ref.read(
                      talkRecordRecordingRuntimeProvider.future,
                    );
                    if (capture.phase == TalkRecordCaptureBarPhase.recording) {
                      await runtime.pause();
                    } else {
                      await runtime.resume();
                    }
                  }),
            child: Text(
              capture.phase == TalkRecordCaptureBarPhase.recording
                  ? TalkRecordRecorderStrings.pauseButton
                  : TalkRecordRecorderStrings.resumeButton,
            ),
          ),
          CupertinoButton(
            onPressed: _pending ? null : _end,
            child: const Text(TalkRecordRecorderStrings.endButton),
          ),
        ],
        if (_pending) const CupertinoActivityIndicator(),
      ],
    );
  }
}

/// Marks the app-level host so feature pages do not render a duplicate bar.
class TalkRecordRecordingHostScope extends InheritedWidget {
  const TalkRecordRecordingHostScope({super.key, required super.child});

  static bool present(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TalkRecordRecordingHostScope>() !=
      null;

  @override
  bool updateShouldNotify(TalkRecordRecordingHostScope oldWidget) => false;
}
