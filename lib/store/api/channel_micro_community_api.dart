import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/channel_message_model.dart';

import 'channel_micro_community_policy.dart';
import 'channel_results.dart';

/// Requests share ChannelApi's HttpClient and its overridable transport methods.
mixin ChannelMicroCommunityApi on HttpClient {
  static void _requireMicroCommunity() {
    if (!ChannelMicroCommunityPolicy.enabled) {
      throw StateError('micro-community unavailable');
    }
  }

  Future<int?> getDiscussion(String channelId) async {
    _requireMicroCommunity();
    final response = await get('/api/v1/channel/$channelId/discussion');
    response.throwIfFailed();
    final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
    if (!payload.containsKey('discussion_group_id')) {
      throw const FormatException('missing discussion binding');
    }
    if (payload['discussion_group_id'] == null) return null;
    final id = IMBoyHttpResponse.payloadInt(payload, 'discussion_group_id');
    if (id == null || id <= 0) {
      throw const FormatException('invalid discussion binding');
    }
    return id;
  }

  /// Explicit user action only; neither subscribe nor getDiscussion calls this.
  Future<Map<String, dynamic>> joinDiscussion(String channelId) async {
    _requireMicroCommunity();
    final response = await post('/api/v1/channel/$channelId/discussion/join');
    response.throwIfFailed();
    final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
    if ((IMBoyHttpResponse.payloadInt(payload, 'discussion_group_id') ?? 0) <=
        0) {
      throw const FormatException('missing discussion_group_id');
    }
    return payload;
  }

  Future<ChannelPostsResult> searchPosts({
    required String channelId,
    int page = 1,
    int size = 10,
    String? q,
    String? tag,
    bool? essence,
  }) async {
    _requireMicroCommunity();
    if (page < 1 || size < 1 || size > 50) throw ArgumentError('page/size');
    final response = await get(
      '/api/v1/channel/$channelId/posts',
      queryParameters: {
        'page': page,
        'size': size,
        if (q != null && q.isNotEmpty) 'q': q,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (essence != null) 'essence': essence.toString(),
      },
    );
    response.throwIfFailed();
    return _parsePostsPage(response.payload, channelId, page, size);
  }

  ChannelPostsResult _parsePostsPage(
    dynamic responsePayload,
    String channelId,
    int page,
    int size,
  ) {
    final payload = IMBoyHttpResponse.payloadAsMap(responsePayload);
    final total = IMBoyHttpResponse.payloadInt(payload, 'total');
    final actualPage = IMBoyHttpResponse.payloadInt(payload, 'page');
    final actualSize = IMBoyHttpResponse.payloadInt(payload, 'size');
    if (payload['list'] is! List ||
        total == null ||
        total < 0 ||
        actualPage != page ||
        actualSize != size) {
      throw const FormatException('invalid posts page');
    }
    final entries = IMBoyHttpResponse.payloadList(payload);
    final messages = entries.map(ChannelMessageModel.fromJson).toList();
    if (entries.length != (payload['list'] as List).length ||
        messages.any(
          (message) =>
              message.id <= 0 || message.channelId.toString() != channelId,
        )) {
      throw const FormatException('invalid scoped posts');
    }
    return ChannelPostsResult(
      list: messages,
      total: total,
      page: page,
      size: size,
    );
  }

  Future<void> setPostEssence(
    String channelId,
    String messageId,
    bool value,
  ) async {
    _requireMicroCommunity();
    final response = await put(
      '/api/v1/channel/$channelId/posts/$messageId/essence',
      data: {'is_essence': value},
    );
    response.throwIfFailed();
  }

  Future<void> setPostTags(
    String channelId,
    String messageId,
    List<String> tags,
  ) async {
    _requireMicroCommunity();
    final response = await put(
      '/api/v1/channel/$channelId/posts/$messageId/tags',
      data: {'tags': tags},
    );
    response.throwIfFailed();
  }
}
