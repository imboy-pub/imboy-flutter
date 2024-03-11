import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/page/mine/dark_model/dark_model_view.dart';
import 'package:imboy/page/mine/language/language_view.dart';
import 'package:imboy/page/mine/storage_space/storage_space_view.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/store/provider/app_version_provider.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/page/single/markdown.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'setting_logic.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final logic = Get.put(SettingLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'setting'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Column([
          n.Column([
            n.ListTile(
              title: Text('account_security'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => MarkdownPage(
                //     title: 'update_log'.tr,
                //     url:
                //     "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                //   ),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: Text('language_setting'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => LanguagePage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('dark_model'.tr),
                Text(logic.themeTypeTips()),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => DarkModelPage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: Text('message_notification'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => MarkdownPage(
                //     title: 'update_log'.tr,
                //     url:
                //     "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                //   ),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: Text('storage_space'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => StorageSpacePage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            // n.Padding(left: 18, child: HorizontalLine(
            //         height: Get.isDarkMode ? 0.5 : 1.0,
            //         color: Theme.of(context).colorScheme.primary,
            //       )),
            // n.ListTile(
            //   title: Text('friend_permissions'.tr),
            //   trailing: navigateNextIcon,
            //   onTap: () {
            //     Get.to(
            //       () => FriendsPermissionsPage(),
            //       transition: Transition.rightToLeft,
            //       popGesture: true, // 右滑，返回上一页
            //     );
            //   },
            // ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: Text('update_log'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => MarkdownPage(
                    title: 'update_log'.tr,
                    url:
                        "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: Text('help_document'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => MarkdownPage(
                    title: 'help_document'.tr,
                    url:
                        "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/help_document.md",
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('about_app'.tr),
                Text("${'version'.tr} $appVsn"),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                final rightDMActions = [
                  n.Padding(
                    right: 10,
                    top: 10,
                    bottom: 10,
                    child: ElevatedButton(
                      onPressed: () async {
                        final AppVersionProvider p = AppVersionProvider();
                        final navigator = Navigator.of(context);
                        final Map<String, dynamic> info = await p.check(
                          appVsn,
                        );
                        final String downLoadUrl = info['download_url'] ?? '';
                        bool updatable = info['updatable'] ?? false;
                        updatable = downLoadUrl.isEmpty ? false : updatable;
                        if (updatable) {
                          await navigator.push(
                            CupertinoPageRoute(
                              // “右滑返回上一页”功能
                              builder: (_) => UpgradePage(
                                version: info['vsn'],
                                downLoadUrl: downLoadUrl,
                                message: info['description'] ?? '',
                                isForce: 1 == (info['force_update'] ?? 2)
                                    ? true
                                    : false,
                              ),
                            ),
                          );
                        } else {
                          EasyLoading.showInfo('now_new_version'.tr);
                        }
                      },
                      // ignore: sort_child_properties_last
                      child: n.Padding(
                          left: 10,
                          right: 10,
                          child: Text(
                            'check_for_updates'.tr,
                            textAlign: TextAlign.center,
                          )),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).colorScheme.background,
                        ),
                        foregroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).colorScheme.onBackground,
                        ),
                        minimumSize: MaterialStateProperty.all(
                          const Size(80, 32),
                        ),
                        padding: MaterialStateProperty.all(
                          EdgeInsets.zero,
                        ),
                      ),
                    ),
                  )
                ];
                Get.to(
                  () => MarkdownPage(
                    title: "${'about'.tr} $appName",
                    rightDMActions: rightDMActions,
                    url:
                        "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md",
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
          ]),
          /*
          ButtonRow(
            margin: const EdgeInsets.only(
              top: 10.0,
            ),
            text: 'switch_account'.tr,
            style: const TextStyle(
              color: AppColors.ButtonTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {},
          ),
          */
          HorizontalLine(
            height: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
          ButtonRow(
            text: 'log_out'.tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {
              bool result = await UserRepoLocal.to.logout();
              if (result) {
                await StorageService.to.remove(Keys.refreshTokenKey);
                await StorageService.to.remove(Keys.tokenKey);
                Get.offAll(() => PassportPage());
              }
            },
          ),
          // HorizontalLine(
          //   height: 20,
          //   color: Theme.of(context).colorScheme.primary,
          // ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<SettingLogic>();
    super.dispose();
  }
}
