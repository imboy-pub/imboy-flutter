/// 朋友圈通知中心状态（Slice A-3）。
///
/// 不可变状态，`copyWith` 返回新实例；生命周期由 [MomentNotifyNotifier]
/// 持有。`unreadCount` 同步自 Repo（权威源），用于顶部红点与 AppBar 徽标。
library;

import 'package:imboy/store/model/moment_notify_model.dart';

class MomentNotifyState {
  final List<MomentNotifyModel> items;
  final bool isLoading;
  final bool hasMore;
  final int unreadCount;
  final int page;

  const MomentNotifyState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.page = 0,
  });

  MomentNotifyState copyWith({
    List<MomentNotifyModel>? items,
    bool? isLoading,
    bool? hasMore,
    int? unreadCount,
    int? page,
  }) {
    return MomentNotifyState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      page: page ?? this.page,
    );
  }
}
