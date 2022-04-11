import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_login/src/models/signup_data.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/get_extension.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class PassportLogic extends GetxController {
  String? _error = null;

  @override
  void onInit() {
    super.onInit();
  }

  /**
   * 账号验证
   */
  String? userValidator(LoginUserType userType, String value) {
    if (userType == LoginUserType.phone && !isPhone(value)) {
      return 'error_invalid'.trArgs(['hint_login_phone'.tr]);
    } else if (userType == LoginUserType.email && !isEmail(value)) {
      return 'error_invalid'.trArgs(['hint_login_email'.tr]);
    }
    return null;
  }

  /**
   * 密码格式验证
   */
  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_empty_directory'.trArgs(['hint_login_password'.tr]);
    }
    if (value.length < 4 || value.length > 32) {
      return 'error_length_between'.trArgs([
        'hint_login_password'.tr,
        '4',
        '32',
      ]);
    }
    return null;
  }

  /**
   * 用户登录
   */
  Future<String?> loginUser(LoginData data) async {
    // Get.loading();
    bool loginSuccess = await login(data.name.trim(), data.password.trim());
    Get.dismiss();
    if (loginSuccess) {
      return null;
      // Get.off(() => BottomNavigationPage());
    } else {
      return _error;
    }
  }

  Future<Map<String, dynamic>> encryptPassword(String password) async {
    HttpResponse resp1 = await HttpClient.client.get("/init");
    if (!resp1.ok) {
      return {"error": "网络故障或服务故障"};
    }
    // debugPrint(">>> on ${resp1.payload.toString()}");
    // debugPrint(">>> on ${resp1.toString()}");
    String pubKey = resp1.payload['login_rsa_pub_key'] as String;
    final rsaEncrypt = resp1.payload['login_pwd_rsa_encrypt'];
    if (rsaEncrypt == "1") {
      dynamic publicKey = RSAKeyParser().parse(pubKey);
      final encrypter = Encrypter(RSA(publicKey: publicKey));
      final encrypted = encrypter.encrypt(password);
      password = encrypted.base64.toString();
    }
    return {
      "password": password,
      "rsa_encrypt": rsaEncrypt,
    };
  }

  Future<bool> login(String account, String password) async {
    try {
      Map<String, dynamic> data = await encryptPassword(password);
      if (strNoEmpty(data['error'])) {
        _error = data['error'];
        return false;
      }
      HttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: {
          "account": account,
          "pwd": data['password'],
          "rsa_encrypt": data['rsa_encrypt'],
        },
        options: Options(
          contentType: "application/x-www-form-urlencoded",
        ),
      );
      if (!resp2.ok) {
        _error = resp2.error!.message;
        return false;
      } else {
        StorageService.to.setString(Keys.lastLoginAccount, account);
        return await (UserRepoLocal()).loginAfter(resp2.payload);
      }
    } on PlatformException {
      _error = '网络故障，请稍后重试';
      return false;
    }
  }

  /**
   * 用户注册
   */
  Future<String?> signupUser(SignupData data) {
    // return null;
    debugPrint(">>> on signupUser data: ${data.name}, ${data.password}");
    return doSendEmail(data.name ?? '');
  }

  /**
   * 确认注册
   */
  Future<String?> onConfirmSignup(String code, LoginData data) async {
    Map<String, dynamic> data1 = await encryptPassword(data.password);
    if (strNoEmpty(data1['error'])) {
      _error = '';
      return data1['error'];
    }
    HttpResponse resp2 = await HttpClient.client.post(
      API.signup,
      data: {
        "type": "email",
        "account": data.name,
        "pwd": data1["password"],
        "rsa_encrypt": data1["rsa_encrypt"],
        "code": code,
        "ref_uid": "",
      },
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    if (resp2.ok) {
      return null;
    } else {
      _error = resp2.error!.message;
      return _error;
    }
  }

  /**
   * 重新发送验证码
   */
  Future<String?>? onResendCode(SignupData data) {
    debugPrint(">>> on onResendCode data: ${data.name}, ${data.password}");
    // 验证码已发送
    return doSendEmail(data.name ?? '');
  }

  Future<String?> doSendEmail(String email) async {
    if (!isEmail(email)) {
      return 'error_invalid'.trArgs(['hint_login_email'.tr]);
    }

    HttpResponse resp2 = await HttpClient.client.post(
      API.getcode,
      data: {
        "account": email,
        "type": "email",
      },
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    if (resp2.ok) {
      return null;
    } else {
      _error = resp2.error!.message;
      return _error;
    }
  }

  /**
   * 确认找回密码
   */
  Future<String?> onConfirmRecover(String error, LoginData data) async {
    debugPrint(
        ">>> on onConfirmRecover error: ${error}, data: ${data.name}, ${data.password}");
    return null;
  }

  // 找回密码功能
  Future<String>? onRecoverPassword(String name) {
    debugPrint('>>> on onRecoverPassword Name: $name');
    // return 'User not exists';
    return null;
  }
}
