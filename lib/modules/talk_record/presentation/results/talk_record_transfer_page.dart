/// 面聊记录（talk_record）责任移交页（T21，企业记录 owner）。
///
/// 契约源：UI-SPEC §2「责任移交」行 + §3 角色表（移交仅 owner，目标仍须
/// 合法）+ BACKEND-API.md §9：
/// - 仅企业记录 + 当前 owner（caps.transfer_owner 门控；个人记录 V1 不
///   转移归属，如实展示不支持）；
/// - 新责任人选择（fixture 候选；同企业符合工作区授权，服务端裁决）；
/// - 原责任人是否保留查看：**默认不保留**（UI-SPEC §2 冻结）；
/// - 二次确认（destructive；明确移交后果）；
/// - 成功后按所选：保留查看 → 成功页（含归属不变说明）；不保留 →
///   通用失效页（§9 原 owner 不再有权访问内容，不泄露原因）；
/// - 归属不变：移交不修改 created_by/scope（§9）。
///
/// 组件阶段：fixture 注入证明组件行为；真实移交链路待 T19/T20 联调。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_result_views.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_invalid_view.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_views.dart'
    show talkRecordShareCardDecoration;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 责任移交页。
class TalkRecordTransferPage extends ConsumerStatefulWidget {
  const TalkRecordTransferPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordTransferPage> createState() =>
      _TalkRecordTransferPageState();
}

class _TalkRecordTransferPageState
    extends ConsumerState<TalkRecordTransferPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(talkRecordTransferCenterProvider.notifier)
          .bind(widget.recordId, force: true);
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(talkRecordTransferCenterProvider);
    final Widget body;
    switch (center.phase) {
      case TalkRecordTransferPhase.idle:
      case TalkRecordTransferPhase.loading:
        body = const ShimmerList();
      case TalkRecordTransferPhase.noAccess:
        body = const TalkRecordInvalidView();
      case TalkRecordTransferPhase.failed:
        body = _FailedView(
          onRetry: () =>
              ref.read(talkRecordTransferCenterProvider.notifier).reload(),
        );
      case TalkRecordTransferPhase.ready:
        body = _TransferBody(recordId: widget.recordId, onConfirm: _confirm);
    }
    return IosPageTemplate(title: t.talkRecord.transferTitle, body: body);
  }

  /// 二次确认（destructive；移交后果 + 保留查看分支文案）。
  Future<void> _confirm() async {
    final center = ref.read(talkRecordTransferCenterProvider);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        key: const ValueKey('talk_record_transfer_confirm'),
        title: Text(t.talkRecord.transferConfirmTitle),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.talkRecord.transferConfirmTarget(name: center.selectedUserName),
            ),
            const SizedBox(height: AppSpacing.small),
            // C-F3：后果文案可换行。
            Text(
              center.keepViewer
                  ? t.talkRecord.transferConfirmKeepOn
                  : t.talkRecord.transferConfirmKeepOff,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            key: const ValueKey('talk_record_transfer_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.talkRecord.moreActionsCancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('talk_record_transfer_confirm_action'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.talkRecord.transferConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(talkRecordTransferCenterProvider.notifier).submit();
  }
}

class _TransferBody extends ConsumerWidget {
  const _TransferBody({required this.recordId, required this.onConfirm});

  final String recordId;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(talkRecordTransferCenterProvider);
    // 成功分支：保留查看 → 成功页；不保留 → 通用失效页（§9/§11.3）。
    if (center.submitPhase == TalkRecordTransferSubmitPhase.doneKeepAccess) {
      return _TransferSuccessView(recordId: recordId);
    }
    if (center.submitPhase == TalkRecordTransferSubmitPhase.doneNoAccess) {
      return const TalkRecordInvalidView();
    }
    if (center.isPersonal) {
      // §9：V1 不转移个人归属；如实展示不支持，不提供表单。
      return TalkRecordOperationResultView(
        tone: TalkRecordResultTone.failure,
        title: t.talkRecord.transferTitle,
        body: t.talkRecord.transferPersonalUnsupported,
        actions: [
          TalkRecordResultAction(
            key: const ValueKey('talk_record_transfer_personal_back'),
            label: t.talkRecord.resultBack,
            onPressed: () => _backToDetail(context),
          ),
        ],
      );
    }
    if (!center.canTransfer) {
      // §3 角色表：移交仅 owner（编辑者/读者无此能力，入口亦不出现）。
      return TalkRecordOperationResultView(
        tone: TalkRecordResultTone.failure,
        title: t.talkRecord.transferTitle,
        body: t.talkRecord.transferOnlyOwner,
        actions: [
          TalkRecordResultAction(
            key: const ValueKey('talk_record_transfer_forbidden_back'),
            label: t.talkRecord.resultBack,
            onPressed: () => _backToDetail(context),
          ),
        ],
      );
    }
    return _buildForm(context, ref, center);
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    TalkRecordTransferCenterState center,
  ) {
    final brightness = Theme.of(context).brightness;
    final conflict =
        center.submitPhase == TalkRecordTransferSubmitPhase.conflict;
    final failed = center.submitPhase == TalkRecordTransferSubmitPhase.failed;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('talk_record_transfer_scope_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.regular),
            decoration: talkRecordShareCardDecoration(brightness),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // C-F3：说明可换行。
                Text(
                  t.talkRecord.transferScopeHint,
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  t.talkRecord.transferCreatedByHint,
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
          ),
          const SizedBox(height: AppSpacing.xLarge),
          _CandidateCard(center: center),
          const SizedBox(height: AppSpacing.xLarge),
          TalkRecordKeepViewerSection(
            value: center.keepViewer,
            onChanged: (v) => ref
                .read(talkRecordTransferCenterProvider.notifier)
                .setKeepViewer(v),
          ),
          if (conflict)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: TalkRecordResultsBanner(
                key: const ValueKey('talk_record_transfer_conflict_banner'),
                text: t.talkRecord.transferConflictHint,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: TalkRecordResultsBanner(
                key: const ValueKey('talk_record_transfer_failed_banner'),
                text: t.talkRecord.transferFailedBody,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          const SizedBox(height: AppSpacing.small),
          _SubmitButton(center: center, onConfirm: onConfirm),
        ],
      ),
    );
  }

  void _backToDetail(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('$kTalkRecordDetailPath/$recordId');
    }
  }
}

/// 新责任人选择卡（fixture 候选；服务端裁决目标合法性）。
class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.center});

  final TalkRecordTransferCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_transfer_candidate_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.transferCandidateSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          TalkRecordTransferCandidateList(
            candidates: center.candidates,
            selectedUserId: center.selectedUserId,
            onSelect: (c) => ref
                .read(talkRecordTransferCenterProvider.notifier)
                .selectTarget(c),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            t.talkRecord.transferCandidateHint,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.caption2,
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

/// 移交主按钮（未选人 disabled；≥48）。
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.center, required this.onConfirm});

  final TalkRecordTransferCenterState center;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // C-F2：主操作 ≥48 + primaryDark 实底白字；破坏性语义在二次确认
      // 对话框以 destructive 呈现（对齐 UI-SPEC「二次确认」）。
      height: 48,
      child: CupertinoButton(
        key: const ValueKey('talk_record_transfer_submit'),
        minimumSize: const Size.fromHeight(48),
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
        onPressed: center.canSubmit ? onConfirm : null,
        child: Text(
          center.submitting
              ? t.talkRecord.transferSubmitting
              : t.talkRecord.transferSubmit,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 成功页（保留查看分支）：新责任人 + 保留查看说明 + 归属不变。
class _TransferSuccessView extends StatelessWidget {
  const _TransferSuccessView({required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final center = ref.watch(talkRecordTransferCenterProvider);
        final outcome = center.outcome;
        return TalkRecordOperationResultView(
          tone: TalkRecordResultTone.success,
          title: t.talkRecord.transferSuccessTitle,
          body: outcome == null
              ? ''
              : t.talkRecord.transferSuccessOwner(
                  name: outcome.newOwnerDisplayName,
                ),
          detailLines: [
            t.talkRecord.transferSuccessKeptAccess,
            t.talkRecord.transferSuccessScopeUnchanged,
          ],
          actions: [
            TalkRecordResultAction(
              key: const ValueKey('talk_record_transfer_success_back'),
              label: t.talkRecord.transferBackToDetail,
              primary: true,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('$kTalkRecordDetailPath/$recordId');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

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
            key: const ValueKey('talk_record_transfer_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
