/// ENT-APP-06 — 企业工具聚合入口（/organization/:orgId/tools）。
///
/// 只做聚合，不做新工具实体：展示**当前 Org 下我已加入的工作区**与其
/// **已授权的项目（Project）**，点击项目行深链到既有项目详情页（任务/
/// 里程碑/成员/项目频道四聚合都在其内）。数据全部读现有 API：
/// - 工作区清单 = `workspaces/mine` 按 organization_id 过滤（服务端没有
///   「某企业的全部工作区」App 面端点；未加入的工作区不出现是数据源
///   边界，不是权限裁剪）；
/// - 项目清单 = 复用 [workspaceProjectsProvider]（wsId family，active
///   工作区成员可读）——两阶段企业切换（ENT-APP-04）的 Phase 2 失效清单
///   已覆盖该 family，切 Org 后本页自动原子重建，不残留上一企业数据。
///
/// 诚实降级（不做本地伪装过滤）：
/// - org detail 403/404 → 权限/错误终态（个人域与其他企业不可见也不可
///   直达，直达由服务端拒绝）；
/// - 某工作区 projects 403/错误 → 该节显示错误行 + 重试，不整页崩溃、
///   不静默隐藏；
/// - 归档工作区显示「已归档」事实，不拉取项目（归档域读面以服务端为
///   准，需要时由用户在工作区壳内查看）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/org_async_state.dart';
import 'package:imboy/modules/organization/presentation/org_tool_deep_links.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationToolsPage extends ConsumerStatefulWidget {
  const OrganizationToolsPage({
    super.key,
    required this.orgId,
    this.accountKey,
  });

  final EntityId orgId;

  /// 缓存账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  @override
  ConsumerState<OrganizationToolsPage> createState() =>
      _OrganizationToolsPageState();
}

class _OrganizationToolsPageState extends ConsumerState<OrganizationToolsPage> {
  final OrganizationApi _orgApi = OrganizationApi();
  final WorkspaceApi _wsApi = WorkspaceApi();

  Organization? _org;
  List<WorkspaceModel> _workspaces = const [];
  bool _loading = false;

  /// 原始异常（catch 直传）：403/500 分型交给 [OrgAsyncAdapter]，页面不
  /// 自行解析错误字符串（ENT-FND-02 契约）。
  Object? _errorObj;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _errorObj = null;
    });
    try {
      final org = await _orgApi.detail(widget.orgId);
      final page = await _wsApi.mine(size: 100);
      final mine = page.list
          .where((w) => w.belongsToOrg(widget.orgId))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _org = org;
        _workspaces = mine;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _errorObj = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==================== 渲染 ====================

  @override
  Widget build(BuildContext context) {
    final org = _org;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          org != null
              ? t.organization.tools.titleWithOrg(name: org.name)
              : t.organization.tools.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgAsyncAdapter(
          loading: _loading && _org == null,
          error: _errorObj,
          empty: !_loading && _errorObj == null && _org == null,
          emptyText: t.organization.manage.orgNotFound,
          onRetry: _refresh,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    children: [
      ..._scopeNotes(),
      if (_workspaces.isEmpty) _emptyTile() else ..._wsTiles(),
      const Divider(),
      ListTile(
        dense: true,
        leading: const Icon(CupertinoIcons.chevron_right),
        title: Text(t.organization.tools.moreInWorkspaceShell),
        subtitle: Text(t.organization.tools.moreInWorkspaceShellHint),
        onTap: () => context.push('/workspace'),
      ),
    ],
  );

  /// 顶部口径说明：数据源边界 + （若有）企业归档只读事实。
  List<Widget> _scopeNotes() => [
    ListTile(
      dense: true,
      leading: const Icon(CupertinoIcons.info),
      title: Text(t.organization.tools.scopeNote),
    ),
    if (_org?.isArchived == true)
      ListTile(
        dense: true,
        leading: const Icon(CupertinoIcons.lock),
        title: Text(t.organization.tools.archivedNote),
      ),
  ];

  Widget _emptyTile() => ListTile(
    key: const ValueKey('org-tools-empty'),
    title: Text(t.organization.tools.workspaceEmpty),
    subtitle: Text(t.organization.tools.workspaceEmptyHint),
  );

  List<Widget> _wsTiles() => [
    for (final ws in _workspaces)
      if (ws.isArchived) _archivedWsTile(ws) else _wsSection(ws),
  ];

  /// 归档工作区：只呈现事实，不拉项目（不把归档域伪装成空列表）。
  Widget _archivedWsTile(WorkspaceModel ws) => ListTile(
    key: ValueKey('org-tools-ws-${ws.id}'),
    leading: Icon(
      CupertinoIcons.archivebox,
      color: Theme.of(context).disabledColor,
    ),
    title: Text(ws.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(t.organization.manage.archivedBadge),
  );

  /// 单个工作区节：标题行 + 项目清单（watch 现有 wsId family provider，
  /// 两阶段切换的失效清单覆盖它 → 切 Org 原子重建）。
  Widget _wsSection(WorkspaceModel ws) {
    final projects = ref.watch(workspaceProjectsProvider(ws.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: CupertinoIcons.square_stack_3d_up,
          title: ws.name,
          trailing: Text(
            t.organization.tools.projectCount(
              count: projects.value?.length ?? 0,
            ),
          ),
        ),
        projects.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.regular),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => _projectsError(ws, e),
          data: (list) => _projectRows(ws, list),
        ),
        const Divider(),
      ],
    );
  }

  /// 项目读取失败：该节诚实错误态 + 重试（服务端 403/网络错误不吞、
  /// 不隐藏该工作区）。
  Widget _projectsError(WorkspaceModel ws, Object e) => ListTile(
    key: ValueKey('org-tools-ws-error-${ws.id}'),
    leading: const Icon(CupertinoIcons.exclamationmark_triangle),
    title: Text(t.organization.tools.projectsError(err: _errText(e))),
    trailing: TextButton(
      key: ValueKey('org-tools-ws-retry-${ws.id}'),
      onPressed: () => ref.invalidate(workspaceProjectsProvider(ws.id)),
      child: Text(t.organization.manage.retry),
    ),
  );

  String _errText(Object e) => e is WorkspaceApiException
      ? '${e.message} (code=${e.code})'
      : e.toString();

  Widget _projectRows(WorkspaceModel ws, List<WorkspaceProjectItem> list) {
    if (list.isEmpty) {
      return ListTile(
        dense: true,
        title: Text(t.organization.tools.projectsEmpty),
      );
    }
    return Column(
      children: [
        for (final p in list)
          ListTile(
            key: ValueKey('org-tools-project-${ws.id}-${p.id}'),
            leading: const Icon(CupertinoIcons.rectangle_stack),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_projectSubtitle(p)),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => context.push(
              orgProjectDetailPath(workspaceId: ws.id, projectId: p.id),
            ),
          ),
      ],
    );
  }

  String _projectSubtitle(WorkspaceProjectItem p) =>
      [p.status, if (p.description.isNotEmpty) p.description].join(' · ');
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
