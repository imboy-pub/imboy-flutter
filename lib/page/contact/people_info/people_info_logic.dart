import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import 'people_info_state.dart';

class PeopleInfoLogic extends GetxController {
  final PeopleInfoState state = PeopleInfoState();

  Future<void> initData(String id, String scene) async {
    iPrint("people_info.initData 10 ${DateTime.now()}");
    ContactModel? ct = await ContactRepo().findByUid(id);
    iPrint("people_info.initData 20 ${DateTime.now()}");
    // debugPrint("> on cdv initData $id");
    // debugPrint("> on cdv initData ${ct?.toJson().toString()}");
    if (ct != null) {
      state.title.value = ct.title;
      state.nickname.value = ct.nickname;
      state.avatar.value = ct.avatar;
      state.account.value = ct.account;
      state.region.value = ct.region;
      state.sign.value = ct.sign;
      state.source.value = ct.source;
      state.gender.value = ct.gender;
      state.remark.value = ct.remark;
      state.tag.value = ct.tag;
      state.isFriend.value = ct.isFriend;
      state.isFrom.value = ct.isFrom;
      state.tag.value = ct.tag;
    }
    if (state.isFriend.value != 1) {
      if (scene == 'qrcode') {
        state.source.value = 'qrcode';
      } else if (scene == 'visit_card') {
        state.source.value = 'visit_card';
      } else if (scene == 'people_nearby') {
        state.source.value = 'people_nearby';
      } else if (scene == 'recently_user') {
        state.source.value = 'recently_user';
      } else if (scene == 'contact_page' || scene == 'denylist') {
        state.source.value = '';
      } else if (scene == 'group_member') {
      } else if (scene == 'user_search') {
        state.source.value = 'search'.tr;
        // } else if (scene == '') {
        // } else if (scene == '') {
        // } else if (scene == '') {
      } else if (scene == '') {
        state.source.value = 'qrcode';
      }
    }
  }
}
