import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
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
      appBar: PageAppBar(
        title: '设置'.tr,
      ),
      // color: appBarColor,
      body: SingleChildScrollView(
          child: n.Column(
        [
          Container(
            color: Colors.white,
            child: n.Column([
              n.ListTile(
                title: Text('消息通知'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  // Get.to(
                  //       () => MarkdownPage(
                  //     title: '更新日志'.tr,
                  //     url:
                  //     "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                  //   ),
                  //   transition: Transition.rightToLeft,
                  //   popGesture: true, // 右滑，返回上一页
                  // );
                },
              ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: Text('更新日志'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => MarkdownPage(
                      title: '更新日志'.tr,
                      url:
                          "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: Text('帮助文档'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => MarkdownPage(
                      title: '帮助文档'.tr,
                      url:
                          "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/help_document.md",
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              // n.Padding(left: 18, child: const Divider()),
              // n.ListTile(
              //   title: Text('朋友权限'.tr),
              //   trailing: Icon(
              //     Icons.navigate_next,
              //     color: AppColors.MainTextColor.withOpacity(0.5),
              //   ),
              //   onTap: () {
              //     Get.to(
              //       () => FriendsPermissionsPage(),
              //       transition: Transition.rightToLeft,
              //       popGesture: true, // 右滑，返回上一页
              //     );
              //   },
              // ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: n.Row([
                  Text('关于IMBoy'.tr),
                  Text("${'版本'.tr} $appVsn"),
                ])
                  // 两端对齐
                  ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  final rightDMActions = [
                    n.Padding(
                      right: 10,
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final Map<String, dynamic> info =
                              await vsnProvider.check(
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
                            EasyLoading.showInfo('未检测到新版本'.tr);
                          }
                        },
                        // ignore: sort_child_properties_last
                        child: Text(
                          '检查更新'.tr,
                          textAlign: TextAlign.center,
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            AppColors.primaryElement,
                          ),
                          foregroundColor: MaterialStateProperty.all<Color>(
                            Colors.white,
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
                      title: '关于IMBoy'.tr,
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
          ),
          /*
          ButtonRow(
            margin: const EdgeInsets.only(
              top: 10.0,
            ),
            text: '切换账号'.tr,
            style: const TextStyle(
              color: AppColors.ButtonTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {},
          ),
          */
          ButtonRow(
            margin: const EdgeInsets.only(top: 10.0, bottom: 10.0),
            text: '退出登录'.tr,
            style: const TextStyle(
              color: AppColors.ButtonTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {
              bool result = await UserRepoLocal.to.logout();
              if (result) {
                await StorageService.to.remove(Keys.tokenKey);
                Get.offAll(() => PassportPage());
              }
            },
          ),
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      )),
    );
  }

  @override
  void dispose() {
    Get.delete<SettingLogic>();
    super.dispose();
  }
}
