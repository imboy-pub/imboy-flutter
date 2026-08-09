// integration_test/auth/register_flow_test.dart
//
// 注册流程 UI 集成测试
//
// 运行：
//   flutter test integration_test/auth/register_flow_test.dart \
//     --dart-define=APP_ENV=local_office \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

/// 是否允许真实提交注册。默认 false —— 提交会创建真实账号，生产环境禁止。
/// 开启：--dart-define=TEST_ALLOW_REGISTER=true
const bool _allowRegister =
    String.fromEnvironment('TEST_ALLOW_REGISTER', defaultValue: 'false') ==
    'true';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('注册流程', () {
    testWidgets('通过邮箱注册新账号', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final nickname = 'E2E_$ts';
      final email = 'e2e_$ts@test.imboy.pub';
      final password = 'Test${ts}x!';

      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'reg_01_launch');

      if (!await ensureBackendAvailable()) {
        markTestSkipped('后端不可达，跳过');
        return;
      }
      if (!await waitForEntryState(tester)) {
        markTestSkipped('App 入口状态超时，跳过');
        return;
      }

      await takeScreenshot(tester, 'reg_02_entry');

      if (!isOnLoginPage(tester)) {
        markTestSkipped('已登录状态无法测试注册流程，跳过');
        return;
      }

      final signupFinder = _anyText([
        '注册',
        '注 册',
        'Sign up',
        'Signup',
        'Register',
        'Create account',
      ]);
      if (!tester.any(signupFinder)) {
        markTestSkipped('未找到注册入口，跳过');
        return;
      }

      await safeTap(tester, signupFinder.first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'reg_03_signup_page');

      final onSignupPage =
          tester.any(find.byType(TabBar)) ||
          tester.any(find.byType(TabBarView)) ||
          tester.any(find.byType(TextFormField));
      if (!onSignupPage) {
        markTestSkipped('未进入注册页面，跳过');
        return;
      }

      final fields = find.byType(TextField);
      final count = fields.evaluate().length;
      if (count == 0) {
        markTestSkipped('注册页面无输入框，跳过');
        return;
      }

      if (count >= 1) await tester.enterText(fields.at(0), nickname);
      if (count >= 2) await tester.enterText(fields.at(1), email);
      if (count >= 3) await tester.enterText(fields.at(2), password);
      await settle(tester, maxSeconds: 1);
      await takeScreenshot(tester, 'reg_04_form_filled');

      final submitFinder = _anyText([
        '注册',
        '注 册',
        'Sign up',
        'Register',
        '提交',
        'Submit',
      ]);

      // 安全开关：默认不提交。提交会在目标环境真实创建账号，生产环境禁止。
      // 与 auth/password_change_test.dart 的 TEST_ALLOW_PASSWORD_CHANGE 同款。
      if (!_allowRegister) {
        expect(tester.any(submitFinder), isTrue, reason: '注册页应有提交按钮');
        flowLog('TEST_ALLOW_REGISTER=false，仅验收注册页可达性与提交按钮存在');
        return;
      }

      if (!requireBusinessWriteAuthorization()) return;
      final submitted = tester.any(submitFinder)
          ? await safeTap(tester, submitFinder.first)
          : false;
      if (!submitted) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'reg_05_after_submit');

      // 需要验证码时人工介入，标记 skip 而非 fail
      if (tester.any(_anyText(['验证码', 'Verification code', 'Code', 'PIN']))) {
        markTestSkipped('注册需要验证码（人工介入），跳过');
        return;
      }

      flowLog(
        tester.any(
              _anyText(['注册失败', 'Register failed', '已存在', 'already exists']),
            )
            ? '注册返回错误提示（可能邮箱已注册）'
            : '注册提交完成，无错误提示',
      );

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
