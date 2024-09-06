import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:jverify/jverify.dart';
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

import 'passport_state.dart';

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
  final Jverify jverify = Jverify();

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

  Widget backButton() {
    return InkWell(
      onTap: () {
        Get.back();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
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
    } else if (accountType == 'name' && value.length < 5) {
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
  Future<String?> loginUser(
      String accountType, String account, String password) async {
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
                // var nav = Navigator.of(Get.context!);
                // nav.pop();
                // nav.pop(model);
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
        return state.error.value;
      }
    } catch (e, stack) {
      // 也可以使用 print 语句打印异常信息
      iPrint('state.error: $e');
      iPrint('Stack trace:\n${stack.toString()}');
      return e.toString();
    }
  }

  Future<Map<String, dynamic>> _encryptPassword(String password) async {
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

  /// accountType = mobile | email | account
  Future<int> _login(
      String accountType, String account, String password) async {
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
    } else if (accountType == 'name' && isPhone(account)) {
      return doSendCode(account, type: 'sms', scene: scene);
    } else if (accountType == 'email') {
      return doSendCode(account, type: 'email', scene: scene);
    } else if (accountType == 'name' && isEmail(account)) {
      return doSendCode(account, type: 'email', scene: scene);
    }
    return null;
  }

  /// 确认注册
  Future<String?> confirmSignup({
    required String accountType,
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
    String type = '';
    if (accountType == 'mobile') {
      type = 'mobile';
    } else if (accountType == 'name' && isPhone(account)) {
      type = 'mobile';
    } else if (accountType == 'email') {
      type = 'email';
    } else if (accountType == 'name' && isEmail(account)) {
      type = 'email';
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

  snackBar(dynamic message, {Icon? icon}) {
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
        messageText: n.Padding(
          top: 10,
          bottom: 10,
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

  /// Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // 初始化 SDK 之前添加监听
    jverify.addSDKSetupCallBackListener((JVSDKSetupEvent event) {
      iPrint("receive sdk setup call back event :${event.toMap()}");
    });

    jverify.setDebugMode(true); // 打开调试模式
    jverify.setCollectionAuth(true);
    jverify.setup(
        appKey: "6455334942815947cdbcbfed", //"你自己应用的 AppKey",
        channel: "devloper-default"); // 初始化sdk,  appKey 和 channel 只对ios设置有效
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    // if (!mounted) return;

    /// 授权页面点击时间监听
    jverify.addAuthPageEventListener((JVAuthPageEvent event) {
      print("receive auth page event :${event.toMap()}");
    });
  }

  /// sdk 初始化是否完成
  void isInitSuccess() {
    jverify.isInitSuccess().then((map) {
      bool result = map[fResultKey];
      // setState(() {
      //   if (result) {
      //     _result = "sdk 初始换成功";
      //   } else {
      //     _result = "sdk 初始换失败";
      //   }
      // });
    });
  }

  /// 判断当前网络环境是否可以发起认证
  void checkVerifyEnable() {
    jverify.checkVerifyEnable().then((map) {
      bool result = map[fResultKey];
      // setState(() {
      //   if (result) {
      //     _result = "当前网络环境【支持认证】！";
      //   } else {
      //     _result = "当前网络环境【不支持认证】！";
      //   }
      // });
    });
  }

  /// 获取号码认证token
  void getToken() {
    // setState(() {
    //   _showLoading(context);
    // });
    jverify.checkVerifyEnable().then((map) {
      bool result = map[fResultKey];
      iPrint("getToken_checkVerifyEnable 1 ${map.toString()} ");
      if (result) {
        jverify.getToken().then((map) {
          iPrint("getToken_checkVerifyEnable 2 ${map.toString()} ");
          int code = map[fCodeKey];
          String _token = map[fMsgKey];
          String operator = map[fOprKey];
          // setState(() {
          //   _hideLoading();
          //   _result = "[$code] message = $_token, operator = $operator";
          // });
        });
      } else {
        // setState(() {
        //   _hideLoading();
        //   _result = "[2016],msg = 当前网络环境不支持认证";
        // });
      }
    });
  }

  /// SDK 请求授权一键登录
  /// 如果登录成功返回 null
  Future<String?> loginAuth(bool isSms) async {
    Map<dynamic, dynamic> res = await jverify.checkVerifyEnable();
    iPrint("checkVerifyEnable_res ${res.toString()}");
    bool result = res[fResultKey];
    if (result == false) {
      EasyLoading.showError('当前网络环境不支持，或者手机没有绑定电话卡'.tr);
      return '当前网络环境不支持，或者手机没有绑定电话卡'.tr;
    }

    final screenWidth = Get.width;
    final screenHeight = Get.height;
    bool isiOS = Platform.isIOS;

    /// 自定义授权的 UI 界面，以下设置的图片必须添加到资源文件里，
    /// android项目将图片存放至drawable文件夹下，可使用图片选择器的文件名,例如：btn_login.xml,入参为"btn_login"。
    /// ios项目存放在 Assets.xcassets。
    ///
    JVUIConfig uiConfig = JVUIConfig();
    // uiConfig.authBGGifPath = "main_gif";
    // uiConfig.authBGVideoPath="main_vi";
    // uiConfig.authBGVideoPath =
    //     "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4";
    // uiConfig.authBGVideoImgPath = "main_v_bg";

    // uiConfig.navHidden = !isiOS;
    uiConfig.navHidden = false;
    uiConfig.navColor = Colors.green.value;
    uiConfig.navText = " ";
    uiConfig.navTextColor = Colors.white.value;
    uiConfig.navReturnImgPath = null; //图片必须存在 如果设置为null 会给一个默认值
    uiConfig.navReturnBtnHidden = false;

    uiConfig.logoWidth = 100;
    uiConfig.logoHeight = 100;
    //uiConfig.logoOffsetX = isiOS ? 0 : null;//(screenWidth/2 - uiConfig.logoWidth/2).toInt();
    uiConfig.logoOffsetY = (screenHeight / 2).toInt() - 200;
    uiConfig.logoVerticalLayoutItem = JVIOSLayoutItem.ItemSuper;
    uiConfig.logoHidden = false;
    uiConfig.logoImgPath = "logo";

    uiConfig.numberFieldWidth = 200;
    uiConfig.numberFieldHeight = 40;
    //uiConfig.numFieldOffsetX = isiOS ? 0 : null;//(screenWidth/2 - uiConfig.numberFieldWidth/2).toInt();
    uiConfig.numFieldOffsetY = isiOS ? 20 : 120;
    uiConfig.numberVerticalLayoutItem = JVIOSLayoutItem.ItemLogo;
    uiConfig.numberColor = Colors.black.value;
    uiConfig.numberSize = 18;

    uiConfig.sloganOffsetY = isiOS ? 20 : 160;
    uiConfig.sloganVerticalLayoutItem = JVIOSLayoutItem.ItemNumber;
    uiConfig.sloganTextColor = Colors.black.value;
    uiConfig.sloganTextSize = 15;
    //uiConfig.slogan
    //uiConfig.sloganHidden = 0;

    uiConfig.logBtnWidth = 220;
    uiConfig.logBtnHeight = 50;
    //uiConfig.logBtnOffsetX = isiOS ? 0 : null;//(screenWidth/2 - uiConfig.logBtnWidth/2).toInt();
    uiConfig.logBtnOffsetY = isiOS ? 20 : 230;
    uiConfig.logBtnVerticalLayoutItem = JVIOSLayoutItem.ItemSlogan;
    uiConfig.logBtnText = "一键登录".tr;
    uiConfig.logBtnTextColor = Colors.black.value;
    uiConfig.logBtnTextSize = 16;
    uiConfig.logBtnTextBold = true;
    // uiConfig.loginBtnNormalImage = "login_btn_normal"; //图片必须存在
    // uiConfig.loginBtnPressedImage = "login_btn_press"; //图片必须存在
    // uiConfig.loginBtnUnableImage = "login_btn_unable"; //图片必须存在

    uiConfig.privacyHintToast = true; //only android 设置隐私条款不选中时点击登录按钮默认显示toast。

    uiConfig.privacyState = false; //设置默认勾选
    uiConfig.privacyCheckboxSize = 20;
    uiConfig.checkedImgPath = null; //图片必须存在, 如果设置为null 会给一个默认值
    uiConfig.uncheckedImgPath = null; //图片必须存在, 如果设置为null 会给一个默认值
    uiConfig.privacyCheckboxInCenter = true;
    uiConfig.privacyCheckboxHidden = false;
    uiConfig.isAlertPrivacyVc = true;

    // uiConfig.privacyOffsetX = isiOS ? (20 + uiConfig.privacyCheckboxSize!) : null;
    uiConfig.privacyOffsetY = 15; // 距离底部距离
    uiConfig.privacyVerticalLayoutItem = JVIOSLayoutItem.ItemSuper;
    uiConfig.clauseName = "用户服务协议";
    uiConfig.clauseUrl = "http://www.baidu.com";
    uiConfig.clauseBaseColor = Colors.black87.value;
    uiConfig.clauseNameTwo = "隐私保护政策";
    uiConfig.clauseUrlTwo = "http://www.hao123.com";
    uiConfig.clauseColor = Colors.black87.value;
    uiConfig.privacyText = ["我已阅读并同意", ""];
    uiConfig.privacyTextSize = 13;
    uiConfig.privacyItem = [
      JVPrivacy("用户服务协议", "http://www.baidu.com",
          beforeName: "==", afterName: "++", separator: "、"),
      JVPrivacy("隐私保护政策", "http://www.hao123.com", separator: "、"),
    ];
    uiConfig.textVerAlignment = 1;
    //uiConfig.privacyWithBookTitleMark = true;
    //uiConfig.privacyTextCenterGravity = false;
    uiConfig.authStatusBarStyle = JVIOSBarStyle.StatusBarStyleDarkContent;
    uiConfig.privacyStatusBarStyle = JVIOSBarStyle.StatusBarStyleDefault;
    uiConfig.modelTransitionStyle = JVIOSUIModalTransitionStyle.CrossDissolve;

    uiConfig.statusBarColorWithNav = true;
    uiConfig.virtualButtonTransparent = true;

    uiConfig.privacyStatusBarColorWithNav = true;
    uiConfig.privacyVirtualButtonTransparent = true;

    uiConfig.needStartAnim = true;
    uiConfig.needCloseAnim = true;
    uiConfig.enterAnim = "activity_slide_enter_bottom";
    uiConfig.exitAnim = "activity_slide_exit_bottom";

    uiConfig.privacyNavColor = Colors.green.value;
    uiConfig.privacyNavTitleTextColor = Colors.white.value;
    uiConfig.privacyNavTitleTextSize = 16;

    uiConfig.privacyNavTitleTitle = " "; //only ios
    uiConfig.privacyNavReturnBtnImage = null; //图片必须存在;

    //协议二次弹窗内容设置 -iOS
    uiConfig.isAlertPrivacyVc = true;
    uiConfig.agreementAlertViewCornerRadius = 15;
    uiConfig.agreementAlertViewBackgroundColor =
        const Color.fromARGB(255, 28, 27, 32).value;
    uiConfig.agreementAlertViewTitleTextColor = Colors.white.value;
    uiConfig.agreementAlertViewTitleText =
        "Please Read And Agree to The Following Terms".tr;
    uiConfig.agreementAlertViewTitleTexSize = 16;
    uiConfig.agreementAlertViewContentTextAlignment =
        JVTextAlignmentType.center;
    uiConfig.agreementAlertViewContentTextFontSize = 13;
    uiConfig.agreementAlertViewLoginBtnNormalImagePath = "login_btn_normal";
    uiConfig.agreementAlertViewLoginBtnPressedImagePath = "login_btn_press";
    uiConfig.agreementAlertViewLoginBtnUnableImagePath = "login_btn_unable";
    uiConfig.agreementAlertViewLoginBtnNormalImagePath =
        "login_btn_normal_dark";
    uiConfig.agreementAlertViewLoginBtnPressedImagePath =
        "login_btn_normal_dark";
    uiConfig.agreementAlertViewLoginBtnUnableImagePath =
        "login_btn_normal_dark";
    uiConfig.agreementAlertViewLogBtnText = "同意";
    uiConfig.agreementAlertViewLogBtnTextFontSize = 13;
    uiConfig.agreementAlertViewLogBtnTextColor =
        const Color.fromARGB(255, 128, 120, 89).value;

    //协议二次弹窗内容设置 -Android
    JVPrivacyCheckDialogConfig privacyCheckDialogConfig =
        JVPrivacyCheckDialogConfig();
    // privacyCheckDialogConfig.width = 250;
    // privacyCheckDialogConfig.height = 100;
    privacyCheckDialogConfig.title = "测试协议标题";
    privacyCheckDialogConfig.offsetX = 0;
    privacyCheckDialogConfig.offsetY = 0;
    privacyCheckDialogConfig.logBtnText = "同11意";
    privacyCheckDialogConfig.titleTextSize = 22;
    privacyCheckDialogConfig.gravity = "center";
    privacyCheckDialogConfig.titleTextColor = Colors.black.value;
    privacyCheckDialogConfig.contentTextGravity = "left";
    privacyCheckDialogConfig.contentTextSize = 14;
    privacyCheckDialogConfig.logBtnImgPath = "login_btn_normal";
    privacyCheckDialogConfig.logBtnTextColor = Colors.black.value;
    privacyCheckDialogConfig.logBtnMarginT = 20;
    privacyCheckDialogConfig.logBtnMarginB = 20;
    privacyCheckDialogConfig.logBtnMarginL = 10;
    privacyCheckDialogConfig.logBtnWidth = 140;
    privacyCheckDialogConfig.logBtnHeight = 40;

    /// 添加自定义的 控件 到dialog
    List<JVCustomWidget> dialogWidgetList = [];
    final String btn_dialog_widgetId = "jv_add_custom_dialog_button"; // 标识控件 id
    JVCustomWidget buttonDialogWidget =
        JVCustomWidget(btn_dialog_widgetId, JVCustomWidgetType.button);
    buttonDialogWidget.title = "取消";
    buttonDialogWidget.titleColor = Colors.white.value;
    buttonDialogWidget.left = 0;
    buttonDialogWidget.top = 160;
    buttonDialogWidget.width = 140;
    buttonDialogWidget.height = 40;
    buttonDialogWidget.textAlignment = JVTextAlignmentType.center;
    buttonDialogWidget.btnNormalImageName = "main_btn_other";
    buttonDialogWidget.btnPressedImageName = "main_btn_other";
    // buttonDialogWidget.backgroundColor = Colors.yellow.value;
    //buttonWidget.textAlignment = JVTextAlignmentType.left;

    // 添加点击事件监听
    jverify.addClikWidgetEventListener(btn_dialog_widgetId, (eventId) {
      print("receive listener - click dialog widget event :$eventId");
      if (btn_dialog_widgetId == eventId) {
        print("receive listener - 点击【新加 dialog button】");
      }
    });
    dialogWidgetList.add(buttonDialogWidget);
    privacyCheckDialogConfig.widgets = dialogWidgetList;
    uiConfig.privacyCheckDialogConfig = privacyCheckDialogConfig;

    //sms
    JVSMSUIConfig smsConfig = JVSMSUIConfig();
    smsConfig.smsPrivacyBeanList = [
      JVPrivacy("自定义协议1", "http://www.baidu.com",
          beforeName: "==", afterName: "++", separator: "*")
    ];
    smsConfig.enableSMSService = true;
    uiConfig.smsUIConfig = smsConfig;

    uiConfig.setIsPrivacyViewDarkMode = false; //协议页面是否支持暗黑模式

    //弹框模式
    // JVPopViewConfig popViewConfig = JVPopViewConfig();
    // popViewConfig.width = (screenWidth - 100.0).toInt();
    // popViewConfig.height = (screenHeight - 150.0).toInt();

    // uiConfig.popViewConfig = popViewConfig;

    /// 添加自定义的 控件 到授权界面
    List<JVCustomWidget> widgetList = [];

    /*
    final String text_widgetId = "jv_add_custom_text"; // 标识控件 id
    JVCustomWidget textWidget =
        JVCustomWidget(text_widgetId, JVCustomWidgetType.textView);
    textWidget.title = "新加 text view 控件";
    textWidget.left = 20;
    textWidget.top = 360;
    textWidget.width = 200;
    textWidget.height = 40;
    textWidget.backgroundColor = Colors.yellow.value;
    textWidget.isShowUnderline = true;
    textWidget.textAlignment = JVTextAlignmentType.center;
    textWidget.isClickEnable = true;

    // 添加点击事件监听
    jverify.addClikWidgetEventListener(text_widgetId, (eventId) {
      print("receive listener - click widget event :$eventId");
      if (text_widgetId == eventId) {
        print("receive listener - 点击【新加 text】");
      }
    });
    widgetList.add(textWidget);
    */

    /*
    final String btn_widgetId = "jv_add_custom_button"; // 标识控件 id
    JVCustomWidget buttonWidget =
        JVCustomWidget(btn_widgetId, JVCustomWidgetType.button);
    buttonWidget.title = "新加 button 控件";
    buttonWidget.left = 100;
    buttonWidget.top = 400;
    buttonWidget.width = 150;
    buttonWidget.height = 40;
    buttonWidget.isShowUnderline = true;
    buttonWidget.backgroundColor = Colors.brown.value;
    //buttonWidget.btnNormalImageName = "";
    //buttonWidget.btnPressedImageName = "";
    //buttonWidget.textAlignment = JVTextAlignmentType.left;

    // 添加点击事件监听
    jverify.addClikWidgetEventListener(btn_widgetId, (eventId) {
      print("receive listener - click widget event :$eventId");
      if (btn_widgetId == eventId) {
        print("receive listener - 点击【新加 button】");
      }
    });
    widgetList.add(buttonWidget);
    */
    // 设置iOS的二次弹窗按钮
    uiConfig.agreementAlertViewWidgets = dialogWidgetList;
    uiConfig.agreementAlertViewUIFrames = {
      "superViewFrame": [
        (screenWidth ~/ 2).toInt() - 140,
        (screenHeight ~/ 2).toInt() - 150,
        280,
        200
      ],
      "alertViewFrame": [0, 0, 280, 200],
      "titleFrame": [10, 10, 260, 60],
      "contentFrame": [15, 70, 250, 110],
      "buttonFrame": [140, 160, 140, 40]
    };

    /// 步骤 1：调用接口设置 UI
    jverify.setCustomAuthorizationView(
      true,
      uiConfig,
      landscapeConfig: uiConfig,
      widgets: widgetList,
    );
    if (!isSms) {
      /// 步骤 2：调用一键登录接口
      jverify.loginAuthSyncApi2(
          autoDismiss: true,
          enableSms: true,
          loginAuthcallback: (event) {
            // setState(() {
            //   _hideLoading();
            final _result = "获取返回数据：[${event.code}] message = ${event.message}";

            // });
            print(
                "获取到 loginAuthSyncApi 接口返回数据，code=${event.code},message = ${event.message},operator = ${event.operator}");
          });
    } else {
      /// 步骤 2：调用短信登录接口
      jverify.smsAuth(
          autoDismiss: true,
          smsCallback: (event) {
            // setState(() {
            //   _hideLoading();
            //   _result = "获取返回数据：[${event.code}] message = ${event.message}";
            // });
            print(
                "获取到 smsAuth 接口返回数据，code=${event.code},message = ${event.message},phone = ${event.phone}");
          });
    }
    return "jverify";
    /*
    //需要使用sms的时候不检查result
    if (result) {
    } else {
      // setState(() {
      //   _hideLoading();
      //   _result = "[2016],msg = 当前网络环境不支持认证";
      // });

      /* 弹框模式
        JVPopViewConfig popViewConfig = JVPopViewConfig();
        popViewConfig.width = (screenWidth - 100.0).toInt();
        popViewConfig.height = (screenHeight - 150.0).toInt();

        uiConfig.popViewConfig = popViewConfig;
        */

      /*

        /// 方式二：使用异步接口 （如果想使用异步接口，则忽略此步骤，看方式二）

        /// 先，执行异步的一键登录接口
        jverify.loginAuth(true).then((map) {

          /// 再，在回调里获取 loginAuth 接口异步返回数据（如果是通过添加 JVLoginAuthCallBackListener 监听来获取返回数据，则忽略此步骤）
          int code = map[f_code_key];
          String content = map[f_msg_key];
          String operator = map[f_opr_key];
          setState(() {
           _hideLoading();
            _result = "接口异步返回数据：[$code] message = $content";
          });
          print("通过接口异步返回，获取到 loginAuth 接口返回数据，code=$code,message = $content,operator = $operator");
        });

        */
    }
    */
  }

  checkSignupContinue() {
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
    // iPrint("checkSignupContinue_1 ${state.nickname.value.length > 1} ");
    // iPrint("checkSignupContinue_2 ${state.mobileValidated.isTrue} ");
    // iPrint("checkSignupContinue_3 ${state.selectedAgreement.value == 'on'} ");
    // iPrint("checkSignupContinue_4 $pwdValidated ");
    // iPrint("checkSignupContinue_5 ${state.showSignupContinue.toString()} ");
  }
}
