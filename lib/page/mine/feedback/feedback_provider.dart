import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/store/api/feedback_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/i18n/strings.g.dart';

part 'feedback_provider.g.dart';

/// Feedback 模块的状态
class FeedbackPageState {
  final List<FeedbackModel> itemList;
  final List<FeedbackReplyModel> pageReplyList;
  final bool isLoading;
  final String? error;

  const FeedbackPageState({
    this.itemList = const [],
    this.pageReplyList = const [],
    this.isLoading = false,
    this.error,
  });

  FeedbackPageState copyWith({
    List<FeedbackModel>? itemList,
    List<FeedbackReplyModel>? pageReplyList,
    bool? isLoading,
    String? error,
  }) {
    return FeedbackPageState(
      itemList: itemList ?? this.itemList,
      pageReplyList: pageReplyList ?? this.pageReplyList,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

@riverpod
class FeedbackPageNotifier extends _$FeedbackPageNotifier {
  @override
  FeedbackPageState build() {
    return const FeedbackPageState();
  }

  /// 加载反馈列表
  Future<List<FeedbackModel>> page({int page = 1, int size = 10}) async {
    List<FeedbackModel> list = [];
    page = page > 1 ? page : 1;

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showToast(t.networkExceptionPlaseNeedNetworkToViewData);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await FeedbackApi().page(
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      FeedbackModel model = FeedbackModel.fromJson(json);
      list.add(model);
    }
    return list;
  }

  /// 加载数据并更新状态
  Future<void> loadData({int page = 1, int size = 1000}) async {
    state = state.copyWith(isLoading: true);
    try {
      var list = await this.page(page: page, size: size);
      state = state.copyWith(itemList: list, isLoading: false);
    } on Exception {
      state = state.copyWith(isLoading: false, error: t.operationFailedAgainLater);
    }
  }

  /// 删除反馈
  Future<bool> remove(int feedbackId) async {
    bool res = await FeedbackApi().remove(feedbackId: feedbackId);
    if (res) {
      final newList = List<FeedbackModel>.from(state.itemList);
      newList.removeWhere((e) => e.feedbackId == feedbackId);
      state = state.copyWith(itemList: newList);
    }
    return res;
  }

  /// 加载反馈回复列表
  Future<List<FeedbackReplyModel>> pageReply(
    int feedbackId, {
    int page = 1,
    int size = 10,
  }) async {
    List<FeedbackReplyModel> list = [];
    page = page > 1 ? page : 1;

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showToast(t.networkExceptionPlaseNeedNetworkToViewData);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await FeedbackApi().pageReply(
      feedbackId,
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      FeedbackReplyModel model = FeedbackReplyModel.fromJson(json);
      list.add(model);
    }
    return list;
  }

  /// 加载回复列表并更新状态
  Future<void> loadReplyData(
    int feedbackId, {
    int page = 1,
    int size = 100,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      var list = await pageReply(feedbackId, page: page, size: size);
      state = state.copyWith(pageReplyList: list, isLoading: false);
    } on Exception {
      state = state.copyWith(isLoading: false, error: t.operationFailedAgainLater);
    }
  }

  /// 设置反馈列表
  void setItemList(List<FeedbackModel> list) {
    state = state.copyWith(itemList: list);
  }

  /// 设置回复列表
  void setPageReplyList(List<FeedbackReplyModel> list) {
    state = state.copyWith(pageReplyList: list);
  }
}
