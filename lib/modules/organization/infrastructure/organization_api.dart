/// Organization API 客户端（计划 ORG-10 冻结的 v2 面 + 既有 v1 治理面）
///
/// 契约要点：
/// - 邀请只走 v2 invitation 端点（C11：`POST /organizations/:id/members`
///   是 legacy direct-add adapter，本客户端**不暴露**该方法——客户端
///   禁止用 direct-add 伪装邀请）；
/// - token 明文只在 create 响应出现一次；accept 需要目标用户持有 token；
/// - 删除预检（C17）：依赖域事实不可用 = 503 DEPENDENCY_FACTS_UNAVAILABLE，
///   失败即拒绝，客户端不做任何降级放行；
/// - 错误映射：401 未授权 / 403 无权 / 404 不存在 / 409 状态冲突 /
///   503 依赖事实不可用（[OrganizationApiException] 判定属性）。
///
/// 镜像 [EnterpriseApi] 的 HttpClient 模式：失败抛异常而非静默空值。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';

/// Organization API 失败（透传服务端 envelope code 与消息）。
class OrganizationApiException implements Exception {
  final int code;
  final String message;

  const OrganizationApiException(this.code, this.message);

  /// 401：JWT 失效 / 未授权。
  bool get isUnauthorized => code == 401;

  /// 403：非成员 / 角色不足（owner/admin 门）/ archived fail-closed。
  bool get isForbidden => code == 403;

  /// 404：目标不存在（跨 Org 资源同样 404，不做租户枚举；组织/部门等
  /// 读面对非成员会先撞 403——授权门先于存在性判定）。
  bool get isNotFound => code == 404;

  /// 409：状态冲突（已归档/幂等冲突/层级成环等）。
  bool get isConflict => code == 409;

  /// 503：删除预检依赖域事实不可用（fail-closed，C17）。
  bool get isFactsUnavailable => code == 503;

  /// 981：企业邀请码无效/已撤销（GZAPP-01 契约，与 ws 团队码同语义）。
  bool get isInviteInvalid => code == 981;

  /// 982：企业邀请码已过期（GZAPP-01 契约，与 ws 团队码同语义）。
  bool get isInviteExpired => code == 982;

  @override
  String toString() => 'OrganizationApiException($code): $message';
}

/// Organization API 客户端。
class OrganizationApi extends HttpClient {
  // ==================== 组织本体 ====================

  /// 我所在的组织（分页；suspended/removed 成员不出现在结果里）。
  Future<OrganizationPage<Organization>> mine({
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/organizations/mine',
      queryParameters: {'page': page, 'size': size},
    );
    return _page(resp, Organization.fromJson);
  }

  /// 创建组织（名称 1..200 字符）。
  Future<Organization> create({required String name}) async {
    final resp = await post('/api/v1/organizations', data: {'name': name});
    return _unwrap(resp, Organization.fromJson);
  }

  /// 组织详情（含 member_role 投影；非成员 403/不存在 404）。
  Future<Organization> detail(EntityId orgId) async {
    final resp = await get('/api/v1/organizations/$orgId');
    return _unwrap(resp, Organization.fromJson);
  }

  /// 更新名称/品牌/设置（owner/admin）。
  Future<Organization> update(
    EntityId orgId, {
    String? name,
    Map<String, dynamic>? branding,
    Map<String, dynamic>? settings,
  }) async {
    final resp = await patch(
      '/api/v1/organizations/$orgId',
      data: {'name': ?name, 'branding': ?branding, 'settings': ?settings},
    );
    return _unwrap(resp, Organization.fromJson);
  }

  /// 归档（幂等 command，C16；archived 后写面全部 fail-closed）。
  Future<Organization> archive(EntityId orgId) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/archive',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, Organization.fromJson);
  }

  /// 恢复（archived 态唯一放行的写入口）。
  Future<Organization> restore(EntityId orgId) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/restore',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, Organization.fromJson);
  }

  /// User 删除预检（C17：五依赖域 blocker 展示；503 = 事实不可用即拒）。
  Future<DeletionPreflightReport> deletionPreflight() async {
    final resp = await get('/api/v1/organizations/deletion-preflight');
    return _unwrap(resp, DeletionPreflightReport.fromJson);
  }

  // ==================== 成员（治理面） ====================

  /// 成员列表（服务端 owner/admin 门；普通成员 403 → 页面转权限态）。
  Future<OrganizationPage<OrganizationMember>> members(
    EntityId orgId, {
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$orgId/members',
      queryParameters: {'page': page, 'size': size},
    );
    return _page(resp, OrganizationMember.fromJson);
  }

  /// 成员在本企业内的**有权 Workspace**（计划 §5.2 成员详情）。
  ///
  /// 与 [members] 不同：服务端只要求调用者是本 Org 的 active 成员（任意角色），
  /// 因此普通成员也能看到成员详情里的工作区信息（§5.2「所有企业成员可见」）。
  /// 目标非本 Org 成员 → 404；调用者非本 Org 成员 → 403。
  Future<List<OrganizationMemberWorkspace>> memberWorkspaces(
    EntityId orgId,
    EntityId userId,
  ) async {
    final resp = await get(
      '/api/v1/organizations/$orgId/members/$userId/workspaces',
    );
    _ensureOk(resp);
    final payload = resp.payload;
    final raw = (payload is Map<String, dynamic>) ? payload['list'] : null;
    if (raw is! List) return const <OrganizationMemberWorkspace>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(OrganizationMemberWorkspace.fromJson)
        .where((w) => w.id.isNotEmpty)
        .toList(growable: false);
  }

  /// 改角色（仅 admin/member 可设；owner 行不可改，C04）。
  Future<OrganizationMember> changeRole(
    EntityId orgId,
    EntityId userId, {
    required String role,
  }) async {
    final resp = await put(
      '/api/v1/organizations/$orgId/members/$userId/role',
      data: {'role': role},
    );
    return _unwrapMember(resp);
  }

  /// 移除成员（owner 不可被移除；最后 owner 保护在服务端）。
  Future<void> removeMember(EntityId orgId, EntityId userId) async {
    final resp = await delete('/api/v1/organizations/$orgId/members/$userId');
    _ensureOk(resp);
  }

  /// Owner 转移（危险操作：服务端单 owner 不变量互换，C04）。
  Future<void> transferOwner(EntityId orgId, EntityId toUserId) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/members/transfer_owner',
      data: {'user_id': toUserId},
    );
    _ensureOk(resp);
  }

  // ==================== 邀请（C11 v2 面） ====================

  /// 我收到的待决邀请（target 视角）。
  Future<List<OrgInvitation>> myInvitations({
    String? status,
    int limit = 20,
  }) async {
    final resp = await get(
      '/api/v1/organizations/invitations/mine',
      queryParameters: _statusQuery(status, limit),
    );
    return _list(resp, OrgInvitation.fromJson);
  }

  /// Org 邀请管理列表（owner/admin 治理面）。
  Future<List<OrgInvitation>> orgInvitations(
    EntityId orgId, {
    String? status,
    int limit = 20,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$orgId/invitations',
      queryParameters: _statusQuery(status, limit),
    );
    return _list(resp, OrgInvitation.fromJson);
  }

  /// 创建邀请。返回视图含**一次性明文 token**（仅此一次；后续任何接口
  /// 只返回无 digest 的投影）——调用方必须立即转交目标用户。
  Future<OrgInvitation> createInvitation(
    EntityId orgId,
    EntityId targetUserId, {
    int? expiresAtEpochSeconds,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invitations',
      data: {'user_id': targetUserId, 'expires_at': ?expiresAtEpochSeconds},
    );
    return _unwrap(resp, OrgInvitation.fromJson);
  }

  /// 持 token 接受（一次性消费；重复 accept 幂等返回同一视图）。
  Future<OrgInvitation> acceptInvitation(
    EntityId orgId, {
    required String token,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invitations/accept',
      data: {'token': token},
    );
    return _unwrap(resp, OrgInvitation.fromJson);
  }

  /// 拒绝（target-only；重复 reject 幂等 already_terminal=true）。
  Future<OrgInvitation> rejectInvitation(
    EntityId orgId,
    EntityId invitationId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invitations/$invitationId/reject',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, OrgInvitation.fromJson);
  }

  /// 撤销（inviter/治理面；重复 revoke 幂等 already_terminal=true）。
  Future<OrgInvitation> revokeInvitation(
    EntityId orgId,
    EntityId invitationId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invitations/$invitationId/revoke',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, OrgInvitation.fromJson);
  }

  // ==================== 部门（ORG-04） ====================

  /// 部门列表（status 可选 all/active/archived，缺省 all）。
  Future<List<OrganizationDepartment>> departments(
    EntityId orgId, {
    String? status,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$orgId/departments',
      queryParameters: _statusQuery(status, null),
    );
    return _list(resp, OrganizationDepartment.fromJson);
  }

  /// 部门详情（含成员列表；非成员 403 且先于存在性判定；存在但跨
  /// Org/不存在 = 404）。
  Future<(OrganizationDepartment, List<DepartmentMember>)> departmentDetail(
    EntityId orgId,
    EntityId departmentId,
  ) async {
    final resp = await get(
      '/api/v1/organizations/$orgId/departments/$departmentId',
    );
    final map = _ensureOk(resp);
    final dept = OrganizationDepartment.fromJson(
      (map['department'] as Map?)?.cast<String, dynamic>() ?? map,
    );
    final members = <DepartmentMember>[];
    final raw = map['members'];
    if (raw is List) {
      for (final m in raw) {
        if (m is Map<String, dynamic>) {
          members.add(DepartmentMember.fromJson(m));
        }
      }
    }
    return (dept, members);
  }

  /// 创建部门（parentId 空 = 根部门）。
  Future<OrganizationDepartment> createDepartment(
    EntityId orgId, {
    required String name,
    EntityId parentId = '',
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/departments',
      data: {'name': name, if (parentId.isNotEmpty) 'parent_id': parentId},
    );
    return _unwrap(resp, OrganizationDepartment.fromJson);
  }

  /// 改部门名（PATCH item）。
  Future<OrganizationDepartment> renameDepartment(
    EntityId orgId,
    EntityId departmentId, {
    required String name,
  }) async {
    final resp = await patch(
      '/api/v1/organizations/$orgId/departments/$departmentId',
      data: {'name': name},
    );
    return _unwrap(resp, OrganizationDepartment.fromJson);
  }

  /// 移动部门（换父 / 提为根；键名 `parent_id`，null = 根；服务端防成环
  /// 409）。
  Future<OrganizationDepartment> moveDepartment(
    EntityId orgId,
    EntityId departmentId, {
    required EntityId newParentId,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/departments/$departmentId/move',
      data: {'parent_id': newParentId.isEmpty ? null : newParentId},
    );
    return _unwrap(resp, OrganizationDepartment.fromJson);
  }

  /// 归档部门（幂等；归档父部门下不可新建——服务端 409）。
  Future<OrganizationDepartment> archiveDepartment(
    EntityId orgId,
    EntityId departmentId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/departments/$departmentId/archive',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, OrganizationDepartment.fromJson);
  }

  /// 部门加成员（兼职；目标必须是本 Org active member，服务端触发器权威）。
  Future<DepartmentMember> addDepartmentMember(
    EntityId orgId,
    EntityId departmentId,
    EntityId userId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/departments/$departmentId/members',
      data: {'user_id': userId},
    );
    return _unwrap(resp, DepartmentMember.fromJson);
  }

  /// 移除部门成员。
  Future<void> removeDepartmentMember(
    EntityId orgId,
    EntityId departmentId,
    EntityId userId,
  ) async {
    final resp = await delete(
      '/api/v1/organizations/$orgId/departments/$departmentId/members/$userId',
    );
    _ensureOk(resp);
  }

  /// 设置/取消部门局部管理员。
  Future<void> setDepartmentAdmin(
    EntityId orgId,
    EntityId departmentId,
    EntityId userId, {
    required bool admin,
  }) async {
    final resp = await put(
      '/api/v1/organizations/$orgId/departments/$departmentId/members/$userId/admin',
      data: {'admin': admin},
    );
    _ensureOk(resp);
  }

  // ==================== 默认 Workspace 指针（C05） ====================

  /// 读默认 Workspace 指向事实（null = 未设置；**不是** membership 授权）。
  Future<DefaultWorkspaceRef> defaultWorkspace(EntityId orgId) async {
    final resp = await get('/api/v1/organizations/$orgId/default-workspace');
    return _unwrap(resp, DefaultWorkspaceRef.fromJson);
  }

  /// 设置默认 Workspace（必须指向本 Org 下 workspace，服务端裁决）。
  Future<DefaultWorkspaceRef> setDefaultWorkspace(
    EntityId orgId,
    EntityId workspaceId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/default-workspace',
      data: {'workspace_id': workspaceId},
    );
    return _unwrap(resp, DefaultWorkspaceRef.fromJson);
  }

  /// 清除默认 Workspace 指向。
  Future<void> clearDefaultWorkspace(EntityId orgId) async {
    final resp = await delete('/api/v1/organizations/$orgId/default-workspace');
    _ensureOk(resp);
  }

  // ==================== 企业邀请码加入（GZAPP-04/GZAPP-01 契约） ====================

  /// 凭企业邀请码加入组织（POST `/organizations/:orgId/invite_code/join`
  /// body `{code}`）。joined | unchanged 均为成功；加入编排（默认 WS /
  /// 全员群 / 公告频道）由服务端事务完成。
  ///
  /// 路径真源 = 后端契约 `.contract/api_contract.json`
  /// （operationId `invite_code_join`）。此前这里写的是 `/join_by_code`——
  /// 那是**服务端不存在的路径**，真机实测 404「加入失败：错误 (404)」；
  /// 而本模块的 widget 测试把这个错路径一起 mock 了，于是永远绿。
  /// 改任何一侧前先看契约，别再让客户端测试自证。
  ///
  /// 错误语义（envelope code，GZAPP-01 负例口径）：981 码无效/已撤销、
  /// 982 码过期、403 越权、404 组织不存在、archived 拒绝——经
  /// [OrganizationApiException.isInviteInvalid] / [isInviteExpired] 等区分。
  ///
  /// 注意：码按 org 发放（同 org 一个 active），后端按 path orgId 消歧，
  /// 因此**必须**携带目标组织 ID——UI 侧由用户从邀请人处获取。
  Future<OrganizationJoinOutcome> joinByCode(
    EntityId orgId, {
    required String code,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invite_code/join',
      data: {'code': code},
    );
    return _unwrap(resp, OrganizationJoinOutcome.fromJson);
  }

  // ==================== 内部 ====================

  Map<String, dynamic> _query({int? limit, String? status}) => {
    'limit': ?limit,
    if (status != null && status.isNotEmpty) 'status': status,
  };

  Map<String, dynamic> _statusQuery(String? status, int? limit) =>
      _query(limit: limit, status: status);

  Map<String, dynamic> _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw OrganizationApiException(resp.code, resp.msg);
    }
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  T _unwrap<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return fromJson(_ensureOk(resp));
  }

  List<T> _list<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _ensureOk(resp);
    return IMBoyHttpResponse.payloadList(resp.payload).map(fromJson).toList();
  }

  OrganizationPage<T> _page<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = _ensureOk(resp);
    return OrganizationPage<T>(
      list: IMBoyHttpResponse.payloadList(resp.payload).map(fromJson).toList(),
      page: _int(map['page']),
      size: _int(map['size']),
      total: _int(map['total']),
      totalPage: _int(map['total_page']),
    );
  }

  OrganizationMember _unwrapMember(IMBoyHttpResponse resp) {
    final map = _ensureOk(resp);
    // change_role/invite 成功响应 = member 行 + status_flag 附加键；
    // status_flag 属服务端内部提示，不进 DTO。
    return OrganizationMember.fromJson(map);
  }

  int _int(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? 0;
  }
}
