/// Organization 页面共享 UI 件（owned path 内；状态/标签映射/二次确认）。
///
/// 展示即事实：状态/角色文案只做 wire 值 → 中文标签的机械映射，
/// 未知值原样展示，绝不臆造语义（ORG-A13）。
library;

import 'package:flutter/material.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 全量状态视图：loading / empty / error（含 403 权限态变体）。
/// offline 场景复用 error 态（网络异常文案可见，可下拉/按钮重试）。
class OrgStateView extends StatelessWidget {
  const OrgStateView({
    super.key,
    required this.loading,
    required this.error,
    this.permissionDenied = false,
    required this.empty,
    this.emptyText = '暂无数据',
    required this.onRetry,
    this.child,
  });

  final bool loading;
  final String? error;

  /// 403 专用文案态（权限 denied ≠ 系统错误，不引导盲目重试）。
  final bool permissionDenied;
  final bool empty;
  final String emptyText;
  final VoidCallback onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40),
            const SizedBox(height: AppSpacing.small),
            const Text('无权查看（该操作仅限 owner / admin）'),
            const SizedBox(height: AppSpacing.regular),
            TextButton(onPressed: onRetry, child: const Text('返回刷新')),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: AppSpacing.small),
            Text('加载失败：$error', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.regular),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }
    if (empty) {
      return Center(child: Text(emptyText));
    }
    return child ?? const SizedBox.shrink();
  }
}

/// 危险操作二次确认弹窗（行点击为第一步，本弹窗为第二步）。
/// [consequence] 必须写明不可逆后果；返回 true 才执行。
Future<bool> orgConfirmDangerAction(
  BuildContext context, {
  required String title,
  required String consequence,
  String confirmText = '确认执行',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(consequence),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        Semantics(
          button: true,
          label: '$title 确认',
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 一般操作二次确认弹窗（正向语义，与危险变体唯一差异是确认键配色）。
/// 行点击为第一步，本弹窗为第二步；返回 true 才执行。
Future<bool> orgConfirmAction(
  BuildContext context, {
  required String title,
  required String consequence,
  String confirmText = '确认执行',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(consequence),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        Semantics(
          button: true,
          label: '$title 确认',
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.primary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 单行输入弹窗（创建组织/部门、邀请 token 兑换等）。
Future<String?> orgPromptInput(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  bool multiline = false,
}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        Semantics(
          button: true,
          label: '$title 提交',
          child: TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ),
      ],
    ),
  );
  return (value == null || value.isEmpty) ? null : value;
}

/// 角色标签映射（owner/admin/member 之外原样返回）。
String orgRoleLabel(String role) => switch (role) {
  'owner' => '所有者',
  'admin' => '管理员',
  'member' => '成员',
  _ => role,
};

/// 组织/部门/成员状态标签映射。
String orgStatusLabel(String status) => switch (status) {
  'active' => '正常',
  'archived' => '已归档',
  'suspended' => '已暂停',
  'removed' => '已移除',
  _ => status,
};

/// 邀请状态标签映射（C11 五态；未知原样）。
String invitationStatusLabel(String status) => switch (status) {
  'pending' => '待处理',
  'accepted' => '已接受',
  'rejected' => '已拒绝',
  'revoked' => '已撤销',
  'expired' => '已过期',
  _ => status,
};

/// 成员行 subtitle 组装：角色 · 状态 · 加入时间（时间宽容解析）。
String memberSubtitle(OrganizationMember m) {
  final parts = <String>[
    orgRoleLabel(m.role),
    orgStatusLabel(m.status),
    if (m.joinedAt.isNotEmpty) flexTsLabel(m.joinedAt),
  ];
  return parts.join(' · ');
}

/// 邀请行 subtitle 组装。
String invitationSubtitle(OrgInvitation i) {
  final parts = <String>[
    invitationStatusLabel(i.status),
    if (i.expiresAt.isNotEmpty) '有效期至 ${flexTsLabel(i.expiresAt)}',
  ];
  return parts.join(' · ');
}
