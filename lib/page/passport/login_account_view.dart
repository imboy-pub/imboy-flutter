import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';

import 'forgot_password_view.dart';
import 'passport_logic.dart';

class LoginAccountPage extends StatefulWidget {
  const LoginAccountPage({super.key, this.account, this.refUid});

  final String? account;

  // 经过 hashids 编码的，邀请人用户ID
  final String? refUid;

  @override
  LoginAccountPageState createState() => LoginAccountPageState();
}

class LoginAccountPageState extends State<LoginAccountPage> {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;
  List<String> loginHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      state.loginAccountCtl.text =
          StorageService.to.getString(Keys.lastLoginAccount) ?? '';
    } else {
      state.loginAccountCtl.text = widget.account ?? '';
    }


    state.loginHistory.value =
        StorageService.to.getStringList(Keys.loginHistory) ?? [];
    if (state.loginHistory.isNotEmpty) {
      for (final item in state.loginHistory.value) {
        if (item.startsWith('+') == false) {
          loginHistory.add(item);
        }
      }
      setState(() {
        // mobile;
        loginHistory;
      });
    }
    if (state.loginAccountCtl.text.startsWith('+')) {
      state.loginAccountCtl.text = loginHistory.isNotEmpty ? loginHistory[0] : '';
    }
    state.loginAccount.value = state.loginAccountCtl.text;
    state.error.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.green,
        height: Get.height,
        child: SingleChildScrollView(
          child: n.Column([
            n.Column([
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8.0,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                child: TextField(
                  controller: state.loginAccountCtl,
                  enableSuggestions: false,
                  autocorrect: false,
                  // TextField 垂直居中光标
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'hint_login_account'.tr,
                    hintStyle: const TextStyle(fontSize: 14.0),
                    prefixIcon: const Icon(Icons.account_box),
                    suffixIcon: loginHistory.isEmpty
                        ? null
                        : InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return ListView.builder(
                                    itemCount: loginHistory.length,
                                    // Number of items
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final item = loginHistory[index];
                                      return ListTile(
                                        title: Text(item),
                                        onTap: () {
                                          state.loginAccountCtl.text = item;
                                          state.loginAccount.value =
                                              state.loginAccountCtl.text;
                                          // Handle item selection
                                          // print('Selected Option $index');
                                          Navigator.pop(
                                              context); // Close the bottom sheet
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: const Icon(Icons.menu_open_outlined),
                          ),
                  ),
                  onChanged: (String? val) {
                    if (strNoEmpty(val)) {
                      state.loginAccount.value = val!.trim();
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8.0,
                ),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(5))),
                child: Obx(() => PasswordTextField(
                      obscureText: state.loginPwdObscure.value,
                      hintText: 'password'.tr,
                      onTap: () {
                        state.loginPwdObscure.value =
                            !state.loginPwdObscure.value;
                      },
                      onChanged: (String? val) {
                        if (strNoEmpty(val)) {
                          state.loginPwd.value = val!.trim();
                        }
                      },
                    )),
              ),
            ])
              ..mainAxisAlignment = MainAxisAlignment.start,
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String? err1 =
                    logic.userValidator('email', state.loginAccount.value);
                if (err1 != null) {
                  logic.snackBar(err1);
                  return;
                }
                String? err2 = logic.passwordValidator(state.loginPwd.value);
                if (err2 != null) {
                  logic.snackBar(err2);
                  return;
                }
                String? err3 = await logic.loginUser(
                  'account',
                  state.loginAccount.value,
                  state.loginPwd.value,
                );
                if (err3 != null) {
                  logic.snackBar(err3.tr);
                  return;
                }
                Get.off(() => BottomNavigationPage());
              },
              // ignore: sort_child_properties_last
              child: n.Padding(
                  left: 10,
                  right: 10,
                  child: Text(
                    'login'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  )),

              style: lightGreenButtonStyle(null),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () {
                    Get.to(
                      () =>
                          ForgotPasswordPage(account: state.loginAccount.value),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                    );
                  },
                  child: Text(
                    'forgot_password'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}
