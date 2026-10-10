/// Organization 域 DTO（Core Contract C04/C05/C11/C16/C17 + 计划 ORG-13）
///
/// TSID 约定：64-bit ID 后端以 JSON integer 传输，App 端一律经
/// [entityIdOf]（safeParseBigIntJson 语义）转 String 持有（[EntityId]），
/// 全程不回转 int/num；序列化（toJson）时 TSID 也以 String 落 JSON。
///
/// 展示即事实（ORG-A13）：本文件只镜像服务端出站字段，不做任何客户端
/// 权限判定（权限以每次 API 响应的 200/403 为准）。状态字段保持 wire
/// 字符串 + 只读辅助 getter：未知值原样保留展示，绝不臆造枚举分支。
///
/// 本文件保持纯 Dart（无 flutter import），可被单测直接驱动。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// 时间戳宽容展示：后端出站秒/毫秒并存（邀请 expires_at 为 epoch 秒，
/// 审计字段为 PG timestamp 出站值），< 10^12 按秒、否则按毫秒解释；
/// 非数字原样返回（展示层容错，不参与任何业务判断）。
String flexTsLabel(String raw) {
  final ts = int.tryParse(raw);
  if (ts == null || ts <= 0) return raw;
  final millis = ts < 1000000000000 ? ts * 1000 : ts;
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// 组织（organization 表出站行 + member_role 投影）。
class Organization {
  final EntityId id;
  final String name;
  final EntityId ownerId;

  /// 服务端组织状态：active | archived（C16：archived 后全部写入口
  /// fail-closed，仅 restore 放行）。未知值原样保留。
  final String status;
  final Map<String, dynamic> branding;
  final Map<String, dynamic> settings;

  /// 当前账号在本 Org 的角色：owner | admin | member（detail/mine 投影）。
  final String memberRole;
  final String createdAt;
  final String updatedAt;

  const Organization({
    required this.id,
    required this.name,
    this.ownerId = '',
    this.status = 'active',
    this.branding = const {},
    this.settings = const {},
    this.memberRole = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: entityIdOf(json['id']),
      name: parseModelString(json['name']),
      ownerId: entityIdOf(json['owner_id']),
      status: parseModelString(json['status'], defaultValue: 'active'),
      branding: _jsonMap(json['branding']),
      settings: _jsonMap(json['settings']),
      memberRole: parseModelString(json['member_role']),
      createdAt: parseModelString(json['created_at']),
      updatedAt: parseModelString(json['updated_at']),
    );
  }

  bool get isArchived => status == 'archived';
  bool get iAmOwner => memberRole == 'owner';
  bool get iAmAdmin => memberRole == 'admin';

  /// 治理动作可用性仅用于**预先隐藏入口**；服务端 403 仍是唯一裁决
  /// （客户端判定只做减法不做放行，Core Contract 权限语义）。
  bool get canGovern => iAmOwner || iAmAdmin;
}

/// 组织成员（organization_member LEFT JOIN user 投影，治理面列表行）。
/// 成员在某企业内的**有权 Workspace**（计划 §5.2：成员详情必须含该信息）。
///
/// 出站形状由后端 organization_member_repo:member_workspaces/2 供给：
/// 只含本企业内 active 的 workspace（跨企业授权不算本企业内权限）。
class OrganizationMemberWorkspace {
  final EntityId id;
  final String name;

  const OrganizationMemberWorkspace({required this.id, this.name = ''});

  factory OrganizationMemberWorkspace.fromJson(Map<String, dynamic> json) {
    return OrganizationMemberWorkspace(
      id: entityIdOf(json['id']),
      name: parseModelString(json['name']),
    );
  }
}

class OrganizationMember {
  final EntityId organizationId;
  final EntityId userId;

  /// owner | admin | member。
  final String role;
  final EntityId invitedBy;

  /// 服务端成员状态：active | suspended（EB-D07 可恢复撤权）| removed
  /// （offboard 终态）。治理面列表只回 active 行——suspended/removed 行
  /// 仅出现在生命周期命令（suspend/restore/offboard）的响应里；未知值
  /// 原样保留展示（ORG-A13）。
  final String status;
  final String joinedAt;
  final String nickname;
  final String avatar;

  /// 登录账号（服务端治理面出站字段；仅 owner/admin 可拉取列表）。
  final String account;

  const OrganizationMember({
    required this.organizationId,
    required this.userId,
    this.role = 'member',
    this.invitedBy = '',
    this.status = 'active',
    this.joinedAt = '',
    this.nickname = '',
    this.avatar = '',
    this.account = '',
  });

  factory OrganizationMember.fromJson(Map<String, dynamic> json) {
    return OrganizationMember(
      organizationId: entityIdOf(json['organization_id']),
      userId: entityIdOf(json['user_id']),
      role: parseModelString(json['role'], defaultValue: 'member'),
      invitedBy: entityIdOf(json['invited_by']),
      status: parseModelString(json['status'], defaultValue: 'active'),
      joinedAt: parseModelString(json['joined_at']),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      account: parseModelString(json['account']),
    );
  }

  /// 展示名：昵称优先，其次账号，再退到 UID 字符串（TSID 精度无损）。
  String get displayName =>
      nickname.isNotEmpty ? nickname : (account.isNotEmpty ? account : userId);

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  /// 生命周期态（EB-D07/EB-08）：suspended 可恢复；removed 为 offboard
  /// 终态（唯一恢复路径 = 重新邀请）。active 为缺省在册态。
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get isRemoved => status == 'removed';

  /// Owner 本身不可改角色/移除/暂停/离场（C04 单 owner 不变量 + 主 Owner
  /// 成员行 DB 守卫）；转移走显式 owner-transfer command，不走本行编辑。
  bool get isGovernable => !isOwner;
}

/// 组织邀请（organization_invitation 出站白名单投影）。
///
/// token 明文只在 create 响应出现一次（C11）；accept 需要目标用户持有
/// 该 token（口令式领取），本 DTO 永不承载 token_digest。
class OrgInvitation {
  final EntityId invitationId;
  final EntityId organizationId;
  final EntityId targetUserId;
  final EntityId invitedBy;

  /// pending | accepted | rejected | revoked | expired（lazy expire 后的
  /// 读面终态）；未知值原样保留展示。
  final String status;
  final String expiresAt;
  final String respondedAt;
  final String createdAt;

  /// 幂等命中标记：accept/reject/revoke 重复提交时服务端置 true。
  final bool alreadyAccepted;
  final bool alreadyTerminal;

  /// 一次性明文 token：**只在 create 响应出现**（C11）；其余接口的
  /// 投影不含该字段（解析为空串）。App 只做转场展示，不持久化。
  final String token;

  /// Org 视角富化列（APP-M02「可能的同事」；list_for_org 的 LEFT JOIN
  /// "user" 投影，target/mine 视角不含这些字段 → 空串）。
  final String targetNickname;
  final String targetAccount;
  final String targetAvatar;
  final String inviterName;

  const OrgInvitation({
    required this.invitationId,
    required this.organizationId,
    required this.targetUserId,
    required this.invitedBy,
    this.status = 'pending',
    this.expiresAt = '',
    this.respondedAt = '',
    this.createdAt = '',
    this.alreadyAccepted = false,
    this.alreadyTerminal = false,
    this.token = '',
    this.targetNickname = '',
    this.targetAccount = '',
    this.targetAvatar = '',
    this.inviterName = '',
  });

  factory OrgInvitation.fromJson(Map<String, dynamic> json) {
    return OrgInvitation(
      invitationId: entityIdOf(json['invitation_id']),
      organizationId: entityIdOf(json['organization_id']),
      targetUserId: entityIdOf(json['target_user_id']),
      invitedBy: entityIdOf(json['invited_by']),
      status: parseModelString(json['status'], defaultValue: 'pending'),
      expiresAt: parseModelString(json['expires_at']),
      respondedAt: parseModelString(json['responded_at']),
      createdAt: parseModelString(json['created_at']),
      alreadyAccepted: json['already_accepted'] == true,
      alreadyTerminal: json['already_terminal'] == true,
      token: parseModelString(json['token']),
      targetNickname: parseModelString(json['target_nickname']),
      targetAccount: parseModelString(json['target_account']),
      targetAvatar: parseModelString(json['target_avatar']),
      inviterName: parseModelString(json['inviter_name']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired';

  /// 展示名：target 昵称 → 账号 → 「用户 #id」（富化列缺失时的兜底口径，
  /// 与目录 display_name 的 nickname→account 降级一致）。
  String get targetDisplayName {
    if (targetNickname.isNotEmpty) return targetNickname;
    if (targetAccount.isNotEmpty) return targetAccount;
    return targetUserId.isEmpty ? '' : '用户#$targetUserId';
  }
}

/// 部门（organization_department 出站白名单行，含 version 乐观并发标记）。
class OrganizationDepartment {
  final EntityId id;
  final EntityId organizationId;

  /// 父部门 ID；根部门为空串（服务端出站 null）。
  final EntityId parentId;
  final String name;

  /// active | archived。
  final String status;
  final String version;
  final String createdAt;
  final String updatedAt;

  const OrganizationDepartment({
    required this.id,
    required this.organizationId,
    this.parentId = '',
    required this.name,
    this.status = 'active',
    this.version = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory OrganizationDepartment.fromJson(Map<String, dynamic> json) {
    return OrganizationDepartment(
      id: entityIdOf(json['id']),
      organizationId: entityIdOf(json['organization_id']),
      parentId: entityIdOf(json['parent_id']),
      name: parseModelString(json['name']),
      status: parseModelString(json['status'], defaultValue: 'active'),
      version: parseModelString(json['version']),
      createdAt: parseModelString(json['created_at']),
      updatedAt: parseModelString(json['updated_at']),
    );
  }

  bool get isArchived => status == 'archived';
  bool get isRoot => parentId.isEmpty;
}

/// 部门成员（organization_department_member 出站行，兼职模型：一人可属
/// 多部门；Organization 与 Workspace membership 各自独立，本表不承载
/// 任何 workspace 语义）。
class DepartmentMember {
  final EntityId organizationId;
  final EntityId departmentId;
  final EntityId userId;
  final bool isAdmin;
  final String createdAt;
  final String updatedAt;

  /// add 幂等命中标记（已是成员时服务端置 true）。
  final bool idempotent;

  const DepartmentMember({
    required this.organizationId,
    required this.departmentId,
    required this.userId,
    this.isAdmin = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.idempotent = false,
  });

  factory DepartmentMember.fromJson(Map<String, dynamic> json) {
    return DepartmentMember(
      organizationId: entityIdOf(json['organization_id']),
      departmentId: entityIdOf(json['department_id']),
      userId: entityIdOf(json['user_id']),
      isAdmin: json['is_admin'] == true,
      createdAt: parseModelString(json['created_at']),
      updatedAt: parseModelString(json['updated_at']),
      idempotent: json['idempotent'] == true,
    );
  }
}

/// Org 默认 Workspace 指针（C05：默认 workspace 是「指向事实」而非
/// 授权）。defaultWorkspaceId 为空串 = 服务端出站 null（未设置）；
/// 该事实**不构成**任何 workspace membership（两者独立，负例有测试）。
class DefaultWorkspaceRef {
  final EntityId organizationId;
  final EntityId defaultWorkspaceId;

  const DefaultWorkspaceRef({
    required this.organizationId,
    this.defaultWorkspaceId = '',
  });

  factory DefaultWorkspaceRef.fromJson(Map<String, dynamic> json) {
    return DefaultWorkspaceRef(
      organizationId: entityIdOf(json['organization_id']),
      defaultWorkspaceId: entityIdOf(json['default_workspace_id']),
    );
  }

  bool get isSet => defaultWorkspaceId.isNotEmpty;
}

/// 企业邀请码（治理面 GET/POST `/organizations/:orgId/invite_code` 出站）。
/// `code` 为空 = 当前无 active 码（服务端可空语义，success 信封 code=null）。
class OrganizationInviteCode {
  final EntityId organizationId;
  final String code;
  final String status;

  /// 过期时刻（epoch 秒；0/缺省 = 未知）。
  final int expiresAt;

  const OrganizationInviteCode({
    this.organizationId = '',
    this.code = '',
    this.status = '',
    this.expiresAt = 0,
  });

  bool get isEmpty => code.isEmpty;

  factory OrganizationInviteCode.fromJson(Map<String, dynamic> json) {
    return OrganizationInviteCode(
      organizationId: entityIdOf(json['organization_id']),
      code: parseModelString(json['code']),
      status: parseModelString(json['status']),
      expiresAt: parseModelInt(json['expires_at']),
    );
  }
}

/// 凭码预览目标组织（GZAPP-J11：POST `/organizations/invite_code/preview`
/// 出站）——扫码 / 单码手输加入的「确认加入 XX 企业」步骤。
class OrgInvitePreview {
  final EntityId organizationId;
  final String name;

  /// 凭码加入后的初始角色（发码方指定）：member | admin。旧出站投影缺该
  /// 字段时兜底 'member'（宽容解析，不臆造 admin 权限语义）。
  final String role;

  const OrgInvitePreview({
    this.organizationId = '',
    this.name = '',
    this.role = 'member',
  });

  factory OrgInvitePreview.fromJson(Map<String, dynamic> json) {
    return OrgInvitePreview(
      organizationId: entityIdOf(json['organization_id']),
      name: parseModelString(json['name']),
      role: parseModelString(json['role'], defaultValue: 'member'),
    );
  }
}

/// 企业邀请码加入结果（GZAPP-01 契约：POST
/// `/organizations/:orgId/join_by_code` body `{code}`）。
///
/// status 语义镜像 ws 团队码：`joined`（本次加入）| `unchanged`（已是
/// 成员，幂等命中）；加入编排（默认 WS / 全员群 / 公告频道）在服务端
/// 事务内完成，客户端只消费出站事实。响应形态联调窗口在 GZAPP-09，
/// 解析保持宽容：`organization` 缺失时落空 [Organization]（页面据此
/// 走「加入成功但详情缺失 → 刷新列表」兜底）。
class OrganizationJoinOutcome {
  final String status;
  final Organization organization;

  const OrganizationJoinOutcome({
    this.status = 'joined',
    this.organization = const Organization(id: '', name: ''),
  });

  factory OrganizationJoinOutcome.fromJson(Map<String, dynamic> json) {
    final orgRaw = json['organization'];
    return OrganizationJoinOutcome(
      status: parseModelString(json['status'], defaultValue: 'joined'),
      organization: orgRaw is Map<String, dynamic>
          ? Organization.fromJson(orgRaw)
          : const Organization(id: '', name: ''),
    );
  }

  /// 幂等命中（已是本企业成员）。
  bool get isAlreadyMember => status == 'unchanged';
}

/// User 删除预检 blocker（C17 §1.6：五依赖域，缺一拒）。
class PreflightBlocker {
  final String code;
  final String resourceType;
  final Map<String, dynamic> raw;

  const PreflightBlocker({
    required this.code,
    required this.resourceType,
    this.raw = const {},
  });

  factory PreflightBlocker.fromJson(Map<String, dynamic> json) {
    return PreflightBlocker(
      code: parseModelString(json['code']),
      resourceType: parseModelString(json['resource_type']),
      raw: json,
    );
  }
}

/// User 删除预检报告（GET /organizations/deletion-preflight 出站）。
class DeletionPreflightReport {
  final EntityId subjectUserId;
  final List<PreflightBlocker> blockers;

  /// 各依赖域出站事实的 domain 名清单（展示用）。
  final List<String> factDomains;
  final String observedAt;

  const DeletionPreflightReport({
    required this.subjectUserId,
    this.blockers = const [],
    this.factDomains = const [],
    this.observedAt = '',
  });

  factory DeletionPreflightReport.fromJson(Map<String, dynamic> json) {
    final facts = json['facts'];
    final domains = <String>[];
    if (facts is List) {
      for (final f in facts) {
        if (f is Map) {
          final d = f['domain'];
          if (d != null) {
            domains.add(d.toString());
          }
        }
      }
    }
    final rawBlockers = json['blockers'];
    final blockers = <PreflightBlocker>[];
    if (rawBlockers is List) {
      for (final b in rawBlockers) {
        if (b is Map<String, dynamic>) {
          blockers.add(PreflightBlocker.fromJson(b));
        }
      }
    }
    return DeletionPreflightReport(
      subjectUserId: entityIdOf(json['subject_user_id']),
      blockers: blockers,
      factDomains: domains,
      observedAt: parseModelString(json['observed_at']),
    );
  }

  bool get hasBlockers => blockers.isNotEmpty;
}

/// 统一分页信封（`{list, page, size, total, total_page}`）。
class OrganizationPage<T> {
  final List<T> list;
  final int page;
  final int size;
  final int total;
  final int totalPage;

  const OrganizationPage({
    required this.list,
    required this.page,
    required this.size,
    required this.total,
    required this.totalPage,
  });

  bool get isEmpty => list.isEmpty;
  bool get hasMore => page < totalPage;
}

Map<String, dynamic> _jsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}
