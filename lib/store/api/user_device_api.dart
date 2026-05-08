import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserDeviceApi extends HttpClient {
  /// 获取设备分页列表
  Future<Map<String, dynamic>?> page({int page = 1, int size = 10}) async {
    IMBoyHttpResponse resp = await get(
      API.userDevicePage,
      queryParameters: {'page': page, 'size': size},
    );
    debugPrint("> on Api/userDevicePage resp: ${resp.payload.toString()}");
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
    debugPrint(
      "> on Api/changeName response: ok=${resp.ok}, code=${resp.code}, msg=${resp.msg}",
    );
    if (!resp.ok) {
      debugPrint(
        "> on Api/changeName failed: ${resp.error?.message ?? 'unknown error'}",
      );
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

  /// 获取活跃会话列表
  /// 返回当前用户的活跃设备会话信息
  Future<Map<String, dynamic>?> getActiveSessions() async {
    IMBoyHttpResponse resp = await get(API.userDeviceSessions);
    debugPrint("> on Api/getActiveSessions resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      debugPrint(
        "> on Api/getActiveSessions failed: ${resp.error?.message ?? 'unknown error'}",
      );
      return null;
    }
    return resp.payload;
  }

  /// 检查登录冲突
  /// 在用户登录时检查是否与现有设备冲突
  ///
  /// [deviceType] 设备类型，如 "ios", "android", "web"
  /// 返回包含冲突信息的 Map
  ///   - conflict: bool 是否有冲突
  ///   - message: String 提示信息
  ///   - conflict_device: Map? 冲突设备信息（如果有）
  Future<Map<String, dynamic>?> checkLoginConflict({
    required String deviceType,
  }) async {
    debugPrint("> on Api/checkLoginConflict request: deviceType=$deviceType");
    IMBoyHttpResponse resp = await post(
      API.userDeviceCheckLogin,
      data: {"device_type": deviceType},
    );
    debugPrint(
      "> on Api/checkLoginConflict response: ok=${resp.ok}, code=${resp.code}, payload=${resp.payload}",
    );
    if (!resp.ok) {
      debugPrint(
        "> on Api/checkLoginConflict failed: ${resp.error?.message ?? 'unknown error'}",
      );
      return null;
    }
    return resp.payload;
  }

  /// 踢出指定设备
  /// 将指定设备从活跃会话中移除
  ///
  /// [deviceType] 要踢出的设备类型，如 "ios", "android"
  /// [deviceId] 要踢出的设备 ID
  /// 返回操作是否成功
  Future<Map<String, dynamic>?> kickDevice({
    required String deviceType,
    required String deviceId,
  }) async {
    debugPrint(
      "> on Api/kickDevice request: deviceType=$deviceType, deviceId=$deviceId",
    );
    IMBoyHttpResponse resp = await post(
      API.userDeviceKick,
      data: {"device_type": deviceType, "device_id": deviceId},
    );
    debugPrint(
      "> on Api/kickDevice response: ok=${resp.ok}, code=${resp.code}, payload=${resp.payload}",
    );
    if (!resp.ok) {
      debugPrint(
        "> on Api/kickDevice failed: ${resp.error?.message ?? 'unknown error'}",
      );
      return null;
    }
    return resp.payload;
  }

  /// 踢出所有其他设备
  /// 保留当前设备，踢出其他所有设备的会话
  ///
  /// [deviceType] 当前设备类型，如 "ios", "android"
  /// [deviceId] 当前设备 ID
  /// 返回操作是否成功
  Future<Map<String, dynamic>?> kickAllOtherDevices({
    required String deviceType,
    required String deviceId,
  }) async {
    debugPrint(
      "> on Api/kickAllOtherDevices request: deviceType=$deviceType, deviceId=$deviceId",
    );
    IMBoyHttpResponse resp = await post(
      API.userDeviceKickOthers,
      data: {"device_type": deviceType, "device_id": deviceId},
    );
    debugPrint(
      "> on Api/kickAllOtherDevices response: ok=${resp.ok}, code=${resp.code}, payload=${resp.payload}",
    );
    if (!resp.ok) {
      debugPrint(
        "> on Api/kickAllOtherDevices failed: ${resp.error?.message ?? 'unknown error'}",
      );
      return null;
    }
    return resp.payload;
  }
}
