import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class UserCollectProvider extends HttpClient {
  Future<Map<String, dynamic>?> page(Map<String, dynamic> args) async {
    IMBoyHttpResponse resp =
        await get(API.userCollectPage, queryParameters: args);
    debugPrint("UserCollectProvider_page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 删除收藏
  Future<bool> remove({
    required String kindId,
  }) async {
    IMBoyHttpResponse resp = await post(API.userCollectRemove, data: {
      'kind_id': kindId,
    });
    debugPrint("> on Provider/deleteDevice resp: ${resp.payload}");
    return resp.ok ? true : false;
  }

  ///
  Future<bool> change({
    required String action,
    required String kindId,
  }) async {
    IMBoyHttpResponse resp = await post(API.userCollectChange, data: {
      'action': action,
      'kind_id': kindId,
    });
    debugPrint(
        "> on Provider/send_to_view callback resp: ${resp.payload.toString()}");
    return resp.ok ? true : false;
  }

  /// Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  Future<bool> add(
    int kind,
    String kindId,
    String source,
    Map<String, dynamic> info,
  ) async {
    // debugPrint("> on Provider/userDeviceAdd info: ${info.toString()}");
    int fileSize = 0;
    if (kind == 4) {
      fileSize = info['payload']['video']['filesize'] ?? 0;
    } else {
      fileSize = info['payload']['size'] ?? 0;
    }

    if (fileSize > 200000) {
      EasyLoading.show(status: '收藏附件比较耗时，请耐心等待！'.tr);
    }
    IMBoyHttpResponse resp = await post(API.userCollectAdd,
        data: {
          'kind': kind,
          'kind_id': kindId,
          'source': source,
          'info': info,
        },
        options: Options(
          sendTimeout: const Duration(minutes: 50),
          receiveTimeout: const Duration(minutes: 50),
        ));
    debugPrint(
        "> on Provider/userDeviceAdd resp: ${resp.error}; ${resp.payload.toString()}");
    EasyLoading.dismiss();
    return resp.ok ? true : false;
  }
}
