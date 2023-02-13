import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/conversation/conversation_view.dart';
import 'package:imboy/page/mine/mine_view.dart';

import 'bottom_navigation_logic.dart';
import 'bottom_navigation_state.dart';

// ignore: must_be_immutable
class BottomNavigationPage extends StatelessWidget {
  //全局状态控制器
  final ConversationLogic clogic = Get.find();
  final BottomNavigationLogic logic = Get.find();

  final BottomNavigationState state = Get.find<BottomNavigationLogic>().state;

  List pageList = [
    ConversationPage(),
    // CooperationPage(),
    // WorkbenchPage(),
    ContactPage(),
    MinePage(),
  ];

  BottomNavigationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var args = Get.arguments;
    if (args is Map<String, dynamic>) {
      state.bottombarIndex.value = args["index"] ?? state.bottombarIndex.value;
    }

    return Scaffold(
      //主题
      body: Obx(() => pageList[state.bottombarIndex.value]),
      //底部导航条
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          // 当前菜单下标
          currentIndex: state.bottombarIndex.value,
          // 点击事件,获取当前点击的标签下标
          onTap: (int index) {
            logic.changeBottomBarIndex(index);
          },
          iconSize: 30.0,
          // 底部导航栏按钮选中时的颜色
          fixedColor: Colors.green,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Badge(
                showBadge: clogic.chatMsgRemindCounter > 0,
                shape: BadgeShape.square,
                borderRadius: BorderRadius.circular(10),
                position: BadgePosition.topStart(top: -4, start: 20),
                padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
                badgeContent: Container(
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: Text(
                    clogic.chatMsgRemindCounter.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ),
                child: const Icon(Icons.chat),
              ),
              label: 'title_message'.tr,
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.cloud),
            //   label: "云协作",
            // ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.account_tree),
            //   label: "工作台",
            // ),
            BottomNavigationBarItem(
              icon: Badge(
                showBadge: logic.newFriendRemindCounter.isNotEmpty,
                shape: BadgeShape.square,
                borderRadius: BorderRadius.circular(10),
                position: BadgePosition.topStart(top: -4, start: 20),
                padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
                badgeContent: Container(
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: Text(
                    logic.newFriendRemindCounter.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ),
                child: const Icon(Icons.perm_contact_cal),
              ),
              label: 'title_contact'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: 'title_mine'.tr,
            )
          ],
        ),
      ),
    );
  }
}
