import 'package:fluent_ui/fluent_ui.dart' as fl;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

// import 'group_list_logic.dart';

class GroupListPage extends StatelessWidget {
  const GroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // final logic = Get.put(GroupListLogic());
    // final state = Get.find<GroupListLogic>().state;

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      // backgroundColor: Colors.white,
      appBar: PageAppBar(
        title: '群聊'.tr,
      ),
      body: fl.FluentTheme(
        data: fl.FluentThemeData(),
        child: n.Padding(
          left: 12,
          top: 12,
          right: 12,
          child: n.Column(
            const [],
            // 内容文本左对齐
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
        ),
      ),
    );
  }
}
