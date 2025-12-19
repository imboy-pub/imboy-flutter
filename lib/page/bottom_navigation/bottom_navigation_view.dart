import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

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
    // 使用优化后的主题管理器获取字体大小
    final labelFontSize = ThemeManager.instance.getFontSize(FontSizeType.small, context: context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 使用主题背景色
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
          // 使用优化后的主题颜色系统
          selectedItemColor: AppColors.primaryGreen, // 使用主题主色
          unselectedItemColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.6), // 使用主题未选中色
          backgroundColor: Theme.of(context).colorScheme.surface, // 使用主题背景色
          iconSize: ThemeManager.instance.getFontSize(FontSizeType.large, context: context),
          type: BottomNavigationBarType.fixed,
          elevation: 8.0, // 添加阴影效果
          // 使用主题管理器的字体样式
          selectedLabelStyle: ThemeManager.instance.getTextStyle(
            FontSizeType.normal,
            fontWeight: FontWeight.w600, // 增强选中状态的字重
            color: AppColors.primaryGreen,
            context: context,
          ),
          unselectedLabelStyle: ThemeManager.instance.getTextStyle(
            FontSizeType.small,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            context: context,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Obx(
                () => badges.Badge(
                  showBadge: conversationLogic.chatMsgRemindCounter.value > 0,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    conversationLogic.chatMsgRemindCounter.value.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelFontSize * 0.85,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600, // 增强徽章文字的可读性
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.messageFailed, // 使用消息状态颜色
                    borderRadius: BorderRadius.circular(10), // 圆角徽章
                    elevation: 2, // 添加阴影
                  ),
                  child: const Icon(Icons.chat),
                ),
              ),
              label: 'titleMessage'.tr,
            ),
            BottomNavigationBarItem(
              icon: Obx(
                () => badges.Badge(
                  showBadge: logic.newFriendRemindCounter.isNotEmpty,
                  position: badges.BadgePosition.topStart(top: -8, start: 20),
                  badgeContent: Text(
                    logic.newFriendRemindCounter.length.toString(),
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      context: context,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.messageFailed, // 使用消息状态颜色
                    borderRadius: BorderRadius.circular(10), // 圆角徽章
                    elevation: 2, // 添加阴影
                  ),
                  child: const Icon(Icons.perm_contact_cal),
                ),
              ),
              label: 'titleContact'.tr,
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
                        ? AppColors
                              .success // 在线状态使用成功色
                        : AppColors.messageFailed, // 离线状态使用失败色
                    borderRadius: BorderRadius.circular(4), // 小圆角状态指示器
                  ),
                  child: const Icon(Icons.person),
                ),
              ),
              label: 'titleMine'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
