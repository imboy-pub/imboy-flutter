/// WP6 (T10a/T10b) — Project / ProjectTask 领域模型（双体验 v2.5.2）
///
/// 后端契约（imboy `project_handler.erl` / `project_task_handler.erl`，
/// TSID 以 JSON integer 传输）：
/// - project 行：`{id, workspace_id, name, description, owner_id,
///   status(active|done), created_at, updated_at}`；
///   W0 无 members / Pinned / Resources / Activity / 关联 Channel 端点
///   （Gate W Scope Contract：defer = 无 schema 无占位 UI）。
/// - project_task 行：`{id, project_id, title, creator_id, assignee_id(可空),
///   status(todo|doing|review|done), sort, created_at, updated_at}`。
///
/// TSID 约定：与 WP5 一致，64-bit ID 一律以 [EntityId]（String）持有，
/// 经 [entityIdOf] 安全解析（int/num/String 均可入，绝不丢精度回转 int）。
library;

import 'model_parse_utils.dart';
import 'workspace_model.dart';

export 'workspace_model.dart' show EntityId;

/// Project 状态（后端 project.status：active|done；回退允许 done→active）。
enum ProjectStatus {
  active('active'),
  done('done');

  final String wireName;

  const ProjectStatus(this.wireName);

  static ProjectStatus parse(dynamic raw) {
    return raw == ProjectStatus.done.wireName
        ? ProjectStatus.done
        : ProjectStatus.active;
  }

  bool get isDone => this == ProjectStatus.done;
}

/// Task 四态状态机（§三 边界：Task 只有 title/assignee/status/排序）。
///
/// 契约源 imboy `project_task_logic.erl`：
/// - 前向仅相邻一步：todo→doing→review→done（rank +1）
/// - 回退任意：done→review/doing/todo、review→doing/todo、doing→todo
/// - 同态与跳级前向均为非法（服务端 400：非法任务状态流转 from → to）。
enum TaskStatus {
  todo('todo', 1),
  doing('doing', 2),
  review('review', 3),
  done('done', 4);

  final String wireName;

  /// rank 与后端 ?TASK_STATUS_RANK 对齐（前向判定/回退候选排序用）。
  final int rank;

  const TaskStatus(this.wireName, this.rank);

  static TaskStatus? tryParse(dynamic raw) {
    final s = raw is String ? raw : raw?.toString() ?? '';
    for (final v in TaskStatus.values) {
      if (v.wireName == s) return v;
    }
    return null;
  }

  /// 是否允许 from → this 的流转（镜像后端 legal_transition/2）。
  ///
  /// 前向仅相邻一步；回退任意低 rank；同态非法。
  bool canTransitionFrom(TaskStatus from) {
    if (from == this) return false;
    return rank == from.rank + 1 || rank < from.rank;
  }

  /// 前向相邻一步的目标态（done 无前向 → null）。
  TaskStatus? get nextForward {
    for (final v in TaskStatus.values) {
      if (v.canTransitionFrom(this) && v.rank > rank) return v;
    }
    return null;
  }

  /// 回退候选（全部更低 rank 态，按 rank 升序）。
  List<TaskStatus> get fallbackTargets {
    return TaskStatus.values.where((v) => v.rank < rank).toList();
  }
}

/// Project 模型（W0 最小字段集）。
class ProjectModel {
  final EntityId id;
  final EntityId workspaceId;
  final String name;
  final String description;
  final EntityId ownerId;
  final ProjectStatus status;
  final String createdAtText;
  final String updatedAtText;

  const ProjectModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description = '',
    required this.ownerId,
    this.status = ProjectStatus.active,
    this.createdAtText = '',
    this.updatedAtText = '',
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: entityIdOf(json['id']),
      workspaceId: entityIdOf(json['workspace_id']),
      name: parseModelString(json['name']),
      description: parseModelString(json['description']),
      ownerId: entityIdOf(json['owner_id']),
      status: ProjectStatus.parse(json['status']),
      createdAtText: parseModelString(json['created_at']),
      updatedAtText: parseModelString(json['updated_at']),
    );
  }

  bool get isActive => status == ProjectStatus.active;
}

/// Project Task 模型（轻量执行实体：title/assignee/status/sort）。
class ProjectTaskModel {
  final EntityId id;
  final EntityId projectId;
  final String title;
  final EntityId creatorId;

  /// 未指派为空串（后端 assignee_id 可空列）。
  final EntityId assigneeId;
  final TaskStatus status;
  final int sort;
  final String createdAtText;
  final String updatedAtText;

  const ProjectTaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.creatorId,
    this.assigneeId = '',
    this.status = TaskStatus.todo,
    this.sort = 0,
    this.createdAtText = '',
    this.updatedAtText = '',
  });

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
    return ProjectTaskModel(
      id: entityIdOf(json['id']),
      projectId: entityIdOf(json['project_id']),
      title: parseModelString(json['title']),
      creatorId: entityIdOf(json['creator_id']),
      assigneeId: entityIdOf(json['assignee_id']),
      status: TaskStatus.tryParse(json['status']) ?? TaskStatus.todo,
      sort: parseModelInt(json['sort']),
      createdAtText: parseModelString(json['created_at']),
      updatedAtText: parseModelString(json['updated_at']),
    );
  }

  bool get hasAssignee => assigneeId.isNotEmpty;
}
