part of 'channel_provider.dart';

/// Search uses page/size, separate from the legacy created_at message cursor.
typedef ChannelPostSearch = ({
  String channelId,
  String q,
  String? tag,
  bool? essence,
  int page,
});

final channelPostSearchProvider = FutureProvider.autoDispose
    .family<ChannelPostsResult, ChannelPostSearch>((ref, filter) {
      return ref
          .watch(channelApiProvider)
          .searchPosts(
            channelId: filter.channelId,
            q: filter.q,
            tag: filter.tag,
            essence: filter.essence,
            page: filter.page,
          );
    });
