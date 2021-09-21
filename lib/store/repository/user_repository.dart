import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/store/model/user_model.dart';

class UserRepository {
  static Future<bool> loginAfter(Map payload) async {
    await GetStorage().write(Keys.tokenKey, payload['token']);
    if (payload['avatar'].toString().isEmpty) {
      payload['avatar'] = 'assets/images/logo.png';
    }
    GetStorage().write(Keys.currentUser, payload);
    return true;
  }

  static String? accessToken() {
    return GetStorage().read(Keys.tokenKey);
  }

  static UserModel currentUser() {
    var data = GetStorage().read(Keys.currentUser);
    if (data == null) {
      Get.off(() => LoginPage());
    }
    // debugPrint(">>>>>>>>>>>>>>>>>>> currentUser {$data}");
    return UserModel.fromJson(data);
  }

  static void logout() {
    final box = GetStorage();
    box.write(Keys.tokenKey, '');
    Get.to(() => LoginPage());
  }
}
