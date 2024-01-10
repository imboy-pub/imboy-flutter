import 'dart:async';

import 'package:get/get.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';

import 'user_tag_relation_state.dart';

class UserTagRelationLogic extends GetxController {
  final UserTagRelationState state = UserTagRelationState();

  RxBool valueChanged = false.obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
    update([valueChanged]);
  }

  Future<bool> add(String scene, String objectId, List<String> tag) async {
    bool res = await UserTagProvider().relationAdd(
      scene: scene,
      objectId: objectId,
      tag: tag,
    );
    // debugPrint("tag_add_logic/add $objectId, tag ${tag.toString()} ;");
    if (res) {
      if (scene == 'friend') {
        await ContactRepo().update({
          ContactRepo.peerId: objectId,
          ContactRepo.tag: tag.join(','),
        });
      } else if (scene == 'collect') {
        await UserCollectRepo().update(objectId, {
          UserCollectRepo.kindId: objectId,
          UserCollectRepo.tag: tag.join(','),
        });
      }
      // res = res2 > 0 ? true : false;
    }
    return res;
  }

  Future<List<String>> getRecentTagItems(String scene) async {
    Map<String, dynamic>? resp = await UserTagProvider().page(
      scene: scene,
      size: 100,
    );
    List<dynamic> items = resp?['list'] ?? [];

    List<String> res = [];
    for (var item in items) {
      String tag = "${item['name'] ?? ''}";
      // 去除重复和空白字符串
      if (tag.isNotEmpty && !res.contains(tag)) {
        res.add(tag);
      }
    }
    return res;
  }
}
