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
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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

  StreamSubscription<dynamic>? _localeSubscription;

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
    Color backgroundColor = AppColors.iosRed,
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
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.iosRed,
              ),
              const SizedBox(height: 16),
              Text(
                t.common.unknown,
                style: context.textStyle(
                  FontSizeType.large,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (!context.mounted) return;
                  context.go('/sign_up');
                },
                child: Text(t.common.buttonBack),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
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
                            horizontal: AppSpacing.none,
                            vertical: AppSpacing.small,
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: _accountType == 'email'
                                  ? t.account.codeSentToEmail
                                  : t.account.codeSentToMobile,
                              children: [
                                TextSpan(
                                  text: _account,
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              // 字号归一：原 15 不在 FontSizeType 枚举，就近取 normal(14)
                              // ⚠️ 真机复核：副文本由 15→14 略缩，确认可接受
                              style: context.textStyle(
                                FontSizeType.normal,
                                color: textSecondary,
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
                              // 固定字号（不缩放）：pin 格子尺寸固定 40×50，
                              // 随用户字号放大会溢出格子，故用 .size 取固定基础值
                              textStyle: TextStyle(
                                color: textPrimary,
                                fontSize: FontSizeType.extraLarge.size,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onCompleted: (v) {},
                            onChanged: (value) {
                              setState(() {
                                currentText = value;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.large,
                          ),
                          child: Text(
                            hasError ? t.common.pinCodeFillTips : '',
                            style: context.textStyle(
                              FontSizeType.small,
                              color: errorColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.common.notReceiveCoeQ,
                                // 字号归一：15→normal(14)，同上须真机复核
                                style: context.textStyle(
                                  FontSizeType.normal,
                                  color: textSecondary,
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
                                        t.main.codeSentToParam(param: _account),
                                        // 彩底恒定前景用 onPrimary
                                        style: context.textStyle(
                                          FontSizeType.medium,
                                          color: AppColors.onPrimary,
                                        ),
                                      ),
                                      backgroundColor: AppColors.primary,
                                    );
                                  } else {
                                    if (res == 'param_already_exist') {
                                      final label = _accountType == 'email'
                                          ? t.account.email
                                          : t.account.mobile;
                                      _showSnackBar(
                                        context,
                                        Text(
                                          t.chat.paramAlreadyExist(
                                            param: label,
                                          ),
                                          style: context.textStyle(
                                            FontSizeType.medium,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      );
                                    } else {
                                      _showSnackBar(
                                        context,
                                        Text(
                                          res,
                                          style: context.textStyle(
                                            FontSizeType.medium,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  t.chat.resendCode,
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
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
                                  t.common.tipSuccess,
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                                backgroundColor: AppColors.iosGreen,
                                duration: const Duration(seconds: 2),
                              );
                              // 注册成功后引导用户去管理账户（绑定手机号/关联邮箱）
                              context.go('/manage_account');
                            } else {
                              _showSnackBar(
                                context,
                                Text(
                                  res,
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderRadiusRegular,
                            ),
                            elevation: 0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Text(
                              t.account.signup,
                              textAlign: TextAlign.center,
                              style: context.textStyle(
                                FontSizeType.extraLarge,
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
                          t.main.tryAgainQ,
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
                            t.account.login,
                            // context.textStyle 扩展不含 letterSpacing，用 copyWith 补回
                            style: context
                                .textStyle(
                                  FontSizeType.normal,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                )
                                .copyWith(letterSpacing: 0.5),
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
