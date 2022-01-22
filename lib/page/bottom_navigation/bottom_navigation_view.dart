import 'package:badges/badges.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact_view.dart';
import 'package:imboy/page/conversation/conversation_view.dart';
import 'package:imboy/page/mine/mine_view.dart';
import 'package:imboy/service/message.dart';

import 'bottom_navigation_logic.dart';
import 'bottom_navigation_state.dart';

class BottomNavigationPage extends StatelessWidget {
  //全局状态控制器
  final logic = Get.put(BottomNavigationLogic());

  // final logic = Get.find<BottomNavigationLogic>();
  final BottomNavigationState state = Get.find<BottomNavigationLogic>().state;

  List pageList = [
    ConversationPage(),
    // CooperationPage(),
    // WorkbenchPage(),
    ContactPage(),
    MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
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
                showBadge:
                    (MessageService.to.chatMsgRemindCounter > 0 ? true : false),
                shape: BadgeShape.square,
                borderRadius: BorderRadius.circular(10),
                position: BadgePosition.topStart(top: -4, start: 20),
                padding: EdgeInsets.fromLTRB(5, 3, 5, 3),
                child: Icon(Icons.chat),
                badgeContent: Container(
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: Text(
                    MessageService.to.chatMsgRemindCounter.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
              label: "消息",
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
              icon: Icon(Icons.perm_contact_cal),
              label: "联系人",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "我的",
            )
          ],
        ),
      ),
    );
  }
}
