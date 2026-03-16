import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/group_task_api.dart';

/// 群作业/任务服务
///
/// 负责协调 API 和本地存储，处理群作业业务逻辑
///
/// Temporary compatibility wrapper for the group_collab module shell.
/// New callers should prefer `package:imboy/modules/group_collab/public.dart`.
class GroupTaskService {
  static final GroupTaskService to = GroupTaskService._privateConstructor();
  GroupTaskService._privateConstructor();

  final GroupTaskApi _api = GroupTaskApi();

  String _normalizeTaskId(dynamic taskId) {
    if (taskId == null) return '';
    return taskId.toString().trim();
  }

  // ==================== 任务创建与管理 ====================

  /// 创建任务
  Future<Map<String, dynamic>?> createTask({
    required String groupId,
    required String title,
    String? description,
    int? deadline,
    List<String>? assigneeIds,
  }) async {
    try {
      final result = await _api.createTask(
        groupId: groupId,
        title: title,
        description: description,
        deadline: deadline,
        assigneeIds: assigneeIds,
      );
      if (result != null) {
        iPrint('GroupTaskService: 创建任务成功 - $title');
        AppEventBus.fire(TaskCreatedEvent(groupId: groupId, data: result));
      }
      return result;
    } catch (e) {
      iPrint('GroupTaskService: 创建任务失败 - $e');
      return null;
    }
  }

  /// 获取任务详情
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async {
    try {
      return await _api.getTask(groupId: groupId, taskId: taskId);
    } catch (e) {
      iPrint('GroupTaskService: 获取任务详情失败 - $e');
      return null;
    }
  }

  /// 获取群任务列表
  Future<List<Map<String, dynamic>>> getTasks({
    required String groupId,
    int? status,
    String? assigneeId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getTasks(
        groupId: groupId,
        status: status,
        assigneeId: assigneeId,
        page: page,
        size: size,
      );
    } catch (e) {
      iPrint('GroupTaskService: 获取任务列表失败 - $e');
      return [];
    }
  }

  /// 获取我的任务列表
  Future<List<Map<String, dynamic>>> getMyTasks({
    int? status,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getMyTasks(status: status, page: page, size: size);
    } catch (e) {
      iPrint('GroupTaskService: 获取我的任务失败 - $e');
      return [];
    }
  }

  /// 获取待审核任务
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getPendingReview(
        taskId: taskId,
        page: page,
        size: size,
      );
    } catch (e) {
      iPrint('GroupTaskService: 获取待审核任务失败 - $e');
      return [];
    }
  }

  // ==================== 任务操作 ====================

  /// 更新任务
  Future<bool> updateTask({
    required String groupId,
    required dynamic taskId,
    String? title,
    String? description,
    int? deadline,
    int? status,
  }) async {
    try {
      final success = await _api.updateTask(
        groupId: groupId,
        taskId: taskId,
        title: title,
        description: description,
        deadline: deadline,
        status: status,
      );
      if (success) {
        iPrint('GroupTaskService: 更新任务成功 - $taskId');
        final taskIdText = _normalizeTaskId(taskId);
        AppEventBus.fire(
          TaskUpdatedEvent(groupId: groupId, taskId: taskIdText),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupTaskService: 更新任务失败 - $e');
      return false;
    }
  }

  /// 分配任务给成员
  Future<bool> assignTask({
    required String groupId,
    required dynamic taskId,
    required List<String> assigneeIds,
  }) async {
    try {
      final success = await _api.assignTask(
        groupId: groupId,
        taskId: taskId,
        assigneeIds: assigneeIds,
      );
      if (success) {
        iPrint('GroupTaskService: 分配任务成功 - $taskId');
        final taskIdText = _normalizeTaskId(taskId);
        AppEventBus.fire(
          TaskAssignedEvent(
            groupId: groupId,
            taskId: taskIdText,
            assigneeIds: assigneeIds,
          ),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupTaskService: 分配任务失败 - $e');
      return false;
    }
  }

  /// 提交任务（执行者）
  Future<bool> submitTask({
    required String groupId,
    required dynamic taskId,
    String? content,
    List<String>? attachments,
  }) async {
    try {
      final success = await _api.submitTask(
        groupId: groupId,
        taskId: taskId,
        content: content,
        attachments: attachments,
      );
      if (success) {
        iPrint('GroupTaskService: 提交任务成功 - $taskId');
        final taskIdText = _normalizeTaskId(taskId);
        AppEventBus.fire(
          TaskSubmittedEvent(groupId: groupId, taskId: taskIdText),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupTaskService: 提交任务失败 - $e');
      return false;
    }
  }

  /// 审核任务
  Future<bool> reviewTask({
    required String groupId,
    required dynamic taskId,
    required int status,
    String? comment,
  }) async {
    try {
      final success = await _api.reviewTask(
        groupId: groupId,
        taskId: taskId,
        status: status,
        comment: comment,
      );
      if (success) {
        iPrint('GroupTaskService: 审核任务成功 - $taskId');
        final taskIdText = _normalizeTaskId(taskId);
        AppEventBus.fire(
          TaskReviewedEvent(
            groupId: groupId,
            taskId: taskIdText,
            status: status,
          ),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupTaskService: 审核任务失败 - $e');
      return false;
    }
  }

  // ==================== WebSocket 消息处理 ====================

  /// 处理 WebSocket 推送的新任务消息
  Future<void> handleNewTask(Map<String, dynamic> data) async {
    try {
      final groupId = data['group_id'];
      final taskId = data['task_id'];
      iPrint('GroupTaskService: 收到新任务 - $taskId, 群: $groupId');
      AppEventBus.fire(NewTaskEvent(data: data));
    } catch (e) {
      iPrint('GroupTaskService: 处理新任务消息失败 - $e');
    }
  }

  /// 处理任务分配通知
  Future<void> handleTaskAssigned(Map<String, dynamic> data) async {
    try {
      final taskId = data['task_id'];
      final assigneeIds = data['assignee_ids'];
      iPrint('GroupTaskService: 任务已分配 - $taskId 给 $assigneeIds');
      AppEventBus.fire(TaskAssignedNotification(data: data));
    } catch (e) {
      iPrint('GroupTaskService: 处理任务分配通知失败 - $e');
    }
  }

  /// 处理任务截止提醒
  Future<void> handleTaskDeadlineReminder(Map<String, dynamic> data) async {
    try {
      final taskId = data['task_id'];
      final title = data['title'];
      iPrint('GroupTaskService: 任务截止提醒 - $taskId, $title');
      AppEventBus.fire(TaskDeadlineReminderEvent(data: data));
    } catch (e) {
      iPrint('GroupTaskService: 处理任务截止提醒失败 - $e');
    }
  }
}

/// 任务创建事件
class TaskCreatedEvent extends AppEvent {
  final String groupId;
  final Map<String, dynamic> data;
  const TaskCreatedEvent({required this.groupId, required this.data});

  @override
  List<Object?> get props => [groupId, data];
}

/// 任务更新事件
class TaskUpdatedEvent extends AppEvent {
  final String groupId;
  final String taskId;
  const TaskUpdatedEvent({required this.groupId, required this.taskId});

  @override
  List<Object?> get props => [groupId, taskId];
}

/// 任务分配事件
class TaskAssignedEvent extends AppEvent {
  final String groupId;
  final String taskId;
  final List<String> assigneeIds;
  const TaskAssignedEvent({
    required this.groupId,
    required this.taskId,
    required this.assigneeIds,
  });

  @override
  List<Object?> get props => [groupId, taskId, assigneeIds];
}

/// 任务提交事件
class TaskSubmittedEvent extends AppEvent {
  final String groupId;
  final String taskId;
  const TaskSubmittedEvent({required this.groupId, required this.taskId});

  @override
  List<Object?> get props => [groupId, taskId];
}

/// 任务审核事件
class TaskReviewedEvent extends AppEvent {
  final String groupId;
  final String taskId;
  final int status;
  const TaskReviewedEvent({
    required this.groupId,
    required this.taskId,
    required this.status,
  });

  @override
  List<Object?> get props => [groupId, taskId, status];
}

/// 新任务事件（WebSocket 推送）
class NewTaskEvent extends AppEvent {
  final Map<String, dynamic> data;
  const NewTaskEvent({required this.data});

  @override
  List<Object?> get props => [data];
}

/// 任务分配通知
class TaskAssignedNotification extends AppEvent {
  final Map<String, dynamic> data;
  const TaskAssignedNotification({required this.data});

  @override
  List<Object?> get props => [data];
}

/// 任务截止提醒事件
class TaskDeadlineReminderEvent extends AppEvent {
  final Map<String, dynamic> data;
  const TaskDeadlineReminderEvent({required this.data});

  @override
  List<Object?> get props => [data];
}
