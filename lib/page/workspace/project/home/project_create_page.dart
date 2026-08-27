/// WP6 (T10a) — 创建项目表单（name/description 最小字段集）
///
/// 权限：Workspace Owner/Member 可写、Guest 只读（服务端 403 兜底；
/// 服务端消息原样透出，禁止静默失败）。archived 工作区服务端 980 拒绝。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ProjectCreatePage extends ConsumerStatefulWidget {
  final EntityId workspaceId;

  const ProjectCreatePage({super.key, required this.workspaceId});

  @override
  ConsumerState<ProjectCreatePage> createState() => _ProjectCreatePageState();
}

class _ProjectCreatePageState extends ConsumerState<ProjectCreatePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = context.t;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppLoading.showError(t.workspace.projectNameRequired);
      return;
    }
    if (_submitting) return; // 防抖：重复点击只提交一次
    setState(() => _submitting = true);
    try {
      await ref
          .read(projectApiProvider)
          .create(
            workspaceId: widget.workspaceId,
            name: name,
            description: _descCtrl.text.trim(),
          );
      // 刷新列表首页（下拉刷新与详情入口所在）
      ref.invalidate(projectListPageProvider((widget.workspaceId, 1)));
      if (!mounted) return;
      AppLoading.showSuccess(t.workspace.projectCreateSuccess);
      context.pop();
    } on WorkspaceApiException catch (e) {
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
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.projectCreateTitle)),
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          TextField(
            key: const ValueKey('project-create-name-field'),
            controller: _nameCtrl,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: t.workspace.projectNameLabel,
              hintText: t.workspace.projectNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalRegular,
          TextField(
            key: const ValueKey('project-create-desc-field'),
            controller: _descCtrl,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: t.workspace.projectDescLabel,
              hintText: t.workspace.projectDescHint,
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalRegular,
          FilledButton(
            key: const ValueKey('project-create-submit'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.workspace.projectSubmit),
          ),
        ],
      ),
    );
  }
}
