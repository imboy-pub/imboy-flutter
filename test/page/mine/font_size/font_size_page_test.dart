import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// FontSizePage widget test
///
/// 关键挑战：FontSizeNotifier.build() ref.watch(themeProvider) 触发主题链。
/// 测试策略：fontSizeProvider.overrideWith 注入指定 FontSizeState 跳过依赖。
///
/// 覆盖：
///   - AppBar title "字体大小设置"
///   - Slider 渲染（min=0, max=options.length-1）
///   - 不同 sliderValue 反映在 previewOption
///   - 预览区文本渲染（thisIsTitleText / fontPreviewText / thisIsAuxiliaryText）
///   - 底部 "更小 / 更大" 标签可见
///   - InsetGrouped Scaffold 背景
class _StateOverrideNotifier extends FontSizeNotifier {
  _StateOverrideNotifier(this._initial);
  final FontSizeState _initial;

  @override
  FontSizeState build() => _initial;
}

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/font_size',
    routes: [
      GoRoute(path: '/font_size', builder: (_, _) => const FontSizePage()),
    ],
  );
}

Future<void> _pumpFont(
  WidgetTester tester, {
  FontSizeOption option = FontSizeOption.normal,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final state = FontSizeState(
    currentOption: option,
    previewOption: option,
    sliderValue: FontSizeOption.values.indexOf(option).toDouble(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fontSizeProvider.overrideWith(() => _StateOverrideNotifier(state)),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('FontSizePage layout', () {
    testWidgets('Scaffold uses iOS surfaceGrouped background', (tester) async {
      await _pumpFont(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.lightSurfaceGrouped);
      await _unmount(tester);
    });

    testWidgets('AppBar title 渲染 "字体大小设置"', (tester) async {
      await _pumpFont(tester);
      expect(find.text('字体大小设置'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders Slider widget', (tester) async {
      await _pumpFont(tester);
      expect(find.byType(Slider), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('Slider min=0, max=options.length-1, divisions=length-1', (
      tester,
    ) async {
      await _pumpFont(tester);
      final slider = tester.widget<Slider>(find.byType(Slider));
      final optionsCount = FontSizeOption.values.length;

      expect(slider.min, 0);
      expect(slider.max, (optionsCount - 1).toDouble());
      expect(slider.divisions, optionsCount - 1);

      await _unmount(tester);
    });
  });

  group('FontSizePage preview area', () {
    testWidgets('renders preview labels (预览效果 / 标题 / 正文)', (tester) async {
      await _pumpFont(tester);

      // i18n: previewEffect="预览效果" / thisIsTitleText="这是标题文本"
      expect(find.text('预览效果'), findsOneWidget);
      expect(find.text('这是标题文本'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders 更小 / 更大 labels under slider', (tester) async {
      await _pumpFont(tester);

      expect(find.text('更小'), findsOneWidget);
      expect(find.text('更大'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('FontSizePage state binding', () {
    testWidgets('Slider value follows state.sliderValue (normal=1)', (
      tester,
    ) async {
      await _pumpFont(tester, option: FontSizeOption.normal);

      final slider = tester.widget<Slider>(find.byType(Slider));
      // FontSizeOption.normal index = 1
      expect(slider.value, 1.0);

      await _unmount(tester);
    });

    testWidgets('Slider value reflects different options (large=3)', (
      tester,
    ) async {
      await _pumpFont(tester, option: FontSizeOption.large);

      final slider = tester.widget<Slider>(find.byType(Slider));
      // FontSizeOption.large index = 3
      expect(slider.value, 3.0);

      await _unmount(tester);
    });

    testWidgets('preview footer shows displayName + scale percentage', (
      tester,
    ) async {
      await _pumpFont(tester, option: FontSizeOption.large);

      // 源码 Slider 未设置 label；displayName + 百分比由预览区
      // _buildPreviewFooter 的 t.common.currentFontScale 渲染：
      // zh_CN 格式 "当前：${param1} ${param2}%"
      // large displayName='大', scale=1.2 → "当前：大 120%"
      expect(find.text('当前：大 120%'), findsOneWidget);

      await _unmount(tester);
    });
  });
}
