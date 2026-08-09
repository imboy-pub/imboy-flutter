// integration_test/chat/chat_setting_locale_test.dart
//
// 聊天设置页国际化及语言实时切换测试
//

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';

import '../flows/test_utils.dart'
    show
        flowLog,
        drainKnownFrameworkExceptions,
        autoLoginOrSkip,
        waitForEntryState,
        isOnMainShell;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('聊天设置页国际化测试', () {
    testWidgets('切换系统语言后页面实时刷新', (tester) async {
      app.main();

      // 抽帧等待启动/网络初始化完成。
      await _pump(tester, seconds: 5);

      // 等待页面加载（欢迎页、登录页或主界面）
      flowLog('等待页面加载...');
      for (int i = 0; i < 40; i++) {
        final hasSkip =
            tester.any(find.text('跳过')) || tester.any(find.text('Skip'));
        final isLogin =
            tester.any(find.byKey(const Key('login_phone_input'))) ||
            tester.any(find.text('登录')) ||
            tester.any(find.text('登 录'));
        final isMain =
            tester.any(find.byType(BottomNavigationBar)) ||
            tester.any(find.byType(NavigationBar)) ||
            tester.any(find.byType(BottomAppBar)) ||
            tester.any(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
              ),
            );

        if (hasSkip || isLogin || isMain) {
          flowLog('页面已加载：hasSkip=$hasSkip, isLogin=$isLogin, isMain=$isMain');
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 如果在欢迎页，点击跳过以进入登录页
      final skipFinder = find.text('跳过');
      final skipEnFinder = find.text('Skip');
      if (tester.any(skipFinder)) {
        flowLog('在欢迎页，点击跳过');
        await tester.tap(skipFinder.first);
        await _pump(tester, seconds: 4);
      } else if (tester.any(skipEnFinder)) {
        flowLog('On welcome page, clicking Skip');
        await tester.tap(skipEnFinder.first);
        await _pump(tester, seconds: 4);
      }

      // 等待进入可操作入口（登录页或主界面）
      flowLog('等待进入可操作界面...');
      await waitForEntryState(tester);

      // 如果未登录，执行自动登录
      flowLog('执行自动登录检查...');
      await autoLoginOrSkip(tester);

      // 确保进入了主界面（完成登录后的所有跳转和重定向）
      flowLog('确保完全进入了主界面...');
      for (int i = 0; i < 40; i++) {
        if (isOnMainShell(tester)) {
          flowLog('已进入主界面 shell');
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
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

      // 我们使用我们在 logcat 里面看到的真实 peerId: 104603643803863040
      const peerId = '104603643803863040';
      const path = '/chat_setting/$peerId';

      flowLog('进入聊天设置页 ($path)');
      try {
        router.push(path);
      } catch (e) {
        markTestSkipped('push $path 失败：$e，跳过');
        return;
      }

      await _pump(tester, seconds: 4);

      // 1. 设置语言为中文 zh-CN，确认标题为「聊天设置」
      flowLog('1. 切换语言为 简体中文 (zh-CN)');
      LocaleSettings.setLocale(AppLocale.zhCn);
      await _pump(tester, seconds: 2);

      expect(
        find.text('聊天设置'),
        findsOneWidget,
        reason: '切换为 zh-CN 后，AppBar 标题应实时更新为「聊天设置」',
      );

      // 2. 设置语言为英文 en-US，确认标题为「Chat settings」
      flowLog('2. 切换语言为 英文 (en-US)');
      LocaleSettings.setLocale(AppLocale.enUs);
      await _pump(tester, seconds: 2);

      expect(
        find.text('Chat settings'),
        findsOneWidget,
        reason: '切换为 en-US 后，AppBar 标题应实时更新为「Chat settings」',
      );

      // 3. 恢复中文
      flowLog('3. 恢复语言为 简体中文 (zh-CN)');
      LocaleSettings.setLocale(AppLocale.zhCn);
      await _pump(tester, seconds: 2);

      expect(
        find.text('聊天设置'),
        findsOneWidget,
        reason: '恢复为 zh-CN 后，AppBar 标题应恢复为「聊天设置」',
      );

      // 返回
      final nav = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (nav.canPop()) nav.pop();
      await _pump(tester, seconds: 2);

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<void> _pump(WidgetTester tester, {required int seconds}) async {
  for (int i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}
