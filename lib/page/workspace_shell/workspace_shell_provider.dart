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
  }

  /// 切换导航目的地（§4.2 五项之一）。
  void selectDestination(WorkspaceShellDestination destination) {
    if (destination == state.destination) return;
    state = state.copyWith(destination: destination);
  }

  /// 创建成功后回填（Template 原子结果：workspace + channel + group）。
  void applyCreated(WorkspaceCreateResult result) {
    if (result.workspace.id.isEmpty) return;
    // 最新创建置顶（服务端列表按 created_at DESC，回填顺序与之一致）
    final list = [
      result.workspace,
      ...state.workspaces.where((ws) => ws.id != result.workspace.id),
    ];
    state = state.copyWith(
      workspaces: list,
      currentWorkspaceId: result.workspace.id,
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
