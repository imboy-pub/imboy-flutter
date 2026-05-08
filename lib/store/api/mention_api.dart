import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// @提及 API 客户端
///
/// 负责与后端 API 通信，处理@提及相关的网络请求
class MentionApi extends HttpClient {
  /// 获取@提及我的消息列表
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async {
    final data = <String, dynamic>{'page': page, 'size': size};
    if (isRead != null) data['is_read'] = isRead;
    if (groupId != null) data['group_id'] = groupId;

    final resp = await post(API.mentionList, data: data);
    debugPrint("MentionApi_getMentions resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload;
  }

  /// 获取未读@提及数量
  Future<int> getUnreadCount({String? groupId}) async {
    final data = <String, dynamic>{};
    if (groupId != null) data['group_id'] = groupId;

    final resp = await post(API.mentionUnread, data: data);
    debugPrint("MentionApi_getUnreadCount resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return 0;
    }

    return resp.payload['count'] ?? 0;
  }

  /// 标记@提及为已读
  Future<bool> markAsRead(int mentionId) async {
    final resp = await post(
      API.mentionMarkRead,
      data: {'mention_id': mentionId},
    );
    debugPrint("MentionApi_markAsRead resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 批量标记@提及为已读
  Future<bool> markAllAsRead({String? groupId}) async {
    final data = <String, dynamic>{'all': true};
    if (groupId != null) data['group_id'] = groupId;

    final resp = await post(API.mentionMarkRead, data: data);
    debugPrint("MentionApi_markAllAsRead resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 获取@提及建议（输入@时调用）
  Future<List<Map<String, dynamic>>> getSuggest({
    required String groupId,
    required String keyword,
    int limit = 10,
  }) async {
    final resp = await post(
      API.mentionSuggest,
      data: {'group_id': groupId, 'keyword': keyword, 'limit': limit},
    );
    debugPrint("MentionApi_getSuggest resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['items'] as List?;
    if (list == null) return [];

    return List<Map<String, dynamic>>.from(list);
  }
}
