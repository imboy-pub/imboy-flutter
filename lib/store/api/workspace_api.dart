/// WP5 (T9) — Workspace API 客户端（双体验 v2.5.2）
///
/// 契约源：imboy `src/api/workspace_handler.erl`（全部 JWT 保护；TSID
/// integer 传输）。错误语义透传：失败统一抛 [WorkspaceApiException]，
/// `code` 携带服务端 envelope code（403 越权 / 404 不存在 / 409 成员冲突 /
/// 980 workspace 已归档），页面据此区分 UI（409 冲突清单、980 归档提示）。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// Workspace API 失败（透传服务端 envelope code 与消息）。
class WorkspaceApiException implements Exception {
  final int code;
  final String message;

  const WorkspaceApiException(this.code, this.message);

  /// 归档写守卫（T7 workspace_guard 稳定错误码）。
  bool get isArchived => code == 980;

  /// 成员移除冲突（未完成任务 / 项目 Owner 清单由服务端拼进消息）。
  bool get isConflict => code == 409;

  @override
  String toString() => 'WorkspaceApiException($code): $message';
}

/// 工作区 API 客户端。
///
/// 镜像 [ChannelApi] / [GroupMemberApi] 的 HttpClient 模式；与二者不同的
/// 是：本模块所有方法在失败时抛异常而非静默返回空值——Workspace 页面
/// 均设计了独立错误态（Day-1 Bar），静默空值会把失败伪装成"没有数据"。
class WorkspaceApi extends HttpClient {
  // ==================== Workspace 生命周期 ====================

  /// 创建工作区（Template 原子初始化；request_id 幂等）。
  Future<WorkspaceCreateResult> create({
    required String name,
    required String requestId,
  }) async {
    final resp = await post(
      '/api/v1/workspaces',
      data: {'name': name, 'request_id': requestId},
    );
    return _unwrap(
      resp,
      (json) => WorkspaceCreateResult.fromJson(json),
      fallback: const WorkspaceCreateResult(
        workspace: WorkspaceModel(id: '', name: '', ownerId: ''),
        channelId: '',
        groupId: '',
        status: 'created',
      ),
    );
  }

  /// 我的工作区列表（分页；稳定排序 created_at DESC,id DESC）。
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async {
    final resp = await get(
      '/api/v1/workspaces/mine',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, WorkspaceModel.fromJson),
      fallback: const WorkspacePageResult<WorkspaceModel>(),
    );
  }

  /// 工作区详情（active 工作区成员可读）。
  Future<WorkspaceModel> detail(EntityId workspaceId) async {
    final resp = await get('/api/v1/workspaces/$workspaceId');
    return _unwrap(
      resp,
      WorkspaceModel.fromJson,
      fallback: const WorkspaceModel(id: '', name: '', ownerId: ''),
    );
  }

  /// 改名 / 改 logo（仅 Owner；archived 980）。
  Future<WorkspaceModel> updateProfile(
    EntityId workspaceId, {
    String? name,
    String? logo,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (logo != null) data['logo'] = logo;
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/update',
      data: data,
    );
    return _unwrap(
      resp,
      WorkspaceModel.fromJson,
      fallback: const WorkspaceModel(id: '', name: '', ownerId: ''),
    );
  }

  /// 归档工作区（T7；仅 Owner）。
  Future<void> archive(EntityId workspaceId) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/archive',
      data: <String, dynamic>{},
    );
    _ensureOk(resp);
  }

  /// 恢复工作区（T7；仅 Owner）。
  Future<void> restore(EntityId workspaceId) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/restore',
      data: <String, dynamic>{},
    );
    _ensureOk(resp);
  }

  // ==================== Branding（T12） ====================

  /// Branding 读（白名单 name/logo/primaryColor）。
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async {
    final resp = await get('/api/v1/workspaces/$workspaceId/branding');
    return _unwrap(
      resp,
      WorkspaceBranding.fromJson,
      fallback: const WorkspaceBranding(),
    );
  }

  /// Branding 写（仅 Owner；白名单外键由服务端静默丢弃）。
  Future<WorkspaceBranding> updateBranding(
    EntityId workspaceId,
    WorkspaceBranding branding,
  ) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/branding',
      data: branding.toJson(),
    );
    return _unwrap(resp, WorkspaceBranding.fromJson, fallback: branding);
  }

  // ==================== Overview / 资源清单 ====================

  /// Overview：资源摘要 + 工作区成员预览（后端有什么就展示什么）。
  Future<WorkspaceOverview> overview(EntityId workspaceId) async {
    final resp = await get('/api/v1/workspaces/$workspaceId/overview');
    return _unwrap(
      resp,
      WorkspaceOverview.fromJson,
      fallback: const WorkspaceOverview(),
    );
  }

  /// 工作区频道列表（scope=workspace 严格分区；active 成员可读）。
  Future<List<ChannelModel>> channels(EntityId workspaceId) async {
    final resp = await get('/api/v1/workspaces/$workspaceId/channels');
    return _unwrapList(resp, ChannelModel.fromJson);
  }

  /// 工作区群列表（scope=workspace 严格分区；active 成员可读）。
  Future<List<GroupModel>> groups(EntityId workspaceId) async {
    final resp = await get('/api/v1/workspaces/$workspaceId/groups');
    return _unwrapList(resp, GroupModel.fromJson);
  }

  // ==================== 工作区成员（Workspace Member） ====================

  /// 工作区成员分页列表（active 成员可读）。
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    final resp = await get(
      '/api/v1/workspaces/$workspaceId/members',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) =>
          WorkspacePageResult.fromJson(json, WorkspaceMemberModel.fromJson),
      fallback: const WorkspacePageResult<WorkspaceMemberModel>(),
    );
  }

  /// 邀请工作区成员（仅 Owner；仅已注册用户；幂等；不自动入群/订阅）。
  ///
  /// 返回 `status`: changed | unchanged（幂等命中）。
  Future<String> invite({
    required EntityId workspaceId,
    required EntityId userId,
    required WorkspaceMemberRole role,
  }) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/members/invite',
      data: {'user_id': userId, 'role': role.wireName},
    );
    final payload = _ensureOk(resp);
    return payload['status']?.toString() ?? '';
  }

  /// 移除工作区成员（仅 Owner）。
  ///
  /// 冲突（仍是项目 Owner / 有未完成任务）时服务端返回 409，消息内含
  /// 冲突清单文本——以 [WorkspaceApiException.message] 原样透出。
  Future<void> removeMember({
    required EntityId workspaceId,
    required EntityId userId,
  }) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/members/remove',
      data: {'user_id': userId},
    );
    _ensureOk(resp);
  }

  /// 改角色（仅 Owner；最后 Owner 保护）。
  Future<void> changeRole({
    required EntityId workspaceId,
    required EntityId userId,
    required WorkspaceMemberRole role,
  }) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/members/role',
      data: {'user_id': userId, 'role': role.wireName},
    );
    _ensureOk(resp);
  }

  /// 主 Owner 转移（仅 Owner；目标须为非 Guest active 成员）。
  Future<void> transferOwner({
    required EntityId workspaceId,
    required EntityId userId,
  }) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/members/transfer_owner',
      data: {'user_id': userId},
    );
    _ensureOk(resp);
  }

  // ==================== 内部：envelope 解包 ====================

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

  List<T> _unwrapList<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _ensureOk(resp);
    return IMBoyHttpResponse.payloadList(
      resp.payload,
    ).map(fromJson).toList(growable: false);
  }
}
