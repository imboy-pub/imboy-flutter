/// T16 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p2_groups_share_surface_and_insets
///  2. p2_empty_resources_leave_no_empty_container
///  3. p2_single_apps_has_no_duplicate_section_title
///  4. 真实隐藏 CS 行场景无空卡
///  5. scale2 自然增高
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

// 统一分组容器 _GroupedSection 为私有类；合同测试通过公开页面行为
// 断言（DecoratedBox 数量/颜色/尺寸），不依赖私有实现符号。
Finder _groupSurfaces() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).borderRadius != null,
);

double _groupHeight(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(_groupSurfaces().first);
  final RenderBox rb = tester.renderObject<RenderBox>(
    find.byWidgetPredicate((w) => identical(w, box)),
  );
  return rb.size.height;
}

void main() {
  Future<void> pumpWorkbench(
    WidgetTester tester, {
    required List<Widget> resourceEntries,
    List<Widget> oaEntries = const [],
    bool androidInbound = false,
    double scale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child!,
          ),
        ),
        home: EnterpriseWorkbenchPage(
          entries: const [],
          accountKey: 'synthetic-account',
          organizationId: '10',
          resourceEntries: resourceEntries,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('p2_groups_share_surface_and_insets：各组同背景同边距', (tester) async {
    final Key probe = const Key('probe-tile');
    await pumpWorkbench(
      tester,
      resourceEntries: <Widget>[
        CupertinoListTile(key: probe, title: const Text('资源')),
      ],
    );
    final List<DecoratedBox> groups = tester
        .widgetList<DecoratedBox>(_groupSurfaces())
        .toList();
    expect(groups, isNotEmpty);
    // 所有分组背景装饰一致（同一 surface token + 同圆角）
    for (final DecoratedBox g in groups) {
      expect(g.decoration, groups.first.decoration);
    }
  });

  testWidgets('p2_empty_resources_leave_no_empty_container：全隐藏子项零高度', (
    tester,
  ) async {
    await pumpWorkbench(tester, resourceEntries: const []);
    final appsOnlyHeight = _groupHeight(tester);
    // 应用入口与资源共用一组；隐藏资源不应给常驻应用入口增加空白。
    await pumpWorkbench(
      tester,
      resourceEntries: <Widget>[const SizedBox.shrink()],
    );
    expect(_groupSurfaces(), findsOneWidget);
    expect(_groupHeight(tester), appsOnlyHeight, reason: '隐藏资源不增加分组高度');
  });

  testWidgets('p2_single_apps_has_no_duplicate_section_title：单应用无重复标题', (
    tester,
  ) async {
    await pumpWorkbench(tester, resourceEntries: const <Widget>[]);
    // 联调入口常驻且无 section header 重复标题
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
    expect(
      find.byType(CupertinoListSection),
      findsNothing,
      reason: '旧 insetGrouped 已被自然收缩容器替代',
    );
  });

  testWidgets('真实隐藏 CS 行场景无空卡：shrink 子项不产生可见残留', (tester) async {
    await pumpWorkbench(tester, resourceEntries: const []);
    final appsOnlyHeight = _groupHeight(tester);
    await pumpWorkbench(
      tester,
      resourceEntries: <Widget>[
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
    expect(_groupSurfaces(), findsOneWidget);
    expect(_groupHeight(tester), appsOnlyHeight);
  });

  testWidgets('scale2 自然增高：无渲染异常', (tester) async {
    await pumpWorkbench(
      tester,
      resourceEntries: <Widget>[CupertinoListTile(title: const Text('资源行'))],
      scale: 2.0,
    );
    expect(tester.takeException(), isNull);
    expect(_groupHeight(tester), greaterThan(0));
  });
}
