import 'package:flutter_keychain/flutter_keychain.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/user_model.dart';

class UserRepoLocal extends GetxController {
  static UserRepoLocal get to => Get.find();


  String get currentUid => StorageService.to.getString(Keys.currentUid) ?? '';

  bool get isLogin {
    return currentUid.isNotEmpty;
  }

  //
  UserSettingModel get setting {
    Map<String, dynamic> u = StorageService.getMap(Keys.currentUser);
    return UserSettingModel.fromJson(u['setting'] ?? {});
  }

  // 令牌 token
  Future<String> get accessToken async {
    return await FlutterKeychain.get(key: Keys.tokenKey) ?? '';
  }

  Future<String> get refreshToken async {
    // StorageService.to.getString(Keys.refreshTokenKey) ?? '';
    return await FlutterKeychain.get(key: Keys.refreshTokenKey) ?? '';
  }

  UserModel get current {
    Map<String, dynamic> user = StorageService.getMap(Keys.currentUser);
    iPrint("current user ${user.toString()}");
    if (user.isEmpty) {
      WebSocketService.to.closeSocket(exit: true);
      Get.offAll(() => PassportPage());
    }
    return UserModel.fromJson(user);
  }

  String get lastLoginAccount =>
      StorageService.to.getString(Keys.lastLoginAccount) ?? '';

  @override
  void onInit() {
    super.onInit();
    // _loadIsLogin();
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
    await StorageService.to.setString(Keys.currentUid, payload['uid']);

    await FlutterKeychain.put(
      key: Keys.tokenKey,
      value: payload['token'],
    );
    await FlutterKeychain.put(
      key: Keys.refreshTokenKey,
      value: payload['refreshtoken'],
    );
    payload.remove('token');
    payload.remove('refreshtoken');

    // await StorageService.to.setString(Keys.currentUid, payload['uid']);
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
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.wsUrl);
    await StorageService.to.remove(Keys.uploadUrl);
    await StorageService.to.remove(Keys.uploadKey);
    await StorageService.to.remove(Keys.uploadScene);

    await FlutterKeychain.remove(key:Keys.tokenKey);
    await FlutterKeychain.remove(key:Keys.currentUid);
    await FlutterKeychain.remove(key:Keys.currentUser);
    WebSocketService.to.closeSocket(exit: true);
    SqliteService.to.close();
    return true;
  }
}
