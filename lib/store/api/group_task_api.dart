import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 群作业/任务 API 客户端
///
/// 负责与后端 API 通信，处理群作业相关的网络请求
class GroupTaskApi extends HttpClient {
  String _toTaskId(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _toAssignmentId(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _toRfc3339(int seconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toIso8601String();
  }

  Map<String, dynamic> _normalizeTask(Map<dynamic, dynamic> raw) {
    final task = Map<String, dynamic>.from(raw);
    final deadline = task['deadline'];
    if (deadline is String) {
      final parsed = DateTime.tryParse(deadline);
      if (parsed != null) {
        task['deadline'] = parsed.millisecondsSinceEpoch ~/ 1000;
      }
    } else if (deadline is num) {
      final value = deadline.toInt();
      task['deadline'] = value > 1000000000000 ? value ~/ 1000 : value;
    }
    return task;
  }

  List<Map<String, dynamic>> _parseListPayload(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(_normalizeTask).toList();
  }

  /// 创建任务
  Future<Map<String, dynamic>?> createTask({
    required String groupId,
    required String title,
    String? description,
    int? deadline,
    List<String>? assigneeIds,
  }) async {
    final data = <String, dynamic>{'group_id': groupId, 'title': title};
    if (description != null) data['description'] = description;
    if (deadline != null) data['deadline'] = _toRfc3339(deadline);
    if (assigneeIds != null) data['user_ids'] = assigneeIds;

    final resp = await post(API.groupTaskCreate, data: data);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    if (resp.payload is! Map) return null;
    return _normalizeTask(resp.payload as Map<dynamic, dynamic>);
  }

  /// 更新任务
  Future<bool> updateTask({
    required String groupId,
    required dynamic taskId,
    String? title,
    String? description,
    int? deadline,
    int? status,
  }) async {
    final taskIdText = _toTaskId(taskId);
    if (taskIdText.isEmpty) return false;

    final data = <String, dynamic>{'group_id': groupId, 'task_id': taskIdText};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (deadline != null) data['deadline'] = _toRfc3339(deadline);
    if (status != null) data['status'] = status;

    final resp = await post(API.groupTaskUpdate, data: data);
    return resp.ok;
  }

  /// 分配任务
  Future<bool> assignTask({
    required String groupId,
    required dynamic taskId,
    required List<String> assigneeIds,
  }) async {
    final taskIdText = _toTaskId(taskId);
    if (taskIdText.isEmpty) return false;

    final resp = await post(
      API.groupTaskAssign,
      data: {
        'group_id': groupId,
        'task_id': taskIdText,
        'user_ids': assigneeIds,
      },
    );
    return resp.ok;
  }

  /// 提交任务（执行者）
  Future<bool> submitTask({
    required String groupId,
    required dynamic taskId,
    String? content,
    List<String>? attachments,
  }) async {
    final taskIdText = _toTaskId(taskId);
    if (taskIdText.isEmpty) return false;

    final data = <String, dynamic>{'group_id': groupId, 'task_id': taskIdText};
    if (content != null) data['content'] = content;
    if (attachments != null) data['attachments'] = attachments;

    final resp = await post(API.groupTaskSubmit, data: data);
    return resp.ok;
  }

  /// 审核任务
  Future<bool> reviewTask({
    required String groupId,
    required dynamic taskId,
    required int status,
    String? comment,
  }) async {
    final assignmentIdText = _toAssignmentId(taskId);
    if (assignmentIdText.isEmpty) return false;

    final data = <String, dynamic>{
      'group_id': groupId,
      'assignment_id': assignmentIdText,
      'score': status,
    };
    if (comment != null) data['comment'] = comment;

    final resp = await post(API.groupTaskReview, data: data);
    return resp.ok;
  }

  /// 获取任务列表
  Future<List<Map<String, dynamic>>> getTasks({
    required String groupId,
    int? status,
    String? assigneeId,
    int page = 1,
    int size = 20,
  }) async {
    final query = <String, dynamic>{
      'group_id': groupId,
      'page': page,
      'size': size,
    };
    if (status != null) query['status'] = status;
    if (assigneeId != null) query['assignee_id'] = assigneeId;

    final resp = await get(API.groupTaskList, queryParameters: query);

    // 链路：group_task_page(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return [];
    }

    return _parseListPayload(resp.payload['list']);
  }

  /// 获取任务详情
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async {
    final taskIdText = _toTaskId(taskId);
    if (taskIdText.isEmpty) return null;

    final resp = await get(
      API.groupTaskDetail,
      queryParameters: {'group_id': groupId, 'task_id': taskIdText},
    );

    // 链路：group_task_detail_page(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return null;
    }

    if (resp.payload is! Map) return null;
    return _normalizeTask(resp.payload as Map<dynamic, dynamic>);
  }

  /// 获取我的任务
  Future<List<Map<String, dynamic>>> getMyTasks({
    int? status,
    int page = 1,
    int size = 20,
  }) async {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (status != null) query['status'] = status;

    final resp = await get(API.groupTaskMy, queryParameters: query);

    // 链路：group_task_page(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return [];
    }

    return _parseListPayload(resp.payload['list']);
  }

  /// 获取待审核任务
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async {
    final resp = await get(
      API.groupTaskPending,
      queryParameters: {'task_id': taskId, 'page': page, 'size': size},
    );

    // 链路：group_task_page(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return [];
    }

    return _parseListPayload(resp.payload['list']);
  }
}
