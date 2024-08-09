import 'dart:io';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/get_extension.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class PassportLogic extends GetxController {
  // 网络状态描述
  RxString connectDesc = "".obs;

  String? _error;

  /// 账号验证
  String? userValidator(LoginUserType userType, String value) {
    if (userType == LoginUserType.phone && !isPhone(value)) {
      return 'error_invalid'.trArgs(['mobile'.tr]);
    } else if (userType == LoginUserType.email && !isEmail(value)) {
      return 'error_invalid'.trArgs(['email'.tr]);
    }
    return null;
  }

  /// 密码格式验证
  String? passwordValidator(String? val) {
    if (strEmpty(val)) {
      return 'error_empty_directory'.trArgs(['password'.tr]);
    }
    if (val!.length < 4 || val.length > 32) {
      return 'error_length_between'.trArgs([
        'password'.tr,
        '4',
        '32',
      ]);
    }
    return null;
  }

  /// 用户登录
  Future<String?> loginUser(LoginData data) async {
    // Get.loading();
    try {
      int status = await _login(data.name.trim(), data.password.trim());
      Get.dismiss();
      if (status == 1) {
        return null;
        // Get.off(() => BottomNavigationPage());
      } else if ( status == 2){
        Get.defaultDialog(
          title: 'cancel_logout_title'.tr,
          backgroundColor: Get.isDarkMode
              ? const Color.fromRGBO(80, 80, 80, 1)
              : const Color.fromRGBO(240, 240, 240, 1),
          radius: 6,
          cancel: TextButton(
            onPressed: () {
              Get.close();
            },
            child: Text(
              'button_cancel'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(Get.context!).colorScheme.onPrimary,
              ),
            ),
          ),
          confirm: TextButton(
            onPressed: () async {
              // var nav = Navigator.of(Get.context!);
              // nav.pop();
              // nav.pop(model);
              await UserProvider().cancelLogout();
              Get.off(() => BottomNavigationPage());
            },
            child: Text(
              'button_login'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(Get.context!).colorScheme.onPrimary),
            ),
          ),
          content: SizedBox(
            height: 108,
            child: n.Column([
                Expanded(
                  child: n.Padding(
                    left: 10,
                    child: Text(
                      'cancel_logout_body'.tr,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ])
              ..crossAxisAlignment = CrossAxisAlignment.start,

        ));

        return 'cancel_logout_title'.tr;
      } else {
        return _error;
      }
    } catch (e, stack) {
      // 也可以使用 print 语句打印异常信息
      iPrint('login_error: $e');
      iPrint('Stack trace:\n${stack.toString()}');
      return e.toString();
    }
  }

  Future<Map<String, dynamic>> encryptPassword(String password) async {
    password = EncrypterService.md5(password);
    Map<String, dynamic> payload = await initConfig();
    if (payload.containsKey('error')) {
      return payload;
    }
    // debugPrint("login_pwd_rsa_encrypt ${payload.toString()}");
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

  Future<int> _login(String account, String password) async {
    try {
      Map<String, dynamic> data = await encryptPassword(password);
      if (strNoEmpty(data['error'])) {
        _error = data['error'];
        return 0;
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
        "public_key": await RSAService.publicKey(),
        // "dname": dinfo["deviceName"],
        // "dvsn": dinfo["deviceVersion"],
      };
      if (UserRepoLocal.to.lastLoginAccount != account) {
        // 二次登录的时候不需要这2个参数
        postData["dname"] = dinfo["deviceName"];
        postData["dvsn"] = dinfo["deviceVersion"];
      }
      debugPrint("> on doLogin $currentEnv postData: ${postData.toString()}");
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
      );
      if (!resp2.ok) {
        _error = resp2.error?.message.tr;
        return 0;
      } else {
        StorageService.to.setString(Keys.lastLoginAccount, account);

        int status = (resp2.payload['status'] ?? 1).toInt();
        if (status == 1 || status == 2) {
          await (UserRepoLocal()).loginAfter(resp2.payload);
        }
        return status;
      }
    } on PlatformException {
      _error = '网络故障，请稍后重试';
      return 0;
    }
  }

  /// 用户注册
  Future<String?> signupUser(SignupData data) {
    // return null;
    // debugPrint("> on signupUser data: ${data.name}, ${data.password}");
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
        "sys_version": Platform.operatingSystemVersion,
        "ref_uid": "",
      },
    );
    if (resp2.ok) {
      return null;
    } else {
      _error = resp2.error?.message ?? 'unknown'.tr;
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
      return 'error_invalid'.trArgs(['email'.tr]);
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
      _error = resp2.error?.message ?? 'error';
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
        "sys_version": Platform.operatingSystemVersion,
      };

      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.findPassword,
        data: postData,
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
