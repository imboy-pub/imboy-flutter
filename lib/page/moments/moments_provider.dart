import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Moments 页面状态
class MomentsState {
  final bool showTitle;

  const MomentsState({this.showTitle = false});

  MomentsState copyWith({bool? showTitle}) {
    return MomentsState(showTitle: showTitle ?? this.showTitle);
  }
}

/// Moments 状态管理 Provider
final momentsProvider = NotifierProvider<MomentsNotifier, MomentsState>(
  MomentsNotifier.new,
);

/// Moments 状态管理 Notifier
class MomentsNotifier extends Notifier<MomentsState> {
  @override
  MomentsState build() => MomentsState();

  /// 切换标题显示状态
  void setShowTitle(bool show) {
    state = MomentsState(showTitle: show);
  }
}
