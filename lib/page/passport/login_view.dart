import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

import 'login_account_view.dart';
import 'login_mobile_view.dart';
import 'passport_logic.dart';
import 'signup_view.dart';
import 'widget/bezier_container.dart';
import 'widget/bubble_indicator_painter.dart';

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

  Color left = Colors.black;
  Color right = Colors.white;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

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
    final height = Get.height;
    return Scaffold(
      body: Container(
          color: Colors.green,
          height: height,
          child: n.Stack([
            Positioned(
              top: -height * .15,
              right: -Get.width * .4,
              child: const BezierContainer(),
            ),
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 760,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      const SizedBox(height: 80),
                      logic.title(),
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0, bottom: 20),
                        child: _buildMenuBar(context),
                      ),
                      Flexible(
                        flex: 2,
                        child: PageView(
                          controller: _pageController,
                          physics: const ClampingScrollPhysics(),
                          onPageChanged: (int i) {
                            FocusScope.of(context).requestFocus(FocusNode());
                            if (i == 0) {
                              setState(() {
                                right = Colors.white;
                                left = Colors.black;
                              });
                            } else if (i == 1) {
                              setState(() {
                                right = Colors.black;
                                left = Colors.white;
                              });
                            }
                          },
                          children: <Widget>[
                            ConstrainedBox(
                              constraints: const BoxConstraints.expand(),
                              child: const LoginMobilePage(),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints.expand(),
                              child: const LoginAccountPage(),
                            ),
                          ],
                        ),
                      ),
                      /*
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.white10,
                                    Colors.white,
                                  ],
                                  begin: FractionalOffset(0.0, 0.0),
                                  end: FractionalOffset(1.0, 1.0),
                                  stops: <double>[0.0, 1.0],
                                  tileMode: TileMode.clamp),
                            ),
                            width: 100.0,
                            height: 1.0,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 15.0, right: 15.0),
                            child: Text(
                              'Or',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontFamily: 'WorkSansMedium'),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.white,
                                    Colors.white10,
                                  ],
                                  begin: FractionalOffset(0.0, 0.0),
                                  end: FractionalOffset(1.0, 1.0),
                                  stops: <double>[0.0, 1.0],
                                  tileMode: TileMode.clamp),
                            ),
                            width: 100.0,
                            height: 1.0,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 10.0, right: 40.0),
                            child: GestureDetector(
                              onTap: () {
                                logic.loginAuth(false);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(15.0),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  IMBoyIcon.jiguang,
                                  color: Color(0xFF0084ff),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: GestureDetector(
                              // onTap: () => CustomSnackBar(
                              //     context, const Text('Google button pressed')),
                              child: Container(
                                padding: const EdgeInsets.all(15.0),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  IMBoyIcon.huawei,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      */
                      _createAccountLabel(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: 40, left: 0, child: logic.backButton()),
            // 使用Align组件将NetworkFailureTips固定在底部并垂直居中
            Positioned(
              bottom: 0, // 固定在底部
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center, // 垂直和水平居中
                child: Obx(() {
                  return state.connectDesc.isEmpty
                      ? const SizedBox.shrink() // 如果没有连接描述，则不显示
                      : NetworkFailureTips(backgroundColor: Colors.white);
                }),
              ),
            ),
          ])),
    );
  }

  Widget _buildMenuBar(BuildContext context) {
    return Container(
      width: Get.width - 40,
      height: 50.0,
      decoration: const BoxDecoration(
        color: Color(0x552B2B2B),
        borderRadius: BorderRadius.all(Radius.circular(25.0)),
      ),
      child: CustomPaint(
        painter: BubbleIndicatorPainter(pageController: _pageController),
        child: n.Row([
          Expanded(
            child: TextButton(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: _onSignInButtonPress,
              child: Text(
                'param_login'.trArgs(['mobile'.tr]),
                style: TextStyle(
                  color: left,
                  fontSize: 16.0,
                  fontFamily: 'WorkSansSemiBold',
                ),
              ),
            ),
          ),
          //Container(height: 33.0, width: 1.0, color: Colors.white),
          Expanded(
            child: TextButton(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: _onSignUpButtonPress,
              child: Text(
                'param_login'.trArgs(['account'.tr]),
                style: TextStyle(
                  color: right,
                  fontSize: 16.0,
                  fontFamily: 'WorkSansSemiBold',
                ),
              ),
            ),
          ),
        ])
          ..mainAxisAlignment = MainAxisAlignment.spaceEvenly,
      ),
    );
  }

  void _onSignInButtonPress() {
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  void _onSignUpButtonPress() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
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
        ])
          ..mainAxisAlignment = MainAxisAlignment.center,
      ),
    );
  }
}
