part of 'channel_provider.dart';

/// 频道详情状态
class ChannelDetailState {
  final ChannelModel? channel;
  final List<ChannelMessageModel> messages;
  final bool isLoading;
  final bool isPublishing;
  final bool hasMore;
  final String? error;

  const ChannelDetailState({
    this.channel,
    this.messages = const [],
    this.isLoading = false,
    this.isPublishing = false,
    this.hasMore = true,
    this.error,
  });

  ChannelDetailState copyWith({
    ChannelModel? channel,
    List<ChannelMessageModel>? messages,
    bool? isLoading,
    bool? isPublishing,
    bool? hasMore,
    String? error,
    bool clearChannel = false,
  }) {
    return ChannelDetailState(
      channel: clearChannel ? null : (channel ?? this.channel),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isPublishing: isPublishing ?? this.isPublishing,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}
