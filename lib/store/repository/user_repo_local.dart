import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/provider/user_provider.dart';

class UserRepoLocal extends GetxController {
  static UserRepoLocal get to => Get.find();

  bool get isLogin => accessToken.isNotEmpty;
  bool get hasToken => accessToken.isNotEmpty;

  // 令牌 token
  String get accessToken => StorageService.to.getString(Keys.tokenKey);
  String get refreshtoken => StorageService.to.getString(Keys.refreshtokenKey);
  String get currentUid => StorageService.to.getString(Keys.currentUid);
  UserModel get currentUser => UserModel.fromJson(
        StorageService.to.getMap(Keys.currentUser),
      );
  String get lastLoginAccount =>
      StorageService.to.getString(Keys.lastLoginAccount);

  @override
  void onInit() {
    super.onInit();
    update();
  }

  Future<bool> changeInfo(Map<String, dynamic> payload) async {
    await StorageService.to.setMap(Keys.currentUser, payload);
    update();
    return true;
  }

  Future<bool> loginAfter(Map<String, dynamic> payload) async {
    await StorageService.to.setString(Keys.tokenKey, payload['token']);
    await StorageService.to
        .setString(Keys.refreshtokenKey, payload['refreshtoken']);
    await StorageService.to.setString(Keys.currentUid, payload['uid']);
    await StorageService.to.setMap(Keys.currentUser, payload);
    Sqlite.instance.database;
    // 初始化 WebSocket 链接
    // 检查WS链接状
    WSService.to.openSocket();
    return true;
  }

  Future<bool> logout() async {
    WSService.to.sendMessage("logout");
    sleep(const Duration(seconds: 1));
    await StorageService.to.remove(Keys.tokenKey);
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);

    WSService.to.closeSocket();
    Sqlite.instance.close();
    return true;
  }

  /// 刷新token
  Future<String> refreshAccessToken() async {
    String newToken = await (UserProvider()).refreshAccessToken(
      UserRepoLocal.to.refreshtoken,
    );
    if (strNoEmpty(newToken)) {
      await StorageService.to.setString(Keys.tokenKey, newToken);
    }
    await Future.delayed(const Duration(seconds: 1));
    return newToken;
  }

  @override
  void dispose() {
    debugPrint(">>> on user UserRepoSP disponse");
    super.dispose();
  }
}
