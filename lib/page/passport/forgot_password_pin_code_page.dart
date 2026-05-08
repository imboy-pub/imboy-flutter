import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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

  StreamSubscription? _localeSubscription;

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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              horizontal: 0.0,
                              vertical: 8,
                            ),
                            child: RichText(
                              text: TextSpan(
                                text: widget.accountType == 'email'
                                    ? t.codeSentToEmail
                                    : t.codeSentToMobile,
                                children: [
                                  TextSpan(
                                    text: widget.account,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Text(
                              hasError ? t.pinCodeFillTips : '',
                              style: TextStyle(
                                color: errorColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                      widget.accountType,
                                      widget.account,
                                      'forgot_pwd',
                                    );
                                    if (res == null) {
                                      notifier.snackBar(
                                        Text(
                                          t.codeSentToParam(
                                            param: widget.account,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                      );
                                    } else {
                                      notifier.snackBar(
                                        Text(
                                          res,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                          ),
                                        ),
                                      );
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0,
                                  vertical: 8.0,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    return PasswordTextField(
                                      obscureText: state.newPwdObscure,
                                      hintText: t.newPassword,
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
                                  horizontal: 0.0,
                                  vertical: 8.0,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    return PasswordTextField(
                                      obscureText: state.retypePwdObscure,
                                      hintText: t.retypePassword,
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
                                    EasyLoading.showSuccess(
                                      t.confirmRecoverSuccess,
                                    );
                                    if (!context.mounted) return;
                                    context.go('/sign_in');
                                  } else {
                                    setState(() {
                                      hasError = false;
                                      notifier.snackBar(
                                        Text(
                                          res,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                          ),
                                        ),
                                      );
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.borderRadiusRegular,
                                  ),
                                ),
                                child: Text(
                                  t.setParam(param: t.password),
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                              style: const TextStyle(
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
