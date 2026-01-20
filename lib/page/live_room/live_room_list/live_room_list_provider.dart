import 'package:flutter_riverpod/flutter_riverpod.dart';

/// LiveRoomList 页面状态
class LiveRoomListState {
  final List<dynamic> items;

  const LiveRoomListState({this.items = const []});

  LiveRoomListState copyWith({List<dynamic>? items}) {
    return LiveRoomListState(items: items ?? this.items);
  }
}

/// LiveRoomList 状态管理 Provider
final liveRoomListProvider =
    NotifierProvider<LiveRoomListNotifier, LiveRoomListState>(
      LiveRoomListNotifier.new,
    );

/// LiveRoomList 状态管理 Notifier
class LiveRoomListNotifier extends Notifier<LiveRoomListState> {
  @override
  LiveRoomListState build() => const LiveRoomListState();

  /// 设置直播间列表
  void setItems(List<dynamic> items) {
    state = LiveRoomListState(items: items);
  }
}
