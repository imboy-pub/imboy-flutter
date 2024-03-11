import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/store/provider/feedback_provider.dart';

import 'feedback_state.dart';

class FeedbackLogic extends GetxController {
  final FeedbackState state = FeedbackState();

  Future<List<FeedbackModel>> page({int page = 1, int size = 10}) async {
    List<FeedbackModel> list = [];
    page = page > 1 ? page : 1;
    // int offset = (page - 1) * size;
    // var repo = FeedbackRepo();

    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      EasyLoading.showToast(
          'network_exception_plase_need_network_to_view_data'.tr);
      // list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await FeedbackProvider().page(
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      FeedbackModel model = FeedbackModel.fromJson(json);
      // await repo.insert(model);
      list.add(model);
    }
    return list;
  }

  Future<bool> remove(int feedbackId) async {
    bool res = await FeedbackProvider().remove(feedbackId: feedbackId);
    // if (res) {
    //   int res2 = await UserCollectRepo().delete(obj.kindId);
    //   res = res2 > 0 ? true : false;
    // }
    return res;
  }

  Future<List<FeedbackReplyModel>> pageReply(
    int feedbackId, {
    int page = 1,
    int size = 10,
  }) async {
    List<FeedbackReplyModel> list = [];
    page = page > 1 ? page : 1;
    // int offset = (page - 1) * size;
    // var repo = FeedbackRepo();

    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      EasyLoading.showToast(
          'network_exception_plase_need_network_to_view_data'.tr);
      // list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await FeedbackProvider().pageReply(
      feedbackId,
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      FeedbackReplyModel model = FeedbackReplyModel.fromJson(json);
      // await repo.insert(model);
      list.add(model);
    }
    return list;
  }
}
