import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/setting/setting_logic.dart';
import 'package:niku/namespace.dart' as n;

class FriendsPermissionsPage extends StatelessWidget {
  // final String id; // 用户ID
  // final String remark;

  FriendsPermissionsPage({
    super.key,
    // required this.id,
    // required this.remark,
  });

  final logic = Get.put(SettingLogic());

  Future<void> initData() async {}

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
        backgroundColor: AppColors.ChatBg,
        appBar: PageAppBar(
          title: '朋友权限'.tr,
        ),
        body: SingleChildScrollView(child: n.Column(const [])));
  }
}
