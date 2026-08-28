/// WP6 (T10a/T10b) — Project / ProjectTask API 客户端（双体验 v2.5.2）
///
/// 契约源：imboy `project_handler.erl` / `project_task_handler.erl`
/// （全部 JWT 保护；TSID integer 传输）。错误语义透传：失败统一抛
/// [WorkspaceApiException]（与 workspace_api.dart 同一 envelope 约定），
/// `code` 携带服务端 code：
/// - 400 标题为空/超长、非法任务状态流转（消息含 from → to）、
///   assignee 非活跃工作区成员；
/// - 403 Guest / 非工作区成员；
/// - 404 项目或任务不存在；
/// - 980 工作区已归档（写守卫 workspace_guard）。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, WorkspacePageResult;

/// Project API 客户端（镜像 [WorkspaceApi] 模式：失败抛异常而非静默空值，
/// 页面据此渲染独立错误态与操作反馈 toast；禁止静默失败）。
class ProjectApi extends HttpClient {
  // ==================== Project（T10a） ====================

  /// 创建项目（Workspace Owner/Member；Guest/非成员 403；archived 980）。
  Future<ProjectModel> create({
    required EntityId workspaceId,
    required String name,
    String description = '',
  }) async {
    final resp = await post(
      '/api/v1/workspaces/$workspaceId/projects',
      data: {'name': name, 'description': description},
    );
    return _unwrap(resp, ProjectModel.fromJson, fallback: _emptyProject);
  }

  /// 项目列表分页（active 工作区成员可读；稳定排序 created_at DESC, id DESC）。
  Future<WorkspacePageResult<ProjectModel>> list(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    final resp = await get(
      '/api/v1/workspaces/$workspaceId/projects',
      queryParameters: {'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, ProjectModel.fromJson),
      fallback: const WorkspacePageResult<ProjectModel>(),
    );
  }

  /// 项目详情（active 工作区成员可读，W0 无成员端点）。
  Future<ProjectModel> detail(EntityId projectId) async {
    final resp = await get('/api/v1/projects/$projectId');
    return _unwrap(resp, ProjectModel.fromJson, fallback: _emptyProject);
  }

  /// 改名/描述（Owner/Member；Guest 403）。
  Future<ProjectModel> update(
    EntityId projectId, {
    String? name,
    String? description,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    final resp = await post('/api/v1/projects/$projectId/update', data: data);
    return _unwrap(resp, ProjectModel.fromJson, fallback: _emptyProject);
  }

  /// 状态流转 active⇄done（Owner/Member；Guest 403；archived 980）。
  Future<ProjectModel> updateStatus(
    EntityId projectId,
    ProjectStatus status,
  ) async {
    final resp = await post(
      '/api/v1/projects/$projectId/status',
      data: {'status': status.wireName},
    );
    return _unwrap(resp, ProjectModel.fromJson, fallback: _emptyProject);
  }

  // ==================== Project Task（T10b） ====================

  /// 创建任务（Owner/Member；Guest 403；assignee 必须是活跃工作区成员否则
  /// 400；同 project+creator+title 幂等返回既有任务，`statusFlag`=existing）。
  Future<TaskWriteResult> createTask({
    required EntityId projectId,
    required String title,
    EntityId? assigneeId,
    int sort = 0,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/tasks',
      data: {
        'title': title,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
        'sort': sort,
      },
    );
    final payload = _ensureOk(resp);
    return TaskWriteResult(
      task: _taskFrom(payload),
      statusFlag: parseModelString(
        payload['status_flag'],
        defaultValue: 'created',
      ),
    );
  }

  /// 任务列表（active 工作区成员可读；status=all|todo|doing|review|done）。
  ///
  /// 后端返回 `{list => [...]}`（数组直出，无分页 envelope），客户端按
  /// `size` 上限一次拉取后在 UI 分组/筛选。
  Future<List<ProjectTaskModel>> tasks(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 200,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/tasks',
      queryParameters: {'status': status, 'page': page, 'size': size},
    );
    _ensureOk(resp);
    final list = (resp.payload is Map<String, dynamic>)
        ? ((resp.payload as Map<String, dynamic>)['list'] as List?)
        : null;
    if (list == null) return const <ProjectTaskModel>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ProjectTaskModel.fromJson)
        .toList(growable: false);
  }

  /// 任务详情（active 工作区成员可读）。
  Future<ProjectTaskModel> taskDetail(EntityId taskId) async {
    final resp = await get('/api/v1/tasks/$taskId');
    return _unwrap(resp, _taskFrom, fallback: _emptyTask(''));
  }

  /// 更新任务 title/assignee/sort（assignee 变更同活跃成员校验 400）。
  ///
  /// [clearAssignee] 为 true 时传 `assignee_id: null`（后端 to_assignee(null)
  /// → 未指派）；[assigneeId] 非 null 时直接指派。二者同时给出以 clear 为准。
  Future<ProjectTaskModel> updateTask(
    EntityId taskId, {
    String? title,
    EntityId? assigneeId,
    bool clearAssignee = false,
    int? sort,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (clearAssignee) {
      data['assignee_id'] = null;
    } else if (assigneeId != null && assigneeId.isNotEmpty) {
      data['assignee_id'] = assigneeId;
    }
    if (sort != null) data['sort'] = sort;
    final resp = await post('/api/v1/tasks/$taskId/update', data: data);
    return _unwrap(resp, _taskFrom, fallback: _emptyTask(taskId));
  }

  /// 四态流转 + 回退（非法流转服务端 400，消息原样透出给 UI toast）。
  Future<ProjectTaskModel> changeTaskStatus(
    EntityId taskId,
    TaskStatus to,
  ) async {
    final resp = await post(
      '/api/v1/tasks/$taskId/status',
      data: {'status': to.wireName},
    );
    return _unwrap(resp, _taskFrom, fallback: _emptyTask(taskId));
  }

  // ==================== 内部：envelope 解包 ====================

  static const ProjectModel _emptyProject = ProjectModel(
    id: '',
    workspaceId: '',
    name: '',
    ownerId: '',
  );

  static ProjectTaskModel _emptyTask(EntityId id) =>
      ProjectTaskModel(id: id, projectId: '', title: '', creatorId: '');

  ProjectTaskModel _taskFrom(Map<String, dynamic> json) =>
      ProjectTaskModel.fromJson(json);

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

/// 任务写入结果（创建幂等标记 + 最终任务行）。
class TaskWriteResult {
  final ProjectTaskModel task;

  /// created | existing（幂等命中返回既有任务）。
  final String statusFlag;

  const TaskWriteResult({required this.task, this.statusFlag = 'created'});

  bool get isIdempotentHit => statusFlag == 'existing';
}
