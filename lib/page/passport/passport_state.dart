import 'package:flutter/material.dart';

/// Passport 模块状态
/// 使用 Riverpod 管理的状态类
class PassportState {
  // 账号输入控制器
  final TextEditingController loginAccountCtl;

  // 网络状态描述
  final String connectDesc;

  // 错误信息
  final String error;

  // 昵称
  final String nickname;

  // 手机号
  final String mobile;

  // 账号类型: 'account' | 'mobile' | 'email'
  final String accountType;

  // 注册使用的 email 字段（用于邮箱注册）
  final String email;

  // 手机号码格式验证（也用于 email 注册时表示账号格式验证通过）
  final bool mobileValidated;

  // 注册页面"同意并继续"按钮是否高亮
  final bool showSignupContinue;

  // 登录账号
  final String loginAccount;

  // 登录密码
  final String loginPwd;

  // 登录密码是否隐藏
  final bool loginPwdObscure;

  // 登录历史记录 (General - kept for backward compatibility)
  final List<String> loginHistory;

  // 登录历史记录 (Specific)
  final List<String> accountHistory;
  final List<String> mobileHistory;
  final List<String> emailHistory;

  // 现有密码
  final String existingPwd;

  // 新密码
  final String newPwd;

  // 确认密码
  final String retypePwd;

  // 现有密码是否隐藏
  final bool existingPwdObscure;

  // 新密码是否隐藏
  final bool newPwdObscure;

  // 确认密码是否隐藏
  final bool retypePwdObscure;

  // 是否同意协议
  final String selectedAgreement;

  // 注册继续页面临时数据（用于 go_router 导航传递敏感数据）
  final String? signupAccount;
  final String? signupAccountType;
  final String? signupPassword;
  final String? signupNickname;

  const PassportState({
    required this.loginAccountCtl,
    this.connectDesc = '',
    this.error = '',
    this.nickname = '',
    this.mobile = '',
    this.accountType =
        'account', // Default to account per request structure (Tab 1)
    this.email = '',
    this.mobileValidated = false,
    this.showSignupContinue = false,
    this.loginAccount = '',
    this.loginPwd = '',
    this.loginPwdObscure = true,
    this.loginHistory = const [],
    this.accountHistory = const [],
    this.mobileHistory = const [],
    this.emailHistory = const [],
    this.existingPwd = '',
    this.newPwd = '',
    this.retypePwd = '',
    this.existingPwdObscure = true,
    this.newPwdObscure = true,
    this.retypePwdObscure = true,
    this.selectedAgreement = '',
    this.signupAccount,
    this.signupAccountType,
    this.signupPassword,
    this.signupNickname,
  });

  /// 复制状态并更新部分字段
  PassportState copyWith({
    TextEditingController? loginAccountCtl,
    String? connectDesc,
    String? error,
    String? nickname,
    String? mobile,
    String? accountType,
    String? email,
    bool? mobileValidated,
    bool? showSignupContinue,
    String? loginAccount,
    String? loginPwd,
    bool? loginPwdObscure,
    List<String>? loginHistory,
    List<String>? accountHistory,
    List<String>? mobileHistory,
    List<String>? emailHistory,
    String? existingPwd,
    String? newPwd,
    String? retypePwd,
    bool? existingPwdObscure,
    bool? newPwdObscure,
    bool? retypePwdObscure,
    String? selectedAgreement,
    String? signupAccount,
    String? signupAccountType,
    String? signupPassword,
    String? signupNickname,
  }) {
    return PassportState(
      loginAccountCtl: loginAccountCtl ?? this.loginAccountCtl,
      connectDesc: connectDesc ?? this.connectDesc,
      error: error ?? this.error,
      nickname: nickname ?? this.nickname,
      mobile: mobile ?? this.mobile,
      accountType: accountType ?? this.accountType,
      email: email ?? this.email,
      mobileValidated: mobileValidated ?? this.mobileValidated,
      showSignupContinue: showSignupContinue ?? this.showSignupContinue,
      loginAccount: loginAccount ?? this.loginAccount,
      loginPwd: loginPwd ?? this.loginPwd,
      loginPwdObscure: loginPwdObscure ?? this.loginPwdObscure,
      loginHistory: loginHistory ?? this.loginHistory,
      accountHistory: accountHistory ?? this.accountHistory,
      mobileHistory: mobileHistory ?? this.mobileHistory,
      emailHistory: emailHistory ?? this.emailHistory,
      existingPwd: existingPwd ?? this.existingPwd,
      newPwd: newPwd ?? this.newPwd,
      retypePwd: retypePwd ?? this.retypePwd,
      existingPwdObscure: existingPwdObscure ?? this.existingPwdObscure,
      newPwdObscure: newPwdObscure ?? this.newPwdObscure,
      retypePwdObscure: retypePwdObscure ?? this.retypePwdObscure,
      selectedAgreement: selectedAgreement ?? this.selectedAgreement,
      signupAccount: signupAccount ?? this.signupAccount,
      signupAccountType: signupAccountType ?? this.signupAccountType,
      signupPassword: signupPassword ?? this.signupPassword,
      signupNickname: signupNickname ?? this.signupNickname,
    );
  }
}
