import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/get_extension.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class PassportLogic extends GetxController {
  // 网络状态描述
  RxString connectDesc = "".obs;

  String? _error;

  /// 账号验证
  String? userValidator(LoginUserType userType, String value) {
    if (userType == LoginUserType.phone && !isPhone(value)) {
      return 'error_invalid'.trArgs(['hint_login_phone'.tr]);
    } else if (userType == LoginUserType.email && !isEmail(value)) {
      return 'error_invalid'.trArgs(['hint_login_email'.tr]);
    }
    return null;
  }

  /// 密码格式验证
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

  /// 用户登录
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
    IMBoyHttpResponse resp1 = await HttpClient.client.get(API.initConfig);
    debugPrint("> on init ${resp1.toString()}");
    if (!resp1.ok) {
      return {"error": "网络故障或服务故障"};
    }
    String encrypted = resp1.payload['res'] ?? '';
    if (encrypted.isEmpty) {
      return {"error": "服务故障协议有误"};
    }

    Map<String, dynamic> payload = jsonDecode(EncrypterService.aesDecrypt(
      encrypted,
      SOLIDIFIED_KEY,
      SOLIDIFIED_KEY_IV,
    ));
    // debugPrint("> on ${resp1.payload.toString()}");
    // debugPrint("> on ${resp1.toString()}");
    final rsaEncrypt = payload['login_pwd_rsa_encrypt'].toString();
    if (rsaEncrypt == "1") {
      String pubKey = payload['login_rsa_pub_key'].toString();
      dynamic publicKey = RSAKeyParser().parse(pubKey);
      final encryptor = Encrypter(RSA(publicKey: publicKey));
      final encrypted = encryptor.encrypt(password);
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
      Map<String, dynamic>? dinfo = await DeviceExt.to.detail;

      Map<String, dynamic> postData = {
        "account": account,
        "pwd": data['password'],
        "rsa_encrypt": data['rsa_encrypt'],
        // 设备ID
        "did": dinfo!["did"],
        // 客户端操作系统（设备类型）
        "cos": dinfo["cos"],
        // "dname": dinfo["deviceName"],
        // "dvsn": dinfo["deviceVersion"],
      };
      if (UserRepoLocal.to.lastLoginAccount != account) {
        // 二次登录的时候不需要这2个参数
        postData["dname"] = dinfo["deviceName"];
        postData["dvsn"] = dinfo["deviceVersion"];
      }
      debugPrint("> on doLogin postData: ${postData.toString()}");
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
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

  /// 用户注册
  Future<String?> signupUser(SignupData data) {
    // return null;
    debugPrint("> on signupUser data: ${data.name}, ${data.password}");
    return doSendEmail(data.name ?? '');
  }

  /// 确认注册
  Future<String?> onConfirmSignup(String code, LoginData data) async {
    Map<String, dynamic> data1 = await encryptPassword(data.password);
    if (strNoEmpty(data1['error'])) {
      _error = '';
      return data1['error'];
    }
    IMBoyHttpResponse resp2 = await HttpClient.client.post(
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

  /// 重新发送验证码
  Future<String?>? onResendCode(SignupData data) {
    debugPrint("> on onResendCode data: ${data.name}, ${data.password}");
    // 验证码已发送
    return doSendEmail(data.name ?? '');
  }

  Future<String?> doSendEmail(String email) async {
    if (!isEmail(email)) {
      return 'error_invalid'.trArgs(['hint_login_email'.tr]);
    }

    IMBoyHttpResponse resp2 = await HttpClient.client.post(
      API.getCode,
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

  // 找回密码，获取Email验证码功能
  Future<String?> onRecoverPassword(String name) {
    debugPrint('> on onRecoverPassword Name: $name');
    // 验证码已发送
    return doSendEmail(name);
    // return 'User not exists';
    // return null;
  }

  /// 邮箱验证码修改密码
  Future<String?> onConfirmRecover(String code, LoginData data) async {
    try {
      Map<String, dynamic> result = await encryptPassword(data.password);
      if (strNoEmpty(result['error'])) {
        _error = result['error'];
        return result['error'];
      }

      Map<String, dynamic> postData = {
        "type": "email",
        "account": data.name,
        "code": code,
        "pwd": result['password'],
        "rsa_encrypt": result['rsa_encrypt'],
      };
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.findPassword,
        data: postData,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
        ),
      );
      if (!resp2.ok) {
        _error = resp2.error!.message;
        return _error;
      } else {
        StorageService.to.setString(Keys.lastLoginAccount, data.name);
        return null;
      }
    } on PlatformException {
      _error = '网络故障，请稍后重试';
      return _error;
    }
  }
}
