import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/service/cache/region_cache.dart';

Future<void> _pumpRegionFlow(
  WidgetTester tester, {
  required Future<bool> Function(String) onSave,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
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
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

Future<void> _selectBeijingDongcheng(WidgetTester tester) async {
  await tester.tap(find.text('中国大陆'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('北京'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('东城'));
  await tester.pumpAndSettle();
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

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('中国香港'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中西区'));
    await tester.pumpAndSettle();

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
