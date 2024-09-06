import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:niku/namespace.dart' as n;

import 'login_view.dart';
import 'signup_view.dart';
import 'passport_logic.dart';
import 'widget/bezier_container.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, this.title});

  final String? title;

  @override
  WelcomePageState createState() => WelcomePageState();
}

class WelcomePageState extends State<WelcomePage> {
  final PassportLogic logic = Get.put(PassportLogic());
  final state = Get.find<PassportLogic>().state;

  final LanguageLogic langLogic = Get.put(LanguageLogic());

  @override
  void initState() {
    super.initState();
    logic.initPlatformState();
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

  /*
  Widget _label() {
    return Container(
        margin: const EdgeInsets.only(top: 40, bottom: 20),
        child: Column(
          children: <Widget>[
            Text(
              'Quick login with Touch ID'.tr,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(
              height: 20,
            ),
            const Icon(Icons.fingerprint, size: 90, color: Colors.white),
            const SizedBox(
              height: 20,
            ),
            Text(
              'Touch ID'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ));
  }
  */
  @override
  Widget build(BuildContext context) {
    final height = Get.height;
    return Scaffold(
        body: Container(
      color: Colors.green,
      height: height,
      child: n.Stack([
        Positioned.fill(
          child: Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
          ),
        ),
        // Positioned(
        //   top: -height * .15,
        //   right: -Get.width * .4,
        //   child: const BezierContainer(),
        // ),

        // 多语言设置
        Positioned(
            top: 40,
            right: 10,
            child: InkWell(
              onTap: () {
                Get.bottomSheet(
                  backgroundColor: Get.isDarkMode
                      ? const Color.fromRGBO(80, 80, 80, 1)
                      : const Color.fromRGBO(240, 240, 240, 1),
                  SizedBox(
                    width: Get.width,
                    height: 268,
                    child: n.Column([
                      n.Row([
                        n.Padding(
                          top: 10,
                          right: 10,
                          child: Obx(() => RoundedElevatedButton(
                              text: 'button_accomplish'.tr,
                              highlighted: langLogic.state.valueChanged.isTrue,
                              onPressed: () async {
                                langLogic.changeLanguage(
                                  langLogic.state.selectedLanguage.value,
                                );
                                Get.closeAllBottomSheets();
                              })),
                        ),
                      ])
                        ..mainAxisAlignment = MainAxisAlignment.end,
                      Expanded(
                        child: ListView.builder(
                          itemBuilder: (BuildContext context, int index) {
                            var model = langLogic.state.languageList[index];
                            return langLogic.getListItem(context, model);
                          },
                          itemCount: langLogic.state.languageList.length,
                        ),
                      ),
                    ], mainAxisSize: MainAxisSize.min)
                      ..useParent(
                          (v) => v..bg = Theme.of(context).colorScheme.surface),
                  ),
                  //改变shape这里即可
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                );
              },
              child: const Icon(
                Icons.language,
                color: Colors.white,
              ),
            )),
        // 使用Align组件将NetworkFailureTips固定在底部并垂直居中
        Positioned(
          bottom: 10, // 固定在底部
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center, // 垂直和水平居中
            child: n.Column([
              // logic.title(),
              // const SizedBox(height: 20),
              n.Row([
                /*
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  style: whiteGreenButtonStyle(const Size(88, 48)),
                  onPressed: () {
                    logic.loginAuth(false);
                  },
                  child: n.Padding(
                      left: 10,
                      right: 10,
                      child: Text(
                        'mobile_quick_login'.tr,
                        textAlign: TextAlign.center,
                      )),
                )),
                */
                Flexible(
                    flex: 1,
                    child: n.Padding(
                      left: 10,
                      child: ElevatedButton(
                        style: lightGreenButtonStyle(const Size(80, 48)),
                        onPressed: () async {
                          Get.to(
                            () => const SignupPage(),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                        child: Text(
                          'signup'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    )),
                Flexible(
                    child: n.Padding(
                  right: 10,
                  child: ElevatedButton(
                    style: whiteGreenButtonStyle(const Size(80, 48)),
                    onPressed: () {
                      Get.to(
                        () => const LoginPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                    child: Text(
                      'param_login'.trArgs(['account'.tr]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              Obx(() {
                return state.connectDesc.isEmpty
                    ? const SizedBox.shrink() // 如果没有连接描述，则不显示
                    : NetworkFailureTips(backgroundColor: Colors.white);
              })
            ]),
          ),
        ),
      ]),
    ));
  }
}
