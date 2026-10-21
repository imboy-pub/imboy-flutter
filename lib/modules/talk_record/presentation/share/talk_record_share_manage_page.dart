/// 面聊记录（talk_record）分享管理页（T18）。
///
/// 契约源：UI-SPEC §2「分享管理」+ §3 角色表 + §4 状态文案 + DESIGN §3/§9：
/// - owner 视角：可见范围概述 + 「谁可以查看」名单（创建者常驻行 +
///   已授权列表：姓名/角色/可导出标记/编辑/撤销）；
/// - 添加入口按归属分型（企业=符合权限同事、个人=联系人，DESIGN §9）；
/// - **UI-SPEC 冻结：没有任何授权时不提供「发送卡片」主操作**；
/// - 「权限已保存」与「卡片已发送」分离反馈（DESIGN §10）；「已发送」
///   仅真实成功后显示（fixture 下标注示例）；
/// - 撤销确认使用冻结文案「将无法继续访问原记录。已导出或保存的副本
///   无法收回。」；撤销后名单即时更新；
/// - 非 owner（capabilities_for_actor.share=false）→ 只读自己的权限视图
///   +「编辑者不能管理 ACL」说明；无访问 → 通用失效视图（不泄露信息）。
///
/// 名单展示件见 talk_record_share_views.dart。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_invalid_view.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_views.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart'
    show talkRecordVisibilityText;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 分享管理页。
class TalkRecordShareManagePage extends ConsumerStatefulWidget {
  const TalkRecordShareManagePage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordShareManagePage> createState() =>
      _TalkRecordShareManagePageState();
}

class _TalkRecordShareManagePageState
    extends ConsumerState<TalkRecordShareManagePage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(talkRecordShareCenterProvider.notifier)
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
    final center = ref.watch(talkRecordShareCenterProvider);
    final Widget body;
    switch (center.phase) {
      case TalkRecordSharePhase.idle:
      case TalkRecordSharePhase.loading:
        body = const ShimmerList();
      case TalkRecordSharePhase.noAccess:
        // §11.3：统一失效视图，不泄露标题/人员/原因。
        body = const TalkRecordInvalidView();
      case TalkRecordSharePhase.failed:
        body = _FailedView(
          onRetry: () =>
              ref.read(talkRecordShareCenterProvider.notifier).reload(),
        );
      case TalkRecordSharePhase.ready:
        body = center.canManage
            ? _OwnerBody(state: center, onRevoke: _confirmRevoke)
            : _ReadonlyBody(state: center);
    }
    return IosPageTemplate(
      title: t.talkRecord.shareManageTitle,
      body: body,
      bottomWidget:
          center.phase == TalkRecordSharePhase.ready && center.canManage
          ? _ShareActions(state: center)
          : null,
    );
  }

  /// 撤销确认：冻结文案逐字展示 + destructive 确认（UI-SPEC §4 冻结）。
  Future<void> _confirmRevoke(TalkRecordGrantModel grant) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        key: const ValueKey('talk_record_revoke_confirm'),
        title: Text(
          t.talkRecord.shareRevokeConfirmTitle(name: grant.granteeDisplayName),
        ),
        content: Text(t.talkRecord.shareRevokeConfirmBody),
        actions: [
          CupertinoDialogAction(
            key: const ValueKey('talk_record_revoke_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.talkRecord.moreActionsCancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('talk_record_revoke_confirm_action'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.talkRecord.shareRevokeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(talkRecordShareCenterProvider.notifier)
        .revokeGrant(grant.id);
    if (!ok && mounted) {
      // 失败/412 如实反馈（不静默；名单保持服务端已知状态）。
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(t.talkRecord.shareRevokeFailedTitle),
          content: Text(
            ref.read(talkRecordShareCenterProvider).writePhase ==
                    TalkRecordShareWritePhase.conflict
                ? t.talkRecord.shareConflictHint
                : t.talkRecord.shareRevokeFailedBody,
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(t.talkRecord.moreActionsCancel),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// owner 主体（可见范围 + 名单）
// ---------------------------------------------------------------------------

class _OwnerBody extends StatelessWidget {
  const _OwnerBody({required this.state, required this.onRevoke});

  final TalkRecordShareCenterState state;
  final void Function(TalkRecordGrantModel grant) onRevoke;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TalkRecordShareVisibilityCard(grantCount: state.activeGrants.length),
          const SizedBox(height: AppSpacing.xLarge),
          TalkRecordShareRosterCard(state: state, onRevoke: onRevoke),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 非 owner 只读权限视图（capabilities 驱动门控）
// ---------------------------------------------------------------------------

class _ReadonlyBody extends StatelessWidget {
  const _ReadonlyBody({required this.state});

  final TalkRecordShareCenterState state;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final record = state.record!;
    final own = state.ownGrant;
    final isEditor = own != null && own.role == TalkRecordGrantRole.editor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Container(
        key: const ValueKey('talk_record_share_my_permission_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: talkRecordShareCardDecoration(brightness),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.talkRecord.shareMyPermissionTitle,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            if (own != null) ...[
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: 4,
                children: [
                  TalkRecordRolePill(
                    key: const ValueKey('talk_record_share_my_role_pill'),
                    text: isEditor
                        ? t.talkRecord.shareGrantRoleEditor
                        : t.talkRecord.shareGrantRoleViewer,
                    emphasized: isEditor,
                  ),
                  if (own.allowExport)
                    TalkRecordMarkPill(
                      key: const ValueKey('talk_record_share_my_export_pill'),
                      text: t.talkRecord.shareAllowExportPill,
                    ),
                  if (own.expiresAt != null)
                    TalkRecordMarkPill(
                      key: const ValueKey('talk_record_share_my_expires_pill'),
                      text: t.talkRecord.shareExpiresPill(
                        date: talkRecordShareFormatDate(own.expiresAt!),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
            ],
            // C-F3：说明可换行。
            Text(
              own == null
                  ? t.talkRecord.shareMyPermissionNone
                  : t.talkRecord.shareMyPermissionReadonly,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.body,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.talkRecord.shareVisibilityOfRecord(
                visibility: talkRecordVisibilityText(record),
              ),
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              // UI-SPEC §2：明确编辑者不能管理 ACL 或删除。
              t.talkRecord.shareEditorCannotManageAcl,
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
    );
  }
}

// ---------------------------------------------------------------------------
// 底部操作区（保存反馈与发送卡片分离；0 授权无主操作）
// ---------------------------------------------------------------------------

class _ShareActions extends ConsumerWidget {
  const _ShareActions({required this.state});

  final TalkRecordShareCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final grantCount = state.activeGrants.length;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.writePhase == TalkRecordShareWritePhase.conflict)
            TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_conflict_banner'),
              text: t.talkRecord.shareConflictHint,
              color: AppColors.getIosOrange(brightness),
            ),
          // 「权限已保存」反馈：仅保存授权动作置位，与发送卡片分离。
          if (state.savedFeedback)
            TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_saved_banner'),
              text: t.talkRecord.shareSaveFeedback,
              color: AppColors.primaryDark,
            ),
          // 发送反馈：sent 仅真实成功；unavailable 如实待接入；示例标注。
          switch (state.cardSendPhase) {
            TalkRecordCardSendPhase.sent => TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_card_sent_banner'),
              text: t.talkRecord.shareCardSent,
              color: AppColors.primaryDark,
            ),
            TalkRecordCardSendPhase.failed => TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_card_failed_banner'),
              text: t.talkRecord.shareCardSendFailed,
              color: AppColors.getIosOrange(brightness),
            ),
            TalkRecordCardSendPhase.pending => TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_card_pending_banner'),
              text: t.talkRecord.shareCardSendPending,
              color: AppColors.getIosOrange(brightness),
            ),
            TalkRecordCardSendPhase.cancelled => TalkRecordShareFeedbackBanner(
              key: const ValueKey('talk_record_share_card_cancelled_banner'),
              text: t.talkRecord.shareCardSendCancelled,
              color: AppColors.getTextSecondary(brightness),
            ),
            TalkRecordCardSendPhase.unavailable =>
              TalkRecordShareFeedbackBanner(
                key: const ValueKey(
                  'talk_record_share_card_unavailable_banner',
                ),
                text: t.talkRecord.shareCardSenderUnavailable,
                color: AppColors.getIosOrange(brightness),
              ),
            _ => const SizedBox.shrink(),
          },
          if (grantCount == 0)
            _SendDisabledHint(brightness: brightness)
          else ...[
            _SendCardButton(state: state),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.talkRecord.shareSendCardHint,
                maxLines: null,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// UI-SPEC 冻结：没有任何授权时不提供「发送卡片」主操作——只保留提示
/// 文字，不渲染按钮。
class _SendDisabledHint extends StatelessWidget {
  const _SendDisabledHint({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('talk_record_share_send_disabled_hint'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.tiny),
      child: Text(
        t.talkRecord.shareSendNeedsGrant,
        maxLines: null,
        textAlign: TextAlign.center,
        style: context.textStyle(
          FontSizeType.footnote,
          color: brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _SendCardButton extends ConsumerWidget {
  const _SendCardButton({required this.state});

  final TalkRecordShareCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sending = state.cardSendPhase == TalkRecordCardSendPhase.sending;
    return SizedBox(
      // C-F2：主操作 ≥48pt 高、primaryDark 实底 + 白字 w600。
      height: 48,
      child: CupertinoButton(
        key: const ValueKey('talk_record_share_send_card'),
        minimumSize: const Size.fromHeight(48),
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
        // sending 中禁用防重复提交（onPressed null = 禁用态）。
        onPressed: sending
            ? null
            : () => ref.read(talkRecordShareCenterProvider.notifier).sendCard(),
        child: Text(
          sending ? t.talkRecord.shareCardSending : t.talkRecord.shareSendCard,
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
            key: const ValueKey('talk_record_share_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
