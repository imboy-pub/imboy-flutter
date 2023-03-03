import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/list_tile_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

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
          /*
          ListTileView(
            title: '账号与安全',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            margin: const EdgeInsets.only(bottom: 8.0),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),
          ListTileView(
            title: '青少年模式',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            // padding: EdgeInsets.symmetric(vertical: 16.0),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.LineColor,
                width: 0.2,
              ),
            ),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),
          ListTileView(
            title: '关怀模式',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            margin: const EdgeInsets.only(bottom: 8.0),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),
          */
          ListTileView(
            title: '消息通知'.tr,
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.LineColor,
                width: 0.2,
              ),
            ),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),
          /*
          ListTileView(
            title: '通用',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            margin: const EdgeInsets.only(bottom: 8.0),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 2.0, top: 6.0),
            child: Text(
              '隐私'.tr,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          ListTileView(
            title: '朋友权限',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            onPressed: () {
              Get.to(() => FriendsPermissionsPage());
            },
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
            border: const Border(
              bottom: BorderSide(
                color: AppColors.LineColor,
                width: 0.2,
              ),
            ),
          ),
          ListTileView(
            title: '个人信息与权限',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
            border: const Border(
              bottom: BorderSide(
                color: AppColors.LineColor,
                width: 0.2,
              ),
            ),
          ),
          ListTileView(
            title: '个人信息收集清单'.tr,
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            margin: const EdgeInsets.only(bottom: 8.0),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
          ),

          */
          ListTileView(
            title: '帮助与反馈',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
            border: const Border(
              bottom: BorderSide(
                color: AppColors.LineColor,
                width: 0.2,
              ),
            ),
          ),
          ListTileView(
            title: '关于IMBoy',
            titleStyle: const TextStyle(fontSize: 15.0),
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 4),
            onPressed: () {},
            width: 25.0,
            fit: BoxFit.cover,
            horizontal: 15.0,
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
                Get.off(() => PassportPage());
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
