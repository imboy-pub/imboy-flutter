import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/api/live_room_api.dart';
import 'package:imboy/store/model/live_room_model.dart';

/// LiveRoomList 页面状态
class LiveRoomListState {
  final List<LiveRoomModel> items;
  final bool isLoading;
  final int page;
  final bool hasMore;

  const LiveRoomListState({
    this.items = const [],
    this.isLoading = false,
    this.page = 1,
    this.hasMore = true,
  });

  LiveRoomListState copyWith({
    List<LiveRoomModel>? items,
    bool? isLoading,
    int? page,
    bool? hasMore,
  }) {
    return LiveRoomListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// LiveRoomList 状态管理 Provider
final liveRoomListProvider =
    NotifierProvider<LiveRoomListNotifier, LiveRoomListState>(
      LiveRoomListNotifier.new,
    );

/// LiveRoomList 状态管理 Notifier
class LiveRoomListNotifier extends Notifier<LiveRoomListState> {
  final LiveRoomApi _api;

  LiveRoomListNotifier({LiveRoomApi? api}) : _api = api ?? LiveRoomApi();

  @override
  LiveRoomListState build() => const LiveRoomListState();

  /// 加载第一页（刷新）
  Future<void> loadFirst() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, page: 1, items: []);
    await _load(1, reset: true);
  }

  /// 加载更多（下一页）
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    await _load(state.page + 1, reset: false);
  }

  Future<void> _load(int page, {required bool reset}) async {
    final result = await _api.myList(page: page, size: 20);
    if (result == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final rawList = result['list'] as List<dynamic>? ?? [];
    final newItems = rawList
        .map((e) => LiveRoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (result['total'] as num?)?.toInt() ?? 0;

    final allItems = reset ? newItems : [...state.items, ...newItems];
    state = state.copyWith(
      items: allItems,
      isLoading: false,
      page: page,
      hasMore: allItems.length < total,
    );
  }

  /// 直接设置列表（兼容旧接口）
  void setItems(List<LiveRoomModel> items) {
    state = state.copyWith(items: items);
  }
}
