/// 类企业微信通讯录浏览页（计划 §14.2 P1 CORE）。
///
/// 交互：企业根 → 直接子部门页（上半直接子部门、下半本级成员）→ 成员
/// 资料 / 发消息（复用既有 `/organization/:orgId/member/:uid` 企业成员详情，
/// 其内保留通往通用 IM 资料页的次级入口）。不一次展开全树、不 N+1——
/// 每层只拉 direct children + 本级成员，两节各自 cursor 分页。
///
/// 数据核：[HumanDirectoryController]（§14.3 状态机：request_generation /
/// request_key / 部门成员独立分页 / cursor 400 一次性重试 / 两阶段 Org
/// 切换）。本页只做接线：
/// - 搜索固定 300ms debounce 后交 `controller.setQuery`（trim <2 字符不请求）；
/// - orgId / path 变化经 didUpdateWidget，账号变化经 Provider 监听 configure
///   （request_key 变化 ⇒ generation 递增 + 从首页重建，上一上下文的
///   列表/cursor/error 一律不复用）；
/// - 企业切换两阶段：prepare = mine() 真源校验 + 目标 Org Workspace 壳
///   加载；commit = 缓存失效 + CurrentOrganizationStore 指针提交
///   （复用既有 store / provider invalidation，不建第二套）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageRoute, CupertinoSearchTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/human_directory_controller.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';

import 'human_directory_org_switch_sheet.dart';
import 'human_directory_layout.dart';
import 'organization_chart.dart';

/// 通讯录层级（页面内部 path 栈；系统返回先上翻一层，根级才真正 pop）。
class _DirectoryLevel {
  const _DirectoryLevel({this.departmentId, required this.name});

  /// null = 企业根。
  final EntityId? departmentId;
  final String name;
}

/// 类企业微信通讯录浏览页（数据核见 [HumanDirectoryController]）。
class HumanDirectoryBrowserPage extends ConsumerStatefulWidget {
  const HumanDirectoryBrowserPage({
    super.key,
    required this.orgId,
    this.orgName = '',
    this.departmentId,
    this.departmentName = '',
    this.dataSource,
    this.embedded = false,
  });

  final EntityId orgId;
  final String orgName;

  /// 深链初始层级（缺省企业根）。
  final EntityId? departmentId;
  final String departmentName;

  /// 测试注入口（缺省 [OrganizationApi]，复用既有 Token/HttpClient）。
  final HumanDirectoryDataSource? dataSource;

  /// 企业壳提供唯一空间切换栏；部门内仍保留逐级返回。
  final bool embedded;

  @override
  ConsumerState<HumanDirectoryBrowserPage> createState() =>
      _HumanDirectoryBrowserPageState();
}

class _HumanDirectoryBrowserPageState
    extends ConsumerState<HumanDirectoryBrowserPage> {
  late final HumanDirectoryController _controller;
  final OrganizationApi _orgApi = OrganizationApi();

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  /// 当前展示的企业名（切换成功后更新；orgName 仅初始种子）。
  late String _orgName;

  /// 层级栈：末位为当前层级。
  List<_DirectoryLevel> _levels = const [];

  String get _accountKey => ref.read(currentUserProvider)?.uid ?? '';

  bool _isCurrentAccount(String uid) =>
      mounted && uid.isNotEmpty && _accountKey == uid;

  _DirectoryLevel get _currentLevel => _levels.last;

  @override
  void initState() {
    super.initState();
    _orgName = widget.orgName;
    _controller = HumanDirectoryController(
      dataSource: widget.dataSource ?? _orgApi,
    );
    _resetLevels(
      departmentId: widget.departmentId,
      departmentName: widget.departmentName,
    );
    ref.listenManual<String>(
      currentUserProvider.select((user) => user?.uid ?? ''),
      (previous, next) {
        _clearSearch();
        _resetLevels(
          departmentId: widget.departmentId,
          departmentName: widget.departmentName,
        );
        _controller.configure(
          accountKey: next,
          organizationId: widget.orgId,
          departmentId: widget.departmentId,
        );
        if (previous != null && mounted) setState(() {});
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant HumanDirectoryBrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orgName != oldWidget.orgName) {
      _orgName = widget.orgName;
      _levels = [_DirectoryLevel(name: _orgName), ..._levels.skip(1)];
    }
    // §14.3：orgId / path 变化 → configure（request_key 变化 ⇒ generation
    // 递增 + 从首页重建；上一 Org 的列表/cursor/error 不复用）。
    if (oldWidget.orgId == widget.orgId &&
        oldWidget.departmentId == widget.departmentId) {
      return;
    }
    if (widget.orgId != oldWidget.orgId) {
      _orgName = widget.orgName;
    }
    _resetLevels(
      departmentId: widget.departmentId,
      departmentName: widget.departmentName,
    );
    _clearSearch();
    _controller.configure(
      accountKey: _accountKey,
      organizationId: widget.orgId,
      departmentId: widget.departmentId,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _resetLevels({EntityId? departmentId, String departmentName = ''}) {
    _levels = [
      _DirectoryLevel(name: _orgName, departmentId: null),
      if (departmentId != null && departmentId.isNotEmpty)
        _DirectoryLevel(
          departmentId: departmentId,
          name: departmentName.isEmpty ? departmentId : departmentName,
        ),
    ];
  }

  // ---- 搜索：固定 300ms debounce ----

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
  }

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _controller.setQuery(raw);
    });
  }

  // ---- 层级导航 ----

  void _openDepartment(HumanDirectoryDepartment dept) {
    setState(() {
      _levels = [
        ..._levels,
        _DirectoryLevel(departmentId: dept.id, name: dept.name),
      ];
    });
    _clearSearch();
    _controller.openDepartment(dept.id);
  }

  void _upOneLevel() {
    _openLevel(_levels.length - 2);
  }

  void _openLevel(int index) {
    if (index < 0 || index >= _levels.length - 1) return;
    setState(() => _levels = _levels.sublist(0, index + 1));
    final target = _levels.last;
    _clearSearch();
    if (target.departmentId == null) {
      _controller.openRoot();
    } else {
      _controller.openDepartment(target.departmentId!);
    }
  }

  // ---- 两阶段企业切换 ----

  Future<void> _openOrgSwitcher() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => HumanDirectoryOrgSwitchSheet(
        orgApi: _orgApi,
        accountKey: _accountKey,
        currentOrgId: _controller.identity?.organizationId ?? widget.orgId,
        onPick: (target) => _switchTo(target),
      ),
    );
  }

  /// 两阶段切换；返回切换失败信息（null = 成功，弹层自行关闭）。
  Future<String?> _switchTo(Organization target) async {
    final account = _accountKey;
    await _controller.switchOrganization(
      target,
      prepare: _prepareSwitch,
      commit: _commitSwitch,
    );
    if (!_isCurrentAccount(account)) {
      return t.organization.directory.switchVerifyFailed;
    }
    final err = _controller.switchError;
    if (err != null) return err;
    if (_controller.identity?.organizationId != target.id) {
      return t.organization.directory.switchVerifyFailed;
    }
    setState(() => _orgName = target.name);
    _resetLevels(departmentId: null);
    _clearSearch();
    return null;
  }

  /// Phase 1：mine() membership 真源校验 + 目标 Org 的 Workspace 壳加载。
  /// 任一步失败抛异常 → 控制器 rollback（旧 Org/数据保留 + 可重试错误）。
  Future<void> _prepareSwitch(Organization target) async {
    final account = _accountKey;
    final organizations = await _orgApi.allMine();
    if (!_isCurrentAccount(account)) {
      throw StateError('Directory account changed');
    }
    Organization? fresh;
    for (final o in organizations) {
      if (o.id == target.id) fresh = o;
    }
    if (fresh == null || fresh.isArchived) {
      throw Exception(t.organization.directory.switchVerifyFailed);
    }
    await ref
        .read(workspaceShellProvider.notifier)
        .loadMine(keepListOnFailure: true);
    if (!_isCurrentAccount(account)) {
      throw StateError('Directory account changed');
    }
    final shell = ref.read(workspaceShellProvider);
    if (shell.error != null && shell.error!.isNotEmpty) {
      throw Exception(t.organization.directory.switchShellFailed);
    }
  }

  /// Phase 2：提交指针 + 缓存失效（镜像 OrganizationPickerPage G11 清单；
  /// 复用既有 store/provider，不建第二套）。
  ///
  /// 先失效展示缓存，最后保存指针。保存失败不发布新指针，不需要二次补偿写。
  Future<void> _commitSwitch(Organization target) async {
    final accountKey = _accountKey;
    if (!_isCurrentAccount(accountKey)) {
      throw StateError('Directory account changed');
    }
    final store = CurrentOrganizationStore.forAccount(accountKey);
    final prev = store.value;
    if (prev != null && prev.id != target.id) {
      OrganizationCache.forAccount(accountKey).invalidateOrg(prev.id);
    }
    ref.invalidate(workspaceOverviewProvider);
    ref.invalidate(workspaceChannelsProvider);
    ref.invalidate(workspaceGroupsProvider);
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(workspaceProjectsProvider);
    await store.set(target);
    if (!_isCurrentAccount(accountKey)) {
      throw StateError('Directory account changed');
    }
    unawaited(_landDefaultWorkspace(target));
  }

  /// 默认 WS 指针落位 best-effort（指向事实；失败不阻塞切换，镜像 picker）。
  Future<void> _landDefaultWorkspace(Organization org) async {
    if (!mounted || _accountKey.isEmpty) return;
    await ref.read(workspaceShellProvider.notifier).selectOrganization(
      org.id,
      () async {
        final dw = await _orgApi.defaultWorkspace(org.id);
        return dw.defaultWorkspaceId;
      },
    );
  }

  // ---- 成员资料 / 发消息（复用既有企业成员详情页） ----

  void _openMemberDetail(HumanDirectoryMember m) {
    final orgId = _controller.identity?.organizationId ?? widget.orgId;
    context.push(
      '$kOrganizationHomePath/$orgId/member/${m.userId}',
      extra: <String, dynamic>{
        'member': OrganizationMember(
          organizationId: orgId,
          userId: m.userId,
          nickname: m.displayName,
          avatar: m.avatar,
        ),
        'orgName': _orgName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isRoot = _currentLevel.departmentId == null;
    final title = isRoot
        ? (_orgName.isEmpty ? t.organization.directory.title : _orgName)
        : _currentLevel.name;
    return PopScope(
      canPop: isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _upOneLevel();
      },
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                title: Semantics(
                  button: isRoot,
                  label: isRoot
                      ? t.organization.picker.switchEnterprise
                      : title,
                  child: GestureDetector(
                    onTap: isRoot ? _openOrgSwitcher : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.title,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRoot) ...[
                          AppSpacing.horizontalTiny,
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: AppColors.iosGray,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.medium,
                AppSpacing.regular,
                AppSpacing.small,
              ),
              child: CupertinoSearchTextField(
                key: const Key('org_directory_search_input'),
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                placeholder: t.organization.directory.searchHint,
              ),
            ),
            // 「组织架构」入口行为页面级固定行（企业微信式：低频治理视图
            // 从首屏分段降级为入口行 → 二级页）。不放进列表：目录加载失败/
            // 错误态下列表整体被错误视图替换，而架构图有独立数据源，入口
            // 必须保持可达。仅企业根展示。
            if (isRoot) ...[
              _orgChartEntryRow(context),
              const Divider(
                height: 0.5,
                indent: AppSpacing.regular,
                endIndent: AppSpacing.regular,
              ),
            ],
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _buildBody(context, isRoot),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isRoot) {
    final c = _controller;
    if (c.phase == HumanDirectoryPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.phase == HumanDirectoryPhase.error) {
      return OrgStateView(
        loading: false,
        error: c.pageError,
        empty: false,
        onRetry: c.refresh,
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: c.isSearchMode
          ? _buildSearchList(context)
          : _buildDirectoryList(context, isRoot),
    );
  }

  // ---- 目录模式：上半直接子部门、下半本级成员 ----

  Widget _buildDirectoryList(BuildContext context, bool isRoot) =>
      HumanDirectoryLayout(
        ancestors: _levels
            .map(
              (level) => level.name.isEmpty
                  ? context.t.organization.directory.title
                  : level.name,
            )
            .toList(growable: false),
        onAncestor: _openLevel,
        showBackButton: widget.embedded,
        departments: _departmentWidgets(context, isRoot),
        members: _memberWidgets(context),
      );

  List<Widget> _departmentWidgets(BuildContext context, bool isRoot) {
    final t = context.t;
    final c = _controller;
    final depts = c.departments;
    return [
      // 「我的部门」捷径（/me；仅企业根展示，失败/为空即收起）。
      if (isRoot && c.myDepartments.isNotEmpty) ...[
        _sectionHeader(context, t.organization.directory.myDepartmentsSection),
        for (var i = 0; i < c.myDepartments.length; i++)
          _departmentRow(
            context,
            c.myDepartments[i],
            keySuffix: 'mine',
            isLast: i == c.myDepartments.length - 1,
          ),
        AppSpacing.verticalSmall,
      ],
      _sectionHeader(context, t.organization.directory.deptSection),
      for (var i = 0; i < depts.items.length; i++)
        _departmentRow(
          context,
          depts.items[i],
          triggerLoadMore: i == depts.items.length - 1,
          isLast: i == depts.items.length - 1,
        ),
      _sectionFooter(
        context,
        loading: depts.loading,
        error: depts.error,
        emptyText: t.organization.directory.emptyDepartments,
        onRetry: () => c.retrySection(HumanDirectorySectionKind.departments),
        // 空分区不渲染「暂无子部门」——原实现把这句顶在最后一行下面，
        // 观感像上一行的副标题（DESIGN.md 一致性/清晰度审查结论）。
        showEmptyText: false,
      ),
    ];
  }

  List<Widget> _memberWidgets(BuildContext context) {
    final t = context.t;
    final c = _controller;
    final members = c.members;
    return [
      _sectionHeader(context, t.organization.directory.currentMembersSection),
      for (var i = 0; i < members.items.length; i++)
        _memberRow(
          context,
          members.items[i],
          triggerLoadMore: i == members.items.length - 1,
          isLast: i == members.items.length - 1,
        ),
      _sectionFooter(
        context,
        loading: members.loading,
        error: members.error,
        emptyText: t.organization.directory.emptyMembers,
        onRetry: () => c.retrySection(HumanDirectorySectionKind.members),
        showEmptyText: false,
      ),
      AppSpacing.verticalSmall,
    ];
  }

  // ---- 组织架构入口行 + 二级页（企业微信式信息架构） ----

  Widget _orgChartEntryRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ImBoyListTile(
      key: const ValueKey('org-directory-chart-entry'),
      onTap: _openOrganizationChart,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.cell),
          color: AppColors.primaryAlpha10,
        ),
        child: const Icon(
          CupertinoIcons.person_3_fill,
          size: 24,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        context.t.organization.directory.structureSection,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: isDark ? AppColors.iosGray3Dark : AppColors.iosGray3,
      ),
    );
  }

  /// 打开组织架构二级页；从图中点部门时 pop 回传路径，本页下钻到该部门
  /// （保留原分段模式下 onOpenDepartment 的交互能力）。
  Future<void> _openOrganizationChart() async {
    final account = _accountKey;
    final path = await Navigator.of(context)
        .push<List<HumanDirectoryDepartment>>(
          CupertinoPageRoute<List<HumanDirectoryDepartment>>(
            builder: (_) => OrganizationChartPage(
              accountKey: account,
              organizationId:
                  _controller.identity?.organizationId ?? widget.orgId,
              organizationName: _orgName,
              source: widget.dataSource ?? _orgApi,
              onAccessDenied: _controller.rejectAccess,
            ),
          ),
        );
    if (path == null || path.isEmpty || !mounted) return;
    _clearSearch();
    setState(() {
      _levels = [
        _DirectoryLevel(name: _orgName),
        for (final department in path)
          _DirectoryLevel(departmentId: department.id, name: department.name),
      ];
    });
    _controller.setQuery('');
    _controller.openDepartment(path.last.id);
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      key: ValueKey('org-dir-section-$label'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      // footnote 13pt + 次级灰（DESIGN.md 8.3 B）；原品牌蓝是 Material 风格。
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  /// 行尾分隔线：左 16(页面 padding) + 44(leading) + 12(间距) = 72，
  /// 与文字左缘对齐（DESIGN.md 8.3 A；推导基数同 ImBoyListTile 注释）。
  Widget _rowDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(
        height: 0.5,
        color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.4),
      ),
    );
  }

  Widget _departmentRow(
    BuildContext context,
    HumanDirectoryDepartment d, {
    String keySuffix = 'list',
    bool triggerLoadMore = false,
    bool isLast = false,
  }) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (triggerLoadMore) {
      _scheduleLoadMore(_controller.loadMoreDepartments);
    }
    return Column(
      key: ValueKey('org-dir-dept-$keySuffix-${d.id}'),
      children: [
        ImBoyListTile(
          onTap: () => _openDepartment(d),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.small,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.cell),
              color: AppColors.primaryAlpha10,
            ),
            child: const Icon(
              CupertinoIcons.folder_fill,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            t.organization.directory.memberCountWith(count: d.memberCount),
          ),
          trailing: Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark ? AppColors.iosGray3Dark : AppColors.iosGray3,
          ),
        ),
        if (!isLast) _rowDivider(context),
      ],
    );
  }

  Widget _memberRow(
    BuildContext context,
    HumanDirectoryMember m, {
    bool triggerLoadMore = false,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (triggerLoadMore) {
      _scheduleLoadMore(_controller.loadMoreMembers);
    }
    return Column(
      key: ValueKey('org-dir-member-${m.userId}'),
      children: [
        ImBoyListTile(
          onTap: () => _openMemberDetail(m),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.small,
          ),
          leading: Avatar(imgUri: m.avatar, width: 44, height: 44),
          title: Text(
            m.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark ? AppColors.iosGray3Dark : AppColors.iosGray3,
          ),
        ),
        if (!isLast) _rowDivider(context),
      ],
    );
  }

  Widget _sectionFooter(
    BuildContext context, {
    required bool loading,
    required String? error,
    required String emptyText,
    required VoidCallback onRetry,
    bool showEmptyText = true,
  }) {
    final t = context.t;
    final theme = Theme.of(context);
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(t.common.buttonRetry)),
          ],
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!showEmptyText) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Text(emptyText, style: theme.textTheme.bodySmall),
    );
  }

  // ---- 搜索模式：混排结果独立于目录分页（§14.3 不合并） ----

  Widget _buildSearchList(BuildContext context) {
    final t = context.t;
    final c = _controller;
    final s = c.search;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      children: [
        for (var i = 0; i < s.items.length; i++)
          _searchRow(
            context,
            s.items[i],
            triggerLoadMore: i == s.items.length - 1,
            isLast: i == s.items.length - 1,
          ),
        _sectionFooter(
          context,
          loading: s.loading,
          error: s.error,
          emptyText: t.organization.directory.emptySearch,
          onRetry: () => c.retrySection(HumanDirectorySectionKind.search),
        ),
      ],
    );
  }

  Widget _searchRow(
    BuildContext context,
    HumanDirectorySearchItem item, {
    bool triggerLoadMore = false,
    bool isLast = false,
  }) {
    if (triggerLoadMore) {
      _scheduleLoadMore(_controller.loadMoreSearch);
    }
    if (item.isDepartment && item.department != null) {
      return _departmentRow(context, item.department!, isLast: isLast);
    }
    if (item.isMember && item.member != null) {
      return _memberRow(context, item.member!, isLast: isLast);
    }
    // 未知 type：原样保留展示，不臆造语义（ORG-A13）。纯文本占位行，
    // 不用 ListTile（DESIGN.md 13.2 禁 Material 风格 cell）。
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Text(
        item.type,
        style: context.textStyle(FontSizeType.normal, color: AppColors.iosGray),
      ),
    );
  }

  /// 末行构建时调度分页追加（build 期不直接改状态）。
  void _scheduleLoadMore(Future<void> Function() loadMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadMore();
    });
  }
}

/// 组织架构全屏二级页（企业微信式：从通讯录入口行进入）。
///
/// 顶栏走 [IosPageTemplate]（毛玻璃 + 0.33pt 分隔线 + 17pt w600 标题，
/// DESIGN.md 8.1），与全 App 导航栏形态一致。
/// 图中点部门 → pop 回传部门路径，由 [HumanDirectoryBrowserPage] 下钻。
class OrganizationChartPage extends StatelessWidget {
  const OrganizationChartPage({
    super.key,
    required this.accountKey,
    required this.organizationId,
    required this.organizationName,
    required this.source,
    this.onAccessDenied,
  });

  final String accountKey;
  final EntityId organizationId;
  final String organizationName;
  final HumanDirectoryDataSource source;
  final ValueChanged<OrganizationApiException>? onAccessDenied;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return IosPageTemplate(
      title: t.organization.directory.structureSection,
      body: OrganizationChart(
        key: ValueKey('organization-chart-$accountKey-$organizationId'),
        accountKey: accountKey,
        organizationId: organizationId,
        organizationName: organizationName,
        source: source,
        onAccessDenied: onAccessDenied,
        onOpenDepartment: (path) => Navigator.of(context).pop(path),
      ),
    );
  }
}
