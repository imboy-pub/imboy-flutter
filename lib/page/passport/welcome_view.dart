import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart';

import 'login_view.dart';
import 'signup_view.dart';
import 'passport_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    
    // 初始化语言状态
    _initializeLanguageState();
    
    // 检查网络状态
    Connectivity().checkConnectivity().then((r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        state.connectDesc.value = t.tipConnectDesc;
      } else {
        state.connectDesc.value = '';
      }
    });
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        state.connectDesc.value = t.tipConnectDesc;
      } else {
        state.connectDesc.value = '';
      }
    });
  }

  /// 初始化语言状态
  void _initializeLanguageState() {
    final currentLang = StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';
    langLogic.state.currentLanguage.value = currentLang;
    langLogic.state.selectedLanguage.value = currentLang;
    langLogic.state.valueChanged.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final height = Get.height;
    return Scaffold(
        body: Container(
      color: Colors.green,
      height: height,
      child: Stack(
        children: [
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Get.bottomSheet(
                    backgroundColor: Colors.transparent,
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeManager.instance.isDarkMode
                            ? const Color.fromRGBO(28, 28, 30, 0.98)
                            : const Color.fromRGBO(255, 255, 255, 0.98),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24.0),
                          topRight: Radius.circular(24.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: Get.width,
                        height: 320,
                        child: Column(
                          children: [
                            // 顶部拖拽指示器
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: ThemeManager.instance.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // 标题和完成按钮
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t.languageSetting,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeManager.instance.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Obx(() => Container(
                                    decoration: BoxDecoration(
                                      color: langLogic.state.valueChanged.isTrue
                                          ? AppColors.primaryGreen
                                          : (ThemeManager.instance.isDarkMode
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: langLogic.state.valueChanged.isTrue
                                            ? () async {
                                                langLogic.changeLanguage(
                                                  langLogic.state.selectedLanguage.value,
                                                );
                                                Get.closeAllBottomSheets();
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            t.buttonAccomplish,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: langLogic.state.valueChanged.isTrue
                                                  ? Colors.white
                                                  : (ThemeManager.instance.isDarkMode
                                                      ? Colors.white.withValues(alpha: 0.4)
                                                      : Colors.black.withValues(alpha: 0.4)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            // 语言列表
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemBuilder: (BuildContext context, int index) {
                                  var model = langLogic.state.languageList[index];
                                  return _buildModernLanguageItem(model, index);
                                },
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: ThemeManager.instance.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemCount: langLogic.state.languageList.length,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    isScrollControlled: true,
                    enableDrag: true,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            )),
        // 使用Align组件将NetworkFailureTips固定在底部并垂直居中
        Positioned(
          bottom: 10, // 固定在底部
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center, // 垂直和水平居中
            child: Column(
              children: [
                // logic.title(),
                // const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /*
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      style: whiteGreenButtonStyle(const Size(88, 48)),
                      onPressed: () {
                        logic.loginAuth(false);
                      },
                      child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Text(
                            t.mobileQuickLogin,
                            textAlign: TextAlign.center,
                          )),
                    )),
                    */
                    Flexible(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: ElevatedButton(
                            style: lightGreenButtonStyle(const Size(80, 48)),
                            onPressed: () async {
                              Get.to(
                                () => const SignupPage(),
                                transition: Transition.rightToLeft,
                                popGesture: true, // 右滑，返回上一页
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Text(
                                t.signup,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        )),
                    Flexible(
                        child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: ElevatedButton(
                          style: whiteGreenButtonStyle(const Size(80, 48)),
                          onPressed: () {
                            Get.to(
                              () => const LoginPage(),
                              transition: Transition.rightToLeft,
                              popGesture: true, // 右滑，返回上一页
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8),
                            child: Text(
                              t.paramLogin.replaceAll('{param}', t.account),
                              textAlign: TextAlign.center,
                            ),
                          )),
                    )),
                  ],
                ),
                Obx(() {
                  return state.connectDesc.isEmpty
                      ? const SizedBox.shrink() // 如果没有连接描述，则不显示
                      : NetworkFailureTips(backgroundColor: Colors.white);
                })
              ],
            ),
          ),
        ),
      ]),
    ));
  }

  /// 构建现代化的语言选择项
  Widget _buildModernLanguageItem(Map<String, dynamic> item, int index) {
    return Obx(() {
      final isSelected = langLogic.state.selectedLanguage.value == item['id'];
      final isCurrentLang = langLogic.state.currentLanguage.value == item['id'];
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected 
              ? (ThemeManager.instance.isDarkMode
                  ? AppColors.primaryGreen.withValues(alpha: 0.06)
                  : AppColors.primaryGreen.withValues(alpha: 0.04))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected 
                        ? AppColors.primaryGreen
                        : (Get.isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (isCurrentLang && !isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ThemeManager.instance.isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: ThemeManager.instance.isDarkMode
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
          trailing: isSelected 
              ? Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                )
              : null,
          onTap: () {
            langLogic.state.selectedLanguage.value = item['id'];
            langLogic.state.valueChanged.value = 
                langLogic.state.selectedLanguage.value != langLogic.state.currentLanguage.value;
          },
        ),
      );
    });
  }
}
