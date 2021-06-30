import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/login_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalLoginRepository {
  static final String keyLogin = 'key_login';

  static saveLogin(LoginModel bean) {
    SharedPreferences sp = Get.find<SharedPreferences>();
    sp.setString(keyLogin, jsonEncode(bean.toJson()));
  }

  static LoginModel getLoginModel() {
    SharedPreferences sp = Get.find<SharedPreferences>();
    try {
      var json = sp.getString(keyLogin);
      return LoginModel.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
}
