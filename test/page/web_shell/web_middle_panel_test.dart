/// Phase 1.1.f — Web Middle Panel widget 测试
///
/// 覆盖：
/// - tabs 渲染 + currentTab 切换
/// - keepAlive=true: IndexedStack 模式（所有 tab mount，state 保留）
/// - keepAlive=false: 仅当前 tab mount
/// - 默认/自定义 width
/// - assert 防御
/// - 右边框（区分中栏与右栏）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_middle_panel.dart';

const _kTab0 = Center(key: ValueKey('tab-0'), child: Text('Tab0'));
const _kTab1 = Center(key: ValueKey('tab-1'), child: Text('Tab1'));
const _kTab2 = Center(key: ValueKey('tab-2'), child: Text('Tab2'));
const _kTab3 = Center(key: ValueKey('tab-3'), child: Text('Tab3'));

const _kAllTabs = [_kTab0, _kTab1, _kTab2, _kTab3];

Future<void> _pumpPanel(
  WidgetTester tester, {
  required int currentTab,
  required List<Widget> tabs,
  double? width,
  bool? keepAlive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            WebMiddlePanel(
              currentTab: currentTab,
              tabs: tabs,
              width: width ?? 360,
              keepAlive: keepAlive ?? true,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('WebMiddlePanel — 基础渲染', () {
    testWidgets('渲染指定 tab 内容（currentTab=0）', (tester) async {
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      // 当前 tab 应可见（在 IndexedStack 中显示）
      expect(find.text('Tab0'), findsOneWidget);
    });

    testWidgets('切换 currentTab 后显示对应内容', (tester) async {
      await _pumpPanel(tester, currentTab: 2, tabs: _kAllTabs);
      // IndexedStack: 所有 tab 都 mount, but only one visible
      // text 仍能通过 finder 找到，因为 IndexedStack 不 detach 子树
      expect(find.text('Tab2'), findsOneWidget);
    });

    testWidgets('默认 width=360', (tester) async {
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      final panel = tester.widget<WebMiddlePanel>(find.byType(WebMiddlePanel));
      expect(panel.width, 360);
    });

    testWidgets('自定义 width 生效', (tester) async {
      await _pumpPanel(
        tester,
        currentTab: 0,
        tabs: _kAllTabs,
        width: 480,
      );
      final panel = tester.widget<WebMiddlePanel>(find.byType(WebMiddlePanel));
      expect(panel.width, 480);
    });
  });

  group('WebMiddlePanel — keepAlive', () {
    testWidgets('keepAlive=true: IndexedStack.children 长度等于 tabs.length', (tester) async {
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      expect(find.byType(IndexedStack), findsOneWidget);
      final stack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.children.length, _kAllTabs.length);
      // skipOffstage:false 可见 + 隐藏的全部子节点
      expect(
        find.byKey(const ValueKey('tab-0'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tab-1'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tab-2'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tab-3'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('keepAlive=true: IndexedStack.index 跟随 currentTab', (tester) async {
      await _pumpPanel(tester, currentTab: 2, tabs: _kAllTabs);
      final stack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 2);
    });

    testWidgets('keepAlive=false: 不使用 IndexedStack', (tester) async {
      await _pumpPanel(
        tester,
        currentTab: 1,
        tabs: _kAllTabs,
        keepAlive: false,
      );
      expect(find.byType(IndexedStack), findsNothing);
      // 仅当前 tab 渲染
      expect(find.byKey(const ValueKey('tab-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-0')), findsNothing);
      expect(find.byKey(const ValueKey('tab-2')), findsNothing);
    });

    testWidgets('keepAlive=true: 切换 tab 后旧 tab 仍 mount（state 保留）', (tester) async {
      // 第一次以 tab=0 渲染（用 skipOffstage:false 看完整 IndexedStack 子树）
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      expect(
        find.byKey(const ValueKey('tab-0'), skipOffstage: false),
        findsOneWidget,
      );

      // 切换到 tab=2 后，IndexedStack 仍持有 4 个 children
      await _pumpPanel(tester, currentTab: 2, tabs: _kAllTabs);
      final stack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.children.length, 4);
      expect(stack.index, 2);
    });
  });

  group('WebMiddlePanel — 主题与边框', () {
    testWidgets('背景用 ColorScheme.surface', (tester) async {
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      final BuildContext ctx =
          tester.element(find.byType(WebMiddlePanel));
      final cs = Theme.of(ctx).colorScheme;
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(WebMiddlePanel),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, cs.surface);
    });

    testWidgets('右侧有 outlineVariant 颜色的 border', (tester) async {
      await _pumpPanel(tester, currentTab: 0, tabs: _kAllTabs);
      final BuildContext ctx =
          tester.element(find.byType(WebMiddlePanel));
      final cs = Theme.of(ctx).colorScheme;
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(WebMiddlePanel),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border?.bottom, BorderSide.none);
      expect(
        (decoration?.border as Border?)?.right.color,
        cs.outlineVariant,
      );
      expect((decoration?.border as Border?)?.right.width, 0.5);
    });
  });

  group('WebMiddlePanel — assert 防御', () {
    test('tabs 长度 < 2 应触发 assert', () {
      expect(
        () => WebMiddlePanel(
          currentTab: 0,
          tabs: const [SizedBox()],
        ),
        throwsAssertionError,
      );
    });

    test('currentTab 越界负数应触发 assert', () {
      expect(
        () => WebMiddlePanel(
          currentTab: -1,
          tabs: _kAllTabs,
        ),
        throwsAssertionError,
      );
    });

    test('currentTab 越界正数应触发 assert', () {
      expect(
        () => WebMiddlePanel(
          currentTab: 4,
          tabs: _kAllTabs,
        ),
        throwsAssertionError,
      );
    });
  });
}
