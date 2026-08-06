import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/dark_model/dark_model_page.dart';

/// DarkModelPage widget test
///
/// 关键挑战：DarkModelNotifier.build() 调 ref.watch(themeProvider) +
/// ref.watch(themeModeProvider)，触发 ThemeManager 单例链。
///
/// 测试策略：用 darkModelProvider.overrideWith 替换 build()，
/// 直接注入指定 DarkModelState，跳过 themeProvider 依赖。
///
/// 源码现状（lib/page/mine/dark_model/dark_model_page.dart）：
///   - 使用 IosPageTemplate + ImBoySettingsSection + ImBoySettingsTile，
///     不再使用 CellPressable / SwitchListTile。
///   - "显示" section 始终渲染 1 个 ImBoySettingsTile（跟随系统开关，
///     trailing 为 CupertinoSwitch）。
///   - switchValue=false 时额外渲染 "主题" section，含 2 个 ImBoySettingsTile
///     （系统默认 / 深色模式），即“主题选项”。
///   - switchValue=true 时不渲染 "主题" section，故主题选项为 0。
///
/// 覆盖：
///   - AppBar title "深色模式"
///   - 跟随系统开关（CupertinoSwitch）渲染
///   - switchValue=true 时不渲染主题选项；switchValue=false 时渲染 2 个选项
///   - 主题选项用 ImBoySettingsTile + 当前选中显示 check_mark
class _StateOverrideNotifier extends DarkModelNotifier {
  _StateOverrideNotifier(this._initial);
  final DarkModelState _initial;

  @override
  DarkModelState build() => _initial;
}

GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/dark_model',
    routes: [
      GoRoute(path: '/dark_model', builder: (_, _) => const DarkModelPage()),
    ],
  );
}

Future<void> _pumpDark(
  WidgetTester tester, {
  required DarkModelState state,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        darkModelProvider.overrideWith(() => _StateOverrideNotifier(state)),
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

  group('DarkModelPage layout', () {
    testWidgets('AppBar title 渲染 "深色模式"', (tester) async {
      await _pumpDark(
        tester,
        state: const DarkModelState(switchValue: true, selectIndex: 2),
      );

      // i18n zhCn: darkModel = "深色模式"
      expect(find.text('深色模式'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('switchValue=true 时仅渲染跟随系统开关，不显示主题选项', (tester) async {
      await _pumpDark(
        tester,
        state: const DarkModelState(switchValue: true, selectIndex: 2),
      );

      // 跟随系统开关（CupertinoSwitch）渲染
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      // 跟随系统开启时仅 "显示" section 的 1 个 tile，主题选项区不渲染
      expect(find.byType(ImBoySettingsTile), findsOneWidget);
      expect(find.byType(ImBoySettingsSection), findsOneWidget);
      // 没有 check_mark（无主题选项）
      expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);

      await _unmount(tester);
    });

    testWidgets('switchValue=false 时渲染 2 个主题选项 (ImBoySettingsTile)', (
      tester,
    ) async {
      await _pumpDark(
        tester,
        state: const DarkModelState(switchValue: false, selectIndex: 2),
      );

      // 跟随系统关闭后渲染 "显示" + "主题" 两个 section
      expect(find.byType(ImBoySettingsSection), findsNWidgets(2));
      // 共 3 个 tile：1 个跟随系统开关 + 2 个主题选项
      expect(find.byType(ImBoySettingsTile), findsNWidgets(3));
      // 跟随系统开关（CupertinoSwitch）仍然在
      expect(find.byType(CupertinoSwitch), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('DarkModelPage selection', () {
    testWidgets('selectIndex=2 (浅色) → 仅"系统默认"显示 check_mark', (tester) async {
      await _pumpDark(
        tester,
        state: const DarkModelState(switchValue: false, selectIndex: 2),
      );

      // 仅 1 个 check_mark
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      // i18n zhCn: systemDefault = "系统默认"
      expect(find.text('系统默认'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('selectIndex=3 (深色) → "深色模式" 选项显示 check_mark', (tester) async {
      await _pumpDark(
        tester,
        state: const DarkModelState(switchValue: false, selectIndex: 3),
      );

      // 仍然只有 1 个 check_mark（移到 deep mode tile）
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      // 主题选项含 "深色模式" 文字（与 AppBar 标题同名，至少 1 个）
      expect(find.text('深色模式'), findsAtLeastNWidgets(1));

      await _unmount(tester);
    });
  });
}
