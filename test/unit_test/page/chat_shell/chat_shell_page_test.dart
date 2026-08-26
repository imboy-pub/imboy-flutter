/// T2 (WP1) — Chat Shell 壳页面 widget 测试
///
/// 覆盖（镜像 `web_shell_page_test.dart` 的 MediaQuery 技巧与断点分组）：
/// - mobile 分支（< 900px）渲染 mobileEntry，desktopEntry 不渲染
/// - desktop 分支（>= 900px）渲染 desktopEntry，mobileEntry 不渲染
/// - 边界值（899.99 / 900）
/// - 纯包装契约：壳不额外包裹 Scaffold / 导航控件（子树原样）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat_shell/chat_shell_page.dart';

const _kMobileEntry = Material(
  key: ValueKey('chat-shell-mobile-entry'),
  child: Center(child: Text('MOBILE_ENTRY')),
);

const _kDesktopEntry = Material(
  key: ValueKey('chat-shell-desktop-entry'),
  child: Center(child: Text('DESKTOP_ENTRY')),
);

Future<void> _pumpShell(WidgetTester tester, {required Size size}) async {
  // MediaQuery.of(context).size 读 view.physicalSize / view.devicePixelRatio，
  // setSurfaceSize 不影响 MediaQuery — 必须直接设 view.physicalSize（按 DPR 放大）
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size; // DPR=1 时 physical == logical
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(
      home: ChatShellPage(
        mobileEntry: _kMobileEntry,
        desktopEntry: _kDesktopEntry,
      ),
    ),
  );
}

void main() {
  group('ChatShellPage — mobile 分支 (< 900px)', () {
    testWidgets('width 320 → 渲染 mobileEntry', (tester) async {
      await _pumpShell(tester, size: const Size(320, 700));
      expect(
        find.byKey(const ValueKey('chat-shell-mobile-entry')),
        findsOneWidget,
      );
      expect(find.text('MOBILE_ENTRY'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-shell-desktop-entry')),
        findsNothing,
      );
    });

    testWidgets('width 768 (平板竖屏) → mobileEntry', (tester) async {
      await _pumpShell(tester, size: const Size(768, 1000));
      expect(
        find.byKey(const ValueKey('chat-shell-mobile-entry')),
        findsOneWidget,
      );
    });

    testWidgets('width 899.99 (刚低于阈值) → mobileEntry', (tester) async {
      await _pumpShell(tester, size: const Size(899.99, 700));
      expect(
        find.byKey(const ValueKey('chat-shell-mobile-entry')),
        findsOneWidget,
      );
    });
  });

  group('ChatShellPage — desktop 分支 (>= 900px)', () {
    testWidgets('width 900 (左闭边界) → 渲染 desktopEntry', (tester) async {
      await _pumpShell(tester, size: const Size(900, 700));
      expect(
        find.byKey(const ValueKey('chat-shell-desktop-entry')),
        findsOneWidget,
      );
      expect(find.text('DESKTOP_ENTRY'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-shell-mobile-entry')),
        findsNothing,
      );
    });

    testWidgets('width 1440 (典型笔记本) → desktopEntry', (tester) async {
      await _pumpShell(tester, size: const Size(1440, 900));
      expect(
        find.byKey(const ValueKey('chat-shell-desktop-entry')),
        findsOneWidget,
      );
    });

    testWidgets('width 1920 (Full HD) → desktopEntry', (tester) async {
      await _pumpShell(tester, size: const Size(1920, 1080));
      expect(
        find.byKey(const ValueKey('chat-shell-desktop-entry')),
        findsOneWidget,
      );
    });
  });

  group('ChatShellPage — 纯包装契约', () {
    testWidgets('壳不额外包 Scaffold（子树 widget 原样承载）', (tester) async {
      await _pumpShell(tester, size: const Size(320, 700));
      // ChatShellPage 自身不应引入 Scaffold；MaterialApp.home 提供的
      // Scaffold 不属于壳（MaterialApp 会为 home 补一个，故统计来源必须是
      // ChatShellPage 子树中入口 widget 之上没有新增 Scaffold）。
      final shellScaffolds = find
          .byType(Scaffold)
          .evaluate()
          .where(
            (element) =>
                element.findAncestorWidgetOfExactType<ChatShellPage>() != null,
          )
          .length;
      expect(shellScaffolds, 0, reason: '纯包装：壳不添加自己的 Scaffold');
    });

    testWidgets('构造契约：const 可构造 + 双 entry 必填', (tester) async {
      const page = ChatShellPage(
        mobileEntry: SizedBox(),
        desktopEntry: SizedBox(),
      );
      expect(page, isA<StatelessWidget>());
      expect(page, isA<ChatShellPage>());
      expect(page.mobileEntry, isA<SizedBox>());
      expect(page.desktopEntry, isA<SizedBox>());
    });
  });
}
