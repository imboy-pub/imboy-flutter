/// 面聊记录准备页（T10）。
///
/// 契约源：UI-SPEC.md §2「准备」+ DESIGN.md §3/§9/§10：
/// - 标题选填；保存到（个人/有权企业+工作区，开始前可更正归属）；
/// - 处理方式按 capabilities 真实降级：未配置转写→「仅录音」
///   （主按钮仍是「开始录音」，不出现虚假 AI 功能）；配额不足→仅录音
///   且明示「录音不受影响」；能力加载失败→按仅录音处理；
/// - 企业协作信息折叠区（选填参与者；目录不可用时如实提示待接入）；
/// - 已告知确认 checkbox（67px 触达区，整行可点）；
/// - 开始录音：麦克风权限拒绝→说明+重试/去设置；通过后交
///   [TalkRecordRecordingLauncher]（T09 注入；默认占位如实提示）。
///
/// 草稿不丢稿：标题/保存到/处理方式/参与者存 [talkRecordDraftProvider]
/// （常驻 Provider），跳保存位置页往返与回列表再进都保留。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:go_router/go_router.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';

import 'ai/talk_record_ai_widgets.dart';
import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';
import 'talk_record_prepare_sections.dart';
import 'talk_record_services.dart';
import 'talk_record_notification_permission.dart';
import 'talk_record_recording_bar.dart';

/// 处理方式降级结论（纯函数，测试直接覆盖）。
class TalkRecordProcessingAvailability {
  /// 可选模式（至少含 recordOnly）。
  final List<TalkRecordProcessingMode> modes;

  /// 降级原因键（null=无降级，正常多档可选）。
  final String? reasonKey;

  const TalkRecordProcessingAvailability({required this.modes, this.reasonKey});

  /// capabilities → 可选处理档位 + 降级原因。
  ///
  /// 语义（§11.4/DESIGN §10）：能力关闭不能仅 UI 禁用——未配置时唯一
  /// 选项是「仅录音」并说明原因；配额不足只阻止处理不影响录音。
  static TalkRecordProcessingAvailability evaluate(
    TalkRecordCapabilitiesModel? capabilities,
  ) {
    if (capabilities == null) {
      return const TalkRecordProcessingAvailability(
        modes: [TalkRecordProcessingMode.recordOnly],
        reasonKey: 'processingReasonLoadFailed',
      );
    }
    final canTranscribe =
        capabilities.processingAvailable &&
        capabilities.asrEnabled &&
        capabilities.processorConfigVersion.isNotEmpty;
    if (!canTranscribe) {
      return const TalkRecordProcessingAvailability(
        modes: [TalkRecordProcessingMode.recordOnly],
        reasonKey: 'processingReasonUnavailable',
      );
    }
    if (capabilities.queueLimit <= 0) {
      return const TalkRecordProcessingAvailability(
        modes: [TalkRecordProcessingMode.recordOnly],
        reasonKey: 'processingReasonQuota',
      );
    }
    final modes = <TalkRecordProcessingMode>[
      TalkRecordProcessingMode.recordOnly,
      TalkRecordProcessingMode.transcribe,
      if (capabilities.summaryEnabled) TalkRecordProcessingMode.summarize,
    ];
    return TalkRecordProcessingAvailability(modes: modes);
  }

  bool allows(TalkRecordProcessingMode mode) => modes.contains(mode);
}

/// 新建面聊记录准备页。
class TalkRecordPreparePage extends ConsumerStatefulWidget {
  const TalkRecordPreparePage({super.key, required this.entryContext});

  /// 入口上下文（保存到未更改时的默认归属）。
  final TalkRecordEntryContext entryContext;

  @override
  ConsumerState<TalkRecordPreparePage> createState() =>
      _TalkRecordPreparePageState();
}

class _TalkRecordPreparePageState extends ConsumerState<TalkRecordPreparePage> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  StreamSubscription<dynamic>? _localeSubscription;
  bool _requesting = false;

  /// 麦克风被拒绝（注入网关返回 denied/restricted 后置位）。
  bool _micDenied = false;
  bool _notificationDenied = false;

  /// 录音引擎占位提示（launcher 返回不可用后置位）。
  bool _recordingUnavailable = false;

  @override
  void initState() {
    super.initState();
    // 回填草稿标题（回列表再进不丢稿）。
    _titleController.text = ref.read(talkRecordDraftProvider).title;
    _titleController.addListener(() {
      ref
          .read(talkRecordDraftProvider.notifier)
          .setTitle(_titleController.text);
    });
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _titleFocus.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_requesting || !ref.read(talkRecordDraftProvider).noticeAcknowledged) {
      return;
    }
    final authEpoch = ref.read(talkRecordAuthEpochProvider);
    final saveTo = ref
        .read(talkRecordDraftProvider)
        .effectiveSaveTo(widget.entryContext);
    bool currentOperation() =>
        mounted &&
        ref.read(talkRecordAuthEpochProvider) == authEpoch &&
        ref.read(talkRecordDraftProvider).noticeAcknowledged &&
        ref
                .read(talkRecordDraftProvider)
                .effectiveSaveTo(widget.entryContext) ==
            saveTo;
    setState(() {
      _requesting = true;
      _micDenied = false;
      _notificationDenied = false;
      _recordingUnavailable = false;
    });
    try {
      final gateway = ref.read(talkRecordMicPermissionGatewayProvider);
      final status = await gateway.request();
      if (!currentOperation()) return;
      if (status != TalkRecordMicPermissionStatus.granted) {
        // 权限拒绝：说明 + 重试/去设置（不自动弹系统面板）。
        setState(() => _micDenied = true);
        return;
      }
      final notifications = ref.read(
        talkRecordNotificationPermissionGatewayProvider,
      );
      if (notifications.required) {
        final permission = await notifications.request();
        if (!currentOperation()) return;
        if (permission != TalkRecordNotificationPermissionStatus.granted) {
          setState(() => _notificationDenied = true);
          return;
        }
      }
      final draft = ref.read(talkRecordDraftProvider);
      final capabilitiesState = ref.read(talkRecordCapabilitiesProvider);
      final capabilities = capabilitiesState.isLoading
          ? null
          : capabilitiesState.asData?.value;
      final availability = TalkRecordProcessingAvailability.evaluate(
        capabilities,
      );
      final selected = availability.allows(draft.processingMode)
          ? draft.processingMode
          : TalkRecordProcessingMode.recordOnly;
      final result = await ref
          .read(talkRecordRecordingLauncherProvider)
          .launch(
            TalkRecordRecordingDraftRequest(
              title: draft.title.trim(),
              isCurrentOperation: currentOperation,
              saveTo: draft.effectiveSaveTo(widget.entryContext),
              processingMode: selected,
              policyVersion: capabilities?.policyVersion ?? '',
              processorConfigVersion:
                  capabilities?.processorConfigVersion ?? '',
              participants: draft.participants,
            ),
          );
      if (!currentOperation()) return;
      // 只有本机服务已开麦才清空草稿；失败保留重试。
      if (result.notificationRequired) {
        setState(() => _notificationDenied = true);
      } else if (!result.started) {
        setState(() => _recordingUnavailable = true);
      } else {
        ref.read(talkRecordDraftProvider.notifier).clear();
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final draft = ref.watch(talkRecordDraftProvider);
    final capabilitiesAsync = ref.watch(talkRecordCapabilitiesProvider);
    final capabilities = capabilitiesAsync.isLoading
        ? null
        : capabilitiesAsync.asData?.value;
    final availability = TalkRecordProcessingAvailability.evaluate(
      capabilitiesAsync.isLoading && capabilities == null ? null : capabilities,
    );
    final saveTo = draft.effectiveSaveTo(widget.entryContext);
    // 草稿模式若被降级禁选，展示层回落仅录音（写入在下一次选择时发生）。
    final effectiveMode = availability.allows(draft.processingMode)
        ? draft.processingMode
        : TalkRecordProcessingMode.recordOnly;

    return CupertinoPageScaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.talkRecord.prepareTitle),
        automaticallyImplyLeading: true,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.regular),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TalkRecordPrepareSectionCard(
                children: [
                  TalkRecordPrepareFieldLabel(t.talkRecord.fieldTitleLabel),
                  const SizedBox(height: AppSpacing.small),
                  CupertinoTextField(
                    key: const ValueKey('talk_record_title_field'),
                    controller: _titleController,
                    focusNode: _titleFocus,
                    placeholder: t.talkRecord.fieldTitlePlaceholder,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.medium,
                    ),
                    // 触达 ≥44pt：12+12 内边距 + 文本行高 ≥44。
                    style: context.textStyle(
                      FontSizeType.medium,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              TalkRecordPrepareSectionCard(
                children: [
                  TalkRecordPrepareFieldLabel(t.talkRecord.saveToSectionTitle),
                  const SizedBox(height: AppSpacing.small),
                  TalkRecordSaveToRow(saveTo: saveTo),
                  if (capabilities != null && capabilities.maxDurationMs > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.small),
                      // C-F3：期限提示可换行。
                      child: Text(
                        t.talkRecord.maxDurationHint(
                          minutes: capabilities.maxDurationMs ~/ 60000,
                        ),
                        style: context.textStyle(
                          FontSizeType.small,
                          color: brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              TalkRecordPrepareSectionCard(
                children: [
                  TalkRecordAiEntryRow(
                    title: t.talkRecord.aiServicesTitle,
                    subtitle: t.talkRecord.aiServicesSubtitle,
                    onTap: () => context.push(kTalkRecordAiServicesPath),
                  ),
                ],
              ),
              TalkRecordProcessingSection(
                availability: availability,
                selected: effectiveMode,
                loadingCapabilities: capabilitiesAsync.isLoading,
                onSelect: (mode) => ref
                    .read(talkRecordDraftProvider.notifier)
                    .setProcessingMode(mode),
              ),
              if (saveTo.isOrganization)
                TalkRecordCollabSection(
                  organizationId: saveTo.organizationId,
                  workspaceId: saveTo.workspaceId,
                  participants: draft.participants,
                  onReplaceParticipants: (participants) => ref
                      .read(talkRecordDraftProvider.notifier)
                      .replaceParticipants(participants),
                  onToggleParticipant: (p) => ref
                      .read(talkRecordDraftProvider.notifier)
                      .toggleParticipant(p),
                ),
              TalkRecordNoticeRow(
                value: draft.noticeAcknowledged,
                onChanged: (v) => ref
                    .read(talkRecordDraftProvider.notifier)
                    .setNoticeAcknowledged(v),
              ),
              if (_micDenied) ...[
                const SizedBox(height: AppSpacing.small),
                TalkRecordMicDeniedPanel(
                  onRetry: _startRecording,
                  onOpenSettings: () => ref
                      .read(talkRecordMicPermissionGatewayProvider)
                      .openSettings(),
                ),
              ],
              if (_notificationDenied) ...[
                const SizedBox(height: AppSpacing.small),
                TalkRecordNotificationDeniedPanel(
                  onRetry: _startRecording,
                  onOpenSettings: () => ref
                      .read(talkRecordNotificationPermissionGatewayProvider)
                      .openSettings(),
                ),
              ],
              if (_recordingUnavailable) ...[
                const SizedBox(height: AppSpacing.small),
                TalkRecordInfoPanel(
                  title: t.talkRecord.recordingUnavailableTitle,
                  message: t.talkRecord.recordingUnavailableMessage,
                ),
              ],
              TalkRecordGlobalRecordingBar(currentContext: saveTo),
              const SizedBox(height: AppSpacing.medium),
              if (!draft.noticeAcknowledged)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  // C-F3：提示可换行。
                  child: Text(
                    t.talkRecord.noticeHint,
                    style: context.textStyle(
                      FontSizeType.small,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                // 主操作 ≥48pt。
                height: AppSpacing.xxxLarge,
                child: CupertinoButton(
                  key: const ValueKey('talk_record_start_button'),
                  borderRadius: BorderRadius.circular(10),
                  // C-F2：白字 on primaryDark(#1565C0) = 5.75:1。
                  color: AppColors.primaryDark,
                  padding: EdgeInsets.zero,
                  onPressed: draft.noticeAcknowledged && !_requesting
                      ? _startRecording
                      : null,
                  child: _requesting
                      ? const CupertinoActivityIndicator(
                          color: AppColors.onPrimary,
                        )
                      : Text(
                          t.talkRecord.startRecording,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
            ],
          ),
        ),
      ),
    );
  }
}
