/// T9 (WP5) — 创建工作区（3 分钟建站 Template 流）
///
/// 消费后端 Template 原子创建（I13：Workspace + Owner Member +
/// Announcements Channel + General Group + 创建者必要权限，单事务全成或
/// 全回滚；request_id 幂等防重复）。成功后进入该 workspace 的 Overview。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceCreatePage extends ConsumerStatefulWidget {
  const WorkspaceCreatePage({super.key});

  @override
  ConsumerState<WorkspaceCreatePage> createState() =>
      _WorkspaceCreatePageState();
}

class _WorkspaceCreatePageState extends ConsumerState<WorkspaceCreatePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final t = context.t;
    if (name.isEmpty) {
      AppLoading.showError(t.workspace.createNameRequired);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(workspaceApiProvider)
          .create(name: name, requestId: Xid().toString());
      // 回填壳状态并进入该 workspace 的 Overview（幂等命中同样进入）
      ref.read(workspaceShellProvider.notifier).applyCreated(result);
      if (!mounted) return;
      AppLoading.showSuccess(
        result.isIdempotentHit
            ? t.workspace.createIdempotentHit
            : t.workspace.createSuccess,
      );
      // 回到壳挂载点（experience=workspace 时即 WorkspaceShell + Overview）
      context.go('/bottom_navigation');
    } on WorkspaceApiException catch (e) {
      // 服务端消息透出（409 上限 / 980 归档等）
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.createTitle)),
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          Text(
            t.workspace.createDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalRegular,
          TextField(
            key: const ValueKey('workspace-create-name-field'),
            controller: _nameCtrl,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: t.workspace.createNameLabel,
              hintText: t.workspace.createNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalRegular,
          WorkspaceSectionCard(
            title: t.workspace.createTemplateTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TemplateRow(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  text: t.workspace.createTemplateChannel,
                ),
                _TemplateRow(
                  icon: CupertinoIcons.person_2,
                  text: t.workspace.createTemplateGroup,
                ),
                _TemplateRow(
                  icon: CupertinoIcons.checkmark_seal,
                  text: t.workspace.createTemplateOwner,
                ),
              ],
            ),
          ),
          AppSpacing.verticalRegular,
          FilledButton(
            key: const ValueKey('workspace-create-submit'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.workspace.createSubmit),
          ),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TemplateRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.tiny),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          AppSpacing.horizontalSmall,
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
