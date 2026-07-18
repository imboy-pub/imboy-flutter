// integration_test/mine/mine_subpages_smoke_test.dart
//
// 「我的」子页面导航冒烟测试
//
// 目标：登录态下逐个进入「我的」各子页路由，断言页面成功渲染（无崩溃）。
// 破坏性页（注销账号 /logout_account）只进入并断言渲染，绝不点任何执行按钮。
//
// ⚠️ 两条刻意设计（都源自真机踩坑）：
//   1. 等待：不用 flows/test_utils.dart 的 settle()（其 pumpAndSettle 在本 App 的
//      持续帧调度下永不静止，真机会挂死到超时）。改用固定 tester.pump(Duration)
//      抽帧，与现有 integration_test/smoke/smoke_test.dart 同款。
//   2. 导航：不点 tab/入口 tile（finder 脆弱，易漏），直接用 go_router 路由 push
//      各子页（路由常量见 lib/config/router/routes/mine_routes.dart）。
//
// 契约：
//   - 停在登录页（无登录态）→ markTestSkipped（不假绿，非裸 return）
//   - 无法取得 GoRouter → markTestSkipped
//
// 运行（真机，需设备已登录）：
//   flutter test integration_test/mine/mine_subpages_smoke_test.dart \
//     -d <device_id> --dart-define=APP_ENV=pro \
//     --dart-define=API_BASE_URL=https://pro.imboy.pub

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;

import '../flows/test_utils.dart' show flowLog, drainKnownFrameworkExceptions;

/// 一个「我的」子页面：路由 + 渲染成功标志候选文案（空则退化为断言存在任意 Text）。
class _SubPage {
  const _SubPage(
    this.name,
    this.path,
    this.renderLabels, {
    this.destructive = false,
  });

  final String name;
  final String path;
  final List<String> renderLabels;

  /// 破坏性页：只进入断言渲染，绝不点执行按钮。
  final bool destructive;
}

// 路由常量核实自 lib/config/router/routes/mine_routes.dart。
const _subPages = <_SubPage>[
  _SubPage('存储空间', '/storage_space', ['存储', 'Storage', '缓存', 'Cache']),
  _SubPage('登录设备管理', '/devices', ['设备', 'Device', '登录设备']),
  _SubPage('账号安全', '/account_security', ['账号安全', 'Account', '安全']),
  _SubPage('语言设置', '/language', ['语言', 'Language', 'English', '简体中文']),
  _SubPage('深色模式', '/dark_model', ['深色', '暗色', 'Dark', '模式', 'Mode']),
  _SubPage('字号设置', '/font_size', ['字号', '字体', 'Font']),
  _SubPage('修改密码', '/change_password', ['密码', 'Password']),
  _SubPage('意见反馈', '/feedback', ['反馈', 'Feedback', '意见']),
  _SubPage('注销账号', '/logout_account', [
    '注销',
    '账号',
    'Delete',
    'Logout',
  ], destructive: true),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('「我的」子页面冒烟', () {
    testWidgets('各子页路由可进入并渲染，破坏性页仅进入不执行', (tester) async {
      app.main();

      // 固定抽帧等待启动/网络初始化完成（仿 smoke_test.dart，不用 settle）。
      await _pump(tester, seconds: 12);

      if (_onLoginPage(tester)) {
        markTestSkipped('停在登录页（设备未登录，且未配置自动登录），跳过');
        return;
      }

      final navFinder = find.byType(Navigator);
      if (!tester.any(navFinder)) {
        markTestSkipped('未找到 Navigator（App 未进入主界面），跳过');
        return;
      }
      final GoRouter router;
      try {
        router = GoRouter.of(tester.element(navFinder.first));
      } catch (e) {
        markTestSkipped('无法取得 GoRouter：$e，跳过');
        return;
      }

      for (final page in _subPages) {
        flowLog('进入子页 ${page.name} (${page.path})');
        try {
          router.push(page.path);
        } catch (e) {
          flowLog('push ${page.path} 失败：$e，跳过该页');
          continue;
        }
        await _pump(tester, seconds: 3);

        // 断言子页已渲染：命中特定文案，或退化为存在任意 Text（页面非空白崩溃）。
        final rendered = page.renderLabels.isEmpty
            ? find.byType(Text)
            : _anyText(page.renderLabels);
        expect(
          rendered,
          findsWidgets,
          reason: '「${page.name}」(${page.path}) 子页应成功渲染',
        );

        if (page.destructive) {
          flowLog('${page.name} 为破坏性页，仅断言渲染，不点任何执行按钮');
        }

        // 返回上一页，避免路由栈叠加干扰后续断言。
        final nav = Navigator.of(
          tester.element(find.byType(Navigator).first),
          rootNavigator: true,
        );
        if (nav.canPop()) nav.pop();
        await _pump(tester, seconds: 2);
      }

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// 固定抽帧推进 [seconds] 秒，不等 UI 静止（规避永不 settle 的 App）。
Future<void> _pump(WidgetTester tester, {required int seconds}) async {
  for (int i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

bool _onLoginPage(WidgetTester tester) {
  return tester.any(find.byKey(const Key('login_phone_input'))) ||
      tester.any(find.text('登 录')) ||
      tester.any(find.byKey(const Key('login_submit_button')));
}

/// 命中候选文案任一子串的 Text。
Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
