import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserCollectApi extends HttpClient {
  Future<Map<String, dynamic>?> page(Map<String, dynamic> args) async {
    IMBoyHttpResponse resp = await get(
      API.userCollectPage,
      queryParameters: args,
    );
    debugPrint("UserCollectApi_page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  /// 删除收藏
  Future<bool> remove({required String kindId}) async {
    IMBoyHttpResponse resp = await post(
      API.userCollectRemove,
      data: {'kind_id': kindId},
    );
    debugPrint("> on Api/deleteDevice resp: ${resp.payload}");
    return resp.ok ? true : false;
  }

  ///
  Future<bool> change(Map<String, dynamic> data) async {
    IMBoyHttpResponse resp = await post(API.userCollectChange, data: data);
    // debugPrint("user_collect_api/change resp: ${resp.payload.toString()}");
    return resp.ok ? true : false;
  }

  /// Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  Future<bool> add(
    int kind,
    String kindId,
    String source,
    Map<String, dynamic> info,
  ) async {
    debugPrint(
      "> on UserCollectApi add params: kind=$kind, kindId=$kindId, source=$source",
    );
    debugPrint("> on UserCollectApi add info keys: ${info.keys.toList()}");
    IMBoyHttpResponse resp = await post(
      API.userCollectAdd,
      data: {'kind': kind, 'kind_id': kindId, 'source': source, 'info': info},
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    debugPrint(
      "> on UserCollectApi add resp: ok=${resp.ok}, code=${resp.code}, msg=${resp.msg}",
    );
    debugPrint(
      "> on UserCollectApi add resp payload: ${resp.payload.toString()}",
    );
    // 如果请求失败，显示详细错误信息
    if (!resp.ok) {
      debugPrint("> on UserCollectApi add error: ${resp.error?.message}");
      EasyLoading.showError(resp.msg.isNotEmpty ? resp.msg : t.tipFailed);
    }
    EasyLoading.dismiss();
    return resp.ok ? true : false;
  }
}
