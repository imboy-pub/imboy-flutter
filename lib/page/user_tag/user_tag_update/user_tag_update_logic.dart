import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';

import 'user_tag_update_state.dart';

class UserTagUpdateLogic extends GetxController {
  final UserTagUpdateState state = UserTagUpdateState();

  Future<bool> changeName({
    required String scene,
    required int tagId,
    required String tagName,
  }) async {
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      return false;
    }
    bool res2 = await UserTagProvider().changeName(
      scene: scene,
      tagId: tagId,
      tagName: tagName,
    );
    if (res2 == false) {
      return false;
    }
    await UserTagRepo().update({
      UserTagRepo.tagId: tagId,
      UserTagRepo.name: tagName,
    });
    return true;
  }
}
