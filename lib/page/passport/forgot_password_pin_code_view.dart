import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:imboy/page/passport/login_view.dart';

import 'passport_logic.dart';
import 'widget/bezier_container.dart';
import 'widget/fadeanimation.dart';
import 'package:imboy/i18n/strings.g.dart';

class PinCodeVerificationPage extends StatefulWidget {
  final String account;
  final String accountType;

  const PinCodeVerificationPage({
    super.key,
    required this.account,
    required this.accountType,
  });

  @override
  State<PinCodeVerificationPage> createState() =>
      _PinCodeVerificationPageState();
}

class _PinCodeVerificationPageState extends State<PinCodeVerificationPage> {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;

  TextEditingController textEditingController = TextEditingController();

  // ignore: close_sinks
  StreamController<ErrorAnimationType>? errorController;

  bool hasError = false;
  String currentText = "";
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    errorController = StreamController<ErrorAnimationType>();
    super.initState();
  }

  @override
  void dispose() {
    errorController!.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.green,
        height: Get.height,
        child: Stack(
          children: [
            Positioned(
              top: -Get.height * .15,
              right: -Get.width * .4,
              child: const BezierContainer(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    FadeAnimation(
                      delay: 0.8,
                      child: logic.title(),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 5,
                      color: Colors.white.withAlpha(229),
                      child: Container(
                        width: 500,
                        padding: const EdgeInsets.all(30.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
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
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 15),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Form(
                              key: formKey,
                              child: PinCodeTextField(
                                appContext: context,
                                pastedTextStyle: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                length: 6,
                                obscureText: true,
                                obscuringCharacter: '*',
                                obscuringWidget: const Icon(
                                  Icons.safety_check,
                                  color: Colors.green,
                                  size: 24,
                                ),
                                blinkWhenObscuring: true,
                                animationType: AnimationType.fade,
                                validator: (v) {
                                  if (v!.length < 3) {
                                    return "Validate me";
                                  } else {
                                    return null;
                                  }
                                },
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(5),
                                  fieldHeight: 50,
                                  fieldWidth: 40,
                                  activeFillColor: Colors.white,
                                  inactiveFillColor: Colors.white,
                                  selectedFillColor: Colors.green,
                                  selectedColor: Colors.green,
                                ),
                                cursorColor: Colors.black,
                                animationDuration: const Duration(milliseconds: 300),
                                enableActiveFill: true,
                                errorAnimationController: errorController,
                                controller: textEditingController,
                                keyboardType: TextInputType.number,
                                boxShadows: const [
                                  BoxShadow(
                                    offset: Offset(0, 1),
                                    color: Colors.black12,
                                    blurRadius: 10,
                                  )
                                ],
                                onCompleted: (v) {
                                  debugPrint("Completed");
                                },
                                onChanged: (value) {
                                  debugPrint(value);
                                  setState(() {
                                    currentText = value;
                                  });
                                },
                                beforeTextPaste: (text) {
                                  debugPrint("Allowing to paste $text");
                                  return true;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Text(
                                hasError ? t.pinCodeFillTips : '',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                    child: Text(
                                      t.notReceiveCoeQ,
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 15),
                                    )),
                                Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        String? res = await logic.sendCode(
                                            widget.accountType,
                                            widget.account,
                                            'forgot_pwd'
                                        );
                                        if (res == null) {
                                          logic.snackBar(
                                            Text(
                                              t.codeSentToParam.replaceAll('{param}', widget.account),
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 20,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            ),
                                          );
                                        } else {
                                          logic.snackBar(
                                            Text(
                                              res,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 20,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        t.resendCode,
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ))
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0.0,
                                    vertical: 8.0,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(Radius.circular(5)),
                                  ),
                                  child: Obx(() => PasswordTextField(
                                    obscureText: state.newPwdObscure.value,
                                    hintText: t.newPassword,
                                    onTap: () {
                                      state.newPwdObscure.value =
                                      !state.newPwdObscure.value;
                                    },
                                    onChanged: (String? val) {
                                      if (strNoEmpty(val)) {
                                        state.newPwd.value = val!.trim();
                                      }
                                    },
                                  )),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0.0,
                                    vertical: 8.0,
                                  ),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                      BorderRadius.all(Radius.circular(5))),
                                  child: Obx(() => PasswordTextField(
                                    obscureText: state.retypePwdObscure.value,
                                    hintText: t.retypePassword,
                                    onTap: () {
                                      state.retypePwdObscure.value =
                                      !state.retypePwdObscure.value;
                                    },
                                    onChanged: (String? val) {
                                      if (strNoEmpty(val)) {
                                        state.retypePwd.value = val!.trim();
                                      }
                                    },
                                  )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FadeAnimation(
                              delay: 1,
                              child: TextButton(
                                  onPressed: () async {
                                    if (currentText.length != 6) {
                                      errorController!.add(ErrorAnimationType
                                          .shake);
                                      setState(() => hasError = true);
                                      return;
                                    }
                                    formKey.currentState!.validate();
                                    String? res = await logic.resetPassword(
                                        type: widget.accountType,
                                        account: widget.account,
                                        code: currentText,
                                        newPwd: state.newPwd.value,
                                        rePwd: state.retypePwd.value);
                                    if (res == null) {
                                      EasyLoading.showSuccess(
                                          t.confirmRecoverSuccess);
                                      Get.to(
                                            () => const LoginPage(),
                                        transition: Transition.rightToLeft,
                                        popGesture: true,
                                      );
                                    } else {
                                      setState(
                                            () {
                                          hasError = false;
                                          logic.snackBar(
                                            Text(
                                              res,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14.0,
                                      horizontal: 80,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: Text(
                                    t.setParam.replaceAll('{param}', t.password),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeAnimation(
                      delay: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.tryAgainQ,
                              style: const TextStyle(
                                color: Colors.white,
                                letterSpacing: 0.5,
                              )),
                          GestureDetector(
                            onTap: () {
                              Get.to(
                                    () => const LoginPage(),
                                transition: Transition.rightToLeft,
                                popGesture: true,
                              );
                            },
                            child: Text(
                              t.login,
                              style: const TextStyle(
                                color: Colors.white,
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
            Positioned(top: 40, left: 0, child: logic.backButton())
          ],
        ),
      ),
    );
  }
}