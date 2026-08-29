/// W2 (ZC-06) — Project Member / Milestone / Channel / 聚合 领域模型
///
/// 后端契约（imboy W2 handler，TSID 以 JSON integer 传输）：
/// - project_member 行（JOIN user 展示列）：
///   `{workspace_id, project_id, user_id, invited_by, joined_at, status,
///   nickname, avatar, account}`（invite 返回行无 JOIN 列，宽容缺省）；
/// - milestone 行：`{id, workspace_id, project_id, name,
///   due_date(YYYY-MM-DD|null), status(planned|reached), reached_at,
///   created_at, updated_at}`；列表 envelope 仅 `{list, page, size}`
///   （无 total/total_page，[WorkspacePageResult] 兜 0）；
/// - 项目关联频道行：`{channel_id, workspace_id, linked_at, name, avatar,
///   channel_status}`；
/// - project.links 元素：`{name, url}`（resources 聚合原样返回）；
/// - Pinned / Related Posts 摘要行：`{id, channel_id, author_id,
///   author_name(pinned 独有), msg_type, created_at}`（有界摘要，无正文）；
/// - Activity 事件行：`{id, event_type, actor_id, target_id, payload,
///   created_at}`（payload 正文键已由服务端清洗）。
///
/// TSID 约定：与 WP5/W0 一致，64-bit ID 一律以 [EntityId]（String）持有，
/// 经 [entityIdOf] 安全解析（int/num/String 均可入，绝不丢精度回转 int）。
library;

import 'model_parse_utils.dart';
import 'workspace_model.dart';

export 'workspace_model.dart' show EntityId;

/// 项目成员行（project_member + user 展示列）。
class ProjectMemberModel {
  final EntityId workspaceId;
  final EntityId projectId;
  final EntityId userId;
  final EntityId invitedBy;
  final String joinedAtText;
  final String status;
  final String nickname;
  final String avatar;
  final String account;

  const ProjectMemberModel({
    required this.workspaceId,
    required this.projectId,
    required this.userId,
    this.invitedBy = '',
    this.joinedAtText = '',
    this.status = 'active',
    this.nickname = '',
    this.avatar = '',
    this.account = '',
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      workspaceId: entityIdOf(json['workspace_id']),
      projectId: entityIdOf(json['project_id']),
      userId: entityIdOf(json['user_id']),
      invitedBy: entityIdOf(json['invited_by']),
      joinedAtText: parseModelString(json['joined_at']),
      status: parseModelString(json['status'], defaultValue: 'active'),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      account: parseModelString(json['account']),
    );
  }

  bool get isActive => status == 'active';

  /// 展示名：nickname 优先，回落 account，再回落 userId。
  String get displayName =>
      nickname.isNotEmpty ? nickname : (account.isNotEmpty ? account : userId);
}

/// 里程碑状态（后端 milestone.status：planned|reached；单向 planned→reached，
/// 唯一流转入口为 POST /milestones/:id/reach，重复 reach 幂等）。
enum MilestoneStatus {
  planned('planned'),
  reached('reached');

  final String wireName;

  const MilestoneStatus(this.wireName);

  static MilestoneStatus parse(dynamic raw) {
    return raw == MilestoneStatus.reached.wireName
        ? MilestoneStatus.reached
        : MilestoneStatus.planned;
  }

  /// planned 可推进 reached；reached 单向终态，不可回退。
  bool get canAdvance => this == MilestoneStatus.planned;
}

/// 里程碑行（轻量计划实体：name/due_date/status + reached_at 审计）。
class MilestoneModel {
  final EntityId id;
  final EntityId workspaceId;
  final EntityId projectId;
  final String name;

  /// 'YYYY-MM-DD'；未设置（后端 null）为空串。
  final String dueDateText;
  final MilestoneStatus status;
  final String reachedAtText;
  final String createdAtText;
  final String updatedAtText;

  const MilestoneModel({
    required this.id,
    required this.projectId,
    required this.name,
    this.workspaceId = '',
    this.dueDateText = '',
    this.status = MilestoneStatus.planned,
    this.reachedAtText = '',
    this.createdAtText = '',
    this.updatedAtText = '',
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      id: entityIdOf(json['id']),
      workspaceId: entityIdOf(json['workspace_id']),
      projectId: entityIdOf(json['project_id']),
      name: parseModelString(json['name']),
      dueDateText: parseModelString(json['due_date']),
      status: MilestoneStatus.parse(json['status']),
      reachedAtText: parseModelString(json['reached_at']),
      createdAtText: parseModelString(json['created_at']),
      updatedAtText: parseModelString(json['updated_at']),
    );
  }

  bool get isReached => status == MilestoneStatus.reached;
}

/// 项目关联频道行（project_channel_rel JOIN channel）。
class ProjectChannelModel {
  final EntityId channelId;
  final EntityId workspaceId;
  final String name;
  final String avatar;

  /// 关联时间（rel.created_at）。
  final String linkedAtText;

  /// 频道自身状态（active|…，透传展示）。
  final String channelStatus;

  const ProjectChannelModel({
    required this.channelId,
    required this.workspaceId,
    this.name = '',
    this.avatar = '',
    this.linkedAtText = '',
    this.channelStatus = 'active',
  });

  factory ProjectChannelModel.fromJson(Map<String, dynamic> json) {
    return ProjectChannelModel(
      channelId: entityIdOf(json['channel_id']),
      workspaceId: entityIdOf(json['workspace_id']),
      name: parseModelString(json['name']),
      avatar: parseModelString(json['avatar']),
      linkedAtText: parseModelString(json['linked_at']),
      channelStatus: parseModelString(json['channel_status']),
    );
  }
}

/// 资源链接（project.links 元素；update-links 全量替换的最小形状）。
class ProjectLinkModel {
  final String name;
  final String url;

  const ProjectLinkModel({required this.name, required this.url});

  factory ProjectLinkModel.fromJson(Map<String, dynamic> json) {
    return ProjectLinkModel(
      name: parseModelString(json['name']),
      url: parseModelString(json['url']),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

/// 置顶消息 / 相关帖子 有界摘要行（元数据白名单，不含正文）。
class AggPostModel {
  final EntityId id;
  final EntityId channelId;
  final EntityId authorId;

  /// pinned 行独有；related_posts 行缺省空串。
  final String authorName;
  final String msgType;
  final String createdAtText;

  const AggPostModel({
    required this.id,
    required this.channelId,
    required this.authorId,
    this.authorName = '',
    this.msgType = '',
    this.createdAtText = '',
  });

  factory AggPostModel.fromJson(Map<String, dynamic> json) {
    return AggPostModel(
      id: entityIdOf(json['id']),
      channelId: entityIdOf(json['channel_id']),
      authorId: entityIdOf(json['author_id']),
      authorName: parseModelString(json['author_name']),
      msgType: parseModelString(json['msg_type']),
      createdAtText: parseModelString(json['created_at']),
    );
  }
}

/// 项目动态事件行（project_event；payload 正文键已由服务端清洗）。
class ActivityEventModel {
  final EntityId id;
  final String eventType;
  final EntityId actorId;
  final EntityId targetId;
  final Map<String, dynamic> payload;
  final String createdAtText;

  const ActivityEventModel({
    required this.id,
    required this.eventType,
    this.actorId = '',
    this.targetId = '',
    this.payload = const {},
    this.createdAtText = '',
  });

  factory ActivityEventModel.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    return ActivityEventModel(
      id: entityIdOf(json['id']),
      eventType: parseModelString(json['event_type']),
      actorId: entityIdOf(json['actor_id']),
      targetId: entityIdOf(json['target_id']),
      payload: payloadRaw is Map<String, dynamic> ? payloadRaw : const {},
      createdAtText: parseModelString(json['created_at']),
    );
  }
}
