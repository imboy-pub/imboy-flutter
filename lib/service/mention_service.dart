import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/mention_api.dart';

/// Temporary compatibility service for the social graph module shell.
/// New upper-layer imports should prefer `package:imboy/modules/social_graph/public.dart`.
/// @提及服务
///
/// 负责协调 API 和本地存储，处理@提及业务逻辑
class MentionService {
  static final MentionService to = MentionService._privateConstructor();
  MentionService._privateConstructor();

  final MentionApi _api = MentionApi();

  // ==================== 查询操作 ====================

  /// 获取@提及我的消息列表
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async {
    try {
      return await _api.getMentions(
        page: page,
        size: size,
        isRead: isRead,
        groupId: groupId,
      );
    } catch (e) {
      iPrint('MentionService: 获取@提及列表失败 - $e');
      return null;
    }
  }

  /// 获取@提及建议（输入@时调用）
  Future<List<Map<String, dynamic>>> getSuggest({
    required String groupId,
    required String keyword,
    int limit = 10,
  }) async {
    try {
      return await _api.getSuggest(
        groupId: groupId,
        keyword: keyword,
        limit: limit,
      );
    } catch (e) {
      iPrint('MentionService: 获取@提及建议失败 - $e');
      return [];
    }
  }

  // ==================== 状态更新 ====================

  /// 标记@提及为已读
  Future<bool> markAsRead(int mentionId) async {
    try {
      final success = await _api.markAsRead(mentionId);
      if (success) {
        iPrint('MentionService: 标记已读 - $mentionId');
        // 通知 UI 刷新
        AppEventBus.fire(MentionReadEvent(mentionId: mentionId));
      }
      return success;
    } catch (e) {
      iPrint('MentionService: 标记已读失败 - $e');
      return false;
    }
  }

  /// 批量标记@提及为已读
  Future<bool> markAllAsRead({String? groupId}) async {
    try {
      final success = await _api.markAllAsRead(groupId: groupId);
      if (success) {
        iPrint('MentionService: 批量标记已读');
        AppEventBus.fire(MentionAllReadEvent(groupId: groupId));
      }
      return success;
    } catch (e) {
      iPrint('MentionService: 批量标记已读失败 - $e');
      return false;
    }
  }

  // ==================== 统计 ====================

  /// 获取未读@提及数量
  Future<int> getUnreadCount({String? groupId}) async {
    try {
      return await _api.getUnreadCount(groupId: groupId);
    } catch (e) {
      iPrint('MentionService: 获取未读数量失败 - $e');
      return 0;
    }
  }

  // ==================== WebSocket 消息处理 ====================

  /// 处理 WebSocket 推送的@提及消息
  Future<void> handleMentionMessage(Map<String, dynamic> data) async {
    try {
      final mentionId = data['id'];
      final groupId = data['group_id'];
      final msgId = data['msg_id'];

      iPrint('MentionService: 收到@提及 - $mentionId, 群: $groupId, 消息: $msgId');

      // 发送事件通知 UI 刷新
      AppEventBus.fire(NewMentionEvent(data: data));
    } catch (e) {
      iPrint('MentionService: 处理@提及消息失败 - $e');
    }
  }
}

/// @提及事件
class NewMentionEvent extends AppEvent {
  final Map<String, dynamic> data;
  const NewMentionEvent({required this.data});

  @override
  List<Object?> get props => [data];
}

/// @提及已读事件
class MentionReadEvent extends AppEvent {
  final int mentionId;
  const MentionReadEvent({required this.mentionId});

  @override
  List<Object?> get props => [mentionId];
}

/// @提及全部已读事件
class MentionAllReadEvent extends AppEvent {
  final String? groupId;
  const MentionAllReadEvent({this.groupId});

  @override
  List<Object?> get props => [groupId];
}
