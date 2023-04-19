import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/page/single/about_imboy.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'friends_permissions_view.dart';
import 'setting_logic.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

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
              ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: Text('帮助与反馈'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
              ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: Text('朋友权限'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => FriendsPermissionsPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(left: 18, child: const Divider()),
              n.ListTile(
                title: Text('关于IMBoy'.tr),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => AboutIMBoyPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
            ]),
          ),
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
