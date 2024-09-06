import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/page/passport/login_view.dart';

import 'passport_logic.dart';
import 'widget/bezier_container.dart';
import 'widget/fadeanimation.dart';

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
        child: n.Stack([
          Positioned(
            top: -Get.height * .15,
            right: -Get.width * .4,
            child: const BezierContainer(),
          ),
          n.Padding(
            left: 20,
            right: 20,
            top: 32,
            child: SingleChildScrollView(
              child: n.Column([
                const SizedBox(height: 40),
                FadeAnimation(
                  delay: 0.8,
                  child: logic.title(),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 5,
                  color: Colors.white.withOpacity(0.9),
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: n.Column([
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 8,
                        ),
                        child: RichText(
                          text: TextSpan(
                            text: 'code_sent_to_param'
                                .trArgs([widget.accountType.tr]),
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
                          // backgroundColor: Colors.green,
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
                          // onTap: () {
                          //   print("Pressed");
                          // },
                          onChanged: (value) {
                            debugPrint(value);
                            setState(() {
                              currentText = value;
                            });
                          },
                          beforeTextPaste: (text) {
                            debugPrint("Allowing to paste $text");
                            //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                            //but you can show anything you want here, like your pop up saying wrong paste format or etc
                            return true;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          hasError ? 'pin_code_fill_tips'.tr : '',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w400),
                        ),
                      ),
                      // const SizedBox(height: 20),
                      n.Row([
                        Expanded(
                            child: Text(
                          'not_receive_coe_q'.tr,
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
                            // EasyLoading.dismiss();
                            if (res == null) {
                              logic.snackBar(
                                Text(
                                  'code_sent_to_param'.trArgs([widget.account]),
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
                              logic.snackBar(res.tr);
                            }
                          },
                          child: Text(
                            'resend_code'.tr,
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ))
                      ]),

                      n.Column([
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
                                hintText: 'new_password'.tr,
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
                                hintText: 'retype_password'.tr,
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
                      ])
                        ..crossAxisAlignment = CrossAxisAlignment.start,
                      const SizedBox(height: 20),
                      FadeAnimation(
                        delay: 1,
                        child: TextButton(
                            onPressed: () async {
                              if (currentText.length != 6) {
                                errorController!.add(ErrorAnimationType
                                    .shake); // Triggering error shake animation
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
                                    'confirm_recover_success'.tr);
                                Get.to(
                                  () => const LoginPage(),
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                              } else {
                                setState(
                                  () {
                                    hasError = false;
                                    logic.snackBar(res.tr);
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
                              'set_param'.trArgs(['password'.tr]),
                              style: const TextStyle(
                                color: Colors.white,
                                letterSpacing: 0.5,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                      ),
                    ])
                      ..mainAxisSize = MainAxisSize.min,
                  ),
                ),

                //End of Center Card
                //Start of outer card
                const SizedBox(height: 20),

                FadeAnimation(
                  delay: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('try_again_q'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            letterSpacing: 0.5,
                          )),
                      GestureDetector(
                        onTap: () {
                          Get.to(
                            () => const LoginPage(),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                        child: Text(
                          'login'.tr,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ])
                ..mainAxisAlignment = MainAxisAlignment.center,
            ),
          ),
          Positioned(top: 40, left: 0, child: logic.backButton())
        ]),
      ),
    );
  }
}
