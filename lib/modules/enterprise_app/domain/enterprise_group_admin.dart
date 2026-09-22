/// 企业群治理（详情/更新/归档/成员角色）的前端契约与状态（FULL-05 / INT-18..21）。
///
/// 逐条对齐后端（FULL-02 真库套件已钉死的语义）：
///
/// | 项 | 契约 | 来源 |
/// |---|---|---|
/// | 角色枚举 | 0 未定义 / 1 普通成员 / 2 嘉宾 / 3 管理员 / 4 群主 / 5 副群主 | `group_member.role` 注释 |
/// | OA 可分配角色 | **仅 [1, 2, 3, 5]**；4（群主）不可经 OA 分配 | `?ASSIGNABLE_ROLES` |
/// | 群主变更 | 群主角色不可改（转让走人类流程） | `set_member_role_tx` 守卫 |
/// | 标题 | 1..200；简介 ≤2000；**空更新拒绝**（不产生无意义写入） | `?MAX_TITLE_LEN` |
/// | 详情成员 | 硬上限 200；超限 → `invalid_request` + detail `members_over_limit`，**绝不静默截断** | `?MAX_DETAIL_MEMBERS` |
/// | 归档 | 单向：`status -> 0` + 归属行 `archived`；归档后全部 internal 路径不可见；幂等（`already`） | `archive_group_tx` |
/// | 归档归属 | 只能归档**本 Application 建立**的企业群；无归属行/他人归属 → `invalid_request` | `own_origin` |
///
/// 纯 Dart（零 Flutter / 零 IO）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 企业群成员角色（数值与 `group_member.role` 一一对应）。
enum EnterpriseGroupRole {
  undefined(0, 'roleUndefined'),
  member(1, 'roleMember'),
  guest(2, 'roleGuest'),
  admin(3, 'roleAdmin'),
  owner(4, 'roleOwner'),
  viceOwner(5, 'roleViceOwner');

  /// 服务端数值（JSON integer 传输，非 TSID，故直接用 int）。
  final int value;

  /// i18n 短键（文案在 `enterpriseApp` 命名空间）。
  final String labelKey;

  const EnterpriseGroupRole(this.value, this.labelKey);

  static EnterpriseGroupRole? tryParse(dynamic raw) {
    final int? v = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (v == null) return null;
    for (final EnterpriseGroupRole r in EnterpriseGroupRole.values) {
      if (r.value == v) return r;
    }
    return null;
  }

  /// OA（Application）是否可分配该角色。
  ///
  /// 与后端 `?ASSIGNABLE_ROLES = [1,2,3,5]` 逐值对齐：群主（4）与未定义（0）
  /// **不可**经 OA 分配。UI 的候选列表由本判定生成，不另写一份白名单。
  bool get assignableFromApplication =>
      this == EnterpriseGroupRole.member ||
      this == EnterpriseGroupRole.guest ||
      this == EnterpriseGroupRole.admin ||
      this == EnterpriseGroupRole.viceOwner;

  /// 群主角色不可变更（后端守卫；UI 侧灰化并给出理由）。
  bool get isLocked => this == EnterpriseGroupRole.owner;

  /// OA 可分配角色全集（顺序即 UI 展示顺序）。
  static List<EnterpriseGroupRole> get assignableRoles => EnterpriseGroupRole
      .values
      .where((r) => r.assignableFromApplication)
      .toList();
}

/// 群成员行（详情面最小字段）。
class EnterpriseGroupMember {
  const EnterpriseGroupMember({
    required this.userId,
    required this.role,
    this.status = 1,
    this.externalUserId = '',
  });

  final EntityId userId;
  final EnterpriseGroupRole role;

  /// `group_member.status`（1 = active；详情面只回 active 行）。
  final int status;

  /// 目录/角色写入用的外部身份（详情面不返回，写入时由调用方补齐）。
  final EntityId externalUserId;

  bool get isActive => status == 1;

  /// 详情面成员行的原样事实（测试以键集合钉死，防止字段被悄悄丢掉）。
  Map<String, Object?> get rawFields => <String, Object?>{
    'user_id': userId,
    'role': role.value,
    'status': status,
  };

  factory EnterpriseGroupMember.fromJson(Map<String, dynamic> json) {
    return EnterpriseGroupMember(
      userId: entityIdOf(json['user_id']),
      role:
          EnterpriseGroupRole.tryParse(json['role']) ??
          EnterpriseGroupRole.undefined,
      status: parseModelInt(json['status'], defaultValue: 1),
      externalUserId: entityIdOf(json['external_user_id']),
    );
  }

  static List<EnterpriseGroupMember> listFrom(dynamic raw) {
    if (raw is! List) return const <EnterpriseGroupMember>[];
    return raw
        .map(
          (dynamic e) => EnterpriseGroupMember.fromJson(_asMap(e) ?? const {}),
        )
        .toList(growable: false);
  }
}

/// 群归属视图（`origin`，null = 无归属行 = 人类自建群）。
class EnterpriseGroupOrigin {
  const EnterpriseGroupOrigin({
    required this.applicationId,
    this.workspaceId = '',
    this.status = 'active',
    this.mine = false,
  });

  final EntityId applicationId;
  final EntityId workspaceId;

  /// `active` | `archived`（归档单向）。
  final String status;

  /// 是否属于**本** Application（决定能否归档）。
  final bool mine;

  bool get isArchived => status == 'archived';

  factory EnterpriseGroupOrigin.fromJson(Map<String, dynamic> json) {
    return EnterpriseGroupOrigin(
      applicationId: entityIdOf(json['application_id']),
      workspaceId: entityIdOf(json['workspace_id']),
      status: parseModelString(json['status'], defaultValue: 'active'),
      mine: parseModelBool(json['mine']),
    );
  }
}

/// 群详情（INT-18 响应）。
class EnterpriseGroupDetail {
  const EnterpriseGroupDetail({
    required this.groupId,
    this.workspaceId = '',
    this.title = '',
    this.ownerUserId = '',
    this.memberCount = 0,
    this.members = const <EnterpriseGroupMember>[],
    this.origin,
  });

  final EntityId groupId;
  final EntityId workspaceId;
  final String title;
  final EntityId ownerUserId;
  final int memberCount;
  final List<EnterpriseGroupMember> members;

  /// null = 人类自建群（无归属行）。
  final EnterpriseGroupOrigin? origin;

  /// 是否由 Application 托管（有归属行）。
  bool get isApplicationOwned => origin != null;

  /// 归档态：归属行 archived（后端在归档时同时把 group.status 置 0，
  /// 归档后本详情面通常已不可达；本字段用于归档响应后的本地回显）。
  bool get isArchived => origin?.isArchived ?? false;

  /// 本 app 能否归档该群（归属 app 必须为自己）。
  bool get canArchive => origin != null && origin!.mine && !origin!.isArchived;

  /// 是否含群主（详情面自洽性：owner invariant 的读侧体现）。
  bool get hasOwner =>
      members.any((m) => m.role == EnterpriseGroupRole.owner && m.isActive);

  factory EnterpriseGroupDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? originRaw = _asMap(json['origin']);
    return EnterpriseGroupDetail(
      groupId: entityIdOf(json['group_id']),
      workspaceId: entityIdOf(json['workspace_id']),
      title: parseModelString(json['title']),
      ownerUserId: entityIdOf(json['owner_user_id']),
      memberCount: parseModelInt(json['member_count']),
      members: EnterpriseGroupMember.listFrom(json['members']),
      origin: originRaw == null
          ? null
          : EnterpriseGroupOrigin.fromJson(originRaw),
    );
  }
}

/// 群更新草稿（INT-19 入参）与前端校验。
///
/// 与后端 `parse_update_input` 同规则：title 1..200 / introduction ≤2000，
/// **两项都缺省 → 拒绝**（空更新不产生写入与审计噪音）。
class EnterpriseGroupUpdateDraft {
  const EnterpriseGroupUpdateDraft({this.title, this.introduction});

  final String? title;
  final String? introduction;

  static const int maxTitleLength = 200;
  static const int maxIntroductionLength = 2000;

  /// 是否为空更新（两项皆 null）。
  bool get isEmpty => title == null && introduction == null;

  /// 校验结果：null = 通过，否则为拒绝原因键。
  String? validate() {
    if (isEmpty) return 'empty_update';
    final String? t = title;
    if (t != null && (t.isEmpty || t.length > maxTitleLength)) {
      return 'invalid_title';
    }
    final String? i = introduction;
    if (i != null && i.length > maxIntroductionLength) {
      return 'invalid_introduction';
    }
    return null;
  }

  /// 只发实际给出的字段（部分更新；不把缺省写成空串）。
  Map<String, dynamic> toWire() => <String, dynamic>{
    if (title != null) 'title': title,
    if (introduction != null) 'introduction': introduction,
  };
}

/// 成员角色变更项（INT-20 入参元素）。
class EnterpriseGroupRoleAssignment {
  const EnterpriseGroupRoleAssignment({
    required this.externalUserId,
    required this.role,
  });

  final EntityId externalUserId;
  final EnterpriseGroupRole role;

  /// 校验：external_user_id 非空、角色在枚举内且可经 OA 分配。
  String? validate() {
    if (externalUserId.isEmpty) return 'missing_external_user_id';
    if (!role.assignableFromApplication) return 'role_not_assignable';
    return null;
  }

  Map<String, dynamic> toWire() => <String, dynamic>{
    'external_user_id': externalUserId,
    'role': role.value,
  };
}

/// 归档结果（INT-21 响应）。
class EnterpriseGroupArchiveOutcome {
  const EnterpriseGroupArchiveOutcome({
    required this.archived,
    this.already = false,
  });

  final bool archived;

  /// 幂等命中（本次调用前已归档）。
  final bool already;

  factory EnterpriseGroupArchiveOutcome.fromJson(Map<String, dynamic> json) {
    return EnterpriseGroupArchiveOutcome(
      archived: parseModelBool(json['archived'], defaultValue: true),
      already: parseModelBool(json['already']),
    );
  }
}

/// 群详情成员数是否越界（后端 `?MAX_DETAIL_MEMBERS`）。
const int kEnterpriseGroupMaxDetailMembers = 200;

/// 后端超限 detail 常量（UI 据此给「已停止加载」而不是空列表）。
const String kDetailOverLimit = 'members_over_limit';

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return parseModelJsonMap(raw);
}
