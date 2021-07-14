import 'package:encrypt/encrypt.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/dio.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repository.dart';

class LoginApi {
  final DioUtil _dio = Get.put(DioUtil());

  Future<bool> login(String account, String password) async {
    try {
      Map resp1 = await _dio.get(API.init);
      debugPrint(">>>>>>>>>>>>>>>>>>> on {$resp1}");
      String pubKey = resp1['payload']['login_rsa_pub_key'];
      final rsaEncrypt = resp1['payload']['login_pwd_rsa_encrypt'];
      if (rsaEncrypt == "1") {
        final parser = RSAKeyParser();
        final publicKey = parser.parse(pubKey);
        final encrypter = Encrypter(RSA(publicKey: publicKey));
        final encrypted = encrypter.encrypt(password);

        password = encrypted.base64.toString();
      }
      Map resp2 = await _dio.post(API.login, data: {
        "account": account,
        "pwd": password,
        "rsa_encrypt": rsaEncrypt
      });
      if (resp2['code'] != 0) {
        print('error::' + resp2.toString());
        Get.snackbar('Hi', resp2['msg'], duration: Duration(seconds: 5));
        return false;
      } else {
        debugPrint(">>>>>>>>>>>>>>>>>>> on logoin success {$resp2.toString()}");
        return await UserRepository.loginAfter(resp2['payload']);
      }
    } on PlatformException {
      Get.snackbar('', '你已登录或者其他错误');
    }
  }

  Future<UserModel> register(
      String account, String password, String repassword) async {
    Map resp = await _dio.post(API.regiser, data: {
      "account": account,
      "password": password,
      "repassword": password
    });
    if (resp['code'] == 0) {
      return UserModel.fromJson(resp['payload']);
    } else {
      throw resp['msg'];
    }
  }
}
