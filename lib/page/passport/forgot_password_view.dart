import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/passport/login_view.dart';

import 'widget/bezier_container.dart';
import 'widget/fadeanimation.dart';
import 'forgot_password_pin_code_view.dart';
import 'passport_logic.dart';

enum FormData { Email, SMSCode }

class ForgotPasswordPage extends StatefulWidget {
  final String? account;

  // final String accountType;

  const ForgotPasswordPage({super.key, this.account});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final PassportLogic logic = Get.put(PassportLogic());

  String accountType = 'email'; // mobile | email

  Color enabled = const Color.fromARGB(255, 63, 56, 89);
  Color enabledtxt = Colors.white;
  Color deaible = Colors.grey;
  Color backgroundColor = Colors.white;
  bool ispasswordev = true;
  FormData? selected;

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _controller.text = widget.account!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = Get.height;
    return Scaffold(
      body: Container(
        color: Colors.green,
        height: Get.height,
        child: Stack(
          children: [
            Positioned(
              top: -height * .15,
              right: -Get.width * .4,
              child: const BezierContainer(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    logic.title(),
                    const SizedBox(height: 40),
                    Card(
                      elevation: 5,
                      color: Colors.white.withValues(alpha: 0.9),
                      child: Container(
                        width: 400,
                        padding: const EdgeInsets.all(30.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            FadeAnimation(
                              delay: 1,
                              child: Text(
                                "recover_password".tr,
                                style: const TextStyle(
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FadeAnimation(
                              delay: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5.0),
                                  color: selected == FormData.Email
                                      ? enabled
                                      : backgroundColor,
                                ),
                                child: TextField(
                                  controller: _controller,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  textAlignVertical: TextAlignVertical.center,
                                  onTap: () {
                                    setState(() {
                                      selected = FormData.Email;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    enabledBorder: InputBorder.none,
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: selected == FormData.Email
                                          ? enabledtxt
                                          : deaible,
                                      size: 20,
                                    ),
                                    hintText: accountType.tr,
                                    hintStyle: TextStyle(
                                        color: selected == FormData.Email
                                            ? enabledtxt
                                            : deaible,
                                        fontSize: 12),
                                  ),
                                  style: TextStyle(
                                      color: selected == FormData.Email
                                          ? enabledtxt
                                          : deaible,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            FadeAnimation(
                              delay: 1,
                              child: TextButton(
                                onPressed: () async {
                                  final account = _controller.text;

                                  if (account.isEmpty) {
                                    logic.snackBar(
                                        'please_input_param'.trArgs(['email'.tr]));
                                    return;
                                  }
                                  if (isEmail(account) == false) {
                                    logic.snackBar(
                                        'param_format_error'.trArgs(['emial'.tr]));
                                    return;
                                  }
                                  String? res = await logic.sendCode(
                                      accountType,
                                      account,
                                      'forgot_pwd'
                                  );
                                  if (res == null) {
                                    Get.to(
                                          () => PinCodeVerificationPage(
                                        account: account,
                                        accountType: accountType,
                                      ),
                                      transition: Transition.rightToLeft,
                                      popGesture: true, // 右滑，返回上一页
                                    );
                                  } else {
                                    logic.snackBar(res.tr);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14.0, horizontal: 80),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0)),
                                ),
                                child: Text(
                                  "button_continue".tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
                            child: Text('login'.tr,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  fontSize: 14,
                                )),
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