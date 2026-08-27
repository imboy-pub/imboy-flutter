/// T9/T12 (WP5) — Branding 编辑页（白名单 name / logo / primaryColor）
///
/// 仅 Owner（服务端校验）；archived 时写操作禁用（980 兜底）。保存成功后
/// 轻量同步壳内工作区行——WorkspaceBrandingScope（T12）随 branding 变化
/// 重建主题，无需离开页面即可看到主色变化。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceBrandingPage extends ConsumerStatefulWidget {
  final EntityId workspaceId;

  const WorkspaceBrandingPage({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceBrandingPage> createState() =>
      _WorkspaceBrandingPageState();
}

class _WorkspaceBrandingPageState extends ConsumerState<WorkspaceBrandingPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _logoCtrl = TextEditingController();
  final TextEditingController _colorCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _logoCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = context.t;
    if (_saving) return;
    final color = _colorCtrl.text.trim();
    if (color.isNotEmpty && parseBrandingPrimaryColor(color) == null) {
      AppLoading.showError(t.workspace.brandingColorInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      final branding = await ref
          .read(workspaceApiProvider)
          .updateBranding(
            widget.workspaceId,
            WorkspaceBranding(
              name: _nameCtrl.text.trim(),
              logo: _logoCtrl.text.trim(),
              primaryColor: color,
            ),
          );
      // 轻量同步壳内行（T12 主题随之切换）
      final ws = ref.read(currentWorkspaceProvider);
      if (ws != null && ws.id == widget.workspaceId) {
        ref
            .read(workspaceShellProvider.notifier)
            .replaceWorkspace(_mergeBranding(ws, branding));
      }
      if (mounted) {
        AppLoading.showSuccess(t.workspace.brandingSaved);
        Navigator.of(context).maybePop();
      }
    } on WorkspaceApiException catch (e) {
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  WorkspaceModel _mergeBranding(WorkspaceModel ws, WorkspaceBranding branding) {
    return WorkspaceModel(
      id: ws.id,
      name: branding.name.isNotEmpty ? branding.name : ws.name,
      logo: branding.logo,
      ownerId: ws.ownerId,
      status: ws.status,
      branding: branding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final ws = ref.watch(currentWorkspaceProvider);
    final archived = ws?.isArchived ?? false;
    if (!_initialized && ws != null) {
      _initialized = true;
      _nameCtrl.text = ws.branding.name.isNotEmpty ? ws.branding.name : ws.name;
      _logoCtrl.text = ws.branding.logo;
      _colorCtrl.text = ws.branding.primaryColor;
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.brandingTitle)),
      body: Column(
        children: [
          if (archived) const WorkspaceArchivedBanner(),
          Expanded(
            child: ListView(
              padding: AppSpacing.allRegular,
              children: [
                TextField(
                  key: const ValueKey('workspace-branding-name-field'),
                  controller: _nameCtrl,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: t.workspace.brandingNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                AppSpacing.verticalRegular,
                TextField(
                  key: const ValueKey('workspace-branding-logo-field'),
                  controller: _logoCtrl,
                  decoration: InputDecoration(
                    labelText: t.workspace.brandingLogoLabel,
                    hintText: t.workspace.brandingLogoHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                AppSpacing.verticalRegular,
                TextField(
                  key: const ValueKey('workspace-branding-color-field'),
                  controller: _colorCtrl,
                  decoration: InputDecoration(
                    labelText: t.workspace.brandingColorLabel,
                    hintText: t.workspace.brandingColorHint,
                    helperText: t.workspace.brandingColorHelper,
                    border: const OutlineInputBorder(),
                  ),
                ),
                AppSpacing.verticalRegular,
                // 主色预览（解析失败回落主题默认色，与 T12 作用域一致）
                WorkspaceSectionCard(
                  title: t.workspace.brandingPreview,
                  child: Builder(
                    builder: (ctx) {
                      final parsed = parseBrandingPrimaryColor(_colorCtrl.text);
                      return Row(
                        children: [
                          Container(
                            key: const ValueKey('workspace-branding-preview'),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  parsed ?? Theme.of(ctx).colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.small,
                              ),
                            ),
                          ),
                          AppSpacing.horizontalRegular,
                          Expanded(
                            child: Text(
                              parsed == null
                                  ? t.workspace.brandingPreviewFallback
                                  : t.workspace.brandingPreviewApplied,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                AppSpacing.verticalRegular,
                FilledButton(
                  key: const ValueKey('workspace-branding-save'),
                  // archived：写操作禁用（服务端 980 兜底）
                  onPressed: archived || _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.common.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
