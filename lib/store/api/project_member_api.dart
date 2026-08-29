/// W2 (ZC-02/ZC-06) — Project Member API 客户端
///
/// 契约源：imboy `project_member_handler.erl`（全部 JWT 保护；TSID integer
/// 传输）。envelope 与 workspace_api 同约定：失败抛 [WorkspaceApiException]
/// 透传服务端语义码——400 参数非法 / 403 非项目成员或 Guest（前端渲染明确
/// 无权限态）/ 404 / 409 Owner 移除冲突 / 980 工作区已归档。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, WorkspacePageResult;

/// 项目成员 API（invite/remove 幂等 status_flag 透传给 UI 反馈）。
class ProjectMemberApi extends HttpClient {
  /// 成员分页列表（Project Owner / Workspace Owner / active 项目成员可读）。
  Future<WorkspacePageResult<ProjectMemberModel>> list(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/members',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, ProjectMemberModel.fromJson),
      fallback: const WorkspacePageResult<ProjectMemberModel>(),
    );
  }

  /// 邀请项目成员（仅 Project Owner；幂等：重复邀请返回既有成员）。
  Future<MemberWriteResult> invite({
    required EntityId projectId,
    required EntityId userId,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/members/invite',
      data: {'user_id': userId},
    );
    final payload = _ensureOk(resp);
    return MemberWriteResult(
      member: _memberFrom(payload),
      statusFlag: _statusFlag(payload, defaultValue: 'created'),
    );
  }

  /// 移除项目成员（Project Owner 或 Workspace Owner；幂等）。
  Future<MemberWriteResult> remove({
    required EntityId projectId,
    required EntityId userId,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/members/remove',
      data: {'user_id': userId},
    );
    final payload = _ensureOk(resp);
    return MemberWriteResult(
      member: _memberFrom(payload),
      statusFlag: _statusFlag(payload, defaultValue: 'removed'),
    );
  }

  /// 项目 Owner 转移（仅 Project Owner；body 键 new_owner_uid）。
  Future<void> transferOwner({
    required EntityId projectId,
    required EntityId newOwnerUid,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/members/transfer_owner',
      data: {'new_owner_uid': newOwnerUid},
    );
    _ensureOk(resp);
  }

  // ==================== 内部 ====================

  static ProjectMemberModel _memberFrom(Map<String, dynamic> json) =>
      ProjectMemberModel.fromJson(json);

  static String _statusFlag(
    Map<String, dynamic> payload, {
    required String defaultValue,
  }) {
    final flag = payload['status_flag'];
    if (flag == null) return defaultValue;
    final s = flag.toString();
    return s.isEmpty ? defaultValue : s;
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

/// 项目成员写操作结果（行 + 幂等标记）。
class MemberWriteResult {
  final ProjectMemberModel member;

  /// invite: created | existing；remove: removed | already_removed。
  final String statusFlag;

  const MemberWriteResult({required this.member, this.statusFlag = ''});

  /// 幂等命中（重复邀请 / 重复移除）。
  bool get isIdempotentHit =>
      statusFlag == 'existing' || statusFlag == 'already_removed';

  /// 邀请幂等命中（该用户已是项目成员）。
  bool get isAlreadyMember => statusFlag == 'existing';

  /// 移除幂等命中（该用户已不在项目成员中）。
  bool get isAlreadyRemoved => statusFlag == 'already_removed';
}
