import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/group/group_detail/transfer_owner_page.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/report_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../group_detail_service.dart';

/// 治理/危险区（5+6）：清空聊天记录、投诉、退出/解散群。
///
/// ENT-APP-02 等价拆分：自 group_detail_page.dart 的「危险操作 Section」、
/// 「退出/解散按钮」及 `_confirmClearChat` / `_confirmExitGroup` /
/// `_showComplaintDialog` / `_submitComplaint` 机械搬运。确认对话文案、
/// isGroupOwner 分支（解散 vs 退出）、成功 pop×2 / 失败 toast+pop 的
/// 时序与原实现逐行一致。
class GroupDangerZone extends ConsumerWidget {
  const GroupDangerZone({
    super.key,
    required this.groupId,
    required this.role,
    required this.onDirty,
  });

  final String groupId;

  /// 页面当前 role（原 `_confirmExitGroup(state)` 的 state.role）。
  final int role;

  /// 会话列表需刷新标记（原 `backDoRefresh = true`）。
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;

    return Column(
      children: [
        // 5. 危险操作 Section
        ImBoySettingsSection(
          children: [
            ImBoySettingsTile(
              title: Text(t.common.clearChatRecord),
              destructive: true,
              onTap: () => _confirmClearChat(context, ref),
            ),
            ImBoySettingsTile(
              title: Text(t.complaint.complaint),
              onTap: () => _showComplaintDialog(context),
            ),
          ],
        ),

        // 6. 退出/解散（与危险操作区留白隔离，强调最高危操作）
        //
        // W10（F17/J19.b/c）：后果分离——群主不再只有「解散」一条路：
        //   - 主按钮「转让后退出」：选合格接任人 → 转让 → 退出（两步
        //     结果准确；转让成功但退出失败明确提示并只重试退出）；
        //   - 另有红色「解散群聊」独立确认（取消无副作用）。
        // 普通成员保持单一「退出群聊」。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.xxxLarge,
            AppSpacing.regular,
            AppSpacing.xxLarge,
          ),
          child: Column(
            children: [
              if (isGroupOwner(role))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.regular),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.getIosRed(brightness)
                          .withValues(alpha: 0.1),
                      onPressed: () => _confirmTransferAndLeave(context),
                      child: Text(
                        t.group.transferAndLeave,
                        style: context.textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getIosRed(brightness),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.getIosRed(brightness).withValues(alpha: 0.1),
                  onPressed: () => isGroupOwner(role)
                      ? _confirmDissolve(context)
                      : _confirmLeave(context),
                  child: Text(
                    isGroupOwner(role)
                        ? t.group.groupDissolve
                        : t.group.groupLeave,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getIosRed(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmClearChat(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.warning),
        content: Text(t.common.confirmDeleteChatRecord),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.buttonConfirm),
            onPressed: () async {
              Navigator.pop(ctx);
              // W10（F17/J19.d）：清空 = 仅清本机记录；入口保留、不隐藏
              // 会话（隐藏是独立的「从列表移除」动作，J19.e）。
              int cid = await GroupDetailService().cleanMessageByPeerId(
                'C2G',
                groupId,
              );
              if (cid > 0) {
                onDirty();
                await ref
                    .read(conversationProvider.notifier)
                    .conversationsList();
                AppLoading.showSuccess(t.common.tipSuccess);
              } else {
                AppLoading.showError(t.common.tipFailed);
              }
            },
          ),
        ],
      ),
    );
  }

  /// W10（J19.b）：群主「转让后退出」——确认 → 选合格接任人 → 转让
  /// → 退出。转让/退出分步结果准确：转让失败即停（原身份保留）；转让
  /// 成功但退出失败提示已转让并只重试退出，不默认解散。
  Future<void> _confirmTransferAndLeave(BuildContext context) async {
    final confirmed = await _confirmAction(
      context,
      t.group.sureToTransferAndLeave,
    );
    if (!confirmed) return; // 取消无副作用
    if (!context.mounted) return;
    final selected = await Navigator.of(context).push<String>(
      CupertinoPageRoute(builder: (_) => TransferOwnerPage(groupId: groupId)),
    );
    if (selected == null || selected.isEmpty) return; // 未选择 = 放弃
    final okTransfer = await GroupApi().transfer(
      gid: groupId,
      newOwnerUid: selected,
    );
    if (!okTransfer) {
      AppLoading.showError(t.common.tipFailed);
      return;
    }
    await HapticFeedback.mediumImpact();
    final okLeave = await GroupDetailService().leave(groupId);
    if (!context.mounted) return;
    if (okLeave) {
      AppLoading.showSuccess(t.common.tipSuccess);
      final nav = Navigator.of(context);
      nav.pop(); // 回列表（转让已生效、退出成功）
      nav.pop();
    } else {
      // §5.2：转让成功但退出失败必须提示已转让并仅重试退出——
      // 不解散、不 pop（停留在详情页可再次点击退出，此时已是成员身份）。
      AppLoading.showError(t.group.transferredButLeaveFailed);
      onDirty();
    }
  }

  /// W10（J19.c）：群主解散——独立高危确认，后果说明清楚，取消无副作用。
  Future<void> _confirmDissolve(BuildContext context) async {
    // navigator 在任何 async gap 之前捕获（use_build_context_synchronously）。
    var nav = Navigator.of(context);
    final confirmed = await _confirmAction(
      context,
      '${t.group.sureToDissolveGroup}\n${t.common.sureDeleteGroupChatRecord}',
    );
    if (!confirmed) return;
    final res = await GroupDetailService().dissolve(groupId);
    if (res) {
      AppLoading.showSuccess(t.common.tipSuccess);
      nav.pop();
      nav.pop();
    } else {
      // 失败必须给反馈+关弹窗，否则用户点确认后界面像卡死
      AppLoading.showError(t.common.tipFailed);
      nav.pop();
    }
  }

  /// W10（J19.a）：普通成员退出——确认/取消分离，取消无副作用。
  Future<void> _confirmLeave(BuildContext context) async {
    // navigator 在任何 async gap 之前捕获（use_build_context_synchronously）。
    var nav = Navigator.of(context);
    final confirmed = await _confirmAction(
      context,
      '${t.group.sureToLeaveGroup}\n${t.common.sureDeleteGroupChatRecord}',
    );
    if (!confirmed) return;
    final res = await GroupDetailService().leave(groupId);
    if (res) {
      AppLoading.showSuccess(t.common.tipSuccess);
      nav.pop();
      nav.pop();
    } else {
      AppLoading.showError(t.common.tipFailed);
      nav.pop();
    }
  }

  /// 统一确认对话框：返回 true=确认、false=取消（取消零副作用）。
  Future<bool> _confirmAction(BuildContext context, String content) async {
    final confirmed = Completer<bool>();
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.tipTips),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.buttonCancel),
            onPressed: () {
              Navigator.pop(ctx);
              confirmed.complete(false);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.buttonConfirm),
            onPressed: () {
              Navigator.pop(ctx);
              confirmed.complete(true);
            },
          ),
        ],
      ),
    );
    return confirmed.future;
  }

  void _showComplaintDialog(BuildContext context) {
    GroupDialogs.actionSheet(
      context,
      title: t.complaint.complaint,
      actions: [
        (
          label: t.complaintReason.spam,
          destructive: false,
          onPressed: () => _submitComplaint('spam'),
        ),
        (
          label: t.complaintReason.harassment,
          destructive: false,
          onPressed: () => _submitComplaint('harassment'),
        ),
        (
          label: t.complaintReason.inappropriate,
          destructive: false,
          onPressed: () => _submitComplaint('inappropriate'),
        ),
        (
          label: t.complaintReason.other,
          destructive: false,
          onPressed: () => _submitComplaint('other'),
        ),
      ],
    );
  }

  Future<void> _submitComplaint(String reason) async {
    final (ok, serverMsg) = await ReportApi().create(
      targetType: 'group',
      targetId: groupId,
      reason: reason,
    );
    if (ok) {
      AppLoading.showSuccess(t.common.complaintSuccess);
    } else {
      AppLoading.showError(
        ReportApi.friendlyError(serverMsg, t.common.complaintFailed),
      );
    }
  }
}
