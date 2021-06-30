/*
 * @Author: your name
 * @Date: 2020-12-08 20:57:12
 * @LastEditTime: 2020-12-13 01:22:52
 * @LastEditors: Please set LastEditors
 * @Description: In User Settings Edit
 * @FilePath: /todo/lib/data/repositories/login_repository.dart
 */
import 'package:get/get.dart';
import 'package:imboy/api/login_api.dart';
import 'package:imboy/store/model/login_model.dart';

class LoginRepository {
  final LoginApi api = Get.put(LoginApi());

  Future<LoginModel> login(String account, String password) {
    return api.login(account, password);
  }

  Future<LoginModel> register(
      String account, String password, String repassword) {
    return api.register(account, password, repassword);
  }
}
