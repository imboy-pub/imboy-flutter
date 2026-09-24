import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';
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

        // 6. 退出/解散按钮（与危险操作区留白隔离，强调最高危操作）
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.xxxLarge,
            AppSpacing.regular,
            AppSpacing.xxLarge,
          ),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: AppColors.getIosRed(brightness).withValues(alpha: 0.1),
              onPressed: () => _confirmExitGroup(context),
              child: Text(
                isGroupOwner(role) ? t.group.groupDissolve : t.group.groupLeave,
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
              int cid = await GroupDetailService().cleanMessageByPeerId(
                'C2G',
                groupId,
              );
              if (cid > 0) {
                onDirty();
                await ref
                    .read(conversationProvider.notifier)
                    .hideConversation(cid);
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

  void _confirmExitGroup(BuildContext context) {
    String tips =
        "${isGroupOwner(role) ? t.group.sureToDissolveGroup : t.group.sureToLeaveGroup}\n${t.common.sureDeleteGroupChatRecord}";
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.tipTips),
        content: Text(tips),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.buttonConfirm),
            onPressed: () async {
              var nav = Navigator.of(context);
              bool res = isGroupOwner(role)
                  ? await GroupDetailService().dissolve(groupId)
                  : await GroupDetailService().leave(groupId);
              if (res) {
                AppLoading.showSuccess(t.common.tipSuccess);
                nav.pop();
                nav.pop();
              } else {
                // 失败必须给反馈+关弹窗，否则用户点确认后界面像卡死
                AppLoading.showError(t.common.tipFailed);
                nav.pop();
              }
            },
          ),
        ],
      ),
    );
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
