import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';

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
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.green,
        height: Get.height,
        child: SingleChildScrollView(
          child: n.Column([
            n.Column([
              // mobile
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0.0,
                  vertical: 8.0,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                child: n.Padding(
                  left: 16,
                  child: InternationalPhoneNumberInput(
                    locale: sysLang('intl_phone_number_input'),
                    // locale: 'zh_TW',
                    // https://github.com/natintosh/intl_phone_number_input/blob/develop/lib/src/models/country_list.dart
                    countries: langLogic.regionCodeList(
                      'intl_phone_number_input',
                    ),
                    initialValue: mobile,
                    // hintText: 'please_input_param'.trArgs(['mobile'.tr]),
                    inputBorder: InputBorder.none,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      useBottomSheetSafeArea: true,
                      trailingSpace: false,
                      leadingPadding: 0,
                    ),
                    searchBoxDecoration:
                        InputDecoration(labelText: 'region_search_tips'.tr),
                    inputDecoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'please_input_param'.trArgs(['mobile'.tr]),
                      hintStyle: const TextStyle(fontSize: 14.0),
                      // contentPadding: const EdgeInsets.only(
                      //   bottom: 0.0,
                      // ),

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
                                  final item =
                                  loginHistory[index];
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
                        child: const Icon(Icons.menu_open_outlined),
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
                      state.mobileValidated.value = value;
                    },
                    onSaved: (PhoneNumber number) {
                      iPrint(
                          "signup_page_onSaved ${number.phoneNumber.toString()};");
                    },
                  ),
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
                if (state.mobileValidated.isFalse) {
                  logic.snackBar('error_invalid'.trArgs(['mobile'.tr]));
                  return;
                }
                String? err2 = logic.passwordValidator(state.loginPwd.value);
                if (err2 != null) {
                  logic.snackBar(err2);
                  return;
                }
                iPrint('state.loginPwd.value ${state.loginPwd.value}');
                String? err3 = await logic.loginUser(
                  'mobile',
                  state.mobile.value,
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
