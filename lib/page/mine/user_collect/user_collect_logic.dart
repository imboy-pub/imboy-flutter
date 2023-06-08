import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/provider/user_device_provider.dart';

import 'user_collect_state.dart';

class UserCollectLogic extends GetxController {
  final UserCollectState state = UserCollectState();

  Future<List<UserCollectModel>> page({int page = 1, int size = 10}) async {
    List<UserCollectModel> list = [];
    page = page > 1 ? page : 1;
    // int offset = (page - 1) * size;
    // var repo = UserDeviceRepo();

    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      // list = await repo.page(limit: size, offset: offset);
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
      UserCollectModel model = UserCollectModel.fromJson(json);
      // await repo.insert(model);
      list.add(model);
    }
    return list;
  }
}
