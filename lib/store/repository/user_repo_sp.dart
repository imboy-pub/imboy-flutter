import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/websocket.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';

class UserRepoSP extends GetxController {
  static UserRepoSP get user => Get.find();

  bool get isLogin => accessToken.isNotEmpty;
  bool get hasToken => accessToken.isNotEmpty;

  // 令牌 token
  String get accessToken => StorageService.to.getString(Keys.tokenKey);
  String get currentUid => StorageService.to.getString(Keys.currentUid);
  UserModel get currentUser => UserModel.fromJson(
        StorageService.to.getMap(Keys.currentUser),
      );

  @override
  void onInit() {
    super.onInit();
    update();
  }

  Future<bool> loginAfter(Map<String, dynamic> payload) async {
    debugPrint(">>>>> on user loginAfter");
    await StorageService.to.setString(Keys.tokenKey, payload['token']);
    await StorageService.to.setString(Keys.currentUid, payload['uid']);
    await StorageService.to.setMap(Keys.currentUser, payload);
    debugPrint(">>>>> on user loginAfter tk: " +
        StorageService.to.getString(Keys.tokenKey));
    update();
    // 初始化 WebSocket 链接
    WebSocket();
    return true;
  }

  Future<bool> logout() async {
    WebSocket().sendMessage("logout");
    debugPrint(">>>>> on user logout currentUid: " + user.currentUid);
    sleep(Duration(seconds: 1));
    debugPrint(">>>>> on user logout currentUid: " + user.currentUid);
    await StorageService.to.remove(Keys.tokenKey);
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);

    WebSocket().closeSocket();
    update();
    return true;
  }

  @override
  void dispose() {
    print(">>>>> on user UserRepoSP disponse");
    super.dispose();
  }
}
