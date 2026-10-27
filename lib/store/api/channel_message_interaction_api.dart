import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// Message reactions use ChannelApi's overridable transport.
mixin ChannelMessageInteractionApi on HttpClient {
  /// 添加消息反应
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/reaction',
      data: {'reaction_type': reactionType},
    );
    if (!resp.ok) {
      // 透出后端中文原因（如"消息已删除"），页面层不再叠兜底文案
      AppLoading.showBackendError(resp.msg);
      return false;
    }
    return true;
  }

  /// 移除消息反应
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await delete(
      '/api/v1/channel/$channelId/message/$messageId/reaction/$reactionType',
    );
    if (!resp.ok) {
      AppLoading.showBackendError(resp.msg);
      return false;
    }
    return true;
  }
}
