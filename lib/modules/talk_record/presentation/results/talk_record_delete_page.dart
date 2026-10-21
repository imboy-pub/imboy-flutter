/// 面聊记录（talk_record）删除状态页（T21）。
///
/// 契约源：UI-SPEC §2「删除状态」行 + §4 状态文案（「记录已删除」与
/// 附件清理状态分离展示；不将排队成功冒充字节已删除）+ BACKEND-API.md
/// §4（DELETE /:id 202 logical_deleted + cleanup pending；立即撤权）+
/// §10.4（清理五态：pending/blocked_retention/blocked_hold/
/// retained_by_other_reference/failed/complete；受治理保护≠异常）+
/// §11.3（删除后 owner 读取仅清理状态白名单；不回正文）：
/// - 确认视图：三条冻结要点（删除后不再展示正文；已导出或保存的副本
///   无法收回；提交清理≠字节已删除）+ 二次确认（destructive）；
/// - 已删除视图：「记录已删除」+ 清理状态独立卡（五态）+ 刷新状态 +
///   failed 由运维检查并重试+ 返回列表；
/// - 门控：删除仅 owner（§3 角色表；viewer/editor 无入口，直开页时
///   如实展示无权限）。
///
/// 组件阶段：清理状态来自 fixture/服务注入；真实删除与清理链路待
/// T19/T20 联调。
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

/// 删除状态页（路由段 cleanup；确认 → 已删除 + 清理状态）。
class TalkRecordDeletePage extends ConsumerStatefulWidget {
  const TalkRecordDeletePage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordDeletePage> createState() =>
      _TalkRecordDeletePageState();
}

class _TalkRecordDeletePageState extends ConsumerState<TalkRecordDeletePage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(talkRecordDeleteCenterProvider.notifier)
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
    final center = ref.watch(talkRecordDeleteCenterProvider);
    final Widget body;
    switch (center.phase) {
      case TalkRecordDeletePhase.idle:
      case TalkRecordDeletePhase.loading:
        body = const ShimmerList();
      case TalkRecordDeletePhase.noAccess:
        // §11.3：无权限/不存在统一失效视图（不泄露信息）。
        body = const TalkRecordInvalidView();
      case TalkRecordDeletePhase.failed:
        body = _FailedView(
          onRetry: () =>
              ref.read(talkRecordDeleteCenterProvider.notifier).reload(),
        );
      case TalkRecordDeletePhase.ready:
        body = center.isDeleted
            ? _DeletedStatusBody(center: center)
            : _ConfirmBody(recordId: widget.recordId, onConfirm: _confirm);
    }
    return IosPageTemplate(title: t.talkRecord.deleteTitle, body: body);
  }

  /// 二次确认（destructive；三条冻结要点已在确认视图正文逐条展示，
  /// 对话框聚焦「确认删除」决策本身）。
  Future<void> _confirm() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        key: const ValueKey('talk_record_delete_confirm'),
        title: Text(t.talkRecord.deleteConfirmTitle),
        content: Text(t.talkRecord.deleteConfirmDialogContent),
        actions: [
          CupertinoDialogAction(
            key: const ValueKey('talk_record_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.talkRecord.moreActionsCancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('talk_record_delete_confirm_action'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.talkRecord.deleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(talkRecordDeleteCenterProvider.notifier).confirmDelete();
  }
}

// ---------------------------------------------------------------------------
// 确认视图（删除前三条冻结要点 + 主操作）
// ---------------------------------------------------------------------------

class _ConfirmBody extends ConsumerWidget {
  const _ConfirmBody({required this.recordId, required this.onConfirm});

  final String recordId;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(talkRecordDeleteCenterProvider);
    if (!state.canDelete) {
      // §3 角色表：删除仅 owner；非 owner 直开页如实展示无权限。
      return TalkRecordOperationResultView(
        tone: TalkRecordResultTone.failure,
        title: t.talkRecord.deleteTitle,
        body: t.talkRecord.deleteOnlyOwner,
        actions: [
          TalkRecordResultAction(
            key: const ValueKey('talk_record_delete_forbidden_back'),
            label: t.talkRecord.resultBack,
            onPressed: () => _backToDetail(context),
          ),
        ],
      );
    }
    final brightness = Theme.of(context).brightness;
    final conflict = state.submitPhase == TalkRecordDeleteSubmitPhase.conflict;
    final failed = state.submitPhase == TalkRecordDeleteSubmitPhase.failed;
    final deleting = state.submitPhase == TalkRecordDeleteSubmitPhase.deleting;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('talk_record_delete_points_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.regular),
            decoration: talkRecordShareCardDecoration(brightness),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, point) in [
                  t.talkRecord.deleteConfirmBodyPoint1,
                  t.talkRecord.deleteConfirmBodyPoint2,
                  t.talkRecord.deleteConfirmBodyPoint3,
                ].indexed) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.tiny),
                        child: Icon(
                          CupertinoIcons.minus_circle,
                          size: AppSpacing.medium + 4,
                          color: AppColors.getIosRed(brightness),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        // C-F3：要点可换行。
                        child: Text(
                          point,
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
                  if (i < 2) const SizedBox(height: AppSpacing.small),
                ],
              ],
            ),
          ),
          if (conflict)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: TalkRecordResultsBanner(
                key: const ValueKey('talk_record_delete_conflict_banner'),
                text: t.talkRecord.deleteConflictHint,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: TalkRecordResultsBanner(
                key: const ValueKey('talk_record_delete_failed_banner'),
                text: t.talkRecord.deleteFailedBody,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          const SizedBox(height: AppSpacing.small),
          SizedBox(
            // C-F2：主操作 ≥48；破坏性操作用警示红实底。
            height: 48,
            child: CupertinoButton(
              key: const ValueKey('talk_record_delete_submit'),
              minimumSize: const Size.fromHeight(48),
              color: AppColors.getIosRed(brightness),
              borderRadius: BorderRadius.circular(8),
              onPressed: deleting ? null : () => onConfirm(),
              child: Text(
                deleting
                    ? t.talkRecord.deleteDeleting
                    : t.talkRecord.deleteConfirmAction,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
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

// ---------------------------------------------------------------------------
// 已删除视图（「记录已删除」+ 清理状态独立卡；不再展示正文）
// ---------------------------------------------------------------------------

class _DeletedStatusBody extends ConsumerWidget {
  const _DeletedStatusBody({required this.center});

  final TalkRecordDeleteCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('talk_record_deleted_banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.regular),
            decoration: talkRecordShareCardDecoration(brightness),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.trash,
                      size: AppSpacing.xLarge,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        // UI-SPEC §4 冻结：删除先显示「记录已删除」。
                        t.talkRecord.deleteStatusTitle,
                        maxLines: null,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  // 删除后不再展示正文（含摘要/标题）。
                  t.talkRecord.deleteStatusNoContentHint,
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
          const SizedBox(height: AppSpacing.small),
          // 清理状态独立卡（五态；与删除标题分离，§10.4）。
          if (center.record?.cleanupReason == 'write_outcome_unknown')
            TalkRecordResultsBanner(
              key: const ValueKey('talk_record_cleanup_write_unknown'),
              text: t.talkRecord.cleanupWriteOutcomeUnknown,
              color: AppColors.getIosOrange(brightness),
            )
          else if (center.record?.processorCleanupUnconfirmed ?? false)
            TalkRecordResultsBanner(
              key: const ValueKey('talk_record_cleanup_processor_unconfirmed'),
              text: t.talkRecord.cleanupProcessorUnconfirmed,
              color: AppColors.getIosOrange(brightness),
            )
          else
            TalkRecordCleanupStatusCard(status: center.cleanupStatus),
          if (center.retryPhase == TalkRecordCleanupRetryPhase.failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: TalkRecordResultsBanner(
                key: const ValueKey('talk_record_cleanup_retry_failed_banner'),
                text: t.talkRecord.cleanupRetryFailedBody,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          const SizedBox(height: AppSpacing.small),
          const SizedBox(height: AppSpacing.small),
          CupertinoButton(
            key: const ValueKey('talk_record_delete_refresh_status'),
            // C-F4：触达 ≥44。
            minimumSize: const Size(120, 44),
            onPressed: () => ref
                .read(talkRecordDeleteCenterProvider.notifier)
                .refreshStatus(),
            child: Text(t.talkRecord.deleteRefreshStatus),
          ),
          const SizedBox(height: AppSpacing.small),
          CupertinoButton(
            key: const ValueKey('talk_record_delete_back_to_list'),
            minimumSize: const Size(120, 44),
            onPressed: () => context.go(kTalkRecordListPath),
            child: Text(t.talkRecord.deleteBackToList),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            t.talkRecord.deleteStatusFixtureHint,
            maxLines: null,
            textAlign: TextAlign.center,
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
            key: const ValueKey('talk_record_delete_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
