import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/store/provider/user_device_provider.dart';
import 'package:imboy/store/repository/user_device_repo_sqlite.dart';

import 'user_device_state.dart';

class UserDeviceLogic extends GetxController {
  final UserDeviceState state = UserDeviceState();

  Future<List<UserDeviceModel>> page({int page = 1, int size = 10}) async {
    List<UserDeviceModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserDeviceRepo();

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await UserDeviceProvider().page(
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      UserDeviceModel model = UserDeviceModel.fromJson(json);
      await repo.insert(model);
      list.add(model);
    }
    return list;
  }

  Future<bool> deleteDevice(String deviceId) async {
    // return true;
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    bool res2 = await UserDeviceProvider().deleteDevice(deviceId: deviceId);
    if (res2 == false) {
      return false;
    }
    await UserDeviceRepo().delete(deviceId);
    return true;
  }

  Future<bool> changeName({
    required String deviceId,
    required String name,
  }) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    bool res2 = await UserDeviceProvider().changeName(
      deviceId: deviceId,
      name: name,
    );
    if (res2 == false) {
      return false;
    }
    await UserDeviceRepo().update(deviceId, {UserDeviceRepo.deviceName: name});
    return true;
  }

  // 新增：获取“当前设备名称”，优先级：全局变量 > 内存列表 > 本地库
  Future<String> getDeviceName(String deviceId) async {
    // 内存列表（若列表已加载）
    try {
      final idx = state.deviceList.indexWhere((e) => e.deviceId == deviceId);
      if (idx >= 0) {
        final name = state.deviceList[idx].deviceName;
        if ((name ?? '').isNotEmpty) {
          return name;
        }
      }
    } catch (_) {}

    // 3) 本地库回退
    try {
      final repo = UserDeviceRepo();
      // 假设本地表以 deviceId 为键可查询到记录（如 find/findById），这里以 find 为例
      final m = await repo.find(deviceId); // 如果方法名不同，替换为你仓库里实际的方法
      if (m != null && m.deviceName.isNotEmpty) {
        return m.deviceName;
      }
    } catch (_) {}

    return '';
  }

  /// 让指定设备下线（向后端请求下发 S2C 指令）
  /// 参数:
  /// - deviceId: 目标设备ID（did）
  /// 返回:
  /// - true 表示请求成功（服务端将尝试向该设备下发下线指令），false 表示请求失败
  Future<bool> forceOffline(String deviceId) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    String name = await getDeviceName(deviceId);
    return WebSocketService.to.sendMessage(
      json.encode({
        "id": "device_force_offline",
        "type": "S2C",
        "msg_type": "device_force_offline",
        "payload": {
          "by_did": deviceId,
          "by_name": name.isEmpty ? '其他设备' : name, //
        },
      }),
      null,
    );
  }
}
