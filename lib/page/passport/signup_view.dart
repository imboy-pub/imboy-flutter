
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/locales/locales.dart';
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

class SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;
  final LanguageLogic langLogic = Get.put(LanguageLogic());

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    state.nickname.value = '';
    state.mobile.value = '';
    state.accountType.value = 'mobile';
    state.email.value = '';
    state.mobileValidated.value = false;
    state.selectedAgreement.value = 'off';
    state.newPwd.value = '';

    // 监听 accountType 变化，同步 TabController
    ever(state.accountType, (String accountType) {
      final index = accountType == 'mobile' ? 0 : 1;
      if (_tabController.index != index) {
        _tabController.animateTo(index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    // double bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = Get.height;
    return Scaffold(
      body: Container(
        color: Colors.green,
        height: height,
        child: Stack(
          children: [
            Positioned(
              top: -Get.height * .15,
              right: -Get.width * .4,
              child: const BezierContainer(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    logic.title(),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        // account input - 支持手机号 / 邮箱 切换 - 使用类似登录页面的切换效果
                        _buildAccountTypeTabBar(width),
                        const SizedBox(height: 20),
                        // nickname - 参考登录页面样式优化
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .3),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: TextField(
                              enableSuggestions: false,
                              autocorrect: false,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                hintText: 'nickname'.tr,
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                              ),
                              onChanged: (String? val) {
                                if (strNoEmpty(val)) {
                                  state.nickname.value = val!.trim();
                                  logic.checkSignupContinue();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Obx(
                          () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 条件输入区：手机号或邮箱
                              if (state.accountType.value == 'mobile')
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: .3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: InternationalPhoneNumberInput(
                                        locale: sysLang(
                                          'intl_phone_number_input',
                                        ),
                                        countries: langLogic.regionCodeList(
                                          'intl_phone_number_input',
                                        ),
                                        inputBorder: InputBorder.none,
                                        selectorConfig: const SelectorConfig(
                                          selectorType: PhoneInputSelectorType
                                              .BOTTOM_SHEET,
                                          useBottomSheetSafeArea: true,
                                          trailingSpace: false,
                                          leadingPadding: 0,
                                        ),
                                        searchBoxDecoration: InputDecoration(
                                          labelText: 'region_search_tips'.tr,
                                        ),
                                        inputDecoration: InputDecoration(
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          hintText: 'please_input_param'.trArgs(
                                            ['mobile'.tr],
                                          ),
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 0,
                                              ),
                                        ),
                                        ignoreBlank: false,
                                        formatInput: true,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              signed: true,
                                              decimal: true,
                                            ),
                                        onInputChanged: (PhoneNumber number) {
                                          iPrint(
                                            "signup_page_onInputChanged 1 ${number.toString()};",
                                          );
                                          state.mobile.value =
                                              number.phoneNumber ?? '';
                                          iPrint(
                                            "signup_page_onInputChanged 2 ${state.mobile.value};",
                                          );
                                          // 使用更准确的手机号验证逻辑
                                          bool isValid = false;
                                          if (number.phoneNumber != null &&
                                              number.phoneNumber!.isNotEmpty) {
                                            // 使用 isPhone 函数进行验证，这与后端逻辑保持一致
                                            isValid = isPhone(
                                              number.phoneNumber!,
                                            );
                                          }
                                          state.mobileValidated.value = isValid;
                                          iPrint(
                                            "signup_page_onInputChanged_validated $isValid; phone: ${number.phoneNumber}",
                                          );
                                          logic.checkSignupContinue();
                                        },
                                        onInputValidated: (bool value) {
                                          // 不再使用组件自带的验证结果，因为它可能不准确
                                          // 我们已经在 onInputChanged 中使用 isPhone() 进行了更准确的验证
                                          iPrint(
                                            "signup_page_onInputValidated $value; (ignored)",
                                          );
                                          // 注释掉这两行，避免覆盖我们在 onInputChanged 中设置的验证结果
                                          // state.mobileValidated.value = value;
                                          // logic.checkSignupContinue();
                                        },
                                        onSaved: (PhoneNumber number) {
                                          iPrint(
                                            "signup_page_onSaved ${number.phoneNumber.toString()};",
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: .3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: TextField(
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      keyboardType: TextInputType.emailAddress,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 16,
                                            ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        hintText: 'please_input_param'.trArgs([
                                          'email'.tr,
                                        ]),
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                        prefixIcon: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Icon(
                                            Icons.email,
                                            color: Colors.grey.shade600,
                                            size: 20,
                                          ),
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 44,
                                              minHeight: 44,
                                            ),
                                      ),
                                      onChanged: (String? val) {
                                        if (strNoEmpty(val)) {
                                          state.email.value = val!.trim();
                                          state.mobileValidated.value = isEmail(
                                            state.email.value,
                                          );
                                          logic.checkSignupContinue();
                                        } else {
                                          state.email.value = '';
                                          state.mobileValidated.value = false;
                                          logic.checkSignupContinue();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        // password - 参考登录页面样式优化
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .3),
                              width: 1,
                            ),
                          ),
                          child: Obx(
                            () => PasswordTextField(
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // 协议同意区域 - 优化UI和交互
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 复选框
                              InkWell(
                                onTap: () {
                                  state.selectedAgreement.value =
                                      state.selectedAgreement.value == 'on'
                                      ? 'off'
                                      : 'on';
                                  logic.checkSignupContinue();
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Obx(
                                    () => Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color:
                                            state.selectedAgreement.value ==
                                                'on'
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child:
                                          state.selectedAgreement.value == 'on'
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.green,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 协议文本
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        state.selectedAgreement.value =
                                            state.selectedAgreement.value ==
                                                'on'
                                            ? 'off'
                                            : 'on';
                                        logic.checkSignupContinue();
                                      },
                                      child: Text(
                                        'read_agree_param'.trArgs([''.tr]),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Get.dialog(
                                          MarkdownPage(
                                            title: 'license_agreement'.tr,
                                            url: logic.licenseAgreementUrl(),
                                            leading: IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                size: 24,
                                                color: Colors.black,
                                              ),
                                              onPressed: () {
                                                Get.closeAllDialogs();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'license_agreement'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    // 主要操作按钮 - 同意并继续
                    Container(
                      width: double.infinity,
                      height: 52,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: Obx(
                        () => Container(
                          decoration: BoxDecoration(
                            // 使用渐变背景，增强视觉层次
                            gradient: state.showSignupContinue.isTrue
                                ? LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: .95),
                                      Colors.white.withValues(alpha: .85),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: .25),
                                      Colors.white.withValues(alpha: .15),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .4),
                              width: 1.5,
                            ),
                            boxShadow: state.showSignupContinue.isTrue
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .15,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: .3),
                                      blurRadius: 6,
                                      offset: const Offset(0, -1),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: state.showSignupContinue.isTrue
                                  ? () async {
                                      final accountType =
                                          state.accountType.value;
                                      final account = accountType == 'email'
                                          ? state.email.value
                                          : state.mobile.value;

                                      if (state.showSignupContinue.isFalse) {
                                        // 类型化的格式错误提示
                                        final label = accountType == 'email'
                                            ? 'email'.tr
                                            : 'mobile'.tr;
                                        logic.snackBar(
                                          'param_format_error'.trArgs([label]),
                                        );
                                        return;
                                      }

                                      if (state.showSignupContinue.isTrue &&
                                          account.isNotEmpty) {
                                        String? res = await logic.sendCode(
                                          accountType,
                                          account,
                                          'signup',
                                        );
                                        if (res == null) {
                                          logic.snackBar(
                                            Text(
                                              'code_sent_to_param'.trArgs([
                                                account,
                                              ]),
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
                                              account: account,
                                              nickname: state.nickname.value,
                                              pwd: state.newPwd.value,
                                            ),
                                            transition: Transition.rightToLeft,
                                            popGesture: true, // 右滑，返回上一页
                                          );
                                        } else {
                                          if (res == 'param_already_exist') {
                                            final label = accountType == 'email'
                                                ? 'email'.tr
                                                : 'mobile'.tr;
                                            logic.snackBar(
                                              'param_already_exist'.trArgs([
                                                label,
                                              ]),
                                            );
                                          } else {
                                            logic.snackBar(res.tr);
                                          }
                                        }
                                      }
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(26),
                              splashColor: state.showSignupContinue.isTrue
                                  ? Colors.green.withValues(alpha: .1)
                                  : Colors.transparent,
                              highlightColor: state.showSignupContinue.isTrue
                                  ? Colors.green.withValues(alpha: .05)
                                  : Colors.transparent,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (state.showSignupContinue.isTrue)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            Icons.check_circle_outline,
                                            size: 20,
                                            color: Colors.green,
                                          ),
                                        ),
                                      Text(
                                        'agree_continue'.tr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: state.showSignupContinue.isTrue
                                              ? Colors.green
                                              : Colors.white.withValues(
                                                  alpha: .5,
                                                ),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 次要操作按钮 - 已有账号登录
                    InkWell(
                      onTap: () {
                        Get.to(
                          () => const LoginPage(),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Colors.white.withValues(alpha: .1),
                      highlightColor: Colors.white.withValues(alpha: .05),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login,
                              size: 18,
                              color: Colors.white.withValues(alpha: .9),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'sigin_q'.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: .9),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'login'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                                decorationThickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: 40, left: 0, child: logic.backButton()),
          ],
        ),
      ),
    );
  }

  /// 构建账户类型切换标签栏 - 参考登录页面样式
  Widget _buildAccountTypeTabBar(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: .3),
            width: 1,
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(2),
          dividerColor: Colors.transparent,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          onTap: (index) {
            // 根据选中的标签更新账户类型
            if (index == 0) {
              state.accountType.value = 'mobile';
            } else {
              state.accountType.value = 'email';
            }
            state.mobileValidated.value = false;
            logic.checkSignupContinue();
          },
          tabs: [
            Tab(text: 'mobile'.tr),
            Tab(text: 'email'.tr),
          ],
        ),
      ),
    );
  }
}
