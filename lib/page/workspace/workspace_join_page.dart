/// T2.6 (WP 团队码) — 团队码加入工作区页
///
/// 输入 8 位团队码加入工作区：输满自动提交（镜像 face_to_face 输满自动
/// 提交体验），保留显式提交按钮。成功（joined / unchanged 均算）→ 回填
/// 壳状态（applyJoined：置顶 + 切当前 + 回 Overview）→ 回壳挂载点
/// /bottom_navigation；失败留在本页，错误文案页内展示（981 无效 / 982
/// 过期映射 i18n，其余透传服务端消息）。
///
/// 页面骨架镜像 workspace_create_page（Scaffold + AppBar 自带返回键——
/// push 可达页面必须自带骨架，透明 Scaffold 会露路由栈黑底）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_join_controller.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceJoinPage extends ConsumerStatefulWidget {
  const WorkspaceJoinPage({super.key});

  @override
  ConsumerState<WorkspaceJoinPage> createState() => _WorkspaceJoinPageState();
}

class _WorkspaceJoinPageState extends ConsumerState<WorkspaceJoinPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final WorkspaceJoinController _join = WorkspaceJoinController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _join.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = context.t;
    final ok = await _join.submit(
      joinByCode: (code) => ref.read(workspaceApiProvider).joinByCode(code),
    );
    if (!ok || !mounted) return;
    final s = _join.state;
    // 异常兜底：成功 envelope 缺 workspace（契约外），留在页面提示失败
    if (s.workspace.id.isEmpty) {
      AppLoading.showError(t.common.tipFailed);
      return;
    }
    // joined / unchanged 都算成功加入：置顶 + 切当前 + 回 Overview
    ref.read(workspaceShellProvider.notifier).applyJoined(s.workspace);
    if (!mounted) return;
    AppLoading.showSuccess(
      s.alreadyMember
          ? t.workspace.joinAlreadyMember
          : t.workspace.joinSuccess(name: s.workspace.name),
    );
    // 回到壳挂载点（experience=workspace 时即 WorkspaceShell + Overview）
    context.go('/bottom_navigation');
  }

  void _onCodeChanged(String raw) {
    // 输满 8 位自动提交（face_to_face 同款体验）；显式按钮兜底
    if (_join.updateCode(raw)) {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.joinTitle)),
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          Text(
            t.workspace.joinDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalRegular,
          AnimatedBuilder(
            animation: _join,
            builder: (context, _) {
              return TextField(
                key: const ValueKey('workspace-join-code-field'),
                controller: _codeCtrl,
                // formatter 已限长；maxLength 弹计数器破坏团队码专注输入
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kWorkspaceJoinCodeLength),
                  const WorkspaceCodeInputFormatter(),
                ],
                enabled: !_join.isSubmitting,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                // visiblePassword：禁 IME 组合态（中文键盘拼音字母经
                // uppercase/formatter 会混入码字段）+ 免联想
                keyboardType: TextInputType.visiblePassword,
                onChanged: _onCodeChanged,
                decoration: InputDecoration(
                  labelText: t.workspace.joinCodeLabel,
                  hintText: t.workspace.joinCodeHint,
                  border: const OutlineInputBorder(),
                ),
              );
            },
          ),
          AppSpacing.verticalTiny,
          AnimatedBuilder(
            animation: _join,
            builder: (context, _) {
              final s = _join.state;
              final errorText = switch (s.phase) {
                WorkspaceJoinPhase.invalidCode => t.workspace.joinInvalidCode,
                WorkspaceJoinPhase.expiredCode => t.workspace.joinExpiredCode,
                WorkspaceJoinPhase.failed => s.message,
                _ => '',
              };
              if (errorText.isEmpty) return const SizedBox.shrink();
              return Text(
                errorText,
                key: const ValueKey('workspace-join-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              );
            },
          ),
          AppSpacing.verticalRegular,
          AnimatedBuilder(
            animation: _join,
            builder: (context, _) {
              return FilledButton(
                key: const ValueKey('workspace-join-submit'),
                onPressed: (_join.canSubmit && !_join.isSubmitting)
                    ? _submit
                    : null,
                child: _join.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.workspace.joinSubmit),
              );
            },
          ),
        ],
      ),
    );
  }
}
