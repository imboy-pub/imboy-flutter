/// T9 (WP5) — Workspace 视图数据 Provider 族（autoDispose.family + watch）
///
/// 用法契约（Riverpod 已知坑规避）：页面必须 `ref.watch(provider(wsId))`
/// 消费——autoDispose family 只 read 不 listen 会在间隙被销毁丢数据。
/// 页面自身持有监听即保活；写操作后 `ref.invalidate(provider(wsId))` 刷新。
///
/// members/channels/groups/overview 全部走后端 W0 契约（workspace_handler）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// WorkspaceApi 依赖注入（测试经 ProviderScope.overrides 注入 mock）。
final workspaceApiProvider = Provider<WorkspaceApi>((ref) => WorkspaceApi());

/// Overview（资源摘要 + 成员预览）。
final workspaceOverviewProvider = FutureProvider.autoDispose
    .family<WorkspaceOverview, EntityId>((ref, wsId) {
      return ref.watch(workspaceApiProvider).overview(wsId);
    });

/// 工作区频道列表（scope=workspace）。
final workspaceChannelsProvider = FutureProvider.autoDispose
    .family<List<ChannelModel>, EntityId>((ref, wsId) {
      return ref.watch(workspaceApiProvider).channels(wsId);
    });

/// 工作区群列表（scope=workspace）。
final workspaceGroupsProvider = FutureProvider.autoDispose
    .family<List<GroupModel>, EntityId>((ref, wsId) {
      return ref.watch(workspaceApiProvider).groups(wsId);
    });

/// 工作区成员分页列表（第一页，size 50；成员管理页当前规模足够）。
final workspaceMembersProvider = FutureProvider.autoDispose
    .family<WorkspacePageResult<WorkspaceMemberModel>, EntityId>((ref, wsId) {
      return ref.watch(workspaceApiProvider).members(wsId, size: 50);
    });

/// Project 列表条目（W0 最小字段；Project 详情/任务 UI 属 WP6，此处仅
/// 为 Projects 导航提供真实列表 + 空态数据源）。
class WorkspaceProjectItem {
  final EntityId id;
  final String name;
  final String description;
  final String status;

  const WorkspaceProjectItem({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'active',
  });

  factory WorkspaceProjectItem.fromJson(Map<String, dynamic> json) {
    return WorkspaceProjectItem(
      id: entityIdOf(json['id']),
      name: parseProjectString(json['name']),
      description: parseProjectString(json['description']),
      status: parseProjectString(json['status'], defaultValue: 'active'),
    );
  }
}

String parseProjectString(dynamic raw, {String defaultValue = ''}) {
  if (raw == null) return defaultValue;
  final s = raw.toString();
  return s.isEmpty ? defaultValue : s;
}

/// Project 列表（GET /api/v1/workspaces/:id/projects；W0 无成员/聚合端点）。
final workspaceProjectsProvider = FutureProvider.autoDispose
    .family<List<WorkspaceProjectItem>, EntityId>((ref, wsId) async {
      final api = ref.watch(workspaceApiProvider);
      final resp = await api.get(
        '/api/v1/workspaces/$wsId/projects',
        queryParameters: {'page': 1, 'size': 50},
      );
      if (!resp.ok) {
        throw WorkspaceApiException(resp.code, resp.msg);
      }
      final list = (resp.payload is Map<String, dynamic>)
          ? ((resp.payload as Map<String, dynamic>)['list'] as List?)
          : null;
      if (list == null) return const <WorkspaceProjectItem>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(WorkspaceProjectItem.fromJson)
          .toList(growable: false);
    });
