import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class FeedbackProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(API.feedbackPage, queryParameters: {
      'page': page,
      'size': size,
    });
    debugPrint("> on Provider/feedbackPage resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 添加用户反馈
  Future<bool> add(Map<String, dynamic> data) async {
    IMBoyHttpResponse resp = await post(API.feedbackAdd, data: data);
    debugPrint("> on Provider/feedbackAdd resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  /// 移除用户反馈
  Future<bool> remove({
    required int feedbackId,
  }) async {
    IMBoyHttpResponse resp = await post(API.feedbackRemove, data: {
      "feedback_id": feedbackId,
    });
    debugPrint("> on Provider/feedbackRemove resp: ${resp.payload}");
    return resp.ok ? true : false;
  }

  /// 修改用户反馈
  Future<bool> change(Map<String, dynamic> data) async {
    IMBoyHttpResponse resp = await post(API.feedbackChange, data: data);
    debugPrint("> on Provider/feedbackRemove resp: ${resp.payload}");
    return resp.ok ? true : false;
  }
}
