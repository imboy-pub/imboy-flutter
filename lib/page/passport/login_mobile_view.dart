import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/passport/manage_account_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'forgot_password_view.dart';
import 'passport_logic.dart';

class LoginMobilePage extends StatefulWidget {
  const LoginMobilePage({super.key, this.account, this.refUid});

  final String? account;

  // 经过 hashids 编码的，邀请人用户ID
  final String? refUid;

  @override
  LoginMobilePageState createState() => LoginMobilePageState();
}

class LoginMobilePageState extends State<LoginMobilePage> {
  final LanguageLogic langLogic = Get.put(LanguageLogic());

  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;
  PhoneNumber? mobile;
  List<String> loginHistory = [];

  @override
  void initState() {
    super.initState();

    state.error.value = '';

    state.loginHistory.value =
        StorageService.to.getStringList(Keys.loginHistory) ?? [];
    if (state.loginHistory.isNotEmpty) {
      for (final item in state.loginHistory.value) {
        if (item.startsWith('+')) {
          loginHistory.add(item);
          mobile = PhoneNumber(
            phoneNumber: item,
            dialCode: '',
            isoCode: '',
          );
        }
      }
      setState(() {
        mobile;
        loginHistory;
      });
    }
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
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // mobile - 修复圆角裁剪问题
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11), // 比外层稍小，确保完美贴合
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: InternationalPhoneNumberInput(
                          locale: sysLang('intl_phone_number_input'),
                          // locale: 'zh_TW',
                          // https://github.com/natintosh/intl_phone_number_input/blob/develop/lib/src/models/country_list.dart
                          countries: langLogic.regionCodeList(
                            'intl_phone_number_input',
                          ),
                          initialValue: mobile,
                          // hintText: 'pleaseInputParam'.trArgs(['mobile'.tr]),
                          inputBorder: InputBorder.none,
                          selectorConfig: const SelectorConfig(
                            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                            useBottomSheetSafeArea: true,
                            trailingSpace: false,
                            leadingPadding: 0,
                          ),
                          searchBoxDecoration:
                          InputDecoration(labelText: 'regionSearchTips'.tr),
                          autoFocus: true,
                          focusNode: focusNode,
                          inputDecoration: InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            hintText: 'pleaseInputParam'.trArgs(['mobile'.tr]),
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                            suffixIcon: loginHistory.isEmpty
                                ? null
                                : Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // 保持焦点
                                        focusNode.requestFocus();
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
                                                    setState(() {
                                                      mobile = PhoneNumber(
                                                        phoneNumber: item,
                                                        dialCode: '',
                                                        isoCode: '',
                                                      );
                                                    });
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
                          ignoreBlank: false,
                          formatInput: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          onInputChanged: (PhoneNumber number) {
                            iPrint(
                                "signup_page_onInputChanged 1 ${number.toString()};");
                            state.mobile.value = number.phoneNumber ?? '';
                            iPrint(
                                "signup_page_onInputChanged 2 ${state.mobile.value};");
                          },
                          onInputValidated: (bool value) {
                            // TOTO: 手机号码格式验证
                            state.mobileValidated.value = value;
                            state.mobileValidated.value = true;
                          },
                          onSaved: (PhoneNumber number) {
                            iPrint(
                                "signup_page_onSaved ${number.phoneNumber.toString()};");
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 密码输入框 - 统一样式设计
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .3),
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
                      if (state.mobileValidated.isFalse) {
                        logic.snackBar('errorInvalid'.trArgs(['mobile'.tr]));
                        return;
                      }
                      String? err2 = logic.passwordValidator(state.loginPwd.value);
                      if (err2 != null) {
                        logic.snackBar(err2);
                        return;
                      }
                      String? err3 = await logic.loginUser(
                        'mobile',
                        state.mobile.value,
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
