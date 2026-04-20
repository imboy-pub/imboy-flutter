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

  /// 最近一次 refresh/loadMore 失败的错误提示（null = 无错误 / 已消费）。
  /// 仅对 UI 暴露"列表加载失败"语义，不包含 markRead / delete 等副作用失败
  /// （后者通过 EasyLoading toast 就近提示即可）。
  final String? errorMessage;

  const MomentNotifyState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.page = 0,
    this.errorMessage,
  });

  /// copyWith 语义说明：
  ///   - `errorMessage` 默认保留旧值（传 null 不覆盖，与其他字段一致）
  ///   - 调用方若要显式清错，传 `clearError: true`
  MomentNotifyState copyWith({
    List<MomentNotifyModel>? items,
    bool? isLoading,
    bool? hasMore,
    int? unreadCount,
    int? page,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MomentNotifyState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      page: page ?? this.page,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
