import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/service/websocket_status_provider.dart';
import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'bottom_navigation_provider.dart';

class BottomNavigationPage extends ConsumerStatefulWidget {
  const BottomNavigationPage({super.key});

  @override
  ConsumerState<BottomNavigationPage> createState() =>
      _BottomNavigationPageState();
}

class _BottomNavigationPageState extends ConsumerState<BottomNavigationPage> {
  late final PageController pageController;

  // 语言变化监听器
  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;

    // 尝试从 go_router 获取参数
    try {
      final routerState = GoRouterState.of(context);
      final indexParam = routerState.uri.queryParameters['index'];
      if (indexParam != null) {
        initialIndex = int.tryParse(indexParam) ?? 0;
      }
    } catch (_) {
      // 如果无法获取 go_router 状态，使用默认值
    }

    pageController = PageController(initialPage: initialIndex);
    // 防止 pageController 还未 attach 的异常
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(initialIndex);
      }
    });

    // 监听语言变化，切换语言时刷新页面
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // 延迟初始化 Riverpod state，避免在 build 期间修改状态
    Future.microtask(() {
      ref.read(bottomNavigationProvider.notifier).changeIndex(initialIndex);
    });

    // 初始化新好友提醒计数
    Future.microtask(() {
      ref.read(newFriendRemindProvider.notifier).countReminders();
    });
  }

  @override
  void dispose() {
    // 取消语言变化监听
    _localeSubscription?.cancel();
    pageController.dispose();
    super.dispose();
  }

  final List<Widget> pageList = [
    const ConversationPage(),
    ContactPage(),
    const ChannelListPage(),
    MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // 使用 context.t 替代全局 t，确保响应语言变化
    final t = context.t;
    // 使用优化后的主题管理器获取字体大小
    final labelFontSize = ThemeManager.instance.getFontSize(
      FontSizeType.small,
      context: context,
    );

    // 使用 Riverpod 监听底部导航索引
    final bottomBarIndex = ref.watch(bottomNavigationProvider);
    // 监听新好友提醒
    final newFriendCount = ref.watch(newFriendRemindProvider);
    // 监听 WebSocket 状态（使用 Provider 响应式监听）
    final socketStatusAsync = ref.watch(webSocketStatusProvider);
    final socketStatus =
        socketStatusAsync.value ?? WebSocketConnectionState.disconnected;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 使用主题背景色
      extendBody: true, // 关键：允许body延伸到底部导航栏下方
      body: PageView(
        controller: pageController,
        onPageChanged: (index) {
          // 使用 Riverpod 更新索引
          ref.read(bottomNavigationProvider.notifier).changeIndex(index);
        },
        physics: const NeverScrollableScrollPhysics(),
        children: pageList, // 禁止手势滑动
      ),
      bottomNavigationBar: GlassBottomNavigationBar(
        currentIndex: bottomBarIndex,
        onTap: (index) {
          ref.read(bottomNavigationProvider.notifier).changeIndex(index);
          if (pageController.hasClients) {
            pageController.jumpToPage(index);
          }
        },
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: t.titleMessage,
            iconBuilder: (isSelected) {
              // TODO: 集成 conversation provider 的 chatMsgRemindCounter
              // 临时设置为0，待 conversation 模块完全迁移后修复
              const chatRemindCount = 0;
              return badges.Badge(
                showBadge: chatRemindCount > 0,
                position: badges.BadgePosition.topStart(top: -8, start: 20),
                badgeContent: Text(
                  chatRemindCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: labelFontSize * 0.85,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: AppColors.messageFailed, // 使用消息状态颜色
                  borderRadius: AppRadius.borderRadiusMedium, // 圆角徽章
                  elevation: 2, // 添加阴影
                ),
                child: Icon(
                  isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  size: 26,
                  color: isSelected ? AppColors.primary : null,
                ),
              );
            },
          ),
          GlassBottomBarItem(
            icon: Icons.perm_contact_cal_outlined,
            activeIcon: Icons.perm_contact_cal,
            label: t.titleContact,
            iconBuilder: (isSelected) {
              final count = newFriendCount.length;
              return badges.Badge(
                showBadge: count > 0,
                position: badges.BadgePosition.topStart(top: -8, start: 20),
                badgeContent: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: labelFontSize * 0.85,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: AppColors.messageFailed,
                  borderRadius: AppRadius.borderRadiusMedium,
                  elevation: 2,
                ),
                child: Icon(
                  isSelected
                      ? Icons.people_alt
                      : Icons.people_alt_outlined, // 优化图标选择
                  size: 26,
                  color: isSelected ? AppColors.primary : null,
                ),
              );
            },
          ),
          GlassBottomBarItem(
            icon: Icons.campaign_outlined,
            activeIcon: Icons.campaign,
            label: t.channel.title,
            iconBuilder: (isSelected) => Icon(
              isSelected ? Icons.campaign : Icons.campaign_outlined,
              size: 26,
              color: isSelected ? AppColors.primary : null,
            ),
          ),
          GlassBottomBarItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: t.titleMine,
            iconBuilder: (isSelected) => badges.Badge(
              showBadge: true,
              position: badges.BadgePosition.topStart(
                top: 2,
                start: 22,
              ), // 调整在线状态点的位置
              badgeStyle: badges.BadgeStyle(
                badgeColor: socketStatus == WebSocketConnectionState.connected
                    ? AppColors
                          .success // 在线状态使用成功色
                    : AppColors.messageFailed, // 离线状态使用失败色
                borderRadius: AppRadius.borderRadiusSmall, // 稍微大一点的圆点
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
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
