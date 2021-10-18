import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/helper/http/http_response.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repository.dart';

class LoginApi {
  Future<bool> login(String account, String password) async {
    var _dio = Get.find<HttpClient>();
    try {
      // Map<String, dynamic> resp1 =
      //     (await (Dio()).get(API.init)) as Map<String, dynamic>;
      HttpResponse resp1 = await _dio.get("/init");
      if (!resp1.ok) {
        String msg = '网络故障或服务故障';
        msg += resp1.error!.code.toString() + "; msg: " + resp1.error!.message;
        Get.snackbar('提示', msg);
        return false;
      }
      debugPrint(">>>>>>>>>>>>>>>>>>> on {resp1.payload}");
      debugPrint(">>>>>>>>>>>>>>>>>>> on {resp1}");
      String pubKey = resp1.payload['login_rsa_pub_key'];
      final rsaEncrypt = resp1.payload['login_pwd_rsa_encrypt'];
      if (rsaEncrypt == "1") {
        dynamic publicKey = RSAKeyParser().parse(pubKey);
        final encrypter = Encrypter(RSA(publicKey: publicKey));
        final encrypted = encrypter.encrypt(password);

        password = encrypted.base64.toString();
      }
      HttpResponse resp2 = await _dio.post(API.login,
          data: {
            "account": account,
            "pwd": password,
            "rsa_encrypt": rsaEncrypt,
          },
          options: Options(
            contentType: "application/x-www-form-urlencoded",
          ));
      if (!resp2.ok) {
        print('error::' + resp2.toString());
        Get.snackbar('Hi', resp2.error!.message,
            duration: Duration(seconds: 5));
        return false;
      } else {
        debugPrint(">>>>>>>>>>>>>>>>>>> on logoin success {$resp2.toString()}");
        return await UserRepository.loginAfter(resp2.payload);
      }
    } on PlatformException {
      Get.snackbar('', '你已登录或者其他错误');
      return false;
    }
  }

  Future<UserModel> register(
      String account, String password, String repassword) async {
    var _dio = Get.find<HttpClient>();
    HttpResponse resp = await _dio.post(API.register, data: {
      "account": account,
      "password": password,
      "repassword": password
    });
    return UserModel.fromJson(resp.payload);
  }
}
