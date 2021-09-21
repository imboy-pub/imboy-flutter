import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contacts/contacts_view.dart';
import 'package:imboy/page/home/home_view.dart';
import 'package:imboy/page/mine/mine_view.dart';

import 'bottom_navigation_logic.dart';
import 'bottom_navigation_state.dart';

class BottomNavigationPage extends StatefulWidget {
  @override
  _BottomNavigationPageState createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  //全局状态控制器
  final logic = Get.put(BottomNavigationLogic());

  // final logic = Get.find<BottomNavigationLogic>();
  final BottomNavigationState state = Get.find<BottomNavigationLogic>().state;

  List pageList = [
    HomePage(),
    // CooperationPage(),
    // WorkbenchPage(),
    ContactsPage(),
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
              icon: Icon(
                Icons.chat,
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

  @override
  void dispose() {
    Get.delete<BottomNavigationLogic>();
    super.dispose();
  }
}
