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
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';

/// Workspace 壳状态。
class WorkspaceShellState {
  final List<WorkspaceModel> workspaces;
  final EntityId currentWorkspaceId;
  final WorkspaceShellDestination destination;
  final bool isLoading;
  final String? error;

  const WorkspaceShellState({
    this.workspaces = const [],
    this.currentWorkspaceId = '',
    this.destination = WorkspaceShellDestination.overview,
    this.isLoading = false,
    this.error,
  });

  /// 当前工作区（无效 id / 未加载 → null）。
  WorkspaceModel? get current {
    for (final ws in workspaces) {
      if (ws.id == currentWorkspaceId) return ws;
    }
    return null;
  }

  bool get hasWorkspace => workspaces.isNotEmpty;

  WorkspaceShellState copyWith({
    List<WorkspaceModel>? workspaces,
    String? currentWorkspaceId,
    bool clearCurrent = false,
    WorkspaceShellDestination? destination,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WorkspaceShellState(
      workspaces: workspaces ?? this.workspaces,
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
  @override
  WorkspaceShellState build() => const WorkspaceShellState();

  /// 拉取「我的工作区」并校正当前选中项。
  ///
  /// - 首次加载 / 当前项不在列表 → 自动选第一个（最新创建）
  /// - 失败：保留既有列表（可能是重试），置 error 供壳展示错误态
  Future<void> loadMine() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref.read(workspaceApiProvider).mine();
      var currentId = state.currentWorkspaceId;
      final exists = page.list.any((ws) => ws.id == currentId);
      if (!exists) {
        currentId = page.list.isEmpty ? '' : page.list.first.id;
      }
      state = state.copyWith(
        workspaces: page.list,
        currentWorkspaceId: currentId,
        isLoading: false,
      );
      // mine 列表接口不含 branding（服务端 page_by_member 只 SELECT
      // id/name/logo/owner_id/status/created_at）：为当前工作区补拉一次。
      // 必须在返回前完成：并发 loadMine 的列表回写会覆盖 fire-and-forget
      // 补拉的结果（冷启动壳主题曾因此回落默认蓝）。
      await ensureCurrentBranding();
    } on WorkspaceApiException catch (e) {
      iPrint('[WorkspaceShell] loadMine failed: $e');
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      iPrint('[WorkspaceShell] loadMine error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 切换当前工作区（Overview 重新开始；Brand 主题随之切换，T12）。
  void selectWorkspace(EntityId workspaceId) {
    if (workspaceId.isEmpty || workspaceId == state.currentWorkspaceId) return;
    state = state.copyWith(
      currentWorkspaceId: workspaceId,
      destination: WorkspaceShellDestination.overview,
    );
    // mine 列表行不带 branding：切换后为新当前工作区补拉（T12 主题切换）
    unawaited(ensureCurrentBranding());
  }

  /// 补拉当前工作区 branding 并轻量同步该行（壳主题 T12 作用域随参数重建）。
  ///
  /// - 已配置 primaryColor 的行不重拉（编辑页保存路径已本地回填）
  /// - 异步期间切走工作区：只同步仍是当前的那一行，不覆盖新当前
  Future<void> ensureCurrentBranding() async {
    final ws = state.current;
    if (ws == null || ws.branding.primaryColor.isNotEmpty) return;
    try {
      final branding = await ref.read(workspaceApiProvider).readBranding(ws.id);
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

  /// 创建成功后回填（Template 原子结果：workspace + channel + group）。
  void applyCreated(WorkspaceCreateResult result) {
    _prependAndSelect(result.workspace);
  }

  /// 团队码加入成功后回填（joined / unchanged 均走此路径）。
  ///
  /// 与 [applyCreated] 同构（去重语义一致）：新加入置顶 + 切当前 +
  /// 回 Overview；已在列表中的工作区 id 不重复插入（置顶去重）。
  void applyJoined(WorkspaceModel ws) {
    _prependAndSelect(ws);
  }

  /// 置顶 + 设当前 + destination=overview（创建/加入共用回填）。
  void _prependAndSelect(WorkspaceModel ws) {
    if (ws.id.isEmpty) return;
    // 最新加入置顶（服务端列表按 created_at DESC，回填顺序与之一致）
    final list = [ws, ...state.workspaces.where((item) => item.id != ws.id)];
    state = state.copyWith(
      workspaces: list,
      currentWorkspaceId: ws.id,
      destination: WorkspaceShellDestination.overview,
    );
  }

  /// 本地替换工作区行（branding/归档状态等变更后的轻量同步）。
  void replaceWorkspace(WorkspaceModel ws) {
    if (ws.id.isEmpty) return;
    state = state.copyWith(
      workspaces: [
        for (final item in state.workspaces) item.id == ws.id ? ws : item,
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
