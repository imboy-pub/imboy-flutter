import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/service/cache/region_cache.dart';

const _regionFixture = [
  {
    'title': '中国大陆',
    'children': [
      {
        'title': '北京',
        'children': ['东城'],
      },
    ],
  },
  {
    'title': '中国香港',
    'children': ['中西区'],
  },
];

/// 固定地区树仅注入测试；路径、保存和缓存逻辑使用生产 Notifier。
class _FixtureRegionNotifier extends SetRegionNotifier {
  @override
  SetRegionState build() => const SetRegionState(regionList: _regionFixture);
}

Future<void> _pumpRegionFlow(
  WidgetTester tester, {
  required Future<bool> Function(String) onSave,
}) async {
  // 前一测试可能仍停留在递归子页面。显式卸载 Navigator 和
  // autoDispose Provider，避免第二、第三个 Widget 测试复用旧状态。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  // 新 ProviderScope 使用测试数据，不依赖 rootBundle 和缓存异步回填。
  // 真正的地区资产加载由 AT-MF06 隔离数据库集成验收覆盖。
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [setRegionProvider.overrideWith(_FixtureRegionNotifier.new)],
      child: TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-region-editor'),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => SetRegionPage(
                        title: '地区',
                        currentValue: '',
                        onSave: onSave,
                      ),
                    ),
                  );
                },
                child: const Text('MorePage'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-region-editor')));
  await tester.pumpAndSettle();
  await _waitForRegionData(tester);
}

Future<void> _waitForRegionData(WidgetTester tester) async {
  final mainland = find.text('中国大陆');
  await tester.pump();
  expect(mainland, findsOneWidget, reason: '地区测试夹具应显示中国大陆');
}

Future<void> _tapRegion(WidgetTester tester, String title) async {
  final finder = find.text(title);
  for (var attempt = 0; attempt < 40; attempt++) {
    if (finder.evaluate().isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget, reason: '地区列表应显示 $title');
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _popRegionRoute(WidgetTester tester) async {
  // IosPageTemplate 使用 GlassBackButton，而不是 Cupertino 默认返回按钮；
  // 直接 pop 当前 Navigator，避免 WidgetTester.pageBack 的组件类型假设。
  final rootPage = find.byType(SetRegionPage, skipOffstage: false);
  Navigator.of(tester.element(rootPage)).pop();
  await tester.pumpAndSettle();
}

Future<void> _selectBeijingDongcheng(WidgetTester tester) async {
  await _tapRegion(tester, '中国大陆');
  await _tapRegion(tester, '北京');
  await _tapRegion(tester, '东城');
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(SetRegionPage, skipOffstage: false)),
  );
}

void main() {
  testWidgets('递归下钻保留完整父级路径，切换地区不残留旧路径', (tester) async {
    await _pumpRegionFlow(tester, onSave: (_) async => true);
    await _selectBeijingDongcheng(tester);

    var state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国大陆 北京 东城');
    expect(state.regionPath, ['中国大陆', '北京', '东城']);

    await _popRegionRoute(tester);
    await _popRegionRoute(tester);
    await _tapRegion(tester, '中国香港');
    await _tapRegion(tester, '中西区');

    state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);

    await tester.tap(find.text('中西区'));
    await tester.pump();
    state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);
  });

  testWidgets('保存失败保持递归页面且不提前写入已提交缓存', (tester) async {
    String? attemptedValue;
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return false;
      },
    );
    await _selectBeijingDongcheng(tester);

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(attemptedValue, '中国大陆 北京 东城');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
    expect(find.text('东城'), findsOneWidget);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
  });

  testWidgets('保存成功退出所有递归页面并提交一致的地区缓存', (tester) async {
    String? savedValue;
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        savedValue = value;
        return true;
      },
    );
    await _selectBeijingDongcheng(tester);

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(savedValue, '中国大陆 北京 东城');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsNothing);
    expect(find.text('MorePage'), findsOneWidget);
    expect(await RegionCache.loadSelectedRegion(), '中国大陆 北京 东城');
    expect(await RegionCache.loadRegionPath(), ['中国大陆', '北京', '东城']);
  });
}
