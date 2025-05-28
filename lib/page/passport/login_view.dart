import 'package:buttons_tabbar/buttons_tabbar.dart' show ButtonsTabBar;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/network_failure_tips.dart';
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
      backgroundColor: Colors.green,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 背景装饰
              Positioned(
                top: -screenHeight * .10,
                right: -screenWidth * .68,
                child: const BezierContainer(),
              ),

              // 主内容区域
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
                          _buildTabBar(screenWidth),
                          _buildPageView(),
                          _buildOrDivider(),
                          if (GetPlatform.isMobile) _buildQuickLoginButton(),
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

              // 返回按钮
              Positioned(top: 40, left: 0, child: logic.backButton()),

              // 网络状态提示
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Obx(
                  () => state.connectDesc.isEmpty
                      ? const SizedBox.shrink()
                      : NetworkFailureTips(backgroundColor: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0x552B2B2B),
          borderRadius: BorderRadius.all(Radius.circular(25)),
        ),
        child: DefaultTabController(
          length: 2,
          child: ButtonsTabBar(
            radius: 25,
            height: 60,
            width: (screenWidth - 40) / 2,
            contentCenter: true,
            duration: 800,
            buttonMargin: const EdgeInsets.all(2),
            backgroundColor: leftBgColor,
            unselectedBackgroundColor: rightBgColor,
            labelStyle: TextStyle(
              color: leftColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'WorkSansSemiBold',
            ),
            unselectedLabelStyle: TextStyle(
              color: rightColor,
              fontSize: 16,
              fontFamily: 'WorkSansSemiBold',
            ),
            tabs: [
              Tab(
                child: TextButton(
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                  onPressed: _onSignInButtonPress,

                  child: Text(
                    'param_login'.trArgs(['mobile'.tr]),
                    style: TextStyle(
                      color: leftColor,
                      fontSize: 16.0,
                      fontFamily: 'WorkSansSemiBold',
                    ),
                  ),
                ),
              ),
              Tab(
                child: TextButton(
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                  onPressed: _onSignUpButtonPress,
                  child: Text(
                    'param_login'.trArgs(['account'.tr]),
                    style: TextStyle(
                      color: rightColor,
                      fontSize: 16.0,
                      fontFamily: 'WorkSansSemiBold',
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

  Widget _buildPageView() {
    return SizedBox(
      height: 240, // 适当的高度
      child: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (int i) {
          FocusScope.of(context).unfocus();
          setState(() {
            if (i == 0) {
              leftColor = Colors.black;
              leftBgColor = Colors.white;
              rightColor = Colors.white;
              rightBgColor = const Color(0x552B2B2B).withAlpha(0);
            } else {
              leftColor = Colors.white;
              leftBgColor = const Color(0x552B2B2B).withAlpha(0);
              rightColor = Colors.black;
              rightBgColor = Colors.white;
            }
          });
        },
        children: const [LoginMobilePage(), LoginAccountPage()],
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

  Widget _buildQuickLoginButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        onPressed: () => logic.loginAuth(false),
        style: lightGreenButtonStyle(
          Size(MediaQuery.of(context).size.width - 40, 40),
        ),
        child: Text(
          'mobile_quick_login'.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _onSignInButtonPress() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
    );
  }

  void _onSignUpButtonPress() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
    );
  }

  Widget _createAccountLabel() {
    return InkWell(
      onTap: () {
        Get.to(
          () => const SignupPage(),
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
            'no_sigin_q'.tr,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'signup'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ])..mainAxisAlignment = MainAxisAlignment.center,
      ),
    );
  }
}
