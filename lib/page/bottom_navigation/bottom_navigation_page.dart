import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/moment_social/public.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
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

  // 固定 3 Tab：消息 / 广场 / 我的
  int _normalizeIndex(int value) {
    return value.clamp(0, 2);
  }

  List<Widget> _buildPageList() {
    return [
      const ConversationPage(),
      const MomentFeedPage(),
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
    } on Exception {
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
    // ignore: unused_local_variable
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBody: true,
      body: PageView(
        controller: pageController,
        onPageChanged: (index) {
          ref.read(bottomNavigationProvider.notifier).changeIndex(index);
        },
        physics: const NeverScrollableScrollPhysics(),
        children: pageList,
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
              final conversationState = ref.watch(conversationProvider);
              final chatRemindCount = conversationState.chatMsgRemindCounter;
              return badges.Badge(
                showBadge: chatRemindCount > 0,
                position: badges.BadgePosition.topStart(top: -8, start: 20),
                badgeContent: Text(
                  chatRemindCount > 99 ? '99+' : chatRemindCount.toString(),
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
                  isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  size: 26,
                  color: isSelected ? AppColors.primary : null,
                ),
              );
            },
          ),
          // 广场 Tab（朋友圈 Feed）
          GlassBottomBarItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: t.titleSquare,
            iconBuilder: (isSelected) => Icon(
              isSelected ? Icons.explore : Icons.explore_outlined,
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
              position: badges.BadgePosition.topStart(top: 2, start: 22),
              badgeStyle: badges.BadgeStyle(
                badgeColor: socketStatus == WebSocketConnectionState.connected
                    ? AppColors.success
                    : AppColors.messageFailed,
                borderRadius: AppRadius.borderRadiusSmall,
                borderSide: BorderSide(
                  color: isSelected
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white)
                      : Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
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
