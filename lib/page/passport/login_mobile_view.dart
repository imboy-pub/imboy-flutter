import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/passport/manage_account_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

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

  final FocusNode _mobileFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    state.error.value = '';

    state.loginHistory.value =
        StorageService.to.getStringList(Keys.loginHistory) ?? [];
    if (state.loginHistory.isNotEmpty) {
      for (final item in state.loginHistory.value) {
        if (item.startsWith('+')) {
          mobile = PhoneNumber(phoneNumber: item, dialCode: '', isoCode: '');
        }
      }
      setState(() {
        mobile;
      });
    }

    _mobileFocus.addListener(() => setState(() {}));
  }

  // 获取手机号历史记录（过滤出手机号）
  List<String> get mobileHistory {
    return state.loginHistory.where((item) => item.startsWith('+')).toList();
  }

  @override
  void dispose() {
    _mobileFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // mobile - Clean Minimalist
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _mobileFocus.hasFocus
                          ? Colors.white
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _mobileFocus.hasFocus
                            ? AppColors.primaryGreen
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: _mobileFocus.hasFocus
                          ? [
                              BoxShadow(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: InternationalPhoneNumberInput(
                          locale: sysLang('intl_phone_number_input'),
                          countries: langLogic.regionCodeList(
                            'intl_phone_number_input',
                          ),
                          initialValue: mobile,
                          inputBorder: InputBorder.none,
                          selectorConfig: const SelectorConfig(
                            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                            useBottomSheetSafeArea: true,
                            trailingSpace: false,
                            leadingPadding: 0,
                          ),
                          searchBoxDecoration: InputDecoration(
                            labelText: 'regionSearchTips'.tr,
                          ),
                          autoFocus: true,
                          focusNode: _mobileFocus,
                          textStyle: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          selectorTextStyle: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: AppColors.primaryGreen,
                          inputDecoration: InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            hintText: 'pleaseInputParam'.trArgs(['mobile'.tr]),
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 0,
                            ),
                            suffixIcon: Obx(() {
                              final history = mobileHistory;
                              if (history.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _mobileFocus.requestFocus();
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return ListView.builder(
                                          itemCount: history.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final item = history[index];
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
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.arrow_drop_down_circle_outlined,
                                      size: 24,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: 56,
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
                              "signup_page_onInputChanged 1 ${number.toString()};",
                            );
                            state.mobile.value = number.phoneNumber ?? '';
                            iPrint(
                              "signup_page_onInputChanged 2 ${state.mobile.value};",
                            );
                          },
                          onInputValidated: (bool value) {
                            state.mobileValidated.value = true;
                          },
                          onSaved: (PhoneNumber number) {
                            iPrint(
                              "signup_page_onSaved ${number.phoneNumber.toString()};",
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 密码输入框 - Clean Minimalist (Simple Grey for now)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Obx(
                      () => PasswordTextField(
                        obscureText: state.loginPwdObscure.value,
                        hintText: 'password'.tr,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        cursorColor: AppColors.primaryGreen,
                        iconColor: Colors.grey[400],
                        onTap: () {
                          state.loginPwdObscure.value =
                              !state.loginPwdObscure.value;
                        },
                        onChanged: (String? val) {
                          if (strNoEmpty(val)) {
                            state.loginPwd.value = val!.trim();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 登录按钮 - Green Gradient Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen,
                        AppColors.primaryGreenLight,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (state.mobileValidated.isFalse) {
                        logic.snackBar('errorInvalid'.trArgs(['mobile'.tr]));
                        return;
                      }
                      String? err2 = logic.passwordValidator(
                        state.loginPwd.value,
                      );
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
                      final needGuide =
                          (user.email.isEmpty || user.mobile.isEmpty);
                      if (needGuide) {
                        Get.offAll(() => const ManageAccountPage());
                      } else {
                        Get.off(() => BottomNavigationPage());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      'login'.tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // 忘记密码链接
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Get.to(
                        () => ForgotPasswordPage(
                          account: state.loginAccount.value,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    child: Text(
                      'forgotPassword'.tr,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
