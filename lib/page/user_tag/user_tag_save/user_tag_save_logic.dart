import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_logic.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';

import 'user_tag_save_state.dart';

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

  Future<UserTagModel?> addTag({
    required String scene,
    required String tagName,
  }) async {
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      return null;
    }
    int tagId = await UserTagProvider().addTag(
      scene: scene,
      tagName: tagName,
    );
    if (tagId > 0) {
      UserTagModel tag = UserTagModel(
        userId: UserRepoLocal.to.currentUid,
        tagId: tagId,
        scene: 2,
        name: tagName,
        subtitle: '',
        refererTime: 0,
        updatedAt: 0,
        createdAt: DateTimeHelper.currentTimeMillis(),
      );
      await UserTagRepo().insert(tag);
      Get.find<ContactTagListLogic>().state.items.insert(0, tag);
      return tag;
    }
    return null;
  }
}
