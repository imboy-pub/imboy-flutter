/// WP6 (T10a/T10b) — Project / Task 视图数据 Provider 族（autoDispose + watch）
///
/// 用法契约与 WP5 `workspace_data_providers.dart` 一致：页面必须
/// `ref.watch(provider(arg))` 消费——autoDispose family 只 read 不 listen
/// 会在间隙被销毁丢数据。写操作后 `ref.invalidate(...)` 刷新。
///
/// W0（Gate W Scope Contract）：只有 Project 基本 CRUD 与 Task 四态；
/// Pinned / Resources / Activity / 关联 Channel / Project Members 全部
/// defer，此处不提供对应 provider，页面亦无占位 UI。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;

/// ProjectApi 依赖注入（测试经 ProviderScope.overrides 注入 mock）。
final projectApiProvider = Provider<ProjectApi>((ref) => ProjectApi());

/// 单页项目列表（page 维度 family；列表页聚合已加载页实现分页/下拉刷新）。
///
/// arg 用 record `(workspaceId, page)`：页数据彼此独立缓存，refresh 时
/// 对每个已加载 page 调 invalidate 即可。
typedef ProjectPageArg = (EntityId, int);

final projectListPageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<ProjectModel>, ProjectPageArg>((ref, arg) {
      final (wsId, page) = arg;
      return ref.watch(projectApiProvider).list(wsId, page: page);
    });

/// 项目详情。
final projectDetailProvider = FutureProvider.autoDispose
    .family<ProjectModel, EntityId>((ref, projectId) {
      return ref.watch(projectApiProvider).detail(projectId);
    });

/// 项目任务全量（四态一次拉取；UI 本地分组/筛选，轻量非看板）。
final projectTasksProvider = FutureProvider.autoDispose
    .family<List<ProjectTaskModel>, EntityId>((ref, projectId) {
      return ref.watch(projectApiProvider).tasks(projectId);
    });

/// 任务详情（编辑表单按 taskId 进入时加载既有行）。
final projectTaskDetailProvider = FutureProvider.autoDispose
    .family<ProjectTaskModel, EntityId>((ref, taskId) {
      return ref.watch(projectApiProvider).taskDetail(taskId);
    });

/// assignee 候选 = active Workspace Member（W0 硬约束）。
///
/// 数据源为 GET /api/v1/workspaces/:id/members（WP5 同一端点；服务端只返回
/// active 关系，非工作区成员天然不在候选）。成员变化后刷新候选 = invalidate
/// 本 provider。不改 WP5 既有函数签名，只新增本 family。
final assigneeCandidatesProvider = FutureProvider.autoDispose
    .family<List<WorkspaceMemberModel>, EntityId>((ref, wsId) async {
      final page = await ref
          .watch(workspaceApiProvider)
          .members(wsId, size: 50);
      return page.list;
    });
