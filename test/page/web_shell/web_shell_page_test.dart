/// Phase 1.1.h.2 — Web Shell 整合 widget 测试
///
/// 覆盖：
/// - mobile fallback (< 900px)
/// - threeColumn 三栏渲染（>= 900px）
/// - tab 切换联动 (NavRail.onTap → webShellProvider.switchTab)
/// - selection 渲染（null=welcome / chat / contact / channel / mine）
/// - i18n label 透传到 navItems
/// - badge 透传
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell.dart';

const _kMobile = Material(
  key: ValueKey('mobile-fallback'),
  child: Center(child: Text('MOBILE')),
);

const _kMessageTab = Center(
  key: ValueKey('msg-tab'),
  child: Text('MSG_TAB'),
);
const _kContactTab = Center(
  key: ValueKey('contact-tab'),
  child: Text('CON_TAB'),
);
const _kChannelTab = Center(
  key: ValueKey('channel-tab'),
  child: Text('CH_TAB'),
);
const _kMineTab = Center(
  key: ValueKey('mine-tab'),
  child: Text('MINE_TAB'),
);

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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: WebShellPage(
          tabMessageLabel: 'Messages',
          tabContactLabel: 'Contacts',
          tabChannelLabel: 'Channels',
          tabMineLabel: 'Me',
          welcomeTitle: welcomeTitle,
          welcomeSubtitle: welcomeSubtitle,
          messageTab: _kMessageTab,
          contactTab: _kContactTab,
          channelTab: _kChannelTab,
          mineTab: _kMineTab,
          chatBuilder: _chatBuilder,
          contactBuilder: _contactBuilder,
          channelBuilder: _channelBuilder,
          mineBuilder: _mineBuilder,
          mobileFallback: _kMobile,
          messageBadgeCount: messageBadgeCount,
          contactBadgeCount: contactBadgeCount,
          channelBadgeCount: channelBadgeCount,
        ),
      ),
    ),
  );
  return container;
}

void main() {
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
    testWidgets('width 1400 → 渲染 NavRail + MiddlePanel + MainPanel', (tester) async {
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

    testWidgets('width 1024 → twoColumn 也走三栏分支（>= 900）', (tester) async {
      await _pumpShell(tester, size: const Size(1024, 800));
      expect(find.byType(WebNavRail), findsOneWidget);
    });
  });

  group('WebShellPage — i18n label 透传', () {
    testWidgets('NavRail items 用调用方传入的 label（Tooltip 验证）', (tester) async {
      await _pumpShell(tester, size: const Size(1400, 800));
      expect(find.byTooltip('Messages'), findsOneWidget);
      expect(find.byTooltip('Contacts'), findsOneWidget);
      expect(find.byTooltip('Channels'), findsOneWidget);
      expect(find.byTooltip('Me'), findsOneWidget);
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

  group('WebShellPage — Tab 切换联动', () {
    testWidgets('点击 NavRail tab 1 → currentTab=1，渲染 contactTab',
        (tester) async {
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
      );
      // 点击 NavRail 的第二项（联系人）
      await tester.tap(find.byType(InkWell).at(1));
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
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
      );
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'p1', chatType: 'C2C'),
          );
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-panel')), findsOneWidget);
      expect(find.text('CHAT:p1'), findsOneWidget);
    });

    testWidgets('ContactSelection → contactBuilder 渲染', (tester) async {
      final container = await _pumpShell(
        tester,
        size: const Size(1400, 800),
      );
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
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'p1', chatType: 'C2C'),
          );
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-panel')), findsOneWidget);

      container.read(webShellProvider.notifier).clearSelection();
      await tester.pump();

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
  });
}
