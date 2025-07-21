import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';

import 'package:imboy/page/contact/contact/contact_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/conversation/conversation_view.dart';
import 'package:imboy/page/mine/mine/mine_view.dart';
import 'package:imboy/service/websocket.dart'
    show SocketStatus, WebSocketService;

import 'bottom_navigation_logic.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({super.key});

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  final logic = Get.find<BottomNavigationLogic>();
  final conversationLogic = Get.find<ConversationLogic>();
  final contactLogic = Get.put(ContactLogic());
  final state = Get.find<BottomNavigationLogic>().state;

  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    var args = Get.arguments;
    if (args is Map<String, dynamic>) {
      initialIndex = args['index'] ?? 0;
      state.bottomBarIndex.value = initialIndex;
    }

    pageController = PageController(initialPage: initialIndex);
    // 防止 pageController 还未 attach 的异常
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(initialIndex);
      }
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  final List<Widget> pageList = [
    const ConversationPage(),
    ContactPage(),
    MinePage(),
  ];

  @override
  Widget build(BuildContext context) {

    final labelFontSize = Theme.of(context)
        .bottomNavigationBarTheme
        .selectedLabelStyle
        ?.fontSize
        ?? Theme.of(context).textTheme.bodySmall?.fontSize
        ?? 12.0;
    return Scaffold(
      body: PageView(
        controller: pageController,
        onPageChanged: logic.changeBottomBarIndex,
        physics: const NeverScrollableScrollPhysics(),
        children: pageList, // 禁止手势滑动
      ),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          currentIndex: state.bottomBarIndex.value,
          onTap: (index) {
            logic.changeBottomBarIndex(index);
            if (pageController.hasClients) {
              pageController.jumpToPage(index);
            }
          },
          fixedColor: Colors.green,
          iconSize: 30.0,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Obx(
                () => badges.Badge(
                  showBadge: conversationLogic.chatMsgRemindCounter.value > 0,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    conversationLogic.chatMsgRemindCounter.value.toString(),
                    style:  TextStyle(
                      color: Colors.white,
                      fontSize: labelFontSize * 0.85,
                    ),
                  ),
                  child: const Icon(Icons.chat),
                ),
              ),
              label: 'title_message'.tr,
            ),
            BottomNavigationBarItem(
              icon: Obx(
                () => badges.Badge(
                  showBadge: logic.newFriendRemindCounter.isNotEmpty,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    logic.newFriendRemindCounter.length.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  child: const Icon(Icons.perm_contact_cal),
                ),
              ),
              label: 'title_contact'.tr,
            ),
            BottomNavigationBarItem(
              icon: Obx(
                () => badges.Badge(
                  showBadge: true,
                  position: badges.BadgePosition.topStart(top: 36, start: 40),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor:
                        WebSocketService.to.status.value ==
                            SocketStatus.connected
                        ? Colors.green
                        : Colors.red,
                  ),
                  child: const Icon(Icons.person),
                ),
              ),
              label: 'title_mine'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
