import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'personal_info_state.dart';

class PersonalInfoLogic extends GetxController {
  final state = PersonalInfoState();
  final HttpClient httpclient = Get.put(HttpClient.client);

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<bool> changeInfo(Map data) async {
    HttpResponse result = await httpclient.put(API.userUpdate, data: data);
    debugPrint(">>> on changeInfo:${result.ok} ${result.payload.toString()}");
    return result.ok;
  }

  Future<dynamic> setUsersProfileMethod({
    String nicknameStr = '',
    String avatarStr = '',
    Callback? callback,
  }) async {
    final user = UserRepoLocal.to.currentUser;
    // var result = await im.setUsersProfile(0, nicknameStr, avatarStr);
    var result = "";
    if (result.toString().contains('succ')) {
      if (strNoEmpty(nicknameStr)) user.nickname = nicknameStr;
      if (strNoEmpty(avatarStr)) user.avatar = avatarStr;
    }
    callback!(result);
    return result;
  }

  Future<dynamic> getUsersProfile(List<String> users,
      {Callback? callback}) async {
    // var result = await im.getUsersProfile(users);
    var result = "";
    return result;
  }
}
