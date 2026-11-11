import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';

import 'dart:async';

import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/config/router/generated_product_feature_routes.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/service/websocket_status_provider.dart';
import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'bottom_navigation_provider.dart';

/// tab 下标越界时归一化到合法范围 [0, tabCount-1]。
@visibleForTesting
int normalizeIndex(int value, int tabCount) {
  return value.clamp(0, tabCount - 1);
}

/// 从路由 query 参数解析初始 tab 下标（越界/非法值归一到合法范围）。
///
/// 独立为纯函数以便单测覆盖「路由参数指定初始标签」与「越界归一化」，
/// 登录守卫保留个人标签 query；系统深链与冷启动链路仍需真机验收。
@visibleForTesting
int resolveInitialIndex(
  Map<String, String> queryParameters,
  int tabCount, {
  int fallback = 0,
  int? restoredIndex,
}) {
  if (restoredIndex != null) return normalizeIndex(restoredIndex, tabCount);
  final raw = queryParameters['index'];
  final index = raw == null ? fallback : (int.tryParse(raw) ?? 0);
  return normalizeIndex(index, tabCount);
}

/// 600–900pt 个人壳是否使用可折叠桌面导航。
///
/// macOS / Windows / Linux 与 Web 共用桌面交互；iOS / Android 平板继续使用
/// 既有 Material NavigationRail，避免把鼠标/键盘导向的折叠模式硬搬到移动端。
@visibleForTesting
bool shouldUseCollapsibleDesktopNavigation({
  required double width,
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final inRailRange =
      width >= AppBreakpoints.mobile && width < AppBreakpoints.wide;
  if (!inRailRange) return false;
  return usesDesktopNavigation(platform: platform, isWeb: isWeb);
}

class BottomNavigationPage extends ConsumerStatefulWidget {
  const BottomNavigationPage({super.key, this.restoredIndex});

  /// A live resize restores the active destination instead of replaying a
  /// previously consumed URL query. Ordinary entry still honors that query.
  final int? restoredIndex;

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

  double _pageOpacity = 1;
  Offset _pageOffset = Offset.zero;
  int _pageTransitionTicket = 0;

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
    return normalizeIndex(value, _buildPageList().length);
  }

  List<Widget> _buildPageList({bool useRail = false}) {
    final channelPage = compiledChannelListPage();
    return [
      // 有侧栏时空间入口全局常驻，消息头不再重复。
      ConversationPage(
        leading: useRail ? null : const PersonalShellDrawerAvatarButton(),
      ),
      ContactPage(),
      if (_isTabEnabled('channel_tab') && channelPage != null) channelPage,
      MinePage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    // 普通入口在 didChangeDependencies 解析路由初值；跨断点先恢复控制器，
    // 避免恢复帧短暂显示消息页。GoRouterState.of 依赖 InheritedWidget，
    // 仍不能在 initState 中读取。
    pageController = PageController(initialPage: widget.restoredIndex ?? 0);

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

    final navigationBeforeRestore = ref.read(bottomNavigationProvider);
    int initialIndex = _normalizeIndex(
      widget.restoredIndex ?? navigationBeforeRestore,
    );

    try {
      final routerState = GoRouterState.of(context);
      initialIndex = resolveInitialIndex(
        routerState.uri.queryParameters,
        _buildPageList().length,
        fallback: initialIndex,
        restoredIndex: widget.restoredIndex,
      );
    } catch (e) {
      // 非 GoRouter 上下文时使用默认值
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentIndex = ref.read(bottomNavigationProvider);
      if (widget.restoredIndex != null &&
          currentIndex != navigationBeforeRestore &&
          currentIndex != initialIndex) {
        return;
      }
      if (pageController.hasClients) {
        pageController.jumpToPage(initialIndex);
      }
      if (widget.restoredIndex == null || currentIndex != initialIndex) {
        ref.read(bottomNavigationProvider.notifier).changeIndex(initialIndex);
      }
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

  void _transitionToPage(int target) {
    if (!pageController.hasClients) return;
    final current = pageController.page?.round() ?? target;
    if (current == target) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      pageController.jumpToPage(target);
      return;
    }

    final ticket = ++_pageTransitionTicket;
    setState(() {
      _pageOpacity = 0.96;
      _pageOffset = Offset(current < target ? 0.012 : -0.012, 0);
    });
    pageController.jumpToPage(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ticket != _pageTransitionTicket) return;
      setState(() {
        _pageOpacity = 1;
        _pageOffset = Offset.zero;
      });
    });
  }

  Color _connectionStatusColor(WebSocketConnectionState socketStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (socketStatus) {
      WebSocketConnectionState.connected =>
        isDark ? AppColors.iosGreenDark : AppColors.iosGreen,
      WebSocketConnectionState.connecting =>
        isDark ? AppColors.iosOrangeDark : AppColors.iosOrange,
      WebSocketConnectionState.disconnected =>
        isDark ? AppColors.iosRedDark : AppColors.iosRed,
    };
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(featureRevisionProvider);
    final t = context.t;
    // channelEnabled 控制会话列表顶部频道置顶区显示（Slice-5 接线）
    final channelEnabled = AppFeatureRegistry.isEnabled(FeatureKeys.channel);

    final rawBottomBarIndex = ref.watch(bottomNavigationProvider);
    final bottomBarIndex = _normalizeIndex(rawBottomBarIndex);
    final socketStatusAsync = ref.watch(webSocketStatusProvider);
    final socketStatus =
        socketStatusAsync.value ?? WebSocketConnectionState.disconnected;

    // 只取宽度：MediaQuery.sizeOf 不会因为键盘内边距/方向以外的无关
    // MediaQueryData 变化（例如 viewInsets 抖动）而重建整个壳层。
    final width = MediaQuery.sizeOf(context).width;
    // 600–900pt 为 rail 布局；桌面/Web 用共享可折叠导航，移动平板
    // 保留既有 Material NavigationRail。
    final isRailLayout =
        width >= AppBreakpoints.mobile && width < AppBreakpoints.wide;
    final useCollapsibleDesktopRail = shouldUseCollapsibleDesktopNavigation(
      width: width,
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
    );
    final pageList = _buildPageList(useRail: isRailLayout);

    ref.listen(bottomNavigationProvider, (_, index) {
      _transitionToPage(_normalizeIndex(index));
    });

    if (rawBottomBarIndex != bottomBarIndex) {
      Future.microtask(() {
        if (!mounted ||
            ref.read(bottomNavigationProvider) != rawBottomBarIndex) {
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
        // 只订阅「未读总数」这个标量：历史上这里是
        // `ref.watch(conversationProvider)`，导致任意会话状态变化（收到消息、
        // isLoading / connectDesc 翻转）都会重建整个底部导航壳层及其 PageView
        // 子页。select 之后仅在未读数真的变化时才重建。
        remindCount: ref.watch(
          conversationProvider.select((s) => s.chatMsgRemindCounter),
        ),
        tabKey: const Key('tab_conversations'),
      ),
      _NavigationItemData(
        icon: CupertinoIcons.person_2,
        activeIcon: CupertinoIcons.person_2_fill,
        label: t.organization.directory.title,
        remindCount: ref.watch(newFriendRemindProvider.select((s) => s.length)),
        tabKey: const Key('tab_contacts'),
      ),
      if (_isTabEnabled('channel_tab') && compiledChannelListPage() != null)
        _NavigationItemData(
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          activeIcon: CupertinoIcons.antenna_radiowaves_left_right,
          label: t.channel.title,
          remindCount: channelEnabled ? compiledChannelUnreadCount(ref) : 0,
          tabKey: const Key('tab_channel'),
        ),
      _NavigationItemData(
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: t.common.me,
        isStatusItem: true,
        tabKey: const Key('tab_mine'),
      ),
    ];

    void selectDestination(int index) {
      ref.read(bottomNavigationProvider.notifier).changeIndex(index);
    }

    final pageTransitionDuration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.fast,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        extendBody: true,
        body: Row(
          children: [
            if (useCollapsibleDesktopRail)
              WebNavRail(
                key: const ValueKey('personal-shell-rail'),
                leading: const PersonalShellDrawerAvatarButton(inRail: true),
                items: navigationItems
                    .map(
                      (item) => WebNavItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        label: item.label,
                        badgeCount: item.remindCount,
                        statusColor: item.isStatusItem
                            ? _connectionStatusColor(socketStatus)
                            : null,
                        controlKey: item.tabKey,
                      ),
                    )
                    .toList(growable: false),
                currentIndex: bottomBarIndex,
                onTap: selectDestination,
              )
            else if (isRailLayout)
              NavigationRail(
                key: const ValueKey('personal-shell-rail'),
                leading: const PersonalShellDrawerAvatarButton(inRail: true),
                scrollable: true,
                selectedIndex: bottomBarIndex,
                onDestinationSelected: selectDestination,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerLow,
                indicatorColor: AppColors.primaryAlpha20,
                selectedLabelTextStyle: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: context.textStyle(
                  FontSizeType.small,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                destinations: navigationItems.map((item) {
                  return NavigationRailDestination(
                    icon: _buildNavigationIcon(item, false, socketStatus),
                    selectedIcon: _buildNavigationIcon(
                      item,
                      true,
                      socketStatus,
                    ),
                    label: Text(item.label),
                  );
                }).toList(),
              ),
            Expanded(
              child: AnimatedSlide(
                duration: pageTransitionDuration,
                curve: Curves.easeOutCubic,
                offset: _pageOffset,
                child: AnimatedOpacity(
                  duration: pageTransitionDuration,
                  curve: Curves.easeOutCubic,
                  opacity: _pageOpacity,
                  child: PageView(
                    controller: pageController,
                    onPageChanged: (index) {
                      ref
                          .read(bottomNavigationProvider.notifier)
                          .changeIndex(index);
                    },
                    physics: const NeverScrollableScrollPhysics(),
                    children: pageList,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isRailLayout
            ? null
            : GlassBottomNavigationBar(
                currentIndex: bottomBarIndex,
                onTap: selectDestination,
                items: navigationItems.map((item) {
                  return GlassBottomBarItem(
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    label: item.label,
                    tabKey: item.tabKey,
                    iconBuilder: (isSelected) =>
                        _buildNavigationIcon(item, isSelected, socketStatus),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildNavigationIcon(
    _NavigationItemData item,
    bool isSelected,
    WebSocketConnectionState socketStatus,
  ) {
    Widget icon = Icon(
      isSelected ? item.activeIcon : item.icon,
      size: AppSizes.iconSizeMedium,
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );

    if (item.isStatusItem) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return BadgeWidget(
        color: _connectionStatusColor(socketStatus),
        padding: AppSpacing.allTiny,
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
        semanticLabel: context.t.common.unreadCount(
          count: '${item.remindCount}',
        ),
        content: Text(
          item.remindCount > 99 ? '99+' : '${item.remindCount}',
          style: context
              .textStyle(
                FontSizeType.tiny,
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
              )
              .copyWith(fontFeatures: [FontFeature.tabularFigures()]),
        ),
        color: AppColors.getIosRed(Theme.of(context).brightness),
        padding: AppSpacing.allTiny,
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

/// 保留既有个人入口与回调契约，容器由共享空间入口按壳布局选择。
class PersonalShellDrawerAvatarButton extends ConsumerWidget {
  const PersonalShellDrawerAvatarButton({
    super.key,
    this.onTap,
    this.inRail = false,
  });

  final VoidCallback? onTap;
  final bool inRail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpaceSwitcherButton(
      key: const ValueKey('personal-shell-drawer-avatar'),
      onTap: onTap,
      inRail: inRail,
    );
  }
}
