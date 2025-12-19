import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/passport/manage_account_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
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
      state.loginAccountCtl.text =
          loginHistory.isNotEmpty ? loginHistory[0] : '';
    }
    state.loginAccount.value = state.loginAccountCtl.text;
    state.error.value = '';
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = FocusNode();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 账号输入框 - 统一样式设计，修复圆角裁剪问题
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11), // 比外层稍小，确保完美贴合
                      child: TextField(
                        controller: state.loginAccountCtl,
                        enableSuggestions: false,
                        autocorrect: false,
                        textAlignVertical: TextAlignVertical.center,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          hintText: 'hintLoginAccount'.tr,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.account_box,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          suffixIcon: loginHistory.isEmpty
                              ? null
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      focusNode.requestFocus();
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return ListView.builder(
                                            itemCount: loginHistory.length,
                                            itemBuilder: (BuildContext context, int index) {
                                              final item = loginHistory[index];
                                              return ListTile(
                                                title: Text(item),
                                                onTap: () {
                                                  state.loginAccountCtl.text = item;
                                                  state.loginAccount.value = state.loginAccountCtl.text;
                                                  Navigator.pop(context);
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.menu_open_outlined, 
                                        size: 22,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                        onChanged: (String? val) {
                          if (strNoEmpty(val)) {
                            state.loginAccount.value = val!.trim();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 密码输入框 - 统一样式设计
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Obx(() => PasswordTextField(
                          obscureText: state.loginPwdObscure.value,
                          hintText: 'password'.tr,
                          onTap: () {
                            state.loginPwdObscure.value = !state.loginPwdObscure.value;
                          },
                          onChanged: (String? val) {
                            if (strNoEmpty(val)) {
                              state.loginPwd.value = val!.trim();
                            }
                          },
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 登录按钮 - 统一样式
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      String? err1 = logic.userValidator('account', state.loginAccount.value);
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
                      final user = UserRepoLocal.to.current;
                      final needGuide = (user.email.isEmpty || user.mobile.isEmpty);
                      if (needGuide) {
                        Get.offAll(() => const ManageAccountPage());
                      } else {
                        Get.off(() => BottomNavigationPage());
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
                      'login'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // 忘记密码链接
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Get.to(
                        () => ForgotPasswordPage(account: state.loginAccount.value),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                    child: Text(
                      'forgotPassword'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
