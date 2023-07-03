import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import 'tag_add_state.dart';

class TagAddLogic extends GetxController {
  final TagAddState state = TagAddState();

  RxBool valueChanged = false.obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
    update([valueChanged]);
  }

  Future<bool> add(String peerId, List<String> tag) async {
    bool res = await UserTagProvider().add(peerId: peerId, tag:tag);
    debugPrint("tag_add_logic/add $peerId, tag ${tag.toString()} ;");
    if (res) {
      await ContactRepo().update({
        ContactRepo.peerId: peerId,
        ContactRepo.tag: tag.join(','),
      });
      // res = res2 > 0 ? true : false;
    }
    return res;
  }
}
