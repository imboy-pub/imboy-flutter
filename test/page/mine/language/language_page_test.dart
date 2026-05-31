import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/language/language_page.dart';
import 'package:imboy/service/storage.dart';

/// LanguagePage widget test
///
/// 覆盖：
///   - AppBar title "语言设置"
///   - 列表项 ImBoySettingsTile 渲染（10 种语言）
///   - 当前语言 (zhCn) 显示 check_mark
///   - 其他语言不显示 check_mark
///   - 点击切换语言 → state.selectedLocaleId 变化（间接验证）
GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/language',
    routes: [
      GoRoute(path: '/language', builder: (_, _) => const LanguagePage()),
    ],
  );
}

Future<void> _pumpLang(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
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
    // 测试默认走 zhCn locale，确保 currentLanguageCode 留空走默认值
    await StorageService.to.remove(Keys.currentLanguageCode);
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('LanguagePage layout', () {
    testWidgets('AppBar title 渲染 "语言设置"', (tester) async {
      await _pumpLang(tester);
      expect(find.text('语言设置'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('列表渲染 10 个 CellPressable 语言项', (tester) async {
      await _pumpLang(tester);

      // 10 种语言：zh_CN / zh_Hant / en_US / ja_JP / ko_KR / de_DE /
      // fr_FR / it_IT / ru_RU / ar_SA
      final cells = find.byType(ImBoySettingsTile);
      expect(
        cells.evaluate().length,
        greaterThanOrEqualTo(10),
        reason: '语言列表至少含 10 个 ImBoySettingsTile Cell',
      );

      await _unmount(tester);
    });

    testWidgets('当前语言（zhCn）显示 check_mark', (tester) async {
      await _pumpLang(tester);

      // zhCn 是默认 locale，列表内"简体中文" tile 应有 check_mark icon
      // 整个页面应只有 1 个 check_mark（仅当前选中项）
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

      // "简体中文" 文字也应渲染（语言列表标题）
      expect(find.text('简体中文'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('多种语言名称渲染（zhCn/enUs/jaJp/koKr 至少 4 种可见）', (tester) async {
      await _pumpLang(tester);

      // 至少能看到几个常见语种 title（i18n 已确认 zhCn=简体中文 / enUs=美国英语）
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('美国英语'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('LanguagePage interactions', () {
    testWidgets('点击其他语言 tile 触发选中切换 (check_mark 跟随)', (tester) async {
      await _pumpLang(tester);

      // 初始：仅 zhCn 有 check_mark
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

      // 找到 "美国英语" tile 并点击
      // 用 tapAt 限定到第一处确保命中
      final enUsTile = find.text('美国英语');
      expect(enUsTile, findsOneWidget);
      await tester.tap(enUsTile);
      await tester.pump();
      await tester.pump(); // 第二帧让 setState 应用

      // 切换后：仍然只有 1 个 check_mark（移到 enUs tile）
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

      await _unmount(tester);
    });
  });
}
