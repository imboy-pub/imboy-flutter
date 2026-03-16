import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/group_schedule_api.dart';

/// 群日程服务
///
/// 负责协调 API 和本地存储，处理群日程业务逻辑
///
/// Temporary compatibility wrapper for the group_collab module shell.
/// New callers should prefer `package:imboy/modules/group_collab/public.dart`.
class GroupScheduleService {
  static final GroupScheduleService to =
      GroupScheduleService._privateConstructor();
  GroupScheduleService._privateConstructor();

  final GroupScheduleApi _api = GroupScheduleApi();

  String _normalizeScheduleId(dynamic scheduleId) {
    if (scheduleId == null) return '';
    return scheduleId.toString().trim();
  }

  // ==================== 日程创建与管理 ====================

  /// 创建日程
  Future<Map<String, dynamic>?> createSchedule({
    required String groupId,
    required String title,
    required int startTime,
    int? endTime,
    String? description,
    String? location,
    int? remindBefore,
  }) async {
    try {
      final result = await _api.createSchedule(
        groupId: groupId,
        title: title,
        startTime: startTime,
        endTime: endTime,
        description: description,
        location: location,
        remindBefore: remindBefore,
      );
      if (result != null) {
        iPrint('GroupScheduleService: 创建日程成功 - $title');
        AppEventBus.fire(ScheduleCreatedEvent(groupId: groupId, data: result));
      }
      return result;
    } catch (e) {
      iPrint('GroupScheduleService: 创建日程失败 - $e');
      return null;
    }
  }

  /// 获取日程详情
  Future<Map<String, dynamic>?> getSchedule({
    required String groupId,
    required dynamic scheduleId,
  }) async {
    try {
      return await _api.getSchedule(groupId: groupId, scheduleId: scheduleId);
    } catch (e) {
      iPrint('GroupScheduleService: 获取日程详情失败 - $e');
      return null;
    }
  }

  /// 获取群日程列表
  Future<List<Map<String, dynamic>>> getSchedules({
    required String groupId,
    int? startTime,
    int? endTime,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getSchedules(
        groupId: groupId,
        startTime: startTime,
        endTime: endTime,
        page: page,
        size: size,
      );
    } catch (e) {
      iPrint('GroupScheduleService: 获取日程列表失败 - $e');
      return [];
    }
  }

  /// 获取我的日程列表
  Future<List<Map<String, dynamic>>> getMySchedules({
    int? startTime,
    int? endTime,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getMySchedules(
        startTime: startTime,
        endTime: endTime,
        page: page,
        size: size,
      );
    } catch (e) {
      iPrint('GroupScheduleService: 获取我的日程失败 - $e');
      return [];
    }
  }

  // ==================== 日程操作 ====================

  /// 更新日程
  Future<bool> updateSchedule({
    required String groupId,
    required dynamic scheduleId,
    String? title,
    int? startTime,
    int? endTime,
    String? description,
    String? location,
    int? remindBefore,
  }) async {
    try {
      final success = await _api.updateSchedule(
        groupId: groupId,
        scheduleId: scheduleId,
        title: title,
        startTime: startTime,
        endTime: endTime,
        description: description,
        location: location,
        remindBefore: remindBefore,
      );
      if (success) {
        iPrint('GroupScheduleService: 更新日程成功 - $scheduleId');
        final scheduleIdText = _normalizeScheduleId(scheduleId);
        AppEventBus.fire(
          ScheduleUpdatedEvent(groupId: groupId, scheduleId: scheduleIdText),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupScheduleService: 更新日程失败 - $e');
      return false;
    }
  }

  /// 取消日程
  Future<bool> cancelSchedule({
    required String groupId,
    required dynamic scheduleId,
  }) async {
    try {
      final success = await _api.cancelSchedule(
        groupId: groupId,
        scheduleId: scheduleId,
      );
      if (success) {
        iPrint('GroupScheduleService: 取消日程成功 - $scheduleId');
        final scheduleIdText = _normalizeScheduleId(scheduleId);
        AppEventBus.fire(
          ScheduleCanceledEvent(groupId: groupId, scheduleId: scheduleIdText),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupScheduleService: 取消日程失败 - $e');
      return false;
    }
  }

  /// 确认参加日程
  Future<bool> confirmSchedule({
    required String groupId,
    required dynamic scheduleId,
    required bool confirm,
  }) async {
    try {
      final success = await _api.confirmSchedule(
        groupId: groupId,
        scheduleId: scheduleId,
        confirm: confirm,
      );
      if (success) {
        iPrint('GroupScheduleService: 确认日程成功 - $scheduleId, $confirm');
        final scheduleIdText = _normalizeScheduleId(scheduleId);
        AppEventBus.fire(
          ScheduleConfirmedEvent(
            groupId: groupId,
            scheduleId: scheduleIdText,
            confirm: confirm,
          ),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupScheduleService: 确认日程失败 - $e');
      return false;
    }
  }

  // ==================== WebSocket 消息处理 ====================

  /// 处理 WebSocket 推送的新日程消息
  Future<void> handleNewSchedule(Map<String, dynamic> data) async {
    try {
      final groupId = data['group_id'];
      final scheduleId = data['schedule_id'];
      iPrint('GroupScheduleService: 收到新日程 - $scheduleId, 群: $groupId');
      AppEventBus.fire(NewScheduleEvent(data: data));
    } catch (e) {
      iPrint('GroupScheduleService: 处理新日程消息失败 - $e');
    }
  }

  /// 处理日程提醒
  Future<void> handleScheduleReminder(Map<String, dynamic> data) async {
    try {
      final scheduleId = data['schedule_id'];
      final title = data['title'];
      iPrint('GroupScheduleService: 日程提醒 - $scheduleId, $title');
      AppEventBus.fire(ScheduleReminderEvent(data: data));
    } catch (e) {
      iPrint('GroupScheduleService: 处理日程提醒失败 - $e');
    }
  }
}

/// 日程创建事件
class ScheduleCreatedEvent extends AppEvent {
  final String groupId;
  final Map<String, dynamic> data;
  const ScheduleCreatedEvent({required this.groupId, required this.data});

  @override
  List<Object?> get props => [groupId, data];
}

/// 日程更新事件
class ScheduleUpdatedEvent extends AppEvent {
  final String groupId;
  final String scheduleId;
  const ScheduleUpdatedEvent({required this.groupId, required this.scheduleId});

  @override
  List<Object?> get props => [groupId, scheduleId];
}

/// 日程取消事件
class ScheduleCanceledEvent extends AppEvent {
  final String groupId;
  final String scheduleId;
  const ScheduleCanceledEvent({
    required this.groupId,
    required this.scheduleId,
  });

  @override
  List<Object?> get props => [groupId, scheduleId];
}

/// 日程确认事件
class ScheduleConfirmedEvent extends AppEvent {
  final String groupId;
  final String scheduleId;
  final bool confirm;
  const ScheduleConfirmedEvent({
    required this.groupId,
    required this.scheduleId,
    required this.confirm,
  });

  @override
  List<Object?> get props => [groupId, scheduleId, confirm];
}

/// 新日程事件（WebSocket 推送）
class NewScheduleEvent extends AppEvent {
  final Map<String, dynamic> data;
  const NewScheduleEvent({required this.data});

  @override
  List<Object?> get props => [data];
}

/// 日程提醒事件
class ScheduleReminderEvent extends AppEvent {
  final Map<String, dynamic> data;
  const ScheduleReminderEvent({required this.data});

  @override
  List<Object?> get props => [data];
}
