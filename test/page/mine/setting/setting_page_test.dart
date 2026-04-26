import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// SettingPage widget test (843 行核心入口)
///
/// 覆盖：
///   - InsetGrouped 背景 (surfaceGrouped)
///   - AppBar title "设置"
///   - 通用 / 隐私与安全 等 section header 渲染
///   - 关键设置项 cell：账号安全 / 语言 / 深色模式 / 字体大小
///   - 跳转契约：tap 设置项触发 context.push 到对应路由
///
/// 测试策略：直接 ProviderScope（themeProvider/themeModeProvider/userRepoProvider/
/// allowSearchProvider 默认 build 在测试中可用，flutter_test_config.dart 已 mock
/// path_provider + StorageService）。每个测试末尾 _unmount 清理 Riverpod scheduler。
GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/setting',
    routes: [
      GoRoute(path: '/setting', builder: (_, _) => const SettingPage()),
      // 设置页内多个跳转目标
      GoRoute(
        path: '/account_security',
        builder: (_, _) => stub('account_security stub'),
      ),
      GoRoute(path: '/language', builder: (_, _) => stub('language stub')),
      GoRoute(
        path: '/dark_model',
        builder: (_, _) => stub('dark_model stub'),
      ),
      GoRoute(
        path: '/font_size',
        builder: (_, _) => stub('font_size stub'),
      ),
    ],
  );
}

Future<void> _pumpSetting(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200); // 大画布让 SingleChildScrollView 内容尽量可见
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
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
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    // 注入 currentUid 让 userRepoProvider 工作
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
    await StorageService.setMap(Keys.currentUser, <String, dynamic>{
      'uid': 'tsid_uid_001',
      'account': 'imboy_user',
      'nickname': 'Tester',
      'avatar': '',
      'email': '',
      'gender': 0,
      'sign': '',
      'region': '',
      'createdAt': 0,
    });
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);
  });

  group('SettingPage layout', () {
    testWidgets('Scaffold uses iOS surfaceGrouped background', (
      tester,
    ) async {
      await _pumpSetting(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.lightSurfaceGrouped);
      await _unmount(tester);
    });

    testWidgets('AppBar title 渲染 "设置"', (tester) async {
      await _pumpSetting(tester);
      // i18n zhCn: setting = "设置"
      expect(find.text('设置'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('Section header "通用" 大写渲染', (tester) async {
      await _pumpSetting(tester);
      // _buildSectionHeader 用 toUpperCase()，中文 toUpperCase() 不变 → "通用"
      expect(find.text('通用'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('SettingPage menu items', () {
    testWidgets('renders 通用 section 4 个菜单项 (账号安全/语言/深色模式/字体)',
        (tester) async {
      await _pumpSetting(tester);

      // 4 个 setting items 主标题
      expect(find.text('账号安全'), findsOneWidget);
      expect(find.text('语言设置'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
      // fontSettings = @:fontSizeSetting 别名 → 解析为 "字体大小设置"
      expect(find.byIcon(Icons.text_fields), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('CellPressable 至少 4 个 (覆盖 4 个菜单项)', (tester) async {
      await _pumpSetting(tester);

      expect(
        find.byType(CellPressable).evaluate().length,
        greaterThanOrEqualTo(4),
        reason: '通用 section 4 项 + 其他 section 应有 ≥4 个 CellPressable',
      );
      await _unmount(tester);
    });

    testWidgets('每个菜单项 trailing 含 chevron_right', (tester) async {
      await _pumpSetting(tester);

      expect(
        find.byIcon(CupertinoIcons.chevron_right).evaluate().length,
        greaterThanOrEqualTo(4),
        reason: '4+ 菜单项每项右侧应有 chevron_right',
      );
      await _unmount(tester);
    });
  });

  group('SettingPage navigation', () {
    testWidgets('tap "账号安全" → /account_security', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('账号安全'));
      await tester.pumpAndSettle();
      expect(find.text('account_security stub'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap "语言设置" → /language', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('语言设置'));
      await tester.pumpAndSettle();
      expect(find.text('language stub'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap "深色模式" → /dark_model', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      expect(find.text('dark_model stub'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
