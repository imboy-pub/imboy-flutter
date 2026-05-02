import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart'
    show subscribedChannelStripProvider;
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

  StreamSubscription? _localeSubscription;

  /// 是否已根据 GoRouter 的 query 参数初始化过 index
  /// GoRouterState.of(context) 必须在 initState 之后调用（依赖 InheritedWidget）
  bool _initialIndexApplied = false;

  // 固定 4 Tab：消息 / 联系人 / 频道 / 我的
  int _normalizeIndex(int value) {
    return value.clamp(0, 3);
  }

  List<Widget> _buildPageList() {
    return [
      const ConversationPage(),
      ContactPage(),
      const ChannelListPage(),
      MinePage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    // PageController 初始为 0，真正的 initialIndex 在 didChangeDependencies 中
    // 根据 GoRouterState 的 query 参数计算并跳转（GoRouterState.of 依赖
    // InheritedWidget，不能在 initState 中调用）
    pageController = PageController(initialPage: 0);

    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    Future.microtask(() {
      ref.read(newFriendRemindProvider.notifier).countReminders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialIndexApplied) return;
    _initialIndexApplied = true;

    int initialIndex = 0;

    try {
      final routerState = GoRouterState.of(context);
      final indexParam = routerState.uri.queryParameters['index'];
      if (indexParam != null) {
        initialIndex = int.tryParse(indexParam) ?? 0;
      }
    } catch (e) {
      // 非 GoRouter 上下文时使用默认值
    }

    initialIndex = _normalizeIndex(initialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pageController.hasClients) {
        pageController.jumpToPage(initialIndex);
      }
      ref.read(bottomNavigationProvider.notifier).changeIndex(initialIndex);
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // channelEnabled 控制会话列表顶部频道置顶区显示（Slice-5 接线）
    final channelEnabled = AppFeatureRegistry.isEnabled('channel');
    final pageList = _buildPageList();
    final labelFontSize = ThemeManager.instance.getFontSize(
      FontSizeType.small,
      context: context,
    );

    final rawBottomBarIndex = ref.watch(bottomNavigationProvider);
    final bottomBarIndex = _normalizeIndex(rawBottomBarIndex);
    final socketStatusAsync = ref.watch(webSocketStatusProvider);
    final socketStatus =
        socketStatusAsync.value ?? WebSocketConnectionState.disconnected;

    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    // 600px - 900px 为 tablet 模式（使用 NavigationRail）
    final isTablet = width >= 600 && width < 900;

    if (rawBottomBarIndex != bottomBarIndex) {
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        ref.read(bottomNavigationProvider.notifier).changeIndex(bottomBarIndex);
        if (pageController.hasClients) {
          pageController.jumpToPage(bottomBarIndex);
        }
      });
    }

    final navigationItems = [
      _NavigationItemData(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: t.titleMessage,
        remindCount: ref.watch(conversationProvider).chatMsgRemindCounter,
      ),
      _NavigationItemData(
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt,
        label: t.titleContact,
        remindCount: ref.watch(newFriendRemindProvider).length,
      ),
      _NavigationItemData(
        icon: Icons.campaign_outlined,
        activeIcon: Icons.campaign,
        label: t.channel.title,
        remindCount: channelEnabled
            ? (ref
                      .watch(subscribedChannelStripProvider)
                      .value
                      ?.fold<int>(0, (sum, s) => sum + s.unreadCount) ??
                  0)
            : 0,
      ),
      _NavigationItemData(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: t.titleMine,
        isStatusItem: true,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBody: true,
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: bottomBarIndex,
              onDestinationSelected: (index) {
                ref.read(bottomNavigationProvider.notifier).changeIndex(index);
                if (pageController.hasClients) {
                  pageController.jumpToPage(index);
                }
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              indicatorColor: AppColors.primary.withValues(alpha: 0.15),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 12,
              ),
              destinations: navigationItems.map((item) {
                return NavigationRailDestination(
                  icon: _buildNavigationIcon(
                    item,
                    false,
                    labelFontSize,
                    socketStatus,
                  ),
                  selectedIcon: _buildNavigationIcon(
                    item,
                    true,
                    labelFontSize,
                    socketStatus,
                  ),
                  label: Text(item.label),
                );
              }).toList(),
            ),
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: (index) {
                ref.read(bottomNavigationProvider.notifier).changeIndex(index);
              },
              physics: const NeverScrollableScrollPhysics(),
              children: pageList,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : GlassBottomNavigationBar(
              currentIndex: bottomBarIndex,
              onTap: (index) {
                ref.read(bottomNavigationProvider.notifier).changeIndex(index);
                if (pageController.hasClients) {
                  pageController.jumpToPage(index);
                }
              },
              items: navigationItems.map((item) {
                return GlassBottomBarItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  iconBuilder: (isSelected) => _buildNavigationIcon(
                    item,
                    isSelected,
                    labelFontSize,
                    socketStatus,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildNavigationIcon(
    _NavigationItemData item,
    bool isSelected,
    double labelFontSize,
    WebSocketConnectionState socketStatus,
  ) {
    if (item.isStatusItem) {
      return badges.Badge(
        showBadge: true,
        position: badges.BadgePosition.topStart(top: 2, start: 22),
        badgeStyle: badges.BadgeStyle(
          badgeColor: socketStatus == WebSocketConnectionState.connected
              ? AppColors.success
              : AppColors.messageFailed,
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: BorderSide(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceContainer
                    : Colors.white)
                : Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
        child: Icon(
          isSelected ? item.activeIcon : item.icon,
          size: 26,
          color: isSelected ? AppColors.primary : null,
        ),
      );
    }

    return badges.Badge(
      showBadge: item.remindCount > 0,
      position: badges.BadgePosition.topStart(top: -8, start: 20),
      badgeContent: Text(
        item.remindCount > 99 ? '99+' : item.remindCount.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: labelFontSize * 0.85,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w600,
        ),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: AppColors.messageFailed,
        borderRadius: AppRadius.borderRadiusMedium,
        elevation: 2,
      ),
      child: Icon(
        isSelected ? item.activeIcon : item.icon,
        size: 26,
        color: isSelected ? AppColors.primary : null,
      ),
    );
  }
}

class _NavigationItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int remindCount;
  final bool isStatusItem;

  _NavigationItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.remindCount = 0,
    this.isStatusItem = false,
  });
}
