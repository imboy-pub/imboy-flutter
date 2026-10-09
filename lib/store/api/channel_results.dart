import 'package:imboy/store/model/channel_message_model.dart';

class ChannelPageResult<T> {
  final List<T> list;
  final String? nextCursor;
  final bool hasMore;

  const ChannelPageResult({
    required this.list,
    required this.nextCursor,
    required this.hasMore,
  });
}

class ChannelPostsResult {
  final List<ChannelMessageModel> list;
  final int total;
  final int page;
  final int size;

  const ChannelPostsResult({
    required this.list,
    required this.total,
    required this.page,
    required this.size,
  });
  bool get hasMore => page * size < total;
}
