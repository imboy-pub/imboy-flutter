import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'dart:async';

import 'package:imboy/component/ui/badge_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart'
    show subscribedChannelStripProvider;
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/service/websocket_status_provider.dart';
import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'bottom_navigation_provider.dart';

class BottomNavigationPage extends ConsumerStatefulWidget {
  const BottomNavigationPage({super.key});

  @override
  ConsumerState<BottomNavigationPage> createState() =>
      _BottomNavigationPageState();
}

class _BottomNavigationPageState extends ConsumerState<BottomNavigationPage> {
  late final PageController pageController;

  StreamSubscription<dynamic>? _localeSubscription;

  /// 是否已根据 GoRouter 的 query 参数初始化过 index
  /// GoRouterState.of(context) 必须在 initState 之后调用（依赖 InheritedWidget）
  bool _initialIndexApplied = false;

  bool _isTabEnabled(String entry) {
    if (entry == 'channel_tab') {
      return AppFeatureRegistry.isEnabled(FeatureKeys.channel);
    }
    final manifest = AppManifestService.manifest;
    if (manifest != null) {
      return manifest.hasAppEntry(entry);
    }
    return true;
  }

  int _normalizeIndex(int value) {
    return value.clamp(0, _buildPageList().length - 1);
  }

  List<Widget> _buildPageList() {
    return [
      const ConversationPage(),
      ContactPage(),
      if (_isTabEnabled('channel_tab')) const ChannelListPage(),
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
      _maybeShowE2EERecoveryGuide();
    });
  }

  /// 登录后首屏检查：若上次登录在本地新生成了 E2EE 密钥（换设备/重装），
  /// 弹出一次密钥恢复引导，随后清除标记避免重复打扰。
  void _maybeShowE2EERecoveryGuide() {
    final pending =
        StorageService.to.getBool(kE2eeNewDeviceGuidePendingKey) ?? false;
    if (!pending) return;
    // 一次性消费：先清标记，弹窗仅作引导，不阻塞主流程。
    unawaited(StorageService.to.setBool(kE2eeNewDeviceGuidePendingKey, false));
    if (!mounted) return;
    unawaited(
      showE2EERecoveryGuide(context, scene: E2EERecoveryScene.newDevice),
    );
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
    final channelEnabled = AppFeatureRegistry.isEnabled(FeatureKeys.channel);
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
        icon: CupertinoIcons.chat_bubble,
        activeIcon: CupertinoIcons.chat_bubble_fill,
        label: t.chat.titleMessage,
        remindCount: ref.watch(conversationProvider).chatMsgRemindCounter,
        tabKey: const Key('tab_conversations'),
      ),
      _NavigationItemData(
        icon: CupertinoIcons.person_2,
        activeIcon: CupertinoIcons.person_2_fill,
        label: t.common.titleContact,
        remindCount: ref.watch(newFriendRemindProvider).length,
        tabKey: const Key('tab_contacts'),
      ),
      if (_isTabEnabled('channel_tab'))
        _NavigationItemData(
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          activeIcon: CupertinoIcons.antenna_radiowaves_left_right,
          label: t.channel.title,
          remindCount: channelEnabled
              ? (ref
                        .watch(subscribedChannelStripProvider)
                        .value
                        ?.fold<int>(0, (sum, s) => sum + s.unreadCount) ??
                    0)
              : 0,
          tabKey: const Key('tab_channel'),
        ),
      _NavigationItemData(
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: t.main.titleMine,
        isStatusItem: true,
        tabKey: const Key('tab_mine'),
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLow,
              indicatorColor: AppColors.primary.withValues(alpha: 0.15),
              selectedLabelTextStyle: TextStyle(
                color: AppColors.primary,
                fontSize: FontSizeType.small.size,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: FontSizeType.small.size,
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
                  tabKey: item.tabKey,
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
    Widget icon = Icon(
      isSelected ? item.activeIcon : item.icon,
      size: 26,
      color: isSelected ? AppColors.primary : AppColors.iosGray,
    );

    if (item.isStatusItem) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      // 三态指示：绿=已连接，橙=重连/连接中，红=已断开
      // 暗色模式下使用 *Dark 变体保持 iOS HIG 推荐的对比度
      final Color badgeColor = switch (socketStatus) {
        WebSocketConnectionState.connected =>
          isDark ? AppColors.iosGreenDark : AppColors.iosGreen,
        WebSocketConnectionState.connecting =>
          isDark ? AppColors.iosOrangeDark : AppColors.iosOrange,
        WebSocketConnectionState.disconnected =>
          isDark ? AppColors.iosRedDark : AppColors.iosRed,
      };
      return BadgeWidget(
        color: badgeColor,
        padding: const EdgeInsets.all(4),
        borderSide: BorderSide(
          color: isSelected
              ? (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface)
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          width: 1.5,
        ),
        top: 0,
        right: 0,
        child: icon,
      );
    }

    if (item.remindCount > 0) {
      return BadgeWidget(
        content: Text(
          item.remindCount > 99 ? '99+' : '${item.remindCount}',
          style: TextStyle(
            color: Colors.white,
            fontSize: FontSizeType.tiny.size,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        color: AppColors.iosRed,
        padding: const EdgeInsets.all(4),
        child: icon,
      );
    }

    return icon;
  }
}

class _NavigationItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int remindCount;
  final bool isStatusItem;
  final Key? tabKey;

  _NavigationItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.remindCount = 0,
    this.isStatusItem = false,
    this.tabKey,
  });
}
