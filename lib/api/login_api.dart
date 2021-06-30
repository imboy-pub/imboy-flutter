import 'package:encrypt/encrypt.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/helper/dio.dart';
import 'package:imboy/store/model/login_model.dart';

class LoginApi {
  final DioUtil _dio = Get.put(DioUtil());

  Future<LoginModel> login(String account, String password) async {
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
        Get.snackbar('', resp2['msg'], duration: Duration(seconds: 5));
        // gloabl.uid = resp2['payload']['uid'];
        // gloabl.nickname = resp2['payload']['nickname'];
        // gloabl.avatar = resp2['payload']['avator'];
        // gloabl.account = resp2['payload']['account'];
        // gloabl.gender = resp2['payload']['gender'];
        // gloabl.goToLogin = false;

        // String token = resp2['payload']['token'];
        // String refreshtoken = resp2['payload']['refreshtoken'];

        // await SharedUtil.instance.saveString(Keys.uid, resp2['payload']['uid']);
        // await SharedUtil.instance
        //     .saveString(Keys.nickname, resp2['payload']['nickname']);
        // await SharedUtil.instance
        //     .saveString(Keys.avatar, resp2['payload']['avatar']);
        // await SharedUtil.instance
        //     .saveString(Keys.account, resp2['payload']['account']);
        // await SharedUtil.instance
        //     .saveInt(Keys.gender, resp2['payload']['gender']);
        // await SharedUtil.instance.saveString(Keys.token, token);
        // await SharedUtil.instance.saveString(Keys.refreshtoken, refreshtoken);
        // await SharedUtil.instance.saveBoolean(Keys.hasLogged, true);
        // gloabl.refresh();
        // await routePushAndRemove(new RootPage());
      }
      debugPrint(">>>>>>>>>>>>>>>>>>> on logoin success {$resp2.toString()}");

      final box = GetStorage();
      box.write(Keys.tokenKey, resp2['payload']['token']);
      return LoginModel.fromJson(resp2['payload']);
    } on PlatformException {
      Get.snackbar('', '你已登录或者其他错误');
    }
  }

  Future<LoginModel> register(
      String account, String password, String repassword) async {
    Map resp = await _dio.post(API.regiser, data: {
      "account": account,
      "password": password,
      "repassword": password
    });
    if (resp['code'] == 0) {
      return LoginModel.fromJson(resp['payload']);
    } else {
      throw resp['msg'];
    }
  }
}
