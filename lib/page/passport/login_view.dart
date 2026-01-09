import 'package:buttons_tabbar/buttons_tabbar.dart' show ButtonsTabBar;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'login_mobile_view.dart';
import 'passport_logic.dart';
import 'signup_view.dart';
import 'forgot_password_view.dart';
import 'manage_account_view.dart';
import 'widget/bezier_container.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.account, this.refUid});

  final String? account;
  final String? refUid;

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;

  late PageController _pageController;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    logic.initPlatformState();

    if (widget.account == null) {
      state.loginAccountCtl.text =
          StorageService.to.getString(Keys.lastLoginAccount) ?? '';
    } else {
      state.loginAccountCtl.text = widget.account!;
    }

    state.loginAccount.value = state.loginAccountCtl.text;
    state.error.value = '';

    state.loginHistory.value =
        StorageService.to.getStringList(Keys.loginHistory) ?? [];

    Connectivity().checkConnectivity().then((r) {
      if (r.contains(ConnectivityResult.none)) {
        state.connectDesc.value = 'tipConnectDesc'.tr;
      } else {
        state.connectDesc.value = '';
      }
    });
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        state.connectDesc.value = 'tipConnectDesc'.tr;
      } else {
        state.connectDesc.value = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        color: Colors.green, // Full Green Background - Just like Signup
        height: screenHeight,
        child: Stack(
          children: [
            // Decorative Bezier (Top Right) - Just like Signup
            Positioned(
              top: -screenHeight * .15,
              right: -screenWidth * .4,
              child: const BezierContainer(),
            ),

            // Main Content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50),
                      // Logo - White (Uses existing logic.title())
                      logic.title(),
                      const SizedBox(height: 30),

                      // Tab Bar - Full Width Pill (Matching Signup Style)
                      _buildAccountTypeTabBar(screenWidth),
                      const SizedBox(height: 24),

                      // Inputs via PageView
                      _buildPageView(),

                      const SizedBox(height: 24),
                      _buildOrDivider(),
                      const SizedBox(height: 8),

                      if (GetPlatform.isMobile) _buildQuickLoginButton(),

                      _createAccountLabel(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Back Button
            Positioned(top: 40, left: 0, child: logic.backButton()),

            // Connectivity Warning
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Obx(
                () => state.connectDesc.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        color: AppColors.messageFailed.withValues(alpha: .95),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.connectDesc.value,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab Bar - Matching Signup Page's style
  Widget _buildAccountTypeTabBar(double screenWidth) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .3), width: 1),
      ),
      child: DefaultTabController(
        length: 2,
        child: ButtonsTabBar(
          radius: 26,
          height: 52,
          width: (screenWidth - 40 - 8) / 2, // Full width, minus padding
          contentCenter: true,
          duration: 250,
          buttonMargin: const EdgeInsets.all(2),
          backgroundColor: Colors.white,
          unselectedBackgroundColor: Colors.transparent,
          labelStyle: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          tabs: [
            Tab(text: 'paramLogin'.trArgs(['account'.tr])),
            Tab(text: 'paramLogin'.trArgs(['mobile'.tr])),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (int i) {
          FocusScope.of(context).unfocus();
        },
        children: [
          // Account Login - Uses same mobile-style input with account hint
          _buildAccountLoginForm(),
          const LoginMobilePage(),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLoginButton() {
    return Container(
      width: double.infinity,
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: .25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => logic.loginAuth(false),
          borderRadius: BorderRadius.circular(26),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'mobileQuickLogin'.tr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createAccountLabel() {
    return InkWell(
      onTap: () {
        Get.to(
          () => const SignupPage(),
          transition: Transition.rightToLeft,
          popGesture: true,
        );
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white.withValues(alpha: 0.1),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: .25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'noSiginQ'.tr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'signup'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountLoginForm() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Account/Email Input
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
                  borderRadius: BorderRadius.circular(11),
                  child: TextField(
                    controller: state.loginAccountCtl,
                    enableSuggestions: false,
                    autocorrect: false,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
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
                          Icons.person,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      suffixIcon: Obx(() {
                        // 过滤出非手机号的账号
                        final accountHistory = state.loginHistory
                            .where((item) => !item.startsWith('+'))
                            .toList();

                        if (accountHistory.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: accountHistory.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final item = accountHistory[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.person_outline,
                                        ),
                                        title: Text(item),
                                        onTap: () {
                                          state.loginAccountCtl.text = item;
                                          state.loginAccount.value = item;
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
                    onChanged: (String? val) {
                      state.loginAccount.value = val?.trim() ?? '';
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Password Input
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
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    iconColor: Colors.grey.shade600,
                    onTap: () {
                      state.loginPwdObscure.value =
                          !state.loginPwdObscure.value;
                    },
                    onChanged: (String? val) {
                      state.loginPwd.value = val?.trim() ?? '';
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Login Button - White with Green Text (Matching Signup)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: .95),
                        Colors.white.withValues(alpha: .85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        String? err = logic.userValidator(
                          'account',
                          state.loginAccount.value,
                        );
                        if (err != null) {
                          logic.snackBar(err);
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
                          'account',
                          state.loginAccount.value,
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
                      borderRadius: BorderRadius.circular(26),
                      splashColor: Colors.green.withValues(alpha: .1),
                      child: Center(
                        child: Text(
                          'login'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Forgot Password
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.8),
                    ),
                    child: Text(
                      'forgotPassword'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
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
