/// WP5 (T9) — Workspace 领域模型（双体验 v2.5.2）
///
/// 后端契约（imboy workspace_handler.erl，TSID 以 JSON integer 传输）：
/// - workspace 行：`{id, name, logo, owner_id, status(active|archived),
///   branding{...}, created_at, updated_at}`
/// - workspace_member 行：`{workspace_id, user_id, role(owner|member|guest),
///   invited_by, joined_at, status, nickname, avatar, account}`
/// - overview：`{project_count, group_count, channel_count,
///   member_preview: [member 行]}`
///
/// TSID 约定：64-bit ID 在 JSON 里是 integer，Dart 端一律转 String 包装
/// （[EntityId]），经 [entityIdOf] 安全解析（等价 imboyadmin 的
/// safeParseBigIntJson 语义：int/num/String 均可入，绝不丢精度回转 int）。
library;

import 'package:intl/intl.dart';

import 'model_parse_utils.dart';

/// TSID 64-bit ID 的前端字符串包装类型。
///
/// 后端以 JSON integer 传输；Dart native int 虽为 64 位，但 ID 一律以
/// String 持有与传递（对齐 imboyadmin `EntityId` 约定），禁止
/// `int.parse` / `Number()` 回转（web 平台丢精度是既有前科）。
typedef EntityId = String;

/// 解析 TSID 字段为 [EntityId]（int/num/String 入参均可）。
///
/// 缺失 / 空值 / 非法值返回空串（调用方以 `isEmpty` 判无效）。
EntityId entityIdOf(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw.trim();
  if (raw is num) return raw.toInt().toString();
  return raw.toString().trim();
}

/// Workspace 状态（后端 workspace.status）。
enum WorkspaceStatus {
  active('active'),
  archived('archived');

  final String wireName;

  const WorkspaceStatus(this.wireName);

  static WorkspaceStatus parse(dynamic raw) {
    return raw == WorkspaceStatus.archived.wireName
        ? WorkspaceStatus.archived
        : WorkspaceStatus.active;
  }

  bool get isArchived => this == WorkspaceStatus.archived;
}

/// Workspace Member 角色（计划 §1.4.2 三角色，唯一授权真相）。
///
/// 跨域术语约束：本枚举只描述「工作区成员」角色，与 Group Member
/// （群成员）/ Channel Subscriber（频道订阅者）是三种独立关系。
enum WorkspaceMemberRole {
  owner('owner'),
  member('member'),
  guest('guest');

  final String wireName;

  const WorkspaceMemberRole(this.wireName);

  /// 后端角色解析：未知值降级 [member]（宽容解析，界面仍显示服务端权威值）。
  static WorkspaceMemberRole parse(dynamic raw) {
    final s = raw is String ? raw : raw?.toString() ?? '';
    return WorkspaceMemberRole.values.firstWhere(
      (r) => r.wireName == s,
      orElse: () => WorkspaceMemberRole.member,
    );
  }
}

/// Branding 白名单视图（后端只接受 name/logo/primaryColor 三键）。
class WorkspaceBranding {
  final String name;
  final String logo;
  final String primaryColor;

  const WorkspaceBranding({
    this.name = '',
    this.logo = '',
    this.primaryColor = '',
  });

  factory WorkspaceBranding.fromJson(Map<String, dynamic> json) {
    return WorkspaceBranding(
      name: parseModelString(json['name']),
      logo: parseModelString(json['logo']),
      primaryColor: parseModelString(json['primaryColor']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (name.isNotEmpty) 'name': name,
    if (logo.isNotEmpty) 'logo': logo,
    if (primaryColor.isNotEmpty) 'primaryColor': primaryColor,
  };
}

/// Workspace 模型（public view，branding 已是对象）。
class WorkspaceModel {
  final EntityId id;
  final String name;
  final String logo;
  final EntityId ownerId;
  final WorkspaceStatus status;
  final WorkspaceBranding branding;

  const WorkspaceModel({
    required this.id,
    required this.name,
    this.logo = '',
    required this.ownerId,
    this.status = WorkspaceStatus.active,
    this.branding = const WorkspaceBranding(),
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    final brandingRaw = json['branding'];
    return WorkspaceModel(
      id: entityIdOf(json['id']),
      name: parseModelString(json['name']),
      logo: parseModelString(json['logo']),
      ownerId: entityIdOf(json['owner_id']),
      status: WorkspaceStatus.parse(json['status']),
      branding: brandingRaw is Map<String, dynamic>
          ? WorkspaceBranding.fromJson(brandingRaw)
          : const WorkspaceBranding(),
    );
  }

  bool get isArchived => status.isArchived;

  /// branding 编辑/补全后的轻量合并（name 空回落现值，其余字段原样保留）。
  /// 供壳 provider（branding 补拉）与 branding 编辑页（保存回填）共用，
  /// 避免两处手写合并漂移。
  WorkspaceModel mergeBranding(WorkspaceBranding branding) {
    return WorkspaceModel(
      id: id,
      name: branding.name.isNotEmpty ? branding.name : name,
      logo: branding.logo,
      ownerId: ownerId,
      status: status,
      branding: branding,
    );
  }
}

/// Template 原子创建结果（I13：全成或全回滚，request_id 幂等）。
class WorkspaceCreateResult {
  final WorkspaceModel workspace;
  final EntityId channelId;
  final EntityId groupId;

  /// created | existing（幂等命中回带既有 Template 结果）
  final String status;

  const WorkspaceCreateResult({
    required this.workspace,
    required this.channelId,
    required this.groupId,
    required this.status,
  });

  factory WorkspaceCreateResult.fromJson(Map<String, dynamic> json) {
    final wsRaw = json['workspace'];
    return WorkspaceCreateResult(
      workspace: wsRaw is Map<String, dynamic>
          ? WorkspaceModel.fromJson(wsRaw)
          : const WorkspaceModel(id: '', name: '', ownerId: ''),
      channelId: entityIdOf(json['channel_id']),
      groupId: entityIdOf(json['group_id']),
      status: parseModelString(json['status'], defaultValue: 'created'),
    );
  }

  bool get isIdempotentHit => status == 'existing';
}

/// 团队码（invite_code；一工作区同时只有一个 active 码）。
///
/// 后端契约：`POST /api/v1/workspaces/{id}/invite_code` envelope data
/// `{code, expires_at}`（8 位大写字母数字；重新生成即覆盖旧码）。
///
/// expires_at 经 elib_cnv 统一转毫秒时间戳（与全 API 时间字段同口径），
/// 展示用 [expiresAtLabel]（裸数字对用户不可读）。
class WorkspaceInviteCode {
  final String code;
  final String expiresAt;

  const WorkspaceInviteCode({this.code = '', this.expiresAt = ''});

  factory WorkspaceInviteCode.fromJson(Map<String, dynamic> json) {
    return WorkspaceInviteCode(
      code: parseModelString(json['code']),
      expiresAt: parseModelString(json['expires_at']),
    );
  }

  bool get isValid => code.isNotEmpty;

  /// 有效期可读格式：毫秒时间戳 → `yyyy-MM-dd HH:mm`；非数字原样返回。
  String get expiresAtLabel {
    final ts = int.tryParse(expiresAt);
    if (ts == null || ts <= 0) return expiresAt;
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }
}

/// 团队码加入结果（`POST /api/v1/workspaces/join` body `{code}`）。
///
/// envelope data `{status, workspace}`：status = joined（本次新加入）|
/// unchanged（已是成员，幂等命中）；workspace 字段同 detail。
class WorkspaceJoinResult {
  final String status;
  final WorkspaceModel workspace;

  const WorkspaceJoinResult({
    this.status = '',
    this.workspace = const WorkspaceModel(id: '', name: '', ownerId: ''),
  });

  factory WorkspaceJoinResult.fromJson(Map<String, dynamic> json) {
    final wsRaw = json['workspace'];
    return WorkspaceJoinResult(
      status: parseModelString(json['status']),
      workspace: wsRaw is Map<String, dynamic>
          ? WorkspaceModel.fromJson(wsRaw)
          : const WorkspaceModel(id: '', name: '', ownerId: ''),
    );
  }

  /// joined | unchanged 都算成功加入（幂等命中不视为错误）。
  bool get isAlreadyMember => status == 'unchanged';
}

/// 工作区成员（Workspace Member）模型。
class WorkspaceMemberModel {
  final EntityId workspaceId;
  final EntityId userId;
  final WorkspaceMemberRole role;
  final String nickname;
  final String avatar;
  final String account;

  const WorkspaceMemberModel({
    required this.workspaceId,
    required this.userId,
    required this.role,
    this.nickname = '',
    this.avatar = '',
    this.account = '',
  });

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberModel(
      workspaceId: entityIdOf(json['workspace_id']),
      userId: entityIdOf(json['user_id']),
      role: WorkspaceMemberRole.parse(json['role']),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      account: parseModelString(json['account']),
    );
  }
}

/// Overview 数据（后端 workspace_ds:overview 实际返回什么就展示什么）：
/// 资源摘要 + 工作区成员预览。
///
/// 注意（I12 / 计划 §1.4）：Channel 置顶内容与最近文件不在当前 overview
/// 契约中，Overview 页对应区块渲染空态说明，不聚合 Group Notice。
class WorkspaceOverview {
  final int projectCount;
  final int groupCount;
  final int channelCount;
  final List<WorkspaceMemberModel> memberPreview;

  const WorkspaceOverview({
    this.projectCount = 0,
    this.groupCount = 0,
    this.channelCount = 0,
    this.memberPreview = const [],
  });

  factory WorkspaceOverview.fromJson(Map<String, dynamic> json) {
    return WorkspaceOverview(
      projectCount: parseModelInt(json['project_count']),
      groupCount: parseModelInt(json['group_count']),
      channelCount: parseModelInt(json['channel_count']),
      memberPreview: (json['member_preview'] is List)
          ? (json['member_preview'] as List)
                .whereType<Map<String, dynamic>>()
                .map(WorkspaceMemberModel.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

/// 分页结果（后端统一 `{list, page, size, total, total_page}` envelope）。
class WorkspacePageResult<T> {
  final List<T> list;
  final int page;
  final int size;
  final int total;
  final int totalPage;

  const WorkspacePageResult({
    this.list = const [],
    this.page = 1,
    this.size = 10,
    this.total = 0,
    this.totalPage = 0,
  });

  factory WorkspacePageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return WorkspacePageResult<T>(
      list: (json['list'] is List)
          ? (json['list'] as List)
                .whereType<Map<String, dynamic>>()
                .map(fromJson)
                .toList(growable: false)
          : const [],
      page: parseModelInt(json['page'], defaultValue: 1),
      size: parseModelInt(json['size'], defaultValue: 10),
      total: parseModelInt(json['total']),
      totalPage: parseModelInt(json['total_page']),
    );
  }
}
