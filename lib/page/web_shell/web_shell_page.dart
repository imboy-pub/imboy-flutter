/// Phase 1.1.h.2 — Web Shell 三栏整合 widget（无 i18n 依赖）
///
/// 把 1.1.a~m 的 11 个组件整合为可消费的入口 [WebShellPage]：
/// - 监听 [webShellProvider] 状态
/// - 用 [resolveShellLayout] 决定 mobile / twoColumn / threeColumn 分歧
/// - mobile（< 900px）→ 回退到 [mobileFallback]（调用方传入移动端 entry）
/// - twoColumn（900–1199px）→ 导航 + 列表/详情互斥，保留列表状态
/// - 宽屏消息保留三栏，个人页面使用完整主区，其余页面按选择展示详情
/// - 用 [buildWebNavItems] 工厂注入 4 个 nav items（label/badge 由调用方传入）
///
/// 设计原则（保持与 1.1.a~m 一致）：
/// - **无 i18n 依赖**：所有用户可见文案通过 props 注入（调用方负责 slang t.xxx 解析）
/// - **无业务依赖**：4 个 tab 内容 widget + 4 个 selection builder 由调用方传入
/// - **mobile fallback 解耦**：调用方传入移动端 entry（通常是 BottomNavigationPage），
///   避免本 widget 反向依赖 page 层
/// - **响应主题**：背景用 ColorScheme.surface
///
/// 注：本 slice 不修改 app_router / 其他业务代码。集成入路由是 1.1.i 切片的工作。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'web_shell.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

/// LAY-06：rail 显示位 ↔ tab 语义索引重排纯函数。
///
/// 频道项不可用（items 长度 3）时，rail 位 2 承载 tab 3（我的）；
/// 语义 tab 索引（WebShellState.currentTab 0..3）不因 rail 收窄而改变。
int railIndexForWebTab(int tab, bool channelAvailable) =>
    !channelAvailable && tab > kWebNavTabChannel ? tab - 1 : tab;

int webTabForRailIndex(int railIndex, bool channelAvailable) =>
    !channelAvailable && railIndex >= kWebNavTabChannel
    ? railIndex + 1
    : railIndex;

/// Web Shell 三栏整合页面
class WebShellPage extends ConsumerStatefulWidget {
  // === i18n 标签（由调用方注入 slang 解析后的字符串） ===

  /// Tab 0 标签（"消息" / "Messages"）
  final String tabMessageLabel;

  /// Tab 1 标签（"联系人" / "Contacts"）
  final String tabContactLabel;

  /// Tab 2 标签（"频道" / "Channels"）
  final String tabChannelLabel;

  /// Tab 3 标签（"我的" / "Me"）
  final String tabMineLabel;

  /// 欢迎屏标题（默认 selectedItem=null 时显示）
  final String welcomeTitle;

  /// 欢迎屏副标题（可选）
  final String? welcomeSubtitle;

  // === Tab 中栏内容（由调用方注入实际 page widget） ===

  final Widget messageTab;
  final Widget contactTab;
  final Widget channelTab;
  final Widget mineTab;

  // === 右栏 sealed selection builder（由调用方注入） ===

  final Widget Function(ChatSelection sel) chatBuilder;
  final Widget Function(ContactSelection sel) contactBuilder;
  final Widget Function(ChannelSelection sel) channelBuilder;
  final Widget Function(MineSelection sel) mineBuilder;

  // === Mobile fallback（< 900px 时渲染） ===

  /// 当浏览器宽度 < 900px 时降级渲染的 widget
  ///
  /// 通常调用方传入 `BottomNavigationPage()` 或类似移动端入口
  final Widget mobileFallback;

  /// Wrap the existing shared list content in the Browser mobile navigation.
  /// Native and legacy callers keep mobileFallback without this composition.
  final Widget Function(Widget content)? mobileFallbackBuilder;

  /// 侧栏顶部的全局入口，由业务接线层注入，不参与 tab 索引。
  final Widget? navigationLeading;

  // === 角标计数（可选，0 时不显示） ===

  /// 消息 Tab 未读数
  final int messageBadgeCount;

  /// 联系人 Tab 角标（如新好友请求数）
  final int contactBadgeCount;

  /// 频道 Tab 未读数
  final int channelBadgeCount;

  /// LAY-06：频道入口是否可用（feature 开关 + 频道页已编译）。
  /// false 时 rail 不渲染频道项（对齐原生条件渲染，消除死入口），
  /// rail 位 ↔ tab 语义索引经 [railIndexForWebTab]/[webTabForRailIndex] 重排。
  final bool channelTabAvailable;

  const WebShellPage({
    super.key,
    required this.tabMessageLabel,
    required this.tabContactLabel,
    required this.tabChannelLabel,
    required this.tabMineLabel,
    required this.welcomeTitle,
    this.welcomeSubtitle,
    required this.messageTab,
    required this.contactTab,
    required this.channelTab,
    required this.mineTab,
    required this.chatBuilder,
    required this.contactBuilder,
    required this.channelBuilder,
    required this.mineBuilder,
    required this.mobileFallback,
    this.mobileFallbackBuilder,
    this.navigationLeading,
    this.messageBadgeCount = 0,
    this.contactBadgeCount = 0,
    this.channelBadgeCount = 0,
    this.channelTabAvailable = true,
  });

  @override
  ConsumerState<WebShellPage> createState() => _WebShellPageState();

  Widget _buildShell(BuildContext context, WidgetRef ref, GlobalKey listKey) {
    final shellState = ref.watch(webShellProvider);
    final width = MediaQuery.of(context).size.width;
    final layout = resolveShellLayout(width);

    final mobile = layout == WebShellLayout.mobile;
    final canonicalWeb =
        kIsWeb &&
        GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ==
            '/web_shell';
    if (mobile && !canonicalWeb) return mobileFallback;

    // 构造 nav items（i18n + badge 通过工厂注入；LAY-06: channel-off 不生成频道项）
    final navItems = buildWebNavItems(
      messageLabel: tabMessageLabel,
      contactLabel: tabContactLabel,
      channelLabel: tabChannelLabel,
      mineLabel: tabMineLabel,
      messageBadgeCount: messageBadgeCount,
      contactBadgeCount: contactBadgeCount,
      channelBadgeCount: channelBadgeCount,
      channelAvailable: channelTabAvailable,
    );

    final notifier = ref.read(webShellProvider.notifier);

    // LAY-06：频道不可用时 tab2（深链 ?tab=channel 残留）不得停留——
    // 渲染帧先按消息 tab 呈现选中态，post-frame 守卫式治愈 state。
    final effectiveTab =
        !channelTabAvailable && shellState.currentTab == kWebNavTabChannel
        ? kWebNavTabMessage
        : shellState.currentTab;
    if (!channelTabAvailable && shellState.currentTab == kWebNavTabChannel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final current = ref.read(webShellProvider);
        if (current.currentTab == kWebNavTabChannel) {
          notifier.switchTab(kWebNavTabMessage);
        }
      });
    }

    return CupertinoPageScaffold(
      child: Row(
        children: [
          // 左栏：NavRail（72px）
          if (!mobile)
            WebNavRail(
              leading: navigationLeading,
              items: navItems,
              currentIndex: railIndexForWebTab(
                effectiveTab,
                channelTabAvailable,
              ),
              onTap: (railIndex) => notifier.switchTab(
                webTabForRailIndex(railIndex, channelTabAvailable),
              ),
            ),
          Expanded(
            key: const ValueKey('web-shell-content'),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = layout != WebShellLayout.threeColumn;
                final mine = effectiveTab == 3;
                final hasSelection = shellState.selectedItem != null;
                final showingDetail = hasSelection && (compact || mine);
                final showMain =
                    hasSelection || (effectiveTab == 0 && !compact);
                final listWidth = compact || mine || !showMain
                    ? constraints.maxWidth
                    : 360.0;
                final mainPanel = WebMainPanel(
                  selection: shellState.selectedItem,
                  welcome: WebWelcomePanel(
                    title: welcomeTitle,
                    subtitle: welcomeSubtitle,
                  ),
                  chatBuilder: chatBuilder,
                  contactBuilder: contactBuilder,
                  channelBuilder: channelBuilder,
                  mineBuilder: mineBuilder,
                );
                return ColoredBox(
                  key: const ValueKey('web-shell-page-background'),
                  color: mine
                      ? AppColors.getSurfaceGrouped(
                          Theme.of(context).brightness,
                        )
                      : AppColors.transparent,
                  child: Row(
                    children: [
                      Offstage(
                        offstage: showingDetail,
                        child: ExcludeFocus(
                          excluding: showingDetail,
                          child: TickerMode(
                            enabled: !showingDetail,
                            child: SizedBox(
                              width: listWidth,
                              child: Builder(
                                builder: (_) {
                                  final lists = WebMiddlePanel(
                                    key: listKey,
                                    width: listWidth,
                                    showDivider: showMain && !showingDetail,
                                    currentTab: effectiveTab,
                                    tabs: [
                                      messageTab,
                                      contactTab,
                                      channelTab,
                                      mineTab,
                                    ],
                                  );
                                  // The kept-alive tabs contain multiple route
                                  // heroes, including duplicate navigation bars.
                                  final scopedLists = HeroMode(
                                    enabled: false,
                                    child: lists,
                                  );
                                  return mobile
                                      ? (mobileFallbackBuilder?.call(
                                              scopedLists,
                                            ) ??
                                            mobileFallback)
                                      : scopedLists;
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showMain)
                        Expanded(
                          child: Column(
                            children: [
                              Visibility(
                                visible: showingDetail,
                                maintainState: true,
                                child: CupertinoNavigationBar(
                                  transitionBetweenRoutes: false,
                                  leading: CupertinoNavigationBarBackButton(
                                    onPressed: notifier.clearSelection,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: mine
                                    ? ResourcePageLayout(child: mainPanel)
                                    : mainPanel,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WebShellPageState extends ConsumerState<WebShellPage> {
  // State-local: AuthScope replacement disposes this key and its list tree.
  final GlobalKey _lists = GlobalKey();

  @override
  Widget build(BuildContext context) =>
      widget._buildShell(context, ref, _lists);
}
