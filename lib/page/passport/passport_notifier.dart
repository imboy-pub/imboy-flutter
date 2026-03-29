import 'dart:async';
import 'dart:io';

/// Temporary compatibility implementation for the identity module shell.
/// New module-facing callers should prefer `package:imboy/modules/identity/public.dart`.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jverify/jverify.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/theme/default/app_colors.dart';
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

    List<String> list = [];
    String key = '';

    if (type == 'account') {
      list = List.from(state.accountHistory);
      key = Keys.loginHistoryAccount;
    } else if (type == 'mobile') {
      list = List.from(state.mobileHistory);
      key = Keys.loginHistoryMobile;
    } else if (type == 'email') {
      list = List.from(state.emailHistory);
      key = Keys.loginHistoryEmail;
    } else {
      return;
    }

    // Remove if exists to move to top
    list.remove(value);
    list.insert(0, value);
    // Limit to 5
    if (list.length > 5) {
      list = list.sublist(0, 5);
    }

    await StorageService.to.setList(key, list);

    if (type == 'account') {
      state = state.copyWith(accountHistory: list);
    } else if (type == 'mobile') {
      state = state.copyWith(mobileHistory: list);
    } else if (type == 'email') {
      state = state.copyWith(emailHistory: list);
    }
  }

  /// 删除历史记录
  Future<void> removeHistory(String type, String value) async {
    List<String> list = [];
    String key = '';

    if (type == 'account') {
      list = List.from(state.accountHistory);
      key = Keys.loginHistoryAccount;
    } else if (type == 'mobile') {
      list = List.from(state.mobileHistory);
      key = Keys.loginHistoryMobile;
    } else if (type == 'email') {
      list = List.from(state.emailHistory);
      key = Keys.loginHistoryEmail;
    } else {
      return;
    }

    list.remove(value);
    await StorageService.to.setList(key, list);

    if (type == 'account') {
      state = state.copyWith(accountHistory: list);
    } else if (type == 'mobile') {
      state = state.copyWith(mobileHistory: list);
    } else if (type == 'email') {
      state = state.copyWith(emailHistory: list);
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

  /// 标题组件
  Widget title({Color? color}) {
    Color c = color ?? AppColors.primary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/imboy_logo0.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'IM',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 1.2,
            ),
            children: [
              TextSpan(
                text: 'Boy',
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simple · Secure · Reliable',
          style: TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
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
      if (status == 1) {
        state = state.copyWith(error: '', loginPwd: '');
        return null;
      } else if (status == 2) {
        // 显示取消登录对话框
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.buttonCancel),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(userApiProvider).cancelLogout();
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
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
        return t.cancelLogoutTitle;
      } else {
        return state.error;
      }
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
      if (status == 1) {
        state = state.copyWith(error: '', loginPwd: '');
        return null;
      } else if (status == 2) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.buttonCancel),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(userApiProvider).cancelLogout();
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
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
        return t.cancelLogoutTitle;
      } else {
        return state.error;
      }
    } catch (e, s) {
      iPrint('state.error: $e; ${s.toString()}');
      return e.toString();
    }
  }

  /// 加密密码
  Future<Map<String, dynamic>> _encryptPassword(String password) async {
    debugPrint('🔐 _encryptPassword 开始, 原始密码长度=${password.length}');
    try {
      password = EncrypterService.md5(password);
      debugPrint('🔐 MD5 加密完成: $password');

      Map<String, dynamic> payload = await AppInitializer.initConfig();
      if (payload.containsKey('error')) {
        debugPrint('❌ initConfig 返回错误: ${payload['error']}');
        return payload;
      }
      String rsaEncrypt = payload['login_pwd_rsa_encrypt'].toString();
      debugPrint('🔐 rsa_encrypt 配置: $rsaEncrypt');

      String? encryptedPassword;
      if (rsaEncrypt == "1") {
        String pubKeyPem = payload['login_rsa_pub_key'].toString();
        debugPrint('🔐 开始 RSA 加密, pubKeyPem长度=${pubKeyPem.length}');
        if (kIsWeb) {
          // Web 平台：使用真正的 RSA 加密（Web Crypto API）
          debugPrint('🌐 Web 平台：使用 Web Crypto API 进行 RSA 加密');
          encryptedPassword = await RSAService.rsaEncryptWithPointyCastleAsync(
            password,
            pubKeyPem,
          );
          debugPrint('✅ Web RSA 加密完成, 加密后密码长度=${encryptedPassword.length}');
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

      final result = <String, dynamic>{
        "password": encryptedPassword,
        "rsa_encrypt": rsaEncrypt,
      };
      debugPrint(
        '🔐 _encryptPassword 返回: password类型=${result['password'].runtimeType}, password长度=${(result['password'] as String).length}, rsa_encrypt=${result['rsa_encrypt']}',
      );
      debugPrint(
        '🔐 _encryptPassword 密码前50字符: ${(result['password'] as String).substring(0, (result['password'] as String).length > 50 ? 50 : (result['password'] as String).length)}',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ _encryptPassword 异常: $e');
      debugPrint('堆栈: $stackTrace');
      return <String, dynamic>{
        "error": "密码加密失败: $e",
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
    debugPrint('🔐 _login 开始: accountType=$accountType, account=$account');
    try {
      debugPrint('🔐 步骤1: 加密密码');
      Map<String, dynamic> data = await _encryptPassword(password);
      if (strNoEmpty(data['error'])) {
        debugPrint('❌ 加密失败: ${data['error']}');
        safeUpdateState((state) => state.copyWith(error: data['error']));
        return 0;
      }
      debugPrint('✅ 密码加密完成');

      debugPrint('🔐 步骤2: 获取设备信息');
      Map<String, dynamic>? dinfo = await DeviceExt.to.detail;
      debugPrint('✅ 设备信息获取完成: did=${dinfo!["did"]}');

      debugPrint('🔐 步骤3: 获取RSA公钥');
      final publicKey = await _getLoginPublicKey();
      debugPrint('✅ RSA公钥获取完成');

      // 添加日志查看 data['password'] 的值
      final pwdValue = data['password'];
      debugPrint(
        '🔐 准备构建 postData: data["password"]类型=${pwdValue.runtimeType}, 值=$pwdValue',
      );

      Map<String, dynamic> postData = {
        "type": accountType,
        "account": account,
        "pwd": pwdValue,
        "rsa_encrypt": data['rsa_encrypt'],
        "did": dinfo["did"],
        "cos": dinfo["cos"],
        "public_key": publicKey,
      };
      debugPrint(
        '🔐 postData["pwd"]类型=${postData["pwd"].runtimeType}, 值=${postData["pwd"]}',
      );
      if (UserRepoLocal.to.lastLoginAccount != account) {
        postData["dname"] = dinfo["deviceName"];
        postData["dvsn"] = dinfo["deviceVersion"];
      }

      debugPrint('🔐 步骤4: 发送登录请求到 ${API.login}');
      IMBoyHttpResponse resp2 = await HttpClient.client.post(
        API.login,
        data: postData,
      );
      debugPrint('✅ 登录请求完成: ok=${resp2.ok}');

      if (!resp2.ok) {
        debugPrint('❌ 登录失败: ${resp2.error!.message}');
        safeUpdateState((state) => state.copyWith(error: resp2.error!.message));
        return 0;
      } else {
        int status = (resp2.payload['status'] ?? 1).toInt();
        debugPrint('✅ 登录响应状态: status=$status');
        if (status == 1 || status == 2) {
          debugPrint('🔐 步骤5: 保存登录信息');
          await UserRepoLocal.to.loginAfter(account, resp2.payload);
          debugPrint('✅ 登录信息保存完成');

          // 步骤 5.5: 上报 E2EE 公钥到服务器
          debugPrint('🔐 步骤5.5: 上报 E2EE 公钥');
          await _reportE2EEPublicKey();
          debugPrint('✅ E2EE 公钥上报完成');

          // 登录成功后主动连接 WebSocket
          debugPrint('🔌 步骤6: 连接 WebSocket');
          // 延迟一小段时间确保存储操作完成
          await Future.delayed(const Duration(milliseconds: 100));
          // 直接调用 openSocket 而不是依赖被动触发
          WebSocketService.to.openSocket(from: 'login');
          unawaited(
            AppInitializer.triggerGroupMembershipSelfHeal(source: 'login'),
          );
          debugPrint('✅ WebSocket 连接已触发');
        }
        return 1;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException: $e');
      safeUpdateState((state) => state.copyWith(error: '网络故障，请稍后重试'));
      return 0;
    } catch (e) {
      debugPrint('❌ 异常: $e');
      safeUpdateState((state) => state.copyWith(error: '登录失败: $e'));
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
        int status = (resp2.payload['status'] ?? 1).toInt();
        if (status == 1 || status == 2) {
          await UserRepoLocal.to.loginAfter(account, resp2.payload);

          // 步骤 5.5: 上报 E2EE 公钥到服务器
          await _reportE2EEPublicKey();

          // 登录成功后主动连接 WebSocket
          await Future.delayed(const Duration(milliseconds: 100));
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
      debugPrint('⚠️ 登录设备公钥获取失败，降级为空继续登录: $e');
      debugPrint('堆栈: $stackTrace');
      return '';
    } catch (e, stackTrace) {
      debugPrint('⚠️ 登录设备公钥获取失败，降级为空继续登录: $e');
      debugPrint('堆栈: $stackTrace');
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
    if (strNoEmpty(data1['error'])) {
      state = state.copyWith(error: '');
      return data1['error'];
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
    debugPrint(
      "post_data account=${data['account']}, rsa_encrypt=${data['rsa_encrypt']}",
    );
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
      if (strNoEmpty(result['error'])) {
        state = state.copyWith(error: result['error']);
        return result['error'];
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
              : message,
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

      jverify!.setDebugMode(true);
      jverify!.setCollectionAuth(true);
      jverify!.setup(appKey: Env().jiguangAppKey, channel: "devloper-default");

      jverify!.addAuthPageEventListener((JVAuthPageEvent event) {
        debugPrint("receive auth page event :${event.toMap()}");
      });
    } catch (e) {
      debugPrint("JVerify初始化异常: $e");
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
      int status = (resp2.payload['status'] ?? 1).toInt();
      String account = resp2.payload['account'] ?? '';
      if (account.isNotEmpty) {
        await StorageService.to.setString(Keys.lastLoginAccount, account);
      }
      if (status == 1 || status == 2) {
        await UserRepoLocal.to.loginAfter(account, resp2.payload);
        await Future.delayed(const Duration(milliseconds: 100));
        WebSocketService.to.openSocket(from: 'quickLogin');
        unawaited(
          AppInitializer.triggerGroupMembershipSelfHeal(source: 'quickLogin'),
        );
      }
      String action = resp2.payload['action'] ?? '';
      if (action == 'need_set_password') {
        await StorageService.to.setBool(Keys.needSetPwd, true);
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(builder: (_) => SetPasswordPage()),
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
              CupertinoPageRoute(builder: (_) => const ManageAccountPage()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (_) => const BottomNavigationPage()),
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
    bool result = res[fResultKey];
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
          quickLogin(
            operator: event.operator!,
            token: event.message!,
            service: 'jverify',
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
        debugPrint('🔐 E2EE 密钥不存在，生成新密钥对...');
        await E2EEKeyService.generateKeyPair();
        debugPrint('✅ E2EE 密钥对已生成');
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
      debugPrint('📤 上报 E2EE 公钥: deviceId=$deviceId, keyId=$keyId');
      final success = await E2EEApi().reportDeviceKey(
        deviceId: deviceId,
        deviceType: deviceType,
        deviceName: deviceName,
        publicKey: publicKey,
        keyId: keyId,
      );

      if (success) {
        debugPrint('✅ E2EE 公钥上报成功');
      } else {
        debugPrint('⚠️ E2EE 公钥上报失败，但不影响登录');
      }
    } catch (e) {
      // E2EE 公钥上报失败不应该阻止登录
      debugPrint('⚠️ E2EE 公钥上报异常: $e');
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
