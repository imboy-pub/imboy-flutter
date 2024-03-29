import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/user_model.dart';

class UserRepoLocal extends GetxController {
  static UserRepoLocal get to => Get.find();

  bool get isLogin => accessToken.isNotEmpty;

  bool get hasToken => accessToken.isNotEmpty;

  //
  UserSettingModel get setting {
    Map<String, dynamic> u = StorageService.getMap(Keys.currentUser);
    return UserSettingModel.fromJson(u['setting'] ?? {});
  }

  // 令牌 token
  String get accessToken => StorageService.to.getString(Keys.tokenKey) ?? '';

  String get refreshToken =>
      StorageService.to.getString(Keys.refreshTokenKey) ?? '';

  String get currentUid => StorageService.to.getString(Keys.currentUid) ?? '';

  UserModel get current => UserModel.fromJson(
        StorageService.getMap(Keys.currentUser),
      );

  String get lastLoginAccount =>
      StorageService.to.getString(Keys.lastLoginAccount) ?? '';

  @override
  void onInit() {
    super.onInit();
    update();
  }

  Future<bool> changeSetting(UserSettingModel setting) async {
    Map<String, dynamic> u = StorageService.getMap(Keys.currentUser);
    u['setting'] = setting.toMap();
    await StorageService.setMap(Keys.currentUser, u);
    update();
    return true;
  }

  Future<bool> changeInfo(Map<String, dynamic> payload) async {
    await StorageService.setMap(Keys.currentUser, payload);
    update();
    return true;
  }

  Future<bool> loginAfter(Map<String, dynamic> payload) async {
    await StorageService.to.setString(Keys.tokenKey, payload['token']);
    await StorageService.to.setString(
      Keys.refreshTokenKey,
      payload['refreshtoken'],
    );
    await StorageService.to.setString(Keys.currentUid, payload['uid']);
    await StorageService.setMap(Keys.currentUser, payload);
    SqliteService.to.db;
    // 初始化 WebSocket 链接
    // 检查WS链接状
    WebSocketService.to;

    // https://github.com/jpush/jpush-flutter-plugin/blob/master/documents/APIs.md
    // 获取 registrationId，这个 JPush 运行通过 registrationId 来进行推送.
    // push.getRegistrationID().then((rid) {
    //   debugPrint("push registrationId $rid");
    // });
    // 设置别名，极光后台可以通过别名来推送，一个 App 应用只有一个别名，一般用来存储用户 id。
    /*
    if (Platform.isAndroid) {
      await push.setAlias(payload['uid']);
    }
    */
    return true;
  }

  Future<bool> logout() async {
    WebSocketService.to.sendMessage("logout");
    await StorageService.to.remove(Keys.tokenKey);
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);

    WebSocketService.to.closeSocket(exit: true);
    SqliteService.to.close();
    return true;
  }
}
