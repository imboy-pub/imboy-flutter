import 'package:buttons_tabbar/buttons_tabbar.dart' show ButtonsTabBar;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

import 'login_account_view.dart';
import 'login_mobile_view.dart';
import 'passport_logic.dart';
import 'signup_view.dart';
import 'widget/bezier_container.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.account, this.refUid});

  final String? account;

  // 经过 hashids 编码的，邀请人用户ID
  final String? refUid;

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;

  late PageController _pageController;

  Color leftColor = Colors.black;
  Color rightColor = Colors.white;

  Color leftBgColor = Colors.white;
  Color rightBgColor = Color(0x552B2B2B).withAlpha(0);

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

    // final AccountAuthParamsHelper authParamsHelper = AccountAuthParamsHelper()
    //   ..setProfile()
    //   ..setAccessToken();
    // final AccountAuthParams authParams = authParamsHelper.createParams();
    // state.authServiceHW = AccountAuthManager.getService(authParams);

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

    // 检查网络状态
    Connectivity().checkConnectivity().then((r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        state.connectDesc.value = 'tip_connect_desc'.tr;
      } else {
        state.connectDesc.value = '';
      }
    });
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        state.connectDesc.value = 'tip_connect_desc'.tr;
      } else {
        state.connectDesc.value = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        color: Colors.green, // 与注册页面相同的背景色
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // 使用与注册页面相同的BezierContainer装饰，但位置不同
                Positioned(
                  top: -screenHeight * .15,
                  right: -screenWidth * .4,
                  child: const BezierContainer(),
                ),

                // 主内容区域 - 简洁设计
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 80,
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            logic.title(),
                            const SizedBox(height: 32),
                            _buildSimpleTabBar(screenWidth),
                            const SizedBox(height: 24),
                            _buildPageView(),
                            const SizedBox(height: 20),
                            _buildOrDivider(),
                            if (GetPlatform.isMobile) 
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildQuickLoginButton(),
                              ),
                            _createAccountLabel(),
                            SizedBox(
                              height: MediaQuery.of(context).viewInsets.bottom,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 返回按钮 - 使用优化后的样式
              Positioned(
                top: 40, 
                left: 0, 
                child: logic.backButton(),
              ),

              // 网络状态提示 - 使用优化后的样式
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Obx(
                  () => state.connectDesc.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.messageFailed.withValues(alpha: .95),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .1),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                state.connectDesc.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建简洁标签栏 - 修复Tab切换焦点问题
  Widget _buildSimpleTabBar(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
        child: DefaultTabController(
          length: 2,
          child: ButtonsTabBar(
            radius: 26,
            height: 52,
            width: (screenWidth - 44) / 2,
            contentCenter: true,
            duration: 300, // 增加动画时长，让切换更明显
            buttonMargin: const EdgeInsets.all(2),
            backgroundColor: Colors.white,
            unselectedBackgroundColor: Colors.transparent,
            // 移除手动的颜色管理，让ButtonsTabBar自己处理
            labelStyle: TextStyle(
              color: ThemeManager.instance.getThemeColor('primary'),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            // 添加Tab切换回调，同步PageView
            onTap: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            tabs: [
              Tab(
                text: 'param_login'.trArgs(['account'.tr]),
              ),
              Tab(
                text: 'param_login'.trArgs(['mobile'.tr]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return SizedBox(
      height: 320, // 增加高度，确保"忘记密码？"文案能够显示
      child: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (int i) {
          FocusScope.of(context).unfocus();
          // 移除手动颜色管理，让ButtonsTabBar自己处理Tab状态
        },
        children: const [
          LoginAccountPage(),
          LoginMobilePage(),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white10, Colors.white],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              'Or',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'WorkSansMedium',
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white10],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建快速登录按钮 - 简洁设计
  Widget _buildQuickLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => logic.loginAuth(false),
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: Text(
              'mobile_quick_login'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ThemeManager.instance.getThemeColor('primary'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建注册账号标签 - 简洁设计
  Widget _createAccountLabel() {
    return InkWell(
      onTap: () {
        Get.to(
          () => const SignupPage(),
          transition: Transition.rightToLeft,
          popGesture: true,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: .2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'no_sigin_q'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'signup'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
