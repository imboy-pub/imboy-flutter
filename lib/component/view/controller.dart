import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

class ThemeController extends GetxController {
  //0:正常模式 1：黑夜模式
  var _darkMode = 0;

  get darkMode => _darkMode;

  void changeMode(value) {
    _darkMode = value;
    Get.changeTheme(Get.isDarkMode ? ThemeData.light() : ThemeData.dark());
    update();
  }
}

class Controller extends GetNotifier {
  Controller() : super('');

  late GetSocket socket;
  String text = '';

  @override
  void onInit() {
    String? tk = UserRepoSP.user.currentUid;

    String url = ws_url + '?' + Keys.tokenKey + '=' + tk.replaceAll('+', '%2B');

    socket = GetSocket(url);
    print('onInit called');

    socket.onOpen(() {
      print('onOpen');
      change(value, status: RxStatus.success());
    });

    socket.onMessage((data) {
      print('message received: $data');
      change(data);
    });

    socket.onClose((close) {
      print('close called');
      change(value, status: RxStatus.error(close.message));
    });

    socket.onError((e) {
      print('error called');
      change(value, status: RxStatus.error(e.message));
    });

    socket.on('event', (val) {
      print(val);
    });

    socket.emit('event', 'you data');

    socket.connect();
  }

  void sendMessage(msg) {
    socket.emit('message', msg);
  }
}
