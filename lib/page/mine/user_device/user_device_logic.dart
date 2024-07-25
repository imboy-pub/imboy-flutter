import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
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
    bool res2 = await UserDeviceProvider().deleteDevice(
      deviceId: deviceId,
    );
    if (res2 == false) {
      return false;
    }
    await UserDeviceRepo().delete(deviceId);
    return true;
  }

  changeName({required String deviceId, required String name}) async {
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
    await UserDeviceRepo().update(deviceId, {
      UserDeviceRepo.deviceName: name,
    });
    return true;
  }
}
