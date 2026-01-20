import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserDeviceApi extends HttpClient {
  Future<Map<String, dynamic>?> page({int page = 1, int size = 10}) async {
    IMBoyHttpResponse resp = await get(
      API.userDevicePage,
      queryParameters: {'page': page, 'size': size},
    );
    debugPrint("> on Api/denylistPage resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 修改设备名称（简化版，仅返回成功/失败）
  Future<bool> changeName({
    required String deviceId,
    required String name,
  }) async {
    final resp = await changeNameWithResponse(deviceId: deviceId, name: name);
    return resp.ok;
  }

  /// 修改设备名称（完整版，返回完整响应）
  Future<IMBoyHttpResponse> changeNameWithResponse({
    required String deviceId,
    required String name,
  }) async {
    debugPrint("> on Api/changeName request: deviceId=$deviceId, name=$name");
    IMBoyHttpResponse resp = await post(
      API.userDeviceChangeName,
      data: {"did": deviceId, "name": name},
    );
    debugPrint("> on Api/changeName response: ok=${resp.ok}, code=${resp.code}, msg=${resp.msg}");
    if (!resp.ok) {
      debugPrint("> on Api/changeName failed: ${resp.error?.message ?? 'unknown error'}");
    }
    return resp;
  }

  /// 删除设备
  Future<bool> deleteDevice({required String deviceId}) async {
    IMBoyHttpResponse resp = await post(
      API.userDeviceDelete,
      data: {"did": deviceId},
    );
    debugPrint("> on Api/deleteDevice resp: ${resp.payload}");
    return resp.ok ? true : false;
  }
}
