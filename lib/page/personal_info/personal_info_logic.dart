import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'personal_info_state.dart';

class PersonalInfoLogic extends GetxController {
  final state = PersonalInfoState();
  final HttpClient _dio = Get.put(HttpClient.client);

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

  Future<dynamic> getRemarkMethod(String id, {Callback? callback}) async {
    // var result = await im.getRemark(id);
    var result = "";
    callback!(result);
    return result;
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

  /// 上传头像 [uploadImg]
  uploadImgApi(base64Img, Callback? callback) async {
    Map<String, dynamic> result = _dio.post(
      API.uploadImg,
      data: {"image_base_64": base64Img},
      // errorCallback: (String msg, int code) {
      //   Get.snackbar("", msg);
      // },
    ) as Map<String, dynamic>;
    print("code::$result['code']");
    print("URL::$result['result']['URL']");
    if (result['code'] == 200) {
      callback!(result['result']['URL']);
    } else {
      callback!(null);
    }
  }
}
