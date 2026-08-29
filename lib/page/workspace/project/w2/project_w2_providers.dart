/// W2 (ZC-06) — Project Member / Milestone / Channel / 聚合 数据 Provider 族
///
/// 用法契约与 W0 `project_data_providers.dart` 一致：页面必须
/// `ref.watch(provider(arg))` 消费——autoDispose family 只 read 不 listen
/// 会在间隙被销毁丢数据。写操作后 `ref.invalidate(...)` 刷新。
///
/// 权限语义（服务端唯一真相，前端只做 UI 预判）：读 403 = 非项目成员/
/// 非工作区成员 → 页面渲染明确无权限态；Guest 只读；写 403 由 toast 透传。
/// autoDispose：离开页面即销毁，403 结果不缓存为成功态（每次进入重新校验）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/store/api/project_channel_api.dart';
import 'package:imboy/store/api/project_member_api.dart';
import 'package:imboy/store/api/project_milestone_api.dart';
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// API 依赖注入（测试经 ProviderScope.overrides 注入 mock）。
final projectMemberApiProvider = Provider<ProjectMemberApi>(
  (ref) => ProjectMemberApi(),
);

final milestoneApiProvider = Provider<MilestoneApi>((ref) => MilestoneApi());

final projectChannelApiProvider = Provider<ProjectChannelApi>(
  (ref) => ProjectChannelApi(),
);

/// 分页 family 参数：`(projectId, page)`。
typedef ProjectW2PageArg = (EntityId, int);

/// 里程碑列表 family 参数：`(projectId, status, page)`——status 筛选进入
/// 缓存键，筛选变化即 page 重置由页面 State 保证（arg 变化即换 provider）。
typedef MilestoneListArg = (EntityId, String, int);

/// 项目成员分页（page 维度独立缓存；列表页聚合已加载页实现分页）。
final projectMemberPageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<ProjectMemberModel>, ProjectW2PageArg>((
      ref,
      arg,
    ) {
      final (projectId, page) = arg;
      return ref
          .watch(projectMemberApiProvider)
          .list(projectId, page: page, size: 10);
    });

/// 里程碑分页（status: all|planned|reached）。
final projectMilestonePageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<MilestoneModel>, MilestoneListArg>((ref, arg) {
      final (projectId, status, page) = arg;
      return ref
          .watch(milestoneApiProvider)
          .list(projectId, status: status, page: page, size: 10);
    });

/// 项目关联频道分页。
final projectChannelPageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<ProjectChannelModel>, ProjectW2PageArg>((
      ref,
      arg,
    ) {
      final (projectId, page) = arg;
      return ref
          .watch(projectChannelApiProvider)
          .list(projectId, page: page, size: 10);
    });

/// Pinned 聚合分页（关联频道置顶消息元数据）。
final projectPinnedPageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<AggPostModel>, ProjectW2PageArg>((ref, arg) {
      final (projectId, page) = arg;
      return ref
          .watch(projectChannelApiProvider)
          .pinned(projectId, page: page, size: 10);
    });

/// Activity 聚合分页（project_event 元数据流）。
final projectActivityPageProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<ActivityEventModel>, ProjectW2PageArg>((
      ref,
      arg,
    ) {
      final (projectId, page) = arg;
      return ref
          .watch(projectChannelApiProvider)
          .activity(projectId, page: page, size: 10);
    });

/// Resources 聚合（project.links 全量数组直出，包装单页）。
final projectResourcesProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<ProjectLinkModel>, EntityId>((ref, projectId) {
      return ref.watch(projectChannelApiProvider).resources(projectId);
    });

/// Related Posts 聚合（有界摘要，数组直出，包装单页）。
final projectRelatedPostsProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<AggPostModel>, EntityId>((ref, projectId) {
      return ref.watch(projectChannelApiProvider).relatedPosts(projectId);
    });
