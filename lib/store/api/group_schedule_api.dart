import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 群日程 API 客户端
///
/// 负责与后端 API 通信，处理群日程相关的网络请求
class GroupScheduleApi extends HttpClient {
  String _toScheduleId(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  int? _toEpochSeconds(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      if (value > 1000000000000) return value ~/ 1000;
      return value;
    }
    if (value is String) {
      final numVal = int.tryParse(value);
      if (numVal != null) {
        if (numVal > 1000000000000) return numVal ~/ 1000;
        return numVal;
      }
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return dt.millisecondsSinceEpoch ~/ 1000;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeSchedule(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final start = _toEpochSeconds(map['start_time'] ?? map['start_at']);
    final end = _toEpochSeconds(map['end_time'] ?? map['end_at']);
    if (start != null) {
      map['start_time'] = start;
      map['start_at'] ??= start;
    }
    if (end != null) {
      map['end_time'] = end;
      map['end_at'] ??= end;
    }
    return map;
  }

  List<Map<String, dynamic>> _normalizeScheduleList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => _normalizeSchedule(Map<String, dynamic>.from(item)))
        .toList();
  }

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
    final normalizedEndTime = endTime ?? (startTime + 3600);
    final data = <String, dynamic>{
      'group_id': groupId,
      'title': title,
      'start_at': startTime,
      'end_at': normalizedEndTime,
    };
    if (description != null) data['description'] = description;
    if (location != null) data['location'] = location;
    if (remindBefore != null) data['remind_before'] = remindBefore;

    final resp = await post(API.groupScheduleCreate, data: data);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return _normalizeSchedule(Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>));
  }

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
    final scheduleIdText = _toScheduleId(scheduleId);
    if (scheduleIdText.isEmpty) return false;

    final data = <String, dynamic>{
      'group_id': groupId,
      'schedule_id': scheduleIdText,
    };
    if (title != null) data['title'] = title;
    if (startTime != null) data['start_at'] = startTime;
    if (endTime != null) data['end_at'] = endTime;
    if (description != null) data['description'] = description;
    if (location != null) data['location'] = location;
    if (remindBefore != null) data['remind_before'] = remindBefore;

    final resp = await post(API.groupScheduleUpdate, data: data);
    return resp.ok;
  }

  /// 取消日程
  Future<bool> cancelSchedule({
    required String groupId,
    required dynamic scheduleId,
  }) async {
    final scheduleIdText = _toScheduleId(scheduleId);
    if (scheduleIdText.isEmpty) return false;

    final resp = await post(
      API.groupScheduleCancel,
      data: {'group_id': groupId, 'schedule_id': scheduleIdText},
    );
    return resp.ok;
  }

  /// 获取日程详情
  Future<Map<String, dynamic>?> getSchedule({
    required String groupId,
    required dynamic scheduleId,
  }) async {
    final scheduleIdText = _toScheduleId(scheduleId);
    if (scheduleIdText.isEmpty) return null;

    final resp = await get(
      API.groupScheduleDetail,
      queryParameters: {'group_id': groupId, 'schedule_id': scheduleIdText},
    );

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    final payload = Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
    final schedule = payload['schedule'];
    if (schedule is Map<String, dynamic>) {
      payload['schedule'] = _normalizeSchedule(
        Map<String, dynamic>.from(schedule),
      );
      return payload;
    }
    return _normalizeSchedule(payload);
  }

  /// 获取群日程列表
  Future<List<Map<String, dynamic>>> getSchedules({
    required String groupId,
    int? startTime,
    int? endTime,
    int page = 1,
    int size = 20,
  }) async {
    final query = <String, dynamic>{
      'group_id': groupId,
      'page': page,
      'size': size,
    };
    if (startTime != null) query['start_at'] = startTime;
    if (endTime != null) query['end_at'] = endTime;

    final resp = await get(API.groupScheduleList, queryParameters: query);

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeScheduleList(resp.payload['list']);
  }

  /// 获取我的日程列表
  Future<List<Map<String, dynamic>>> getMySchedules({
    int? startTime,
    int? endTime,
    int page = 1,
    int size = 20,
  }) async {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (startTime != null) query['start_at'] = startTime;
    if (endTime != null) query['end_at'] = endTime;

    final resp = await get(API.groupScheduleMyList, queryParameters: query);

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeScheduleList(resp.payload['list']);
  }

  /// 确认参加日程
  Future<bool> confirmSchedule({
    required String groupId,
    required dynamic scheduleId,
    required bool confirm,
  }) async {
    final scheduleIdText = _toScheduleId(scheduleId);
    if (scheduleIdText.isEmpty) return false;

    final resp = await post(
      API.groupScheduleConfirm,
      data: {
        'group_id': groupId,
        'schedule_id': scheduleIdText,
        'accept': confirm,
      },
    );
    return resp.ok;
  }
}
