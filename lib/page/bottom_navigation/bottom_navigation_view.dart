import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/page/contact/contact/contact_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/conversation/conversation_view.dart';
import 'package:imboy/page/mine/mine/mine_view.dart';
import 'package:imboy/service/websocket.dart'
    show SocketStatus, WebSocketService;
import 'package:imboy/component/ui/glass_bottom_bar.dart'; // Import custom widget

import 'bottom_navigation_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    // 使用优化后的主题管理器获取字体大小
    final labelFontSize = ThemeManager.instance.getFontSize(
      FontSizeType.small,
      context: context,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 使用主题背景色
      extendBody: true, // 关键：允许body延伸到底部导航栏下方
      body: PageView(
        controller: pageController,
        onPageChanged: logic.changeBottomBarIndex,
        physics: const NeverScrollableScrollPhysics(),
        children: pageList, // 禁止手势滑动
      ),
      bottomNavigationBar: Obx(
        () => GlassBottomNavigationBar(
          currentIndex: state.bottomBarIndex.value,
          onTap: (index) {
            logic.changeBottomBarIndex(index);
            if (pageController.hasClients) {
              pageController.jumpToPage(index);
            }
          },
          items: [
            GlassBottomBarItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: t.titleMessage,
              iconBuilder: (isSelected) => Obx(
                () => badges.Badge(
                  showBadge: conversationLogic.chatMsgRemindCounter.value > 0,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    conversationLogic.chatMsgRemindCounter.value.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelFontSize * 0.85,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.messageFailed, // 使用消息状态颜色
                    borderRadius: BorderRadius.circular(10), // 圆角徽章
                    elevation: 2, // 添加阴影
                  ),
                  child: Icon(
                    isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    size: 26,
                    color: isSelected ? AppColors.primaryGreen : null,
                  ),
                ),
              ),
            ),
            GlassBottomBarItem(
              icon: Icons.perm_contact_cal_outlined,
              activeIcon: Icons.perm_contact_cal,
              label: t.titleContact,
              iconBuilder: (isSelected) => Obx(
                () => badges.Badge(
                  showBadge: logic.newFriendRemindCounter.isNotEmpty,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    logic.newFriendRemindCounter.length.toString(),
                    style: TextStyle(
                      fontSize: labelFontSize * 0.85,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.messageFailed,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 2,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.people_alt
                        : Icons.people_alt_outlined, // 优化图标选择
                    size: 26,
                    color: isSelected ? AppColors.primaryGreen : null,
                  ),
                ),
              ),
            ),
            GlassBottomBarItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: t.titleMine,
              iconBuilder: (isSelected) => Obx(
                () => badges.Badge(
                  showBadge: true,
                  position: badges.BadgePosition.topStart(
                    top: 2,
                    start: 22,
                  ), // 调整在线状态点的位置
                  badgeStyle: badges.BadgeStyle(
                    badgeColor:
                        WebSocketService.to.status.value ==
                            SocketStatus.connected
                        ? AppColors
                              .success // 在线状态使用成功色
                        : AppColors.messageFailed, // 离线状态使用失败色
                    borderRadius: BorderRadius.circular(6), // 稍微大一点的圆点
                    borderSide: BorderSide(
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white)
                          : Theme.of(context).colorScheme.surface,
                      width: 2,
                    ), // 增加描边以区分图标
                  ),
                  child: Icon(
                    isSelected ? Icons.person : Icons.person_outline,
                    size: 26,
                    color: isSelected ? AppColors.primaryGreen : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
