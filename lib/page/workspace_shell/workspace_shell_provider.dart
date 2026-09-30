/// T8 (WP5) — Workspace 壳状态 Provider（手写 Notifier，不用 @riverpod 代码生成）
///
/// 镜像 `new_friend_provider.dart` / `people_nearby_provider.dart` 的手写
/// `Notifier` 模式（本计划不引入新 .g.dart，避免 build_runner 哈希噪音）。
///
/// Riverpod 已知坑规避（计划 T9 GOTCHA）：autoDispose provider 只 read 不
/// listen 会丢数据——本 provider 是壳级常驻状态（非 autoDispose），页面
/// 数据族（overview/channels/groups/members）在 `workspace_data_providers`
/// 中以 autoDispose.family + 页面 ref.watch 的组合使用，绝不只 read。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart'
    show organizationApiProvider;
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';

/// Workspace 壳状态。
class WorkspaceShellState {
  final List<WorkspaceModel> _workspaces;
  final EntityId organizationId;
  final EntityId currentWorkspaceId;
  final WorkspaceShellDestination destination;
  final bool isLoading;
  final String? error;

  const WorkspaceShellState({
    List<WorkspaceModel> workspaces = const [],
    this.organizationId = '',
    this.currentWorkspaceId = '',
    this.destination = WorkspaceShellDestination.overview,
    this.isLoading = false,
    this.error,
    // 保留公开命名参数 workspaces；全集仅在状态内部维护。
    // ignore: prefer_initializing_formals
  }) : _workspaces = workspaces;

  /// 当前工作区（无效 id / 未加载 → null）。
  WorkspaceModel? get current {
    for (final ws in workspaces) {
      if (ws.id == currentWorkspaceId) return ws;
    }
    return null;
  }

  /// mine 保留已加入的全集；企业壳只能选择当前企业内的工作区。
  List<WorkspaceModel> get workspaces => organizationId.isEmpty
      ? _workspaces
      : _workspaces.where((ws) => ws.belongsToOrg(organizationId)).toList();

  bool get hasWorkspace => workspaces.isNotEmpty;

  WorkspaceShellState copyWith({
    List<WorkspaceModel>? workspaces,
    EntityId? organizationId,
    String? currentWorkspaceId,
    bool clearCurrent = false,
    WorkspaceShellDestination? destination,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WorkspaceShellState(
      workspaces: workspaces ?? _workspaces,
      organizationId: organizationId ?? this.organizationId,
      currentWorkspaceId: clearCurrent
          ? ''
          : (currentWorkspaceId ?? this.currentWorkspaceId),
      destination: destination ?? this.destination,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error,
    );
  }
}

/// 壳级导航/当前工作区 Notifier（常驻，随 App 生命周期）。
class WorkspaceShellNotifier extends Notifier<WorkspaceShellState> {
  int _selectionGeneration = 0;
  int _loadGeneration = 0;

  @override
  WorkspaceShellState build() {
    final uid = ref.watch(
      currentUserProvider.select((user) => user?.uid ?? ''),
    );
    _selectionGeneration++;
    _loadGeneration++;
    final org = uid.isEmpty
        ? null
        : CurrentOrganizationStore.forAccount(uid).value;
    return WorkspaceShellState(organizationId: org?.id ?? '');
  }

  /// 冷启动恢复企业默认工作区；重进壳时保留仍有效的手动选择。
  Future<void> initialize() async {
    final accountId = ref.read(currentUserProvider)?.uid ?? '';
    final selection = _selectionGeneration;
    final needsDefault = state.current == null;
    await loadMine();
    if (!_isCurrentAccount(accountId) ||
        selection != _selectionGeneration ||
        !needsDefault ||
        state.error != null ||
        state.organizationId.isEmpty) {
      return;
    }
    final orgId = state.organizationId;
    await selectOrganization(orgId, () async {
      final pointer = await ref
          .read(organizationApiProvider)
          .defaultWorkspace(orgId);
      return pointer.defaultWorkspaceId;
    });
  }

  /// 拉取「我的工作区」并校正当前选中项。
  ///
  /// - 首次加载 / 当前项不在列表 → 自动选当前企业内第一个（最新创建）
  /// - 失败：[keepListOnFailure]（默认 true）保留既有列表并置 error 供壳展示
  ///   错误态——这是普通重试的语义。
  /// - 企业指针提交前的预载可保留旧状态；指针提交后的强制清缓存可传
  ///   false。提交企业时另由 selectOrganization 同步收敛可见列表和当前项。
  Future<void> loadMine({bool keepListOnFailure = true}) async {
    final accountId = ref.read(currentUserProvider)?.uid ?? '';
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final workspaces = await _readMine(generation, accountId);
      if (workspaces == null) return;
      var currentId = state.currentWorkspaceId;
      final available = state.copyWith(workspaces: workspaces).workspaces;
      final exists = available.any((ws) => ws.id == currentId);
      if (!exists) {
        currentId = available.isEmpty ? '' : available.first.id;
      }
      state = state.copyWith(
        workspaces: workspaces,
        currentWorkspaceId: currentId,
        isLoading: false,
      );
      // mine 列表接口不含 branding（服务端 page_by_member 只 SELECT
      // id/name/logo/owner_id/status/created_at）：为当前工作区补拉一次。
      // 必须在返回前完成：并发 loadMine 的列表回写会覆盖 fire-and-forget
      // 补拉的结果（冷启动壳主题曾因此回落默认蓝）。
      await ensureCurrentBranding();
    } on WorkspaceApiException catch (e) {
      if (!_isCurrentAccount(accountId) || generation != _loadGeneration) {
        return;
      }
      iPrint('[WorkspaceShell] loadMine failed: $e');
      state = _onLoadFailure(e.message, keepListOnFailure);
    } catch (e) {
      if (!_isCurrentAccount(accountId) || generation != _loadGeneration) {
        return;
      }
      iPrint('[WorkspaceShell] loadMine error: $e');
      state = _onLoadFailure(e.toString(), keepListOnFailure);
    }
  }

  bool _isCurrentAccount(EntityId uid) =>
      ref.mounted && (ref.read(currentUserProvider)?.uid ?? '') == uid;

  Future<List<WorkspaceModel>?> _readMine(
    int generation,
    EntityId accountId,
  ) async {
    final workspaces = <EntityId, WorkspaceModel>{};
    var totalPages = 1;
    for (var page = 1; page <= totalPages; page++) {
      final result = await ref
          .read(workspaceApiProvider)
          .mine(page: page, size: 100);
      if (!_isCurrentAccount(accountId) || generation != _loadGeneration) {
        return null;
      }
      if (page == 1) totalPages = result.totalPage;
      for (final workspace in result.list) {
        workspaces[workspace.id] = workspace;
      }
    }
    return workspaces.values.toList(growable: false);
  }

  /// 失败态收敛：保留（普通重试）或清空（企业切换，杜绝跨企业残留）。
  WorkspaceShellState _onLoadFailure(String message, bool keepList) {
    if (keepList) {
      return state.copyWith(isLoading: false, error: message);
    }
    return state.copyWith(
      workspaces: const <WorkspaceModel>[],
      clearCurrent: true,
      isLoading: false,
      error: message,
    );
  }

  /// 切换当前工作区（Overview 重新开始；Brand 主题随之切换，T12）。
  void selectWorkspace(EntityId workspaceId) {
    if (workspaceId.isEmpty ||
        !state.workspaces.any((ws) => ws.id == workspaceId)) {
      return;
    }
    _selectionGeneration++;
    if (workspaceId == state.currentWorkspaceId) return;
    state = state.copyWith(
      currentWorkspaceId: workspaceId,
      destination: WorkspaceShellDestination.overview,
    );
    // mine 列表行不带 branding：切换后为新当前工作区补拉（T12 主题切换）
    unawaited(ensureCurrentBranding());
  }

  /// 提交企业指针后调用：立即在目标企业落位，默认指针只用于进一步选择。
  /// 默认读取失败/未配置/未加入时保留同企业回退项，绝不残留上一企业。
  Future<void> selectOrganization(
    EntityId organizationId,
    Future<EntityId> Function() readDefaultWorkspace,
  ) async {
    final accountId = ref.read(currentUserProvider)?.uid ?? '';
    final generation = ++_selectionGeneration;
    final scoped = state.copyWith(organizationId: organizationId);
    final available = scoped.workspaces;
    state = scoped.copyWith(
      currentWorkspaceId: available.isEmpty ? '' : available.first.id,
      destination: WorkspaceShellDestination.overview,
    );
    unawaited(ensureCurrentBranding());
    try {
      final defaultId = await readDefaultWorkspace();
      if (!_isCurrentAccount(accountId) || generation != _selectionGeneration) {
        return;
      }
      selectWorkspace(defaultId);
    } on Exception catch (e) {
      // 回退项已同步选好；保留诊断，默认读取错误不阻断企业切换。
      iPrint('[WorkspaceShell] default workspace unavailable: $e');
    }
  }

  /// 补拉当前工作区 branding 并轻量同步该行（壳主题 T12 作用域随参数重建）。
  ///
  /// - 已配置 primaryColor 的行不重拉（编辑页保存路径已本地回填）
  /// - 异步期间切走工作区：只同步仍是当前的那一行，不覆盖新当前
  Future<void> ensureCurrentBranding() async {
    final accountId = ref.read(currentUserProvider)?.uid ?? '';
    final ws = state.current;
    if (ws == null || ws.branding.primaryColor.isNotEmpty) return;
    try {
      final branding = await ref.read(workspaceApiProvider).readBranding(ws.id);
      if (!_isCurrentAccount(accountId)) return;
      final cur = state.current;
      if (cur == null || cur.id != ws.id) return;
      replaceWorkspace(cur.mergeBranding(branding));
    } catch (e) {
      iPrint('[WorkspaceShell] ensureCurrentBranding failed: $e');
    }
  }

  /// 切换导航目的地（§4.2 五项之一）。
  void selectDestination(WorkspaceShellDestination destination) {
    if (destination == state.destination) return;
    state = state.copyWith(destination: destination);
  }

  /// 创建成功后回填（Template 原子结果）；仅同企业工作区自动选中。
  void applyCreated(WorkspaceCreateResult result) {
    _prependAndSelect(result.workspace);
  }

  /// 团队码加入成功后回填（joined / unchanged 均走此路径）。
  ///
  /// 与 [applyCreated] 同构：新加入置顶，同企业才切当前 +
  /// 回 Overview；已在列表中的工作区 id 不重复插入（置顶去重）。
  void applyJoined(WorkspaceModel ws) {
    _prependAndSelect(ws);
  }

  /// 置顶 + 设当前 + destination=overview（创建/加入共用回填）。
  void _prependAndSelect(WorkspaceModel ws) {
    if (ws.id.isEmpty) return;
    // 最新加入置顶（服务端列表按 created_at DESC，回填顺序与之一致）
    final list = [ws, ...state._workspaces.where((item) => item.id != ws.id)];
    final canSelect =
        state.organizationId.isEmpty || ws.belongsToOrg(state.organizationId);
    if (canSelect) _selectionGeneration++;
    state = state.copyWith(
      workspaces: list,
      currentWorkspaceId: canSelect ? ws.id : state.currentWorkspaceId,
      destination: WorkspaceShellDestination.overview,
    );
  }

  /// 服务端退出成功后立即撤去本企业缓存，并阻止旧异步请求重新写入。
  void forgetOrganization(EntityId organizationId) {
    _selectionGeneration++;
    _loadGeneration++;
    final currentRemoved = state.current?.belongsToOrg(organizationId) ?? false;
    final selected = state.organizationId == organizationId;
    state = state.copyWith(
      workspaces: state._workspaces
          .where((ws) => !ws.belongsToOrg(organizationId))
          .toList(growable: false),
      organizationId: selected ? '' : state.organizationId,
      clearCurrent: selected || currentRemoved,
      isLoading: false,
      clearError: true,
    );
  }

  /// 本地替换工作区行（branding/归档状态等变更后的轻量同步）。
  void replaceWorkspace(WorkspaceModel ws) {
    if (ws.id.isEmpty) return;
    state = state.copyWith(
      workspaces: [
        for (final item in state._workspaces) item.id == ws.id ? ws : item,
      ],
    );
  }
}

/// 壳状态 Provider（常驻）。
final workspaceShellProvider =
    NotifierProvider<WorkspaceShellNotifier, WorkspaceShellState>(
      WorkspaceShellNotifier.new,
    );

/// 派生：当前工作区（无选中 → null）。页面用 ref.watch 消费。
final Provider<WorkspaceModel?> currentWorkspaceProvider = Provider(
  (ref) => ref.watch(workspaceShellProvider).current,
);
