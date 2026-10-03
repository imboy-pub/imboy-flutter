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
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';

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
class OrganizationApi extends HttpClient implements HumanDirectoryDataSource {
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

  /// 切换器需要完整成员企业列表；全部分页成功后才向界面交付。
  Future<List<Organization>> allMine() async {
    final account = UserRepoLocal.to.currentUid;
    final session = UserRepoLocal.to.sessionGeneration;
    final organizations = <EntityId, Organization>{};
    var totalPages = 1;
    for (var page = 1; page <= totalPages; page++) {
      if (!UserRepoLocal.to.isCurrentSession(session) ||
          UserRepoLocal.to.isClearingSession) {
        throw StateError('Organization session changed');
      }
      final result = await mine(page: page, size: 100);
      if (UserRepoLocal.to.currentUid != account ||
          !UserRepoLocal.to.isCurrentSession(session) ||
          UserRepoLocal.to.isClearingSession) {
        throw StateError('Organization account changed');
      }
      if (page == 1) totalPages = result.totalPage;
      for (final organization in result.list) {
        organizations[organization.id] = organization;
      }
    }
    return organizations.values.toList(growable: false);
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

  // ---- 成员生命周期命令（EB-D07/EB-08：suspend → restore/offboard） ----
  //
  // 契约（imboy_router.erl v1 面 × organization_member_logic）：
  // - suspend：active → suspended（可恢复的撤权第一步，不动 workspace_member
  //   与个人账号）；目标非 active 成员 409；主 Owner 不可被暂停（409）。
  // - restore：suspended → active（仅 suspended 来源；active/removed 均 409
  //   不静默成功）。
  // - offboard：两步离场 S3 终态（active|suspended → removed），复用服务端
  //   remove 语义（被依赖资源引用时 409）；恢复唯一路径 = 重新邀请。
  // 三者响应均为成员结果行（organization_id/user_id/role/status）。

  /// 暂停成员（owner/admin；响应 = status=suspended 的成员行）。
  Future<OrganizationMember> suspendMember(
    EntityId orgId,
    EntityId userId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/members/$userId/suspend',
      data: <String, dynamic>{},
    );
    return _unwrapMember(resp);
  }

  /// 恢复被暂停的成员（owner/admin；响应 = status=active 的成员行）。
  Future<OrganizationMember> restoreMember(
    EntityId orgId,
    EntityId userId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/members/$userId/restore',
      data: <String, dynamic>{},
    );
    return _unwrapMember(resp);
  }

  /// 离场：本人退出或 owner/admin 治理他人；removed 终态，重新加入需新邀请。
  /// 本人身份由服务端 JWT 裁决；Owner 和资源交接依赖由服务端拒绝。
  Future<OrganizationMember> offboardMember(
    EntityId orgId,
    EntityId userId,
  ) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/members/$userId/offboard',
      data: <String, dynamic>{},
    );
    return _unwrapMember(resp);
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

  /// 接受邀请（P0 定向邀请免口令）。
  ///
  /// 缺省 token：服务端以当前登录身份匹配 target_user_id 直达接受
  /// （本 App 的「我的邀请」列表项都是定向给自己的，走这条路）；
  /// 显式传 token：旧口令路径，向后兼容（一次性消费；重复 accept
  /// 幂等返回同一视图）。
  Future<OrgInvitation> acceptInvitation(
    EntityId orgId, {
    String? token,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invitations/accept',
      data: (token == null || token.isEmpty)
          ? <String, dynamic>{}
          : {'token': token},
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

  /// 改部门名（PATCH item）。[expectedVersion] = 出站行的 version（CAS
  /// 乐观锁；后端强制要求正整数，不符 400，并发碰撞 409 conflict——
  /// 调用方应刷新最新树后重试，见页面 `_runCommand` 的冲突分支）。
  Future<OrganizationDepartment> renameDepartment(
    EntityId orgId,
    EntityId departmentId, {
    required String name,
    required String expectedVersion,
  }) async {
    final resp = await patch(
      '/api/v1/organizations/$orgId/departments/$departmentId',
      data: {'name': name, 'expected_version': expectedVersion},
    );
    return _unwrap(resp, OrganizationDepartment.fromJson);
  }

  /// 移动部门（换父 / 提为根；键名 `parent_id`，null = 根；服务端防成环
  /// 409 `{cycle}`；[expectedVersion] 同 [renameDepartment] 的 CAS 语义）。
  Future<OrganizationDepartment> moveDepartment(
    EntityId orgId,
    EntityId departmentId, {
    required EntityId newParentId,
    required String expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/departments/$departmentId/move',
      data: {
        'parent_id': newParentId.isEmpty ? null : newParentId,
        'expected_version': expectedVersion,
      },
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
  /// 注意：本端点是「已知 orgId + 码」的旧形态；UI 主路径（扫码/单码）
  /// 已切到 [joinByCodeOnly]（码全局唯一即凭据，免 orgId）。
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

  // ==================== 企业邀请码：免 orgId 面（GZAPP-J11） ====================

  /// 治理面读当前 active 邀请码（owner/admin）；无 active 码 = 成功信封
  /// `code: null` → [OrganizationInviteCode.isEmpty]。
  Future<OrganizationInviteCode> getInviteCode(EntityId orgId) async {
    final resp = await get('/api/v1/organizations/$orgId/invite_code');
    return _unwrap(resp, OrganizationInviteCode.fromJson);
  }

  /// 生成/重新生成邀请码（owner/admin；重新生成 = 旧码立即失效；7 天有效）。
  Future<OrganizationInviteCode> createInviteCode(EntityId orgId) async {
    final resp = await post(
      '/api/v1/organizations/$orgId/invite_code',
      data: <String, dynamic>{},
    );
    return _unwrap(resp, OrganizationInviteCode.fromJson);
  }

  /// 凭码预览目标组织（码全局唯一即凭据，无需 orgId）：返回企业名、
  /// organization_id 与 role（凭码加入后的初始角色，发码方指定，
  /// 缺字段兜底 member），供「确认加入 XX 企业」步骤。981/982 语义同 join；
  /// 目标组织待审核时服务端 409（msg 透传，不加客户端兜底）。
  Future<OrgInvitePreview> previewByCode(String code) async {
    final resp = await post(
      '/api/v1/organizations/invite_code/preview',
      data: {'code': code},
    );
    return _unwrap(resp, OrgInvitePreview.fromJson);
  }

  /// 凭码加入组织（免 orgId 版，GZAPP-J11；payload 与 [joinByCode] 同构）。
  /// 扫码 / 单码手输加入路径统一走这里，用户不再需要输入企业 ID。
  Future<OrganizationJoinOutcome> joinByCodeOnly(String code) async {
    final resp = await post(
      '/api/v1/organizations/invite_code/join',
      data: {'code': code},
    );
    return _unwrap(resp, OrganizationJoinOutcome.fromJson);
  }

  // ==================== Human Directory（§14.2 类企业微信浏览，只读） ====================
  //
  // 契约冻结于 A4 run（2026-09-23）：成功 = imboy envelope
  // `{code:0,msg,sv_ts,payload:{list,cursor,has_more}}`（/me 为
  // `{organization_id,list}`）；错误 = 真实 HTTP 状态 + `{"error":{code,
  // message}}`——经 [OrganizationApiException.code] 透传 HTTP 状态分型
  // （400 invalid_request / 403 insufficient_scope·organization_disabled /
  // 404 resource_not_found / 503 security_gate_closed）。cursor 为 opaque
  // 签名票，只透传不解析。

  @override
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required EntityId organizationId,
    EntityId? parentId,
    String? cursor,
    int? limit,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$organizationId/directory/departments',
      queryParameters: _directoryQuery(
        parentId: parentId,
        cursor: cursor,
        limit: limit,
      ),
    );
    return _directoryPage(resp, HumanDirectoryDepartment.fromJson, (d) => d.id);
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required EntityId organizationId,
    EntityId? departmentId,
    String? cursor,
    int? limit,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$organizationId/directory/members',
      queryParameters: _directoryQuery(
        departmentId: departmentId,
        cursor: cursor,
        limit: limit,
      ),
    );
    return _directoryPage(resp, HumanDirectoryMember.fromJson, (m) => m.userId);
  }

  @override
  Future<HumanDirectoryMe> directoryMe({
    required EntityId organizationId,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$organizationId/directory/me',
    );
    return HumanDirectoryMe.fromJson(_ensureOk(resp));
  }

  @override
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required EntityId organizationId,
    required String q,
    String? cursor,
    int? limit,
  }) async {
    final resp = await get(
      '/api/v1/organizations/$organizationId/directory/search',
      queryParameters: {
        'q': q,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': ?limit,
      },
    );
    return _directoryPage(
      resp,
      HumanDirectorySearchItem.fromJson,
      (s) => s.dedupeKey,
    );
  }

  Map<String, dynamic> _directoryQuery({
    EntityId? parentId,
    EntityId? departmentId,
    String? cursor,
    int? limit,
  }) => {
    if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
    if (departmentId != null && departmentId.isNotEmpty)
      'department_id': departmentId,
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    'limit': ?limit,
  };

  /// `{list, cursor, has_more}` 解析（cursor null = 末页；服务端 limit+1 判
  /// has_more）。列表行按 [idOf] 剔除无 ID 的坏行（防御，不改变服务端顺序）。
  HumanDirectoryPage<T> _directoryPage<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
    String Function(T) idOf,
  ) {
    final map = _ensureOk(resp);
    final rows = IMBoyHttpResponse.payloadList(resp.payload);
    final list = rows
        .map(fromJson)
        .where((row) => idOf(row).isNotEmpty)
        .toList(growable: false);
    final rawCursor = map['cursor'];
    final cursor = rawCursor is String && rawCursor.isNotEmpty
        ? rawCursor
        : null;
    return HumanDirectoryPage<T>(
      list: list,
      cursor: cursor,
      hasMore: map['has_more'] == true,
    );
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
