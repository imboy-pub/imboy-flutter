import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/mine/change_password/set_password_view.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:jverify/jverify.dart';

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

import 'passport_state.dart';

/// 认证登录逻辑控制器
class PassportLogic extends GetxController {
  final PassportState state = PassportState();

  /// 统一 key
  final String fResultKey = "result";

  /// 错误码
  final String fCodeKey = "code";

  /// 回调的提示信息，统一返回 flutter 为 message
  final String fMsgKey = "message";

  /// 运营商信息
  final String fOprKey = "operator";
  late Jverify jverify;

  /// 标题组件
  Widget title() {
    return Column(
      // 内容居中
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            IMBoyIcon.imboyLogo,
            size: 80.0,
            color: Colors.white,
          ),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
                text: 'IM',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(
                    text: 'Boy',
                    style: TextStyle(color: Colors.black, fontSize: 30),
                  ),
                  // TextSpan(
                  //   text: '爱智慧',
                  //   style: TextStyle(color: Colors.white, fontSize: 30),
                  // ),
                ]),
          ),
        ]);
  }

  /// 返回按钮组件
  Widget backButton() {
    return InkWell(
      onTap: () {
        Get.back();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
              child: const Icon(Icons.keyboard_arrow_left, color: Colors.white),
            ),
            Text(
              'back'.tr,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      ),
    );
  }

  /// 账号验证
  String? userValidator(String accountType, String value) {
    if (value.isEmpty) {
      return 'error_empty_directory'.trArgs(['hint_login_account'.tr]);
    }
    if (accountType == 'mobile' && !isPhone(value)) {
      return 'error_invalid'.trArgs(['mobile'.tr]);
    } else if (accountType == 'email' && !isEmail(value)) {
      return 'error_invalid'.trArgs(['email'.tr]);
    } else if (accountType == 'account' && value.length < 5) {
      return 'error_invalid'.trArgs(['account'.tr]);
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
  Future<String?> loginUser(String accountType, String account, String password) async {
    try {
      int status = await _login(accountType, account, password);
      Get.dismiss();
      if (status == 1) {
        state.error.value = '';
        state.loginPwd.value = '';
        return null;
      } else if (status == 2) {
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
                await UserProvider().cancelLogout();
                Get.off(() => BottomNavigationPage());
              },
              child: Text(
                'login'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(Get.context!).colorScheme.onPrimary),
              ),
            ),
            content: SizedBox(
              height: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
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
                ],
              ),
            ));

        return 'cancel_logout_title'.tr;
      } else {
        return state.error.value;
      }
    } catch (e, s) {
      // 也可以使用 print 语句打印异常信息
      iPrint('state.error: $e; ${s.toString()}');
      return e.toString();
    }
  }

  /// 加密密码
  Future<Map<String, dynamic>> _encryptPassword(String password) async {
    password = EncrypterService.md5(password);
    Map<String, dynamic> payload = await AppInitializer.initConfig();
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

  /// accountType = mobile | email | account
  Future<int> _login(String accountType, String account, String password) async {
    try {
      Map<String, dynamic> data = await _encryptPassword(password);
      if (strNoEmpty(data['error'])) {
        state.error.value = data['error'];
        return 0;
      }
      Map<String, dynamic>? dinfo = await DeviceExt.to.detail;
      Map<String, dynamic> postData = {
        "type": accountType,
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
      // debugPrint("> on doLogin $currentEnv postData: ${postData.toString()}");
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
      );
      if (!resp2.ok) {
        state.error.value = resp2.error!.message.tr;
        return 0;
      } else {
        int status = (resp2.payload['status'] ?? 1).toInt();
        if (status == 1 || status == 2) {
          await (UserRepoLocal()).loginAfter(account, resp2.payload);
        }
        return 1;
      }
    } on PlatformException {
      state.error.value = '网络故障，请稍后重试';
      return 0;
    }
  }

  /// 用户注册 发送验证码
  /// sence = forgot_pwd | signup
  Future<String?>? sendCode(String accountType, String account, String scene) {
    if (accountType == 'mobile') {
      return doSendCode(account, type: 'sms', scene: scene);
    } else if (accountType == 'account' && isPhone(account)) {
      return doSendCode(account, type: 'sms', scene: scene);
    } else if (accountType == 'email') {
      return doSendCode(account, type: 'email', scene: scene);
    } else if (accountType == 'account' && isEmail(account)) {
      return doSendCode(account, type: 'email', scene: scene);
    }
    return null;
  }

  /// 确认注册
  Future<String?> confirmSignup({
    required String accountType, // mobile | email
    required String code,
    required String nickname,
    required String account,
    required String pwd,
  }) async {
    Map<String, dynamic> data1 = await _encryptPassword(pwd);
    if (strNoEmpty(data1['error'])) {
      state.error.value = '';
      return data1['error'];
    }
    final data = {
      "type": accountType,
      "nickname": nickname,
      "account": account,
      "pwd": data1["password"],
      "rsa_encrypt": data1["rsa_encrypt"],
      "code": code,
      "sys_version": Platform.operatingSystemVersion,
      "ref_uid": "",
    };
    iPrint("post_data ${data.toString()}");
    IMBoyHttpResponse resp2 = await HttpClient.client.post(
      API.signup,
      data: data,
    );
    if (resp2.ok) {
      return null;
    } else {
      state.error.value = resp2.error?.message ?? 'unknown'.tr;
      return state.error.value;
    }
  }

  /// type email | sms
  Future<String?> doSendCode(
      String account, {
        required String type,
        String? scene,
      }) async {
    IMBoyHttpResponse resp = await HttpClient.client.post(API.getCode, data: {
      "account": account,
      "type": type,
      "scene": scene,
    });
    if (resp.ok) {
      return null;
    } else {
      state.error.value = resp.error?.message ?? 'error';
      return state.error.value;
    }
  }

  /// 验证码修改密码
  /// type email | sms
  /// code 验证码
  Future<String?> resetPassword(
      {required String type,
        required String account,
        required String code,
        required String newPwd,
        required String rePwd}) async {
    if (strEmpty(newPwd)) {
      return 'error_required'.trArgs(['new_password'.tr]);
    }

    String? error = passwordValidator(newPwd);
    if (error != null) {
      return error;
    }
    if (rePwd != newPwd) {
      return 'error_retype_password'.tr;
    }
    try {
      Map<String, dynamic> result = await _encryptPassword(newPwd);
      if (strNoEmpty(result['error'])) {
        state.error = result['error'];
        return result['error'];
      }

      Map<String, dynamic> postData = {
        "type": type,
        "account": account,
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
        state.error.value = resp2.error!.message;
        return state.error.value;
      } else {
        StorageService.to.setString(Keys.lastLoginAccount, account);
        return null;
      }
    } on PlatformException {
      state.error.value = '网络故障，请稍后重试';
      return state.error.value;
    }
  }

  /// 显示SnackBar提示
  void snackBar(dynamic message, {Icon? icon}) {
    Get.closeAllSnackbars();
    // 底部弹窗
    Get.showSnackbar(
      GetSnackBar(
        icon: icon ??
            const Icon(
              Icons.error,
              color: Colors.red,
            ),
        title: null,
        backgroundColor: Colors.white,
        messageText: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: message is String
              ? Text(
            message,
            style: const TextStyle(color: Colors.red, fontSize: 20),
          )
              : message,
        ),
        padding: const EdgeInsets.all(0.0),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// 初始化极光认证SDK
  Future<void> initPlatformState() async {
    try {
      jverify = Jverify();
      // 初始化 SDK 之前添加监听
      jverify.addSDKSetupCallBackListener((JVSDKSetupEvent event) {
        iPrint("receive sdk setup call back event :${event.toMap()}");
      });

      jverify.setDebugMode(true); // 打开调试模式
      jverify.setCollectionAuth(true);
      jverify.setup(
          appKey: Env().jiguangAppKey, //"你自己应用的 AppKey",
          channel: "devloper-default"); // 初始化sdk,  appKey 和 channel 只对ios设置有效

      /// 授权页面点击时间监听
      jverify.addAuthPageEventListener((JVAuthPageEvent event) {
        debugPrint("receive auth page event :${event.toMap()}");
      });
    } catch (e) {
      debugPrint("JVerify初始化异常: $e");
    }
  }

  /// SDK 请求授权一键登录
  /// 如果登录成功返回 null
  Future<String?> loginAuth(bool isSms) async {
    Map<dynamic, dynamic> res = await jverify.checkVerifyEnable();
    iPrint("checkVerifyEnable_res ${res.toString()}");
    bool result = res[fResultKey];
    if (result == false) {
      snackBar('当前网络环境不支持，或者手机没有绑定电话卡'.tr);
      return null;
    }

    // final screenWidth = Get.width;
    final screenHeight = Get.height;
    bool isiOS = Platform.isIOS;

    /// 自定义授权的 UI 界面
    JVUIConfig uiConfig = JVUIConfig();

    uiConfig.navHidden = false;
    uiConfig.navColor = Colors.green.toARGB32(); // 保留原有逻辑，但使用 value 属性
    uiConfig.navText = " ";
    uiConfig.navTextColor = Colors.white.toARGB32();
    uiConfig.navReturnImgPath = null;

    uiConfig.logoWidth = 100;
    uiConfig.logoHeight = 100;
    uiConfig.logoOffsetX = isiOS ? 0 : null;
    uiConfig.logoOffsetY = isiOS ? (screenHeight / 2).toInt() - 200 : null;
    uiConfig.logoVerticalLayoutItem = JVIOSLayoutItem.ItemSuper;
    uiConfig.logoHidden = false;

    uiConfig.numberFieldWidth = 200;
    uiConfig.numberFieldHeight = 40;
    uiConfig.numFieldOffsetY = isiOS ? 20 : 180;
    uiConfig.numberVerticalLayoutItem = JVIOSLayoutItem.ItemLogo;
    uiConfig.numberColor = Colors.black.toARGB32();
    uiConfig.numberSize = 18;

    uiConfig.sloganOffsetY = isiOS ? 20 : 160;
    uiConfig.sloganVerticalLayoutItem = JVIOSLayoutItem.ItemNumber;
    uiConfig.sloganTextColor = Colors.black.toARGB32();
    uiConfig.sloganTextSize = 15;

    uiConfig.logBtnWidth = 220;
    uiConfig.logBtnHeight = 50;
    uiConfig.logBtnOffsetY = isiOS ? 20 : 280;
    uiConfig.logBtnVerticalLayoutItem = JVIOSLayoutItem.ItemSlogan;
    uiConfig.logBtnText = 'mobile_quick_login'.tr;
    uiConfig.logBtnTextColor = isiOS ? Colors.black.toARGB32() : Colors.white.toARGB32();
    uiConfig.logBtnTextSize = 16;
    uiConfig.logBtnTextBold = true;

    uiConfig.privacyHintToast = true;
    uiConfig.privacyState = false;
    uiConfig.privacyCheckboxSize = 20;
    uiConfig.checkedImgPath = null;
    uiConfig.uncheckedImgPath = null;
    uiConfig.privacyCheckboxInCenter = true;
    uiConfig.privacyCheckboxHidden = false;
    uiConfig.isAlertPrivacyVc = true;

    uiConfig.privacyOffsetX = 10;
    uiConfig.privacyOffsetY = 10;
    uiConfig.privacyVerticalLayoutItem = JVIOSLayoutItem.ItemSuper;
    uiConfig.clauseName = 'license_agreement'.tr;
    uiConfig.clauseUrl = licenseAgreementUrl(ext: 'html');
    uiConfig.clauseBaseColor = Colors.black87.toARGB32();

    uiConfig.clauseColor = Colors.black87.toARGB32();
    uiConfig.privacyTextSize = 13;
    uiConfig.privacyItem = [
      JVPrivacy('license_agreement'.tr.replaceAll('《', '').replaceAll('》', ''),
          licenseAgreementUrl(ext: 'html'),
          beforeName: "==", afterName: "++", separator: "、"),
    ];

    // 其他UI配置保持不变...

    /// 步骤 1：调用接口设置 UI
    jverify.setCustomAuthorizationView(
      true,
      uiConfig,
      landscapeConfig: uiConfig,
      widgets: [],
    );

    /// 步骤 2：调用一键登录接口
    jverify.loginAuthSyncApi2(
        autoDismiss: true,
        enableSms: true,
        loginAuthcallback: (event) {
          if (event.code == 6000) {
            quickLogin(operator: event.operator!, token: event.message!, service:'jverify');
          } else {
            snackBar(event.message);
          }
        });
    return "jverify";
  }

  /// 检查注册信息是否完整
  void checkSignupContinue() {
    bool pwdValidated =
    passwordValidator(state.newPwd.value) == null ? true : false;
    if (state.nickname.value.length > 1 &&
        state.mobileValidated.isTrue &&
        state.selectedAgreement.value == 'on' &&
        pwdValidated) {
      state.showSignupContinue.value = true;
    } else {
      state.showSignupContinue.value = false;
    }
    iPrint("checkSignupContinue_1 ${state.nickname.value.length > 1} ");
    iPrint("checkSignupContinue_2 ${state.mobileValidated.isTrue} ");
    iPrint("checkSignupContinue_3 ${state.selectedAgreement.value == 'on'} ");
    iPrint("checkSignupContinue_4 $pwdValidated ");
    iPrint("checkSignupContinue_5 ${state.showSignupContinue.toString()} ");
  }

  /// 获取用户协议URL
  /// ext md | html
  String licenseAgreementUrl({String ext = 'md'}) {
    String lang = 'cn';
    String code = sysLang('').toLowerCase();
    // license_agreement 目前只配置 cn ru en 3个文件
    if (code.contains('en')) {
      lang = 'en';
    } else if (code.contains('ru')) {
      lang = 'ru';
    }
    return "https://imboy.pub/doc/license_agreement_$lang.$ext?vsn=$appVsn";
  }

  /// 快速登录
  /// service jverify | huawei
  /// token 返回码的解释信息，若获取成功，内容信息代表loginToken。
  /// operator ：成功时为对应运营商，CM代表中国移动，CU代表中国联通，CT代表中国电信。失败时可能为 null
  Future<String?> quickLogin({required String operator, required String token, required String service}) async {
    Map<String, dynamic> postData = {
      "service": service,
      "operator": operator,
      "token": token,
      "sys_version": Platform.operatingSystemVersion,
    };

    IMBoyHttpResponse resp2 = await HttpClient.client.post(
      API.quickLogin,
      data: postData,
    );
    if (!resp2.ok) {
      state.error.value = resp2.error!.message;
      return state.error.value;
    } else {
      int status = (resp2.payload['status'] ?? 1).toInt();
      String account = resp2.payload['account'] ?? '';
      if (account.isNotEmpty) {
        await StorageService.to.setString(Keys.lastLoginAccount, account);
      }
      if (status == 1 || status == 2) {
        await (UserRepoLocal()).loginAfter(account, resp2.payload);
      }
      String action = resp2.payload['action'] ?? '';
      if (action == 'need_set_password') {
        await StorageService.to.setBool(Keys.needSetPwd, true);
        Get.off(() => SetPasswordPage());
      } else {
        Get.off(() => BottomNavigationPage());
      }
      return null;
    }
  }
}