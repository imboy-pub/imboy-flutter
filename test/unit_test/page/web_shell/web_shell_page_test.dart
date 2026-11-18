/// Phase 1.1.h.2 — Web Shell 整合 widget 测试
///
/// 覆盖：
/// - mobile fallback (< 900px)
/// - twoColumn 列表/详情切换与 threeColumn 三栏渲染
/// - tab 切换联动 (NavRail.onTap → webShellProvider.switchTab)
/// - selection 渲染（null=welcome / chat / contact / channel / mine）
/// - i18n label 透传到 navItems
/// - badge 透传
library;

import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'fixtures/chat_input_io_fence.dart';
import 'fixtures/text_send_fixture.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell.dart';

import '../../helper/material_tooltip_finder.dart';

const _kMobile = Material(
  key: ValueKey('mobile-fallback'),
  child: Center(child: Text('MOBILE')),
);

const _kMessageTab = Center(key: ValueKey('msg-tab'), child: Text('MSG_TAB'));
const _kContactTab = Center(
  key: ValueKey('contact-tab'),
  child: Text('CON_TAB'),
);
const _kChannelTab = Center(
  key: ValueKey('channel-tab'),
  child: Text('CH_TAB'),
);
const _kMineTab = Center(key: ValueKey('mine-tab'), child: Text('MINE_TAB'));

Widget _chatBuilder(ChatSelection sel) => Center(
  key: const ValueKey('chat-panel'),
  child: Text('CHAT:${sel.peerId}'),
);
Widget _contactBuilder(ContactSelection sel) => Center(
  key: const ValueKey('contact-panel'),
  child: Text('CONT:${sel.uid}'),
);
Widget _channelBuilder(ChannelSelection sel) => Center(
  key: const ValueKey('channel-panel'),
  child: Text('CHA:${sel.channelId}'),
);
Widget _mineBuilder(MineSelection sel) => Center(
  key: const ValueKey('mine-panel'),
  child: Text('MINE:${sel.section ?? "ov"}'),
);

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(1400, 800),
  int messageBadgeCount = 0,
  int contactBadgeCount = 0,
  int channelBadgeCount = 0,
  String welcomeTitle = 'Welcome',
  String? welcomeSubtitle,
  Widget? navigationLeading,
  Widget messageTab = _kMessageTab,
  Widget Function(ChatSelection)? chatBuilder,
  bool canonicalRoute = false,
  bool channelTabAvailable = true,
}) async {
  // MediaQuery.of(context).size 读 view.physicalSize / view.devicePixelRatio，
  // setSurfaceSize 不影响 MediaQuery — 必须直接设 view.physicalSize（按 DPR 放大）
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size; // DPR=1 时 physical == logical
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = ProviderContainer();
  addTearDown(container.dispose);
  // 保活订阅，避免 auto-dispose（Riverpod 3 测试陷阱）
  container.listen(webShellProvider, (_, _) {});

  final shell = WebShellPage(
    tabMessageLabel: 'Messages',
    tabContactLabel: 'Contacts',
    tabChannelLabel: 'Channels',
    tabMineLabel: 'Me',
    welcomeTitle: welcomeTitle,
    welcomeSubtitle: welcomeSubtitle,
    messageTab: messageTab,
    contactTab: _kContactTab,
    channelTab: _kChannelTab,
    mineTab: _kMineTab,
    chatBuilder: chatBuilder ?? _chatBuilder,
    contactBuilder: _contactBuilder,
    channelBuilder: _channelBuilder,
    mineBuilder: _mineBuilder,
    mobileFallback: _kMobile,
    mobileFallbackBuilder: canonicalRoute ? (content) => content : null,
    navigationLeading: navigationLeading,
    messageBadgeCount: messageBadgeCount,
    contactBadgeCount: contactBadgeCount,
    channelBadgeCount: channelBadgeCount,
    channelTabAvailable: channelTabAvailable,
  );
  final router = canonicalRoute
      ? GoRouter(
          initialLocation: '/web_shell',
          routes: [GoRoute(path: '/web_shell', builder: (_, _) => shell)],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: router == null
          ? MaterialApp(home: shell)
          : MaterialApp.router(routerConfig: router),
    ),
  );
  return container;
}

void main() {
  group('A02 first contact message', () {
    late ChatInputIoFence fence;
    setUp(() => fence = ChatInputIoFence()..install());
    tearDown(() => fence.verifyAndRestore());
    isolatedChatInputTestWidgets(
      'A02 empty action opens contact and sends first C2C',
      (tester) => _a02FirstSend(tester),
    );
  });
  group('approved page-specific columns', () {
    for (final width in [
      if (kIsWeb) 390.0,
      900.0,
      1024.0,
      1199.0,
      1200.0,
      1400.0,
    ]) {
      testWidgets(
        'Mine uses full main region and bounded resources at $width',
        (tester) async {
          final container = await _pumpShell(
            tester,
            size: Size(width, 800),
            canonicalRoute: kIsWeb,
          );
          container.read(webShellProvider.notifier).switchTab(3);
          await tester.pumpAndSettle();
          final list = find.byType(WebMiddlePanel);
          final element = tester.element(list);
          expect(find.byType(WebMainPanel), findsNothing);
          expect(find.text('Welcome'), findsNothing);
          final content = tester.getRect(
            find.byKey(const ValueKey('web-shell-content')),
          );
          final bounds = tester.getRect(list);
          expect(bounds.width, closeTo(content.width, 1));
          expect(tester.widget<WebMiddlePanel>(list).showDivider, isFalse);
          final background = find.byKey(
            const ValueKey('web-shell-page-background'),
          );
          expect(tester.getRect(background), content);
          expect(
            tester.widget<ColoredBox>(background).color,
            AppColors.getSurfaceGrouped(
              Theme.of(tester.element(background)).brightness,
            ),
          );
          expect(bounds.center.dx, closeTo(content.center.dx, 1));
          container
              .read(webShellProvider.notifier)
              .selectItem(const MineSelection(section: 'settings'));
          await tester.pumpAndSettle();
          expect(find.byType(WebMiddlePanel), findsNothing);
          expect(
            tester.element(find.byType(WebMiddlePanel, skipOffstage: false)),
            same(element),
          );
          expect(find.text('MINE:settings'), findsOneWidget);
          final panel = tester.getRect(
            find.byKey(const ValueKey('mine-panel')),
          );
          expect(panel.width, lessThanOrEqualTo(ResourcePageLayout.maxWidth));
          expect(panel.center.dx, closeTo(content.center.dx, 1));
          expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
          await tester.tap(find.byType(CupertinoNavigationBarBackButton));
          await tester.pumpAndSettle();
          expect(container.read(webShellProvider).selectedItem, isNull);
          expect(tester.element(list), same(element));
          expect(find.text('Welcome'), findsNothing);
          container
              .read(webShellProvider.notifier)
              .selectItem(const MineSelection(section: 'profile'));
          await tester.pumpAndSettle();
          expect(find.text('MINE:profile'), findsOneWidget);
          expect(find.byType(WebMiddlePanel), findsNothing);
          expect(
            tester.getSize(find.byKey(const ValueKey('mine-panel'))).width,
            lessThanOrEqualTo(ResourcePageLayout.maxWidth),
          );
          expect(tester.takeException(), isNull);
        },
      );
      for (final tab in [1, 2]) {
        testWidgets('tab$tab only splits on actual selection at $width', (
          tester,
        ) async {
          final container = await _pumpShell(
            tester,
            size: Size(width, 800),
            canonicalRoute: kIsWeb,
          );
          container.read(webShellProvider.notifier).switchTab(tab);
          await tester.pumpAndSettle();
          final list = find.byType(WebMiddlePanel);
          final element = tester.element(list);
          final content = tester.getRect(
            find.byKey(const ValueKey('web-shell-content')),
          );
          expect(tester.getSize(list).width, closeTo(content.width, 1));
          expect(find.byType(WebMainPanel), findsNothing);
          expect(find.text('Welcome'), findsNothing);
          container
              .read(webShellProvider.notifier)
              .selectItem(
                tab == 1
                    ? const ContactSelection(uid: '123411316393379840')
                    : const ChannelSelection(channelId: '123411316393379841'),
              );
          await tester.pumpAndSettle();
          expect(find.byType(WebMainPanel), findsOneWidget);
          expect(
            tester.element(find.byType(WebMiddlePanel, skipOffstage: false)),
            same(element),
          );
          if (width >= 1200) {
            expect(tester.getSize(list).width, 360);
          } else {
            expect(list, findsNothing);
            await tester.tap(find.byType(CupertinoNavigationBarBackButton));
            await tester.pumpAndSettle();
          }
          container.read(webShellProvider.notifier).clearSelection();
          await tester.pumpAndSettle();
          expect(tester.element(list), same(element));
          expect(tester.getSize(list).width, closeTo(content.width, 1));
          expect(find.byType(WebMainPanel), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('WebShellPage — mobile fallback (< 900px)', () {
    testWidgets('width 320 → 渲染 mobileFallback', (tester) async {
      await _pumpShell(tester, size: const Size(320, 700));
      expect(find.byKey(const ValueKey('mobile-fallback')), findsOneWidget);
      expect(find.text('MOBILE'), findsOneWidget);
      // 三栏不应渲染
      expect(find.byType(WebNavRail), findsNothing);
      expect(find.byType(WebMiddlePanel), findsNothing);
      expect(find.byType(WebMainPanel), findsNothing);
    });

    testWidgets('width 899.99 → mobile (边界)', (tester) async {
      await _pumpShell(tester, size: const Size(899, 700));
      expect(find.byKey(const ValueKey('mobile-fallback')), findsOneWidget);
    });
  });

  group('WebShellPage — threeColumn (>= 900px)', () {
    testWidgets('全局入口在所有 tab 保留且不占导航索引', (tester) async {
      var opened = 0;
      const key = ValueKey('global-space-entry');
      final container = await _pumpShell(
        tester,
        navigationLeading: CupertinoButton(
          key: key,
          onPressed: () => opened++,
          child: const Text('Space'),
        ),
      );
      final entry = find.byKey(key);
      expect(
        find.descendant(of: find.byType(WebNavRail), matching: entry),
        findsOneWidget,
      );
      await tester.tap(entry);
      expect(opened, 1);
      expect(container.read(webShellProvider).currentTab, 0);
      for (var index = 1; index < 4; index++) {
        tester.widget<WebNavRail>(find.byType(WebNavRail)).onTap(index);
        await tester.pump();
        expect(entry, findsOneWidget);
        expect(container.read(webShellProvider).currentTab, index);
      }
      expect(findMaterialTooltip('Me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('width 1400 → 渲染 NavRail + MiddlePanel + MainPanel', (
      tester,
    ) async {
      await _pumpShell(tester, size: const Size(1400, 800));
      expect(find.byType(WebNavRail), findsOneWidget);
      expect(find.byType(WebMiddlePanel), findsOneWidget);
      expect(find.byType(WebMainPanel), findsOneWidget);
      // mobile fallback 不应渲染
      expect(find.byKey(const ValueKey('mobile-fallback')), findsNothing);
    });

    testWidgets('默认 currentTab=0 → 渲染 messageTab + welcome', (tester) async {
      await _pumpShell(tester, size: const Size(1400, 800));
      // skipOffstage:false 因为 IndexedStack 隐藏其他 tab
      expect(
        find.byKey(const ValueKey('msg-tab'), skipOffstage: false),
        findsOneWidget,
      );
      // welcome 应可见（默认 selection=null）
      expect(find.text('Welcome'), findsOneWidget);
    });

    for (final width in [899.0, 900.0, 901.0, 1199.0, 1200.0, 1201.0]) {
      testWidgets('actual layout at $width', (tester) async {
        final container = await _pumpShell(tester, size: Size(width, 800));
        if (width < 900) {
          expect(find.byKey(const ValueKey('mobile-fallback')), findsOneWidget);
          return;
        }
        expect(find.byType(WebNavRail), findsOneWidget);
        expect(find.byType(WebMiddlePanel), findsOneWidget);
        expect(
          find.byType(WebMainPanel),
          width < 1200 ? findsNothing : findsOneWidget,
        );
        container
            .read(webShellProvider.notifier)
            .selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
        await tester.pump();
        expect(find.byType(WebMainPanel), findsOneWidget);
        expect(
          find.byType(WebMiddlePanel),
          width < 1200 ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'detail draft survives resizing across 1200 in both directions',
      (tester) async {
        const key = ValueKey('detail-draft');
        final container = await _pumpShell(
          tester,
          size: const Size(1199, 800),
          chatBuilder: (_) => const CupertinoTextField(key: key),
        );
        container
            .read(webShellProvider.notifier)
            .selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
        await tester.pump();
        await tester.enterText(find.byKey(key), 'unsent draft');
        final element = tester.element(find.byKey(key));
        for (final width in [1200.0, 1199.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pump();
          expect(tester.element(find.byKey(key)), same(element));
          expect(find.text('unsent draft'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('two columns retain list draft and exclude hidden focus', (
      tester,
    ) async {
      const fieldKey = ValueKey('list-search');
      const spaceKey = ValueKey('space-entry');
      final container = await _pumpShell(
        tester,
        size: const Size(1024, 800),
        messageTab: const CupertinoTextField(key: fieldKey),
        navigationLeading: const Text('SPACE', key: spaceKey),
      );
      await tester.enterText(find.byKey(fieldKey), 'saved query');
      final listElement = tester.element(find.byKey(fieldKey));
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
      await tester.pump();
      expect(find.byKey(fieldKey), findsNothing);
      expect(find.byKey(spaceKey), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.byType(EditableText, skipOffstage: false),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pump();
      expect(tester.element(find.byKey(fieldKey)), same(listElement));
      expect(find.text('saved query'), findsOneWidget);
      expect(container.read(webShellProvider).selectedItem, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('WebShellPage — i18n label 透传', () {
    testWidgets('NavRail items 用调用方传入的 label（Tooltip 验证）', (tester) async {
      await _pumpShell(tester, size: const Size(1400, 800));
      expect(findMaterialTooltip('Messages'), findsOneWidget);
      expect(findMaterialTooltip('Contacts'), findsOneWidget);
      expect(findMaterialTooltip('Channels'), findsOneWidget);
      expect(findMaterialTooltip('Me'), findsOneWidget);
    });

    testWidgets('welcome title 渲染', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(1400, 800),
        welcomeTitle: '欢迎使用',
        welcomeSubtitle: '选一个会话开始',
      );
      expect(find.text('欢迎使用'), findsOneWidget);
      expect(find.text('选一个会话开始'), findsOneWidget);
    });
  });

  // LAY-06：channel-off profile 下桌面 rail 不得出现死入口；索引重排对齐
  // 原生 bottom_navigation（隐藏频道目的地）与移动 fallback（mine3→位2）。
  group('WebShellPage — channelTabAvailable=false（LAY-06）', () {
    testWidgets('rail 不渲染频道入口，其余 3 项保留', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(1400, 800),
        channelTabAvailable: false,
      );

      // 并集修复：合并后 WebNavRail 用 material_ui.Tooltip（main 形态），
      // SDK find.byTooltip 只认 flutter/material 的 Tooltip，须走 findMaterialTooltip。
      expect(
        findMaterialTooltip('Channels'),
        findsNothing,
        reason: 'channel-off 下 rail 显示频道项即死入口',
      );
      expect(findMaterialTooltip('Messages'), findsOneWidget);
      expect(findMaterialTooltip('Contacts'), findsOneWidget);
      expect(findMaterialTooltip('Me'), findsOneWidget);
    });

    testWidgets('rail 位 2（Me）重排到 tab 3，而不是误入频道 tab', (tester) async {
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
        channelTabAvailable: false,
      );

      tester.widget<WebNavRail>(find.byType(WebNavRail)).onTap(2);
      await tester.pumpAndSettle();

      expect(
        container.read(webShellProvider).currentTab,
        3,
        reason: '隐藏频道后 rail 第 3 项是"我的"(tab3)，不得映射到 tab2',
      );
      expect(find.text('MINE_TAB', skipOffstage: false), findsOneWidget);
      // rail 高亮同步重排：tab3 → rail 位 2
      expect(
        tester.widget<WebNavRail>(find.byType(WebNavRail)).currentIndex,
        2,
      );
    });

    testWidgets('currentTab=2 残留（深链 ?tab=channel）在 channel-off 下治愈为消息', (
      tester,
    ) async {
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
        channelTabAvailable: false,
      );
      container
          .read(webShellProvider.notifier)
          .replaceState(const WebShellState(currentTab: 2));
      await tester.pumpAndSettle();

      expect(
        container.read(webShellProvider).currentTab,
        0,
        reason: '频道不可用时不得停留在空频道 tab（死胡同）',
      );
      expect(findMaterialTooltip('Messages'), findsOneWidget);
    });

    testWidgets('WebShellBootstrap 在 channel-off profile 下关闭 rail 频道入口', (
      tester,
    ) async {
      final flags = Map<String, dynamic>.from(AppFeatureRegistry.snapshot);
      addTearDown(() => AppFeatureRegistry.replaceSnapshotForTest(flags));
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});

      late WebShellPage shell;
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  // 构造真实生产 producer 但不挂载业务页（DB/网络），
                  // 只检查 bootstrap 注入的公共参数（模式对齐 web_shell_route_test）。
                  shell = const WebShellBootstrap().build(
                    context,
                    ref,
                  ) as WebShellPage;
                  return const SizedBox(key: ValueKey('bootstrap-probe'));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        shell.channelTabAvailable,
        isFalse,
        reason: 'bootstrap 必须按 personalChannelTabAvailable() 注入 rail 可用性',
      );
    });
  });

  group('WebShellPage — Tab 切换联动', () {
    testWidgets('点击 NavRail tab 1 → currentTab=1，渲染 contactTab', (
      tester,
    ) async {
      final container = await _pumpShell(tester, size: const Size(1400, 800));
      // 点击 NavRail 的第二项（联系人）
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      expect(container.read(webShellProvider).currentTab, 1);
      // 切换后 IndexedStack 显示 contactTab
      expect(
        find.byKey(const ValueKey('contact-tab'), skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('WebShellPage — selection 渲染右栏', () {
    testWidgets('selection=null → welcome 显示', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(1400, 800),
        welcomeTitle: 'WelcomeText',
      );
      expect(find.text('WelcomeText'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-panel')), findsNothing);
    });

    testWidgets('ChatSelection → chatBuilder 渲染', (tester) async {
      final container = await _pumpShell(tester, size: const Size(1400, 800));
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-panel')), findsOneWidget);
      expect(find.text('CHAT:p1'), findsOneWidget);
    });

    testWidgets('ContactSelection → contactBuilder 渲染', (tester) async {
      final container = await _pumpShell(tester, size: const Size(1400, 800));
      container
          .read(webShellProvider.notifier)
          .selectItem(const ContactSelection(uid: 'u1'));
      await tester.pump();

      expect(find.byKey(const ValueKey('contact-panel')), findsOneWidget);
      expect(find.text('CONT:u1'), findsOneWidget);
    });

    testWidgets('clearSelection → 回欢迎屏', (tester) async {
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
        welcomeTitle: 'WelcomeText',
      );
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-panel')), findsOneWidget);

      container.read(webShellProvider.notifier).clearSelection();
      // AnimatedSwitcher cross-fade 300ms，pump 完整时长让动画结束
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      expect(find.byKey(const ValueKey('chat-panel')), findsNothing);
      expect(find.text('WelcomeText'), findsOneWidget);
    });
  });

  group('WebShellPage — badge 透传', () {
    testWidgets('messageBadgeCount=5 → NavRail 显示 "5"', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(1400, 800),
        messageBadgeCount: 5,
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('多 badge 同时显示', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(1400, 800),
        messageBadgeCount: 5,
        contactBadgeCount: 3,
        channelBadgeCount: 99,
      );
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
    });
  });

  group('WebShellPage — 主题', () {
    testWidgets('dark theme 不抛异常', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(webShellProvider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            home: WebShellPage(
              tabMessageLabel: 'M',
              tabContactLabel: 'C',
              tabChannelLabel: 'H',
              tabMineLabel: 'I',
              welcomeTitle: 'Dark',
              messageTab: _kMessageTab,
              contactTab: _kContactTab,
              channelTab: _kChannelTab,
              mineTab: _kMineTab,
              chatBuilder: _chatBuilder,
              contactBuilder: _contactBuilder,
              channelBuilder: _channelBuilder,
              mineBuilder: _mineBuilder,
              mobileFallback: _kMobile,
            ),
          ),
        ),
      );
      expect(find.text('Dark'), findsOneWidget);
      expect(find.byType(WebNavRail), findsOneWidget);
    });

    testWidgets('Scaffold 背景色随主题明暗切换', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Color surfaceOf(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: b,
        ),
      ).colorScheme.surface;

      Future<Color> pumpAndGetBackground(Brightness b) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: b,
                ),
              ),
              home: WebShellPage(
                tabMessageLabel: 'M',
                tabContactLabel: 'C',
                tabChannelLabel: 'H',
                tabMineLabel: 'I',
                welcomeTitle: 'W',
                messageTab: _kMessageTab,
                contactTab: _kContactTab,
                channelTab: _kChannelTab,
                mineTab: _kMineTab,
                chatBuilder: _chatBuilder,
                contactBuilder: _contactBuilder,
                channelBuilder: _channelBuilder,
                mineBuilder: _mineBuilder,
                mobileFallback: _kMobile,
              ),
            ),
          ),
        );
        // MaterialApp 默认 themeAnimationDuration=200ms：主题切换经 AnimatedTheme
        // lerp，未等动画完成就读 Scaffold 会拿到过渡中间值（伪失败）。等动画结束。
        await tester.pump(const Duration(milliseconds: 300));
        // Cupertino 迁移后背景由 CupertinoTheme 层接管；MaterialApp 会把
        // colorScheme.surface 桥接给 Cupertino 主题，明暗语义不变
        final elements = find.byType(CupertinoPageScaffold).evaluate();
        if (elements.isEmpty) return Colors.transparent;
        final ctx = elements.first;
        final scaffold = tester.widget<CupertinoPageScaffold>(
          find.byType(CupertinoPageScaffold).first,
        );
        // scaffoldBackgroundColor 非空（CupertinoTheme 必有值），无需再兜底
        return scaffold.backgroundColor ??
            CupertinoTheme.of(ctx).scaffoldBackgroundColor;
      }

      final lightBg = await pumpAndGetBackground(Brightness.light);
      final darkBg = await pumpAndGetBackground(Brightness.dark);
      // 背景色取自 colorScheme.surface（M3 随明暗自动切换），
      // 明暗两主题下必须不同且各自等于对应 surface 值。
      expect(lightBg, surfaceOf(Brightness.light));
      expect(darkBg, surfaceOf(Brightness.dark));
      expect(lightBg, isNot(darkBg));
    });
  });
}

class _A02EmptyConversations extends ConversationNotifier {
  @override
  ConversationState build() => ConversationState(isLoading: false);
  @override
  Future<void> syncManualPendingFromServer() async {}
  @override
  Future<void> syncAuthoritativeConversationList({
    String trigger = 'manual',
  }) async {}
}

class _A02Contacts extends ContactNotifier {
  _A02Contacts(this.contact);
  final ContactModel contact;
  @override
  ContactState build() => ContactState(
    contactList: [contact],
    isLoading: false,
    indexBarData: const {'F'},
  );
  @override
  Future<void> loadData() async {}
}

class _A02Reminders extends NewFriendRemindNotifier {
  @override
  Set<String> build() => <String>{};
  @override
  Future<void> countReminders() async {}
}

void _a02Connectivity() {
  const check = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(check, (call) async {
    if (call.method == 'check') return <String>['wifi'];
    throw MissingPluginException('unexpected connectivity call');
  });
  messenger.setMockMethodCallHandler(events, (call) async {
    if (call.method == 'listen' || call.method == 'cancel') return null;
    throw MissingPluginException('unexpected connectivity event');
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(check, null);
    messenger.setMockMethodCallHandler(events, null);
  });
}

Future<void> _a02FirstSend(WidgetTester tester) async {
  final oldUid = StorageService.to.getString(Keys.currentUid);
  _a02Connectivity();
  addTearDown(() async {
    await StorageService.to.setString(Keys.currentUid, oldUid);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.runAsync(() async {
    await prepareWebWriter();
    await StorageService.to.setString(Keys.currentUid, '900001');
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 768);
  final contact = ContactModel(
    peerId: '990001',
    nickname: 'Fixture Friend',
    avatar: '',
    isFriend: 1,
  )..nameIndex = 'F';
  final messages = TextSendMessages();
  final chat = TextSendChat(messages);
  final scope = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(_A02EmptyConversations.new),
      contactProvider.overrideWith(() => _A02Contacts(contact)),
      newFriendRemindProvider.overrideWith(_A02Reminders.new),
      chatProvider.overrideWith(() => chat),
    ],
  );
  final router = _a02Router(scope, contact, messages);
  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await _a02Frames(tester);
    await _a02Journey(tester, scope, chat, messages);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    scope.dispose();
  }
}

GoRouter _a02Router(
  ProviderContainer scope,
  ContactModel contact,
  TextSendMessages messages,
) => GoRouter(
  initialLocation: '/web_shell',
  routes: [
    GoRoute(
      path: '/web_shell',
      builder: (_, _) => WebShellPage(
        tabMessageLabel: 'Messages',
        tabContactLabel: 'Contacts',
        tabChannelLabel: 'Channels',
        tabMineLabel: 'Mine',
        welcomeTitle: 'Welcome',
        messageTab: const ConversationPage(),
        contactTab: const ContactPage(),
        channelTab: const SizedBox(),
        mineTab: const SizedBox(),
        mobileFallback: const SizedBox(),
        chatBuilder: (sel) => Material(
          child: WebChatInput(
            selection: sel,
            currentUserId: '900001',
            messageRepository: messages,
          ),
        ),
        contactBuilder: (sel) => WebContactInfoPanel(
          selection: sel,
          sendButtonLabel: 'Start chat',
          closeTooltip: 'Close',
          contactLoader: (_) async => contact,
          onClose: scope.read(webShellProvider.notifier).clearSelection,
          onSendMessage: () => scope
              .read(webShellProvider.notifier)
              .openChat(ChatSelection(peerId: sel.uid, chatType: 'C2C')),
        ),
        channelBuilder: (_) => const SizedBox(),
        mineBuilder: (_) => const SizedBox(),
      ),
    ),
  ],
);

Future<void> _a02Journey(
  WidgetTester tester,
  ProviderContainer scope,
  TextSendChat chat,
  TextSendMessages messages,
) async {
  expect(scope.read(conversationProvider).conversations, isEmpty);
  expect(find.byType(NoDataView), findsOneWidget);
  await tester.tap(find.text(t.organization.directory.title));
  await _a02Frames(tester);
  expect(find.byType(ContactPage), findsOneWidget);
  await tester.tap(find.text('Fixture Friend'));
  await _a02Frames(tester);
  expect(find.byType(WebContactInfoPanel), findsOneWidget);
  await tester.tap(find.text('Start chat'));
  await _a02Frames(tester);
  expect(
    scope.read(webShellProvider).selectedItem,
    const ChatSelection(peerId: '990001', chatType: 'C2C'),
  );
  final field = find.descendant(
    of: find.byKey(const ValueKey('web-chat-input-field')),
    matching: find.byType(TextField),
  );
  final send = find.byKey(const ValueKey('web-chat-input-send-btn'));
  await tester.enterText(field, 'fixture first message');
  await _a02Frames(tester);
  expect(
    tester.widget<IconButton>(send).onPressed,
    isNotNull,
    reason: 'empty-state disabled status must not survive into C2C composer',
  );
  await tester.tap(send);
  await _a02Frames(tester);
  expect(chat.submitted, hasLength(1));
  final sent = chat.submitted.single as TextMessage;
  expect(sent.id, isNotEmpty);
  expect(sent.authorId, '900001');
  expect(sent.text, 'fixture first message');
  expect(sent.metadata?['peer_id'], '990001');
  expect(messages.rows[sent.id]?.toId, '990001');
  expect(messages.rows[sent.id]?.type, 'C2C');
}

Future<void> _a02Frames(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
}
