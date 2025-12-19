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
                    // 使用登录页面相同的输入框样式设计
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeAnimation(
                            delay: 1,
                            child: Text(
                              'recoverPassword'.tr,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // 邮箱输入框 - 参考登录页面样式
                          FadeAnimation(
                            delay: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
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
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16, 
                                      horizontal: 16
                                    ),
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    prefixIcon: Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.email_outlined,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    hintText: accountType.tr,
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // 继续按钮 - 参考登录页面样式
                          FadeAnimation(
                            delay: 1,
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final account = _controller.text;

                                  if (account.isEmpty) {
                                    logic.snackBar(
                                        'pleaseInputParam'.trArgs(['email'.tr]));
                                    return;
                                  }
                                  if (isEmail(account) == false) {
                                    logic.snackBar(
                                        'paramFormatError'.trArgs(['emial'.tr]));
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: Text(
                                  'buttonContinue'.tr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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
                          Text('tryAgainQ'.tr,
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