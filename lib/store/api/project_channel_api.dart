/// W2 (ZC-04/ZC-06) — 项目↔频道关联 + 四类聚合 API 客户端
///
/// 契约源：imboy `project_channel_handler.erl`：
/// - link：body {channel_id}；幂等 `{status_flag: created|existing}`；
/// - unlink：`{status_flag: unlinked}`（缺失关联 404）；
/// - channels 列表：分页 envelope `{list:[{channel_id, workspace_id,
///   linked_at, name, avatar, channel_status}], page, size, total,
///   total_page}`；
/// - links/update：全量替换 `{links:[{name,url}]}` → `{links: Saved}`；
/// - pinned / activity：分页 envelope（activity 行 payload 已清洗正文键）；
/// - resources / related_posts：**数组直出**（无 envelope），客户端包装成
///   单页 [WorkspacePageResult] 统一渲染。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, WorkspacePageResult;

/// 项目频道关联 + 聚合 API。
class ProjectChannelApi extends HttpClient {
  // ==================== 关联管理 ====================

  /// 关联频道列表（分页；active 成员/guest 可读）。
  Future<WorkspacePageResult<ProjectChannelModel>> list(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/channels',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) =>
          WorkspacePageResult.fromJson(json, ProjectChannelModel.fromJson),
      fallback: const WorkspacePageResult<ProjectChannelModel>(),
    );
  }

  /// 关联频道（Owner/active Member 非 guest；幂等 created|existing）。
  Future<String> link({
    required EntityId projectId,
    required EntityId channelId,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/channels',
      data: {'channel_id': channelId},
    );
    final payload = _ensureOk(resp);
    return payload['status_flag']?.toString() ?? 'created';
  }

  /// 解除关联（缺失关联 404 透传）。
  Future<void> unlink({
    required EntityId projectId,
    required EntityId channelId,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/channels/$channelId/unlink',
      data: <String, dynamic>{},
    );
    _ensureOk(resp);
  }

  /// 全量替换 project.links（应用层校验 400 透传）。
  Future<List<ProjectLinkModel>> updateLinks({
    required EntityId projectId,
    required List<ProjectLinkModel> links,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/links/update',
      data: {
        'links': [for (final l in links) l.toJson()],
      },
    );
    final payload = _ensureOk(resp);
    final raw = payload['links'];
    if (raw is! List) return const <ProjectLinkModel>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProjectLinkModel.fromJson)
        .toList(growable: false);
  }

  // ==================== 四类聚合（只读） ====================

  /// Pinned 聚合：关联频道置顶消息元数据（排除公告形态；分页）。
  Future<WorkspacePageResult<AggPostModel>> pinned(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/aggregations/pinned',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, AggPostModel.fromJson),
      fallback: const WorkspacePageResult<AggPostModel>(),
    );
  }

  /// Resources 聚合：project.links 原样返回（数组直出，包装为单页）。
  Future<WorkspacePageResult<ProjectLinkModel>> resources(
    EntityId projectId,
  ) async {
    final resp = await get(
      '/api/v1/projects/$projectId/aggregations/resources',
    );
    _ensureOk(resp);
    return _pageFromList(_payloadList(resp), ProjectLinkModel.fromJson);
  }

  /// Activity 聚合：project_event 元数据流（分页；payload 已清洗）。
  Future<WorkspacePageResult<ActivityEventModel>> activity(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/aggregations/activity',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, ActivityEventModel.fromJson),
      fallback: const WorkspacePageResult<ActivityEventModel>(),
    );
  }

  /// Related Posts 聚合：关联频道最近帖子有界摘要（数组直出，包装为单页）。
  Future<WorkspacePageResult<AggPostModel>> relatedPosts(
    EntityId projectId,
  ) async {
    final resp = await get(
      '/api/v1/projects/$projectId/aggregations/related_posts',
    );
    _ensureOk(resp);
    return _pageFromList(_payloadList(resp), AggPostModel.fromJson);
  }

  // ==================== 内部 ====================

  List<Map<String, dynamic>> _payloadList(IMBoyHttpResponse resp) {
    final raw = resp.payload;
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return IMBoyHttpResponse.payloadList(resp.payload);
  }

  WorkspacePageResult<T> _pageFromList<T>(
    List<Map<String, dynamic>> rows,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = rows.map(fromJson).toList(growable: false);
    return WorkspacePageResult<T>(
      list: items,
      total: items.length,
      totalPage: 1,
    );
  }

  Map<String, dynamic> _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw WorkspaceApiException(resp.code, resp.msg);
    }
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  T _unwrap<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson, {
    required T fallback,
  }) {
    final payload = _ensureOk(resp);
    if (payload.isEmpty) return fallback;
    return fromJson(payload);
  }
}
