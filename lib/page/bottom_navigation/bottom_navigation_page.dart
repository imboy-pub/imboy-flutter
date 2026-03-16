import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
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

  StreamSubscription? _localeSubscription;

  int _normalizeIndex(int value, {required bool channelEnabled}) {
    final maxIndex = channelEnabled ? 3 : 2;
    if (value < 0) {
      return 0;
    }
    if (value > maxIndex) {
      return maxIndex;
    }
    return value;
  }

  List<Widget> _buildPageList({required bool channelEnabled}) {
    return [
      const ConversationPage(),
      ContactPage(),
      if (channelEnabled) const ChannelListPage(),
      MinePage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    final channelEnabled = AppFeatureRegistry.isEnabled('channel');
    int initialIndex = 0;

    try {
      final routerState = GoRouterState.of(context);
      final indexParam = routerState.uri.queryParameters['index'];
      if (indexParam != null) {
        initialIndex = int.tryParse(indexParam) ?? 0;
      }
    } catch (_) {
      // 如果无法获取 go_router 状态，使用默认值
    }

    initialIndex = _normalizeIndex(
      initialIndex,
      channelEnabled: channelEnabled,
    );

    pageController = PageController(initialPage: initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(initialIndex);
      }
    });

    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    Future.microtask(() {
      ref.read(bottomNavigationProvider.notifier).changeIndex(initialIndex);
    });

    Future.microtask(() {
      ref.read(newFriendRemindProvider.notifier).countReminders();
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
    final channelEnabled = AppFeatureRegistry.isEnabled('channel');
    final pageList = _buildPageList(channelEnabled: channelEnabled);
    final labelFontSize = ThemeManager.instance.getFontSize(
      FontSizeType.small,
      context: context,
    );

    final rawBottomBarIndex = ref.watch(bottomNavigationProvider);
    final bottomBarIndex = _normalizeIndex(
      rawBottomBarIndex,
      channelEnabled: channelEnabled,
    );
    final newFriendCount = ref.watch(newFriendRemindProvider);
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
                  isSelected ? Icons.people_alt : Icons.people_alt_outlined,
                  size: 26,
                  color: isSelected ? AppColors.primary : null,
                ),
              );
            },
          ),
          if (channelEnabled)
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
