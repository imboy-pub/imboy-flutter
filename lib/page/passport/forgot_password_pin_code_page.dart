import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/widget/fadeanimation.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class PinCodeVerificationPage extends ConsumerStatefulWidget {
  final String account;
  final String accountType;

  const PinCodeVerificationPage({
    super.key,
    required this.account,
    required this.accountType,
  });

  @override
  ConsumerState<PinCodeVerificationPage> createState() =>
      _PinCodeVerificationPageState();
}

class _PinCodeVerificationPageState
    extends ConsumerState<PinCodeVerificationPage> {
  final _pinController = PinInputController();

  bool hasError = false;
  String currentText = "";
  final formKey = GlobalKey<FormState>();

  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passportProvider);
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

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                                text: widget.accountType == 'email'
                                    ? t.account.codeSentToEmail
                                    : t.account.codeSentToMobile,
                                children: [
                                  TextSpan(
                                    text: widget.account,
                                    style: context.textStyle(
                                      FontSizeType.medium,
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                // 字号归一：15 非枚举值，就近 normal(14)，真机复核
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
                                // 固定字号（不缩放）：pin 格子固定 40×50，缩放会溢出
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
                          AppSpacing.verticalLarge,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.common.notReceiveCoeQ,
                                  // 字号归一：15→normal(14)，真机复核
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
                                      widget.accountType,
                                      widget.account,
                                      'forgot_pwd',
                                    );
                                    if (!context.mounted) return;
                                    if (res == null) {
                                      notifier.snackBar(
                                        Text(
                                          t.main.codeSentToParam(
                                            param: widget.account,
                                          ),
                                          // 彩底前景用 onPrimary
                                          style: context.textStyle(
                                            FontSizeType.extraLarge,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: AppColors.onPrimary,
                                        ),
                                      );
                                    } else {
                                      notifier.snackBar(
                                        Text(
                                          res,
                                          // 彩底前景用 onPrimary
                                          style: context.textStyle(
                                            FontSizeType.extraLarge,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      );
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.none,
                                  vertical: AppSpacing.small,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    return PasswordTextField(
                                      obscureText: state.newPwdObscure,
                                      hintText: t.account.newPassword,
                                      style: TextStyle(color: textPrimary),
                                      hintStyle: TextStyle(
                                        color: textSecondary,
                                      ),
                                      iconColor: textSecondary,
                                      onTap: () {
                                        notifier.toggleNewPwdObscure();
                                      },
                                      onChanged: (String? val) {
                                        if (strNoEmpty(val)) {
                                          notifier.setNewPwd(val!.trim());
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.none,
                                  vertical: AppSpacing.small,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    return PasswordTextField(
                                      obscureText: state.retypePwdObscure,
                                      hintText: t.account.retypePassword,
                                      style: TextStyle(color: textPrimary),
                                      hintStyle: TextStyle(
                                        color: textSecondary,
                                      ),
                                      iconColor: textSecondary,
                                      onTap: () {
                                        setState(() {
                                          notifier.setRetypePwdObscure(
                                            !state.retypePwdObscure,
                                          );
                                        });
                                      },
                                      onChanged: (String? val) {
                                        if (strNoEmpty(val)) {
                                          notifier.setRetypePwd(val!.trim());
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          FadeAnimation(
                            delay: 1,
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  if (currentText.length != 6) {
                                    _pinController.triggerError();
                                    setState(() => hasError = true);
                                    return;
                                  }
                                  formKey.currentState!.validate();
                                  String? res = await notifier.resetPassword(
                                    type: widget.accountType,
                                    account: widget.account,
                                    code: currentText,
                                    newPwd: state.newPwd,
                                    rePwd: state.retypePwd,
                                  );
                                  if (res == null) {
                                    AppLoading.showSuccess(
                                      t.common.confirmRecoverSuccess,
                                    );
                                    if (!context.mounted) return;
                                    context.go('/sign_in');
                                  } else {
                                    setState(() {
                                      hasError = false;
                                      notifier.snackBar(
                                        Text(
                                          res,
                                          // 彩底前景用 onPrimary
                                          style: context.textStyle(
                                            FontSizeType.extraLarge,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      );
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.borderRadiusRegular,
                                  ),
                                ),
                                child: Text(
                                  t.main.setParam(param: t.account.password),
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalLarge,
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
                              // context.textStyle 无 letterSpacing 参数，copyWith 补回
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
      ),
    );
  }
}
