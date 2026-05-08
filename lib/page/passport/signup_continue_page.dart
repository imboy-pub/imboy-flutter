import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/widget/fadeanimation.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';

class SignupContinuePage extends ConsumerStatefulWidget {
  // 构造函数参数改为可选，用于向后兼容
  // go_router 导航时从 provider 读取数据
  final String? account;
  final String? accountType;
  final String? nickname;
  final String? pwd;

  const SignupContinuePage({
    super.key,
    this.account,
    this.accountType,
    this.nickname,
    this.pwd,
  });

  @override
  ConsumerState<SignupContinuePage> createState() => _SignupContinuePageState();
}

class _SignupContinuePageState extends ConsumerState<SignupContinuePage> {
  final _pinController = PinInputController();

  bool hasError = false;
  String currentText = "";
  final formKey = GlobalKey<FormState>();

  StreamSubscription? _localeSubscription;

  // 缓存 notifier 引用：dispose() 中不能再用 ref（widget 已 deactivate），
  // 必须 initState 时缓存到字段内，参考 Riverpod 3.x 推荐模式
  PassportNotifier? _passportNotifier;

  // 从 provider 或构造函数获取数据
  String get _account =>
      widget.account ?? ref.read(passportProvider).signupAccount ?? '';
  String get _accountType =>
      widget.accountType ?? ref.read(passportProvider).signupAccountType ?? '';
  String get _nickname =>
      widget.nickname ?? ref.read(passportProvider).signupNickname ?? '';
  String get _pwd =>
      widget.pwd ?? ref.read(passportProvider).signupPassword ?? '';

  @override
  void initState() {
    super.initState();
    _passportNotifier = ref.read(passportProvider.notifier);
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _pinController.dispose();
    // 清理临时数据：用缓存的 notifier 而非 ref（避免 dispose 阶段 ref 失效）
    _passportNotifier?.clearSignupData();
    super.dispose();
  }

  void _showSnackBar(
    BuildContext context,
    Widget message, {
    Color backgroundColor = Colors.red,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: message,
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(passportProvider.notifier);
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final surfaceContainerColor = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;

    // 验证数据完整性
    if (_account.isEmpty || _accountType.isEmpty || _pwd.isEmpty) {
      return Scaffold(
        backgroundColor: surfaceColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                t.unknown,
                style: TextStyle(fontSize: 18, color: textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (!context.mounted) return;
                  context.go('/sign_up');
                },
                child: Text(t.buttonBack),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  FadeAnimation(
                    delay: 0.8,
                    child: const PassportTitle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0.0,
                            vertical: 8,
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: _accountType == 'email'
                                  ? t.codeSentToEmail
                                  : t.codeSentToMobile,
                              children: [
                                TextSpan(
                                  text: _account,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Form(
                          key: formKey,
                          child: MaterialPinField(
                            length: 6,
                            pinController: _pinController,
                            obscureText: true,
                            obscuringWidget: Icon(
                              Icons.safety_check,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            blinkWhenObscuring: true,
                            theme: MaterialPinTheme(
                              shape: MaterialPinShape.outlined,
                              cellSize: const Size(40, 50),
                              borderRadius: AppRadius.borderRadiusSmall,
                              borderColor: borderColor,
                              focusedBorderColor: AppColors.primary,
                              filledBorderColor: AppColors.primary,
                              fillColor: surfaceContainerColor,
                              textStyle: TextStyle(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onCompleted: (v) {
                              debugPrint("Completed");
                            },
                            onChanged: (value) {
                              setState(() {
                                currentText = value;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            hasError ? t.pinCodeFillTips : '',
                            style: TextStyle(
                              color: errorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.notReceiveCoeQ,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  String? res = await notifier.sendCode(
                                    _accountType,
                                    _account,
                                    'signup',
                                  );
                                  if (!context.mounted) return;
                                  if (res == null) {
                                    _showSnackBar(
                                      context,
                                      Text(
                                        t.codeSentToParam(param: _account),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      backgroundColor: AppColors.primary,
                                    );
                                  } else {
                                    if (res == 'param_already_exist') {
                                      final label = _accountType == 'email'
                                          ? t.email
                                          : t.mobile;
                                      _showSnackBar(
                                        context,
                                        Text(
                                          t.paramAlreadyExist(param: label),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    } else {
                                      _showSnackBar(
                                        context,
                                        Text(
                                          res,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  t.resendCode,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () async {
                            String? res = await notifier.confirmSignup(
                              accountType: _accountType,
                              account: _account,
                              nickname: _nickname,
                              code: currentText,
                              pwd: _pwd,
                            );
                            if (!context.mounted) return;
                            if (res == null) {
                              _showSnackBar(
                                context,
                                Text(
                                  t.tipSuccess,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              );
                              // 注册成功后引导用户去管理账户（绑定手机号/关联邮箱）
                              context.go('/manage_account');
                            } else {
                              _showSnackBar(
                                context,
                                Text(
                                  res,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderRadiusRegular,
                            ),
                            elevation: 0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Text(
                              t.signup,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeAnimation(
                    delay: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.tryAgainQ,
                          style: TextStyle(
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (!context.mounted) return;
                            context.go('/sign_in');
                          },
                          child: Text(
                            t.login,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 底部安全间距，防止小屏/键盘弹出时溢出
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            child: notifier.backButton(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
