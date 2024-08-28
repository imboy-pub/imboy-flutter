import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/provider/group_member_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'people_info_more_state.dart';

class PeopleInfoMoreLogic extends GetxController {
  final state = PeopleInfoMoreState();

  Future<void> initData(String id) async {
    ContactModel? model = await ContactRepo().findByUid(id);

    state.sign.value = model!.sign;
    state.source.value = model.sourceTr;
    // other_party 对方
    state.sourcePrefix.value = model.isFrom == 1 ? '' : 'other_party'.tr;
    debugPrint(
        "PeopleInfoMorePage initData ${state.source}, ${state.sourcePrefix} , sign ${state.sign}");
    // if (state.sameGroupList.value.isEmpty) {
    sameGroup(id);
    // }
  }

  Future<void> sameGroup(String id) async {
    Map<String, dynamic>? p = await GroupMemberProvider().sameGroup(
      UserRepoLocal.to.currentUid,
      id,
    );
    if (p == null) {
      return;
    }
    state.groupCount.value = p['count'] ?? 0;
    if (state.groupCount.value > 0) {
      List<GroupModel> list = [];
      var repo = GroupRepo();

      for (var json in p['list']) {
        GroupModel m = await repo.save('', json);
        m.computeAvatar = await Get.find<GroupListLogic>().computeAvatar(
          m.groupId,
        );
        list.add(m);
        // for test
        // for (int i = 0; i < 50; i++) {
        //   list.add(m);
        // }
      }
      state.sameGroupList.value = list;
    }
  }
}
