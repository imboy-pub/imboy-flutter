import 'dart:async';
import 'dart:io';

/// Temporary compatibility implementation for the identity module shell.
/// New module-facing callers should prefer `package:imboy/modules/identity/public.dart`.
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jverify/jverify.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/mine/change_password/set_password_page.dart';
import 'package:imboy/page/passport/manage_account_page.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'passport_state.dart';
part 'passport_notifier.g.dart';

/// Passport 模块 Riverpod Notifier
/// 管理 Passport 模块的状态和业务逻辑
@riverpod
class PassportNotifier extends _$PassportNotifier {
  final String fResultKey = "result";
  final String fCodeKey = "code";
  final String fMsgKey = "message";
  final String fOprKey = "operator";
  Jverify? jverify;

  @override
  PassportState build() {
    return PassportState(loginAccountCtl: TextEditingController());
  }

  /// 安全地更新 state
  /// 检查 ref 是否仍然 mounted，避免在 provider dispose 后更新 state
  void safeSetState(PassportState newState) {
    if (ref.mounted) {
      state = newState;
    }
  }

  /// 安全地通过 copyWith 更新 state
  void safeUpdateState(PassportState Function(PassportState) updater) {
    if (ref.mounted) {
      state = updater(state);
    }
  }

  /// 初始化登录历史记录
  void initLoginHistory() {
    final history = StorageService.to.getStringList(Keys.loginHistory) ?? [];
    final accountHistory =
        StorageService.to.getStringList(Keys.loginHistoryAccount) ?? [];
    final mobileHistory =
        StorageService.to.getStringList(Keys.loginHistoryMobile) ?? [];
    final emailHistory =
        StorageService.to.getStringList(Keys.loginHistoryEmail) ?? [];

    state = state.copyWith(
      loginHistory: history,
      accountHistory: accountHistory,
      mobileHistory: mobileHistory,
      emailHistory: emailHistory,
    );
  }

  /// 保存历史记录
  Future<void> saveHistory(String type, String value) async {
    if (value.isEmpty) return;
    final info = _historyInfoFor(type);
    if (info == null) return;

    final list = List<String>.from(info.currentList);
    list.remove(value);
    list.insert(0, value);
    final trimmed = list.length > 5 ? list.sublist(0, 5) : list;

    await StorageService.to.setList(info.key, trimmed);
    info.updateState(trimmed);
  }

  /// 删除历史记录
  Future<void> removeHistory(String type, String value) async {
    final info = _historyInfoFor(type);
    if (info == null) return;

    final list = List<String>.from(info.currentList);
    list.remove(value);

    await StorageService.to.setList(info.key, list);
    info.updateState(list);
  }

  /// 统一获取历史记录映射（消除 saveHistory/removeHistory 中的重复 if-else）
  _HistoryInfo? _historyInfoFor(String type) {
    switch (type) {
      case 'account':
        return _HistoryInfo(
          currentList: state.accountHistory,
          key: Keys.loginHistoryAccount,
          updateState: (l) => state = state.copyWith(accountHistory: l),
        );
      case 'mobile':
        return _HistoryInfo(
          currentList: state.mobileHistory,
          key: Keys.loginHistoryMobile,
          updateState: (l) => state = state.copyWith(mobileHistory: l),
        );
      case 'email':
        return _HistoryInfo(
          currentList: state.emailHistory,
          key: Keys.loginHistoryEmail,
          updateState: (l) => state = state.copyWith(emailHistory: l),
        );
      default:
        return null;
    }
  }

  /// 设置网络连接描述
  void setConnectDesc(String desc) {
    state = state.copyWith(connectDesc: desc);
  }

  /// 设置错误信息
  void setError(String error) {
    state = state.copyWith(error: error);
  }

  /// 切换登录密码可见性
  void toggleLoginPwdObscure() {
    state = state.copyWith(loginPwdObscure: !state.loginPwdObscure);
  }

  /// 切换新密码可见性
  void toggleNewPwdObscure() {
    state = state.copyWith(newPwdObscure: !state.newPwdObscure);
  }

  /// 切换确认密码可见性
  void setRetypePwdObscure(bool obscure) {
    state = state.copyWith(retypePwdObscure: obscure);
  }

  /// 设置确认密码
  void setRetypePwd(String pwd) {
    state = state.copyWith(retypePwd: pwd);
  }

  /// 设置账号类型
  void setAccountType(String type) {
    state = state.copyWith(accountType: type);
  }

  /// 设置注册继续页面临时数据（用于 go_router 导航）
  void setSignupData({
    required String account,
    required String accountType,
    required String password,
    String nickname = '',
  }) {
    state = state.copyWith(
      signupAccount: account,
      signupAccountType: accountType,
      signupPassword: password,
      signupNickname: nickname,
    );
  }

  /// 清除注册继续页面临时数据
  void clearSignupData() {
    state = state.copyWith(
      signupAccount: null,
      signupAccountType: null,
      signupPassword: null,
      signupNickname: null,
    );
  }

  /// 更新登录历史记录
  void updateLoginHistory(List<String> history) {
    state = state.copyWith(loginHistory: history);
  }

  /// 设置昵称
  void setNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
  }

  /// 设置手机号
  void setMobile(String mobile) {
    state = state.copyWith(mobile: mobile);
  }

  /// 设置邮箱
  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  /// 设置手机验证状态
  void setMobileValidated(bool validated) {
    state = state.copyWith(mobileValidated: validated);
  }

  /// 设置登录账号
  void setLoginAccount(String account) {
    state = state.copyWith(loginAccount: account);
  }

  /// 设置登录密码
  void setLoginPwd(String pwd) {
    state = state.copyWith(loginPwd: pwd);
  }

  /// 设置新密码
  void setNewPwd(String pwd) {
    state = state.copyWith(newPwd: pwd);
  }

  /// 设置协议同意状态
  void setSelectedAgreement(String agreement) {
    state = state.copyWith(selectedAgreement: agreement);
  }

  /// 返回按钮组件
  Widget backButton({Color? color}) {
    Color c = color ?? Colors.white;
    return InkWell(
      onTap: () {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.pop(context);
        } else {
          debugPrint(
            'Warning: navigatorKey.currentContext is null, cannot navigate back',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
              child: Icon(Icons.keyboard_arrow_left, color: c),
            ),
            Text(
              t.buttonBack,
              style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 账号验证
  String? userValidator(String accountType, String value) {
    if (value.isEmpty) {
      return t.errorEmptyDirectory(param: t.hintLoginAccount);
    }
    if (accountType == 'mobile' && !isPhone(value)) {
      return t.errorInvalid(param: t.mobile);
    } else if (accountType == 'email' && !isEmail(value)) {
      return t.errorInvalid(param: t.email);
    } else if (accountType == 'account' && value.length < 5) {
      return t.errorInvalid(param: t.account);
    }
    return null;
  }

  /// 密码格式验证
  String? passwordValidator(String? val) {
    if (strEmpty(val)) {
      return t.errorEmptyDirectory(param: t.password);
    }
    if (val!.length < 4 || val.length > 32) {
      return t.errorLengthBetween(param: t.password, min: '4', max: '32');
    }
    return null;
  }

  /// 用户登录
  Future<String?> loginUser(
    String accountType,
    String account,
    String password,
  ) async {
    try {
      int status = await _login(accountType, account, password);
      return _handleLoginStatus(status);
    } catch (e, s) {
      iPrint('state.error: $e; ${s.toString()}');
      return e.toString();
    }
  }

  Future<String?> loginUserByCode(
    String accountType,
    String account,
    String code,
  ) async {
    try {
      int status = await _loginByCode(accountType, account, code);
      return _handleLoginStatus(status);
    } catch (e, s) {
      iPrint('state.error: $e; ${s.toString()}');
      return e.toString();
    }
  }

  /// 处理登录结果状态（消除重复代码）
  String? _handleLoginStatus(int status) {
    if (status == 1) {
      state = state.copyWith(error: '', loginPwd: '');
      return null;
    } else if (status == 2) {
      _showCancelLogoutDialog();
      return t.cancelLogoutTitle;
    } else {
      return state.error;
    }
  }

  /// 显示"取消注销"确认对话框
  void _showCancelLogoutDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cancelLogoutTitle),
        content: SizedBox(
          height: 108,
          child: Text(
            t.cancelLogoutBody,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.buttonCancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(userApiProvider).cancelLogout();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                ctx,
                CupertinoPageRoute<dynamic>(
                  builder: (_) => const BottomNavigationPage(),
                ),
              );
            },
            child: Text(t.login),
          ),
        ],
      ),
    );
  }

  /// 加密密码
  Future<Map<String, dynamic>> _encryptPassword(String password) async {
    try {
      password = EncrypterService.md5(password);

      Map<String, dynamic> payload = await AppInitializer.initConfig();
      if (payload.containsKey('error')) {
        return payload;
      }
      String rsaEncrypt = payload['login_pwd_rsa_encrypt'].toString();

      String? encryptedPassword;
      if (rsaEncrypt == "1") {
        String pubKeyPem = payload['login_rsa_pub_key'].toString();
        if (kIsWeb) {
          // Web 平台：使用真正的 RSA 加密（Web Crypto API）
          encryptedPassword = await RSAService.rsaEncryptWithPointyCastleAsync(
            password,
            pubKeyPem,
          );
        } else {
          // 移动端/桌面端：使用 pointycastle
          encryptedPassword = RSAService.rsaEncryptWithPointyCastle(
            password,
            pubKeyPem,
          );
        }
      } else {
        encryptedPassword = password;
      }

      return <String, dynamic>{
        "password": encryptedPassword,
        "rsa_encrypt": rsaEncrypt,
      };
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('_encryptPassword error: $e\n$stackTrace');
      }
      return <String, dynamic>{
        "error": "${t.passwordEncryptFailed}: $e",
        "password": null,
        "rsa_encrypt": "0",
      };
    }
  }

  Future<int> _login(
    String accountType,
    String account,
    String password,
  ) async {
    try {
      Map<String, dynamic> data = await _encryptPassword(password);
      if (strNoEmpty(data['error'] as String?)) {
        safeUpdateState((state) => state.copyWith(error: data['error'] as String?));
        return 0;
      }

      Map<String, dynamic>? dinfo = await DeviceExt.to.detail;

      final publicKey = await _getLoginPublicKey();

      final pwdValue = data['password'];

      Map<String, dynamic> postData = {
        "type": accountType,
        "account": account,
        "pwd": pwdValue,
        "rsa_encrypt": data['rsa_encrypt'],
        "did": dinfo!["did"],
        "cos": dinfo["cos"],
        "public_key": publicKey,
      };
      if (UserRepoLocal.to.lastLoginAccount != account) {
        postData["dname"] = dinfo["deviceName"];
        postData["dvsn"] = dinfo["deviceVersion"];
      }

      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
      );

      if (!resp2.ok) {
        safeUpdateState((state) => state.copyWith(error: resp2.error!.message));
        return 0;
      } else {
        int status = (resp2.payload['status'] ?? 1) as int;
        if (status == 1 || status == 2) {
          await UserRepoLocal.to.loginAfter(account, resp2.payload as Map<String, dynamic>);

          // 上报 E2EE 公钥到服务器
          await _reportE2EEPublicKey();

          // 登录成功后主动连接 WebSocket
          // 延迟一小段时间确保存储操作完成
          await Future<dynamic>.delayed(const Duration(milliseconds: 100));
          WebSocketService.to.openSocket(from: 'login');
          unawaited(
            AppInitializer.triggerGroupMembershipSelfHeal(source: 'login'),
          );
        }
        return 1;
      }
    } on PlatformException catch (e, s) {
      if (kDebugMode) {
        debugPrint('PlatformException in _login: $e, trace $s');
      }
      if (e.code.contains('34018') ||
          e.message?.contains('entitlement') == true) {
        safeUpdateState((state) => state.copyWith(error: '安全存储初始化失败，请重启应用'));
      } else {
        safeUpdateState((state) => state.copyWith(error: '登录失败，请重试'));
      }
      return 0;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('_login error: $e, trace $s');
      }
      safeUpdateState((state) => state.copyWith(error: '登录失败，请重试'));
      return 0;
    }
  }

  Future<int> _loginByCode(
    String accountType,
    String account,
    String code,
  ) async {
    try {
      Map<String, dynamic>? dinfo = await DeviceExt.to.detail;
      Map<String, dynamic> postData = {
        "type": accountType,
        "account": account,
        "code": code,
        "did": dinfo!["did"],
        "cos": dinfo["cos"],
        "public_key": await _getLoginPublicKey(),
      };
      if (UserRepoLocal.to.lastLoginAccount != account) {
        postData["dname"] = dinfo["deviceName"];
        postData["dvsn"] = dinfo["deviceVersion"];
      }
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
      );
      if (!resp2.ok) {
        safeUpdateState((state) => state.copyWith(error: resp2.error!.message));
        return 0;
      } else {
        int status = (resp2.payload['status'] ?? 1) as int;
        if (status == 1 || status == 2) {
          await UserRepoLocal.to.loginAfter(account, resp2.payload as Map<String, dynamic>);

          // 步骤 5.5: 上报 E2EE 公钥到服务器
          await _reportE2EEPublicKey();

          // 登录成功后主动连接 WebSocket
          await Future<dynamic>.delayed(const Duration(milliseconds: 100));
          WebSocketService.to.openSocket(from: 'loginByCode');
          unawaited(
            AppInitializer.triggerGroupMembershipSelfHeal(
              source: 'loginByCode',
            ),
          );
        }
        return 1;
      }
    } on PlatformException {
      safeUpdateState((state) => state.copyWith(error: '网络故障，请稍后重试'));
      return 0;
    }
  }

  /// 登录阶段的设备公钥仅用于补充设备信息，Keychain 异常时不阻断认证。
  Future<String> _getLoginPublicKey() async {
    try {
      return await RSAService.publicKey();
    } on PlatformException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('登录设备公钥获取失败: $e\n$stackTrace');
      }
      return '';
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('登录设备公钥获取失败: $e\n$stackTrace');
      }
      return '';
    }
  }

  /// 用户注册 发送验证码
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
    required String accountType,
    required String code,
    required String nickname,
    required String account,
    required String pwd,
  }) async {
    Map<String, dynamic> data1 = await _encryptPassword(pwd);
    if (strNoEmpty(data1['error'] as String?)) {
      state = state.copyWith(error: '');
      return data1['error'] as String?;
    }
    final data = {
      "type": accountType,
      "nickname": nickname,
      "account": account,
      "pwd": data1["password"],
      "rsa_encrypt": data1["rsa_encrypt"],
      "code": code,
      "sys_version": getSystemVersion(),
      "ref_uid": "",
    };
    // 不在日志中输出 account 等敏感信息
    IMBoyHttpResponse resp2 = await HttpClient.client.post(
      API.signup,
      data: data,
    );
    if (resp2.ok) {
      return null;
    } else {
      state = state.copyWith(error: resp2.error?.message ?? t.unknown);
      return state.error;
    }
  }

  Future<String?> doSendCode(
    String account, {
    required String type,
    String? scene,
  }) async {
    IMBoyHttpResponse resp = await HttpClient.client.post(
      API.getCode,
      data: {"account": account, "type": type, "scene": scene},
    );
    if (resp.ok) {
      return null;
    } else {
      String errorMsg = resp.error?.message ?? 'error';
      if (errorMsg.contains('%s')) {
        errorMsg = errorMsg.replaceFirst('%s', account);
      }
      safeUpdateState((state) => state.copyWith(error: errorMsg));
      return errorMsg;
    }
  }

  /// 验证码修改密码
  Future<String?> resetPassword({
    required String type,
    required String account,
    required String code,
    required String newPwd,
    required String rePwd,
  }) async {
    if (strEmpty(newPwd)) {
      return t.errorRequired(param: t.newPassword);
    }

    String? error = passwordValidator(newPwd);
    if (error != null) {
      return error;
    }
    if (rePwd != newPwd) {
      return t.errorRetypePassword;
    }
    try {
      Map<String, dynamic> result = await _encryptPassword(newPwd);
      if (strNoEmpty(result['error'] as String?)) {
        state = state.copyWith(error: result['error'] as String?);
        return result['error'] as String?;
      }

      Map<String, dynamic> postData = {
        "type": type,
        "account": account,
        "code": code,
        "pwd": result['password'],
        "rsa_encrypt": result['rsa_encrypt'],
        "sys_version": getSystemVersion(),
      };

      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.findPassword,
        data: postData,
      );
      if (!resp2.ok) {
        state = state.copyWith(error: resp2.error!.message);
        return state.error;
      } else {
        StorageService.to.setString(Keys.lastLoginAccount, account);
        return null;
      }
    } on PlatformException {
      state = state.copyWith(error: '网络故障，请稍后重试');
      return state.error;
    }
  }

  /// 显示SnackBar提示
  void snackBar(dynamic message, {Icon? icon}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        'Warning: navigatorKey.currentContext is null, cannot show SnackBar',
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: message is String
              ? Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                )
              : message as Widget,
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  /// 初始化极光认证SDK
  Future<void> initPlatformState() async {
    // Web 平台不支持 JVerify 一键登录
    if (kIsWeb) {
      debugPrint("JVerify: Web 平台不支持一键登录功能");
      return;
    }

    try {
      jverify = Jverify();
      jverify!.addSDKSetupCallBackListener((JVSDKSetupEvent event) {
        iPrint("receive sdk setup call back event :${event.toMap()}");
      });

      jverify!.setDebugMode(kDebugMode);
      jverify!.setCollectionAuth(true);
      jverify!.setup(appKey: Env().jiguangAppKey, channel: "devloper-default");

      jverify!.addAuthPageEventListener((JVAuthPageEvent event) {
        if (kDebugMode) {
          debugPrint("receive auth page event :${event.toMap()}");
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint("JVerify初始化异常: $e");
      }
    }
  }

  /// 检查注册信息是否完整
  void checkSignupContinue() {
    bool pwdValidated = passwordValidator(state.newPwd) == null ? true : false;
    if (state.nickname.length > 1 &&
        state.mobileValidated &&
        state.selectedAgreement == 'on' &&
        pwdValidated) {
      state = state.copyWith(showSignupContinue: true);
    } else {
      state = state.copyWith(showSignupContinue: false);
    }
    iPrint("checkSignupContinue_1 ${state.nickname.length > 1} ");
    iPrint("checkSignupContinue_2 ${state.mobileValidated} ");
    iPrint("checkSignupContinue_3 ${state.selectedAgreement == 'on'} ");
    iPrint("checkSignupContinue_4 $pwdValidated ");
    iPrint("checkSignupContinue_5 ${state.showSignupContinue} ");
  }

  /// 获取用户协议URL
  String licenseAgreementUrl({String ext = 'md'}) {
    String lang = 'cn';
    String code = LocaleHelper.sysLang('').toLowerCase();
    if (code.contains('en')) {
      lang = 'en';
    } else if (code.contains('ru')) {
      lang = 'ru';
    }
    return "https://imboy.pub/doc/license_agreement_$lang.$ext?vsn=$appVsn";
  }

  /// 快速登录
  Future<String?> quickLogin({
    required String operator,
    required String token,
    required String service,
  }) async {
    Map<String, dynamic> postData = {
      "service": service,
      "operator": operator,
      "token": token,
      "sys_version": getSystemVersion(),
    };

    IMBoyHttpResponse resp2 = await HttpClient.client.post(
      API.quickLogin,
      data: postData,
    );
    if (!resp2.ok) {
      state = state.copyWith(error: resp2.error!.message);
      return state.error;
    } else {
      int status = (resp2.payload['status'] ?? 1) as int;
      String account = resp2.payload['account'] as String? ?? '';
      if (account.isNotEmpty) {
        await StorageService.to.setString(Keys.lastLoginAccount, account);
      }
      if (status == 1 || status == 2) {
        await UserRepoLocal.to.loginAfter(account, resp2.payload as Map<String, dynamic>);
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));
        WebSocketService.to.openSocket(from: 'quickLogin');
        unawaited(
          AppInitializer.triggerGroupMembershipSelfHeal(source: 'quickLogin'),
        );
      }
      String action = resp2.payload['action'] as String? ?? '';
      if (action == 'need_set_password') {
        await StorageService.to.setBool(Keys.needSetPwd, true);
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute<dynamic>(builder: (_) => SetPasswordPage()),
          );
        }
      } else {
        final user = UserRepoLocal.to.current;
        final needGuide = (user.email.isEmpty || user.mobile.isEmpty);
        final context = navigatorKey.currentContext;
        if (context != null) {
          if (needGuide) {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute<dynamic>(builder: (_) => const ManageAccountPage()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute<dynamic>(builder: (_) => const BottomNavigationPage()),
              (route) => false,
            );
          }
        }
      }
      return null;
    }
  }

  /// 监听网络状态变化
  StreamSubscription<List<ConnectivityResult>>? listenConnectivity() {
    return Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> r,
    ) {
      if (r.contains(ConnectivityResult.none)) {
        setConnectDesc(t.tipConnectDesc);
      } else {
        setConnectDesc('');
      }
    });
  }

  /// 初始化极光认证 SDK 并设置 UI 配置
  Future<String?> loginAuth(bool isSms) async {
    // Web 平台不支持 JVerify 一键登录
    if (kIsWeb || jverify == null) {
      snackBar('Web 平台不支持一键登录功能');
      return null;
    }

    Map<dynamic, dynamic> res = await jverify!.checkVerifyEnable();
    iPrint("checkVerifyEnable_res ${res.toString()}");
    bool result = res[fResultKey] as bool;
    if (result == false) {
      snackBar('当前网络环境不支持，或者手机没有绑定电话卡');
      return null;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      snackBar('无法获取屏幕尺寸');
      return null;
    }
    final screenHeight = MediaQuery.of(context).size.height;
    bool isiOS = Platform.isIOS;

    /// 自定义授权的 UI 界面
    JVUIConfig uiConfig = JVUIConfig();

    uiConfig.navHidden = false;
    uiConfig.navColor = Colors.green.toARGB32();
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
    uiConfig.logBtnText = t.mobileQuickLogin;
    uiConfig.logBtnTextColor = isiOS
        ? Colors.black.toARGB32()
        : Colors.white.toARGB32();
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
    uiConfig.clauseName = t.licenseAgreement;
    uiConfig.clauseUrl = licenseAgreementUrl(ext: 'html');
    uiConfig.clauseBaseColor = Colors.black87.toARGB32();

    uiConfig.clauseColor = Colors.black87.toARGB32();
    uiConfig.privacyTextSize = 13;
    uiConfig.privacyItem = [
      JVPrivacy(
        t.licenseAgreement.replaceAll('《', '').replaceAll('》', ''),
        licenseAgreementUrl(ext: 'html'),
        beforeName: "==",
        afterName: "++",
        separator: "、",
      ),
    ];

    /// 步骤 1：调用接口设置 UI
    jverify!.setCustomAuthorizationView(
      true,
      uiConfig,
      landscapeConfig: uiConfig,
      widgets: [],
    );

    /// 步骤 2：调用一键登录接口
    jverify!.loginAuthSyncApi2(
      autoDismiss: true,
      enableSms: true,
      loginAuthcallback: (event) {
        if (event.code == 6000) {
          unawaited(
            quickLogin(
              operator: event.operator!,
              token: event.message!,
              service: 'jverify',
            ),
          );
        } else {
          snackBar(event.message);
        }
      },
    );
    return "jverify";
  }

  /// 上报 E2EE 公钥到服务器
  ///
  /// 登录成功后调用，确保服务器有当前设备的 E2EE 公钥
  /// 这样其他用户才能发送加密消息给当前用户
  Future<void> _reportE2EEPublicKey() async {
    try {
      final storage = StorageSecureService.to;

      // 检查是否已有 E2EE 密钥
      bool hasKey = await storage.hasE2EEKeys();

      // 如果没有密钥，生成新的密钥对
      if (!hasKey) {
        await E2EEKeyService.generateKeyPair();
      }

      // 获取密钥信息
      final storedDeviceId = await storage.getDeviceId();
      final keyId = await storage.getKeyId();
      final publicKey = await storage.getPublicKey();

      // 如果存储的 deviceId 为空，从设备信息获取
      String deviceId = storedDeviceId ?? '';
      if (deviceId.isEmpty) {
        final dinfo = await DeviceExt.to.detail;
        deviceId = dinfo?['did']?.toString() ?? '';
        if (deviceId.isNotEmpty) {
          // 保存到存储
          await storage.setDeviceId(deviceId);
        }
      }

      if (deviceId.isEmpty || keyId == null || publicKey == null) {
        debugPrint('⚠️ E2EE 密钥信息不完整，跳过上报');
        return;
      }

      // 获取设备信息
      final dinfo = await DeviceExt.to.detail;
      final deviceType = dinfo?['cos'] ?? 'unknown';
      final deviceName = dinfo?['deviceName'];

      // 上报公钥到服务器
      final success = await E2EEApi().reportDeviceKey(
        deviceId: deviceId,
        deviceType: deviceType as String,
        deviceName: deviceName as String?,
        publicKey: publicKey,
        keyId: keyId,
      );

      if (!success && kDebugMode) {
        debugPrint('E2EE 公钥上报失败，但不影响登录');
      }
    } catch (e) {
      // E2EE 公钥上报失败不应该阻止登录
      if (kDebugMode) {
        debugPrint('E2EE 公钥上报异常: $e');
      }
    }
  }

  /// 获取系统版本（Web 兼容）
  String getSystemVersion() {
    if (kIsWeb) {
      return 'Web Browser';
    }
    return Platform.operatingSystemVersion;
  }
}

/// 历史记录辅助类（用于消除 saveHistory/removeHistory 中的重复 if-else）
class _HistoryInfo {
  final List<String> currentList;
  final String key;
  final void Function(List<String>) updateState;

  const _HistoryInfo({
    required this.currentList,
    required this.key,
    required this.updateState,
  });
}
