import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/single/markdown.dart';

import 'login_view.dart';
import 'signup_continue_view.dart';
import 'widget/bezier_container.dart';
import 'passport_logic.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;
  final LanguageLogic langLogic = Get.put(LanguageLogic());

  String lang = 'cn';

  @override
  void initState() {
    super.initState();
    state.nickname.value = '';
    state.mobile.value = '';
    state.mobileValidated.value = false;
    state.selectedAgreement.value = 'off';
    state.newPwd.value = '';

    String code = sysLang('').toLowerCase();
    // license_agreement 目前只配置 cn ru en 3个文件
    if (code.contains('en')) {
      lang = 'en';
    } else if (code.contains('ru')) {
      lang = 'ru';
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = Get.height;
    return Scaffold(
      body: Container(
        color: Colors.green,
        height: height,
        child: n.Stack([
          Positioned(
            top: -Get.height * .15,
            right: -Get.width * .4,
            child: const BezierContainer(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: n.Column([
                const SizedBox(height: 80),
                logic.title(),
                const SizedBox(height: 40),
                n.Column([
                  // nickname
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
                      // controller: state.loginAccountCtl,
                      enableSuggestions: false,
                      autocorrect: false,
                      // TextField 垂直居中光标
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'nickname'.tr,
                        hintStyle: const TextStyle(fontSize: 14.0),
                        prefixIcon: const Icon(Icons.person),
                        suffixIcon: null,
                      ),
                      onChanged: (String? val) {
                        if (strNoEmpty(val)) {
                          state.nickname.value = val!.trim();
                          logic.checkSignupContinue();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
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
                          contentPadding: const EdgeInsets.only(
                            bottom: 12.0,
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
                          // iPrint("signup_page_onInputValidated $value;");
                          logic.checkSignupContinue();
                        },
                        onSaved: (PhoneNumber number) {
                          iPrint(
                              "signup_page_onSaved ${number.phoneNumber.toString()};");
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
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
                          hintText: 'password'.tr,
                          onTap: () {
                            state.newPwdObscure.value =
                                !state.newPwdObscure.value;
                          },
                          onChanged: (String? val) {
                            if (strNoEmpty(val)) {
                              state.newPwd.value = val!.trim();
                              logic.checkSignupContinue();
                            }
                          },
                        )),
                  ),
                  const SizedBox(height: 30),
                  n.Row([
                    InkWell(
                      onTap: () {
                        state.selectedAgreement.value =
                            state.selectedAgreement.value == 'on'
                                ? 'off'
                                : 'on';

                        logic.checkSignupContinue();
                      },
                      child: Obx(() => Icon(
                            state.selectedAgreement.value == 'on'
                                ? Icons.circle_rounded
                                : Icons.circle_outlined,
                            color: Colors.white,
                          )),
                    ),
                    Flexible(
                        flex: 2,
                        child: InkWell(
                            child: Text(
                              'read_agree_param'.trArgs([''.tr]),
                              maxLines: 2,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                            onTap: () {
                              state.selectedAgreement.value =
                                  state.selectedAgreement.value == 'on'
                                      ? 'off'
                                      : 'on';

                              logic.checkSignupContinue();
                            })),
                    Flexible(
                        flex: 3,
                        child: InkWell(
                            child: Text(
                              'license_agreement'.tr,
                              maxLines: 4,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                            onTap: () {
                              logic.checkSignupContinue();
                              Get.dialog(MarkdownPage(
                                title: 'license_agreement'.tr,
                                url: "https://imboy.pub/doc/license_agreement_$lang.md?vsn=$appVsn",
                                leading: IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 24, color: Colors.black),
                                  onPressed: () {
                                    Get.closeAllDialogs();
                                  },
                                ),
                              ));
                            })),
                  ])
                    ..mainAxisAlignment = MainAxisAlignment.center
                    ..crossAxisAlignment = CrossAxisAlignment.center,
                  const SizedBox(height: 20),
                ]),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: 8.0,
                      bottom: bottomPadding != 20 ? 20 : bottomPadding,
                    ),
                    width: width,
                    child: Obx(() => ElevatedButton(
                          onPressed: () async {
                            if (state.showSignupContinue.isFalse) {
                              logic.snackBar('param_format_error'.trArgs(['mobile'.tr]));
                              return;
                            }

                            if (state.showSignupContinue.isTrue &&
                                state.mobile.isNotEmpty) {
                              const accountType = 'mobile';
                              String? res = await logic.sendCode(
                                  accountType, state.mobile.value, 'signup');
                              // EasyLoading.dismiss();
                              if (res == null) {
                                logic.snackBar(
                                  Text(
                                    'code_sent_to_param'
                                        .trArgs([state.mobile.value]),
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
                                Get.to(
                                  () => SignupContinuePage(
                                    accountType: accountType,
                                    account: state.mobile.value,
                                    nickname: state.nickname.value,
                                    pwd: state.newPwd.value,
                                  ),
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                              } else {
                                if (res == 'param_already_exist') {
                                  res = 'param_already_exist'
                                      .trArgs(['mobile'.tr]);
                                }
                                logic.snackBar(res.tr);
                              }
                            }
                          },
                          style: state.showSignupContinue.isTrue
                              ? lightGreenButtonStyle(null)
                              : null,
                          child: n.Padding(
                              left: 10,
                              right: 10,
                              child: Text(
                                'agree_continue'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20),
                              )),
                        )),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Get.to(
                      () => const LoginPage(),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(15),
                    alignment: Alignment.bottomCenter,
                    child: n.Row([
                      Text(
                        'sigin_q'.tr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'login'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ])
                      ..mainAxisAlignment = MainAxisAlignment.center,
                  ),
                )
              ])
                ..crossAxisAlignment = CrossAxisAlignment.center
                ..mainAxisAlignment = MainAxisAlignment.center,
            ),
          ),
          Positioned(top: 40, left: 0, child: logic.backButton()),
        ]),
      ),
    );
  }
}
