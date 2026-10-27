part of 'channel_provider.dart';

/// 创建频道状态
class CreateChannelState {
  final bool isCreating;
  final ChannelModel? createdChannel;
  final String? error;

  const CreateChannelState({
    this.isCreating = false,
    this.createdChannel,
    this.error,
  });

  CreateChannelState copyWith({
    bool? isCreating,
    ChannelModel? createdChannel,
    String? error,
    bool clearCreatedChannel = false,
  }) {
    return CreateChannelState(
      isCreating: isCreating ?? this.isCreating,
      createdChannel: clearCreatedChannel
          ? null
          : (createdChannel ?? this.createdChannel),
      error: error,
    );
  }
}
