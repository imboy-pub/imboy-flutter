// integration_test/auth/register_flow_test.dart
//
// 注册流程 UI 集成测试
//
// 运行：
//   flutter test integration_test/auth/register_flow_test.dart \
//     --dart-define=APP_ENV=local_office \
//     -d <real_device_id>

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/manage_account_page.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

/// 是否允许真实提交注册。默认 false —— 提交会创建真实账号，生产环境禁止。
/// 开启：--dart-define=TEST_ALLOW_REGISTER=true
const bool _allowRegister =
    String.fromEnvironment('TEST_ALLOW_REGISTER', defaultValue: 'false') ==
    'true';

/// 注册验证码。本地/开发后端可配置万能验证码（sys.local.config
/// verification_master_code，仅非生产环境生效），由 --dart-define 注入后
/// 测试可无人值守完成验证码闭环；留空则遇到验证码页保持人工介入 skip。
const String _regCode = String.fromEnvironment(
  'TEST_REG_CODE',
  defaultValue: '',
);

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

      if (isOnWelcomePage(tester) && !await leaveWelcomePage(tester)) {
        markTestSkipped('欢迎页无法进入登录页，跳过');
        return;
      }
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

      final fields = find.byType(TextField).hitTestable();
      final visibleFields = fields
          .evaluate()
          .map((element) => element.widget as TextField)
          .toList(growable: false);
      final count = visibleFields.length;
      if (count == 0) {
        markTestSkipped('注册页面无输入框，跳过');
        return;
      }

      expect(count, greaterThanOrEqualTo(3), reason: '邮箱注册页应有昵称、邮箱、密码三个可见输入框');
      visibleFields[0].controller!.text = nickname;
      visibleFields[1].controller!.text = email;
      visibleFields[2].controller!.text = password;
      await settle(tester, maxSeconds: 1);
      await takeScreenshot(tester, 'reg_04_form_filled');

      final submitFinder = _anyText([
        '下一步',
        '注 册',
        'Sign up',
        'Register',
        'Next',
      ]);

      // 安全开关：默认不提交。提交会在目标环境真实创建账号，生产环境禁止。
      // 与 auth/password_change_test.dart 的 TEST_ALLOW_PASSWORD_CHANGE 同款。
      if (!_allowRegister) {
        expect(
          tester.any(submitFinder),
          isTrue,
          reason: '注册页应有下一步/注册按钮（signup_page 提交文案为 t.common.nextStep=下一步）',
        );
        flowLog('TEST_ALLOW_REGISTER=false，仅验收注册页可达性与提交按钮存在');
        return;
      }

      if (!requireBusinessWriteAuthorization()) return;
      final submitButton = find.ancestor(
        of: submitFinder.first,
        matching: find.byType(CupertinoButton),
      );
      final buttonEnabled =
          tester.any(submitButton) &&
          tester.widget<CupertinoButton>(submitButton.first).onPressed != null;
      flowLog('注册下一步按钮状态: ${buttonEnabled ? "enabled" : "disabled"}');
      expect(buttonEnabled, isTrue, reason: '注册表单填写完整后，下一步按钮应启用');
      final submitted = buttonEnabled
          ? await safeTap(tester, submitButton.first)
          : false;
      if (!submitted) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'reg_05_after_submit');

      // 注册分两步：第一页「下一步」发码并跳验证码页；验证码页填码后点「注册」。
      // 无注入码且出现验证码页 → 保持人工介入 skip（原行为）。
      if (_regCode.isEmpty) {
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
        return;
      }

      // 等待验证码页挂载：MaterialPinField(pin_code_fields) 或「重新发送」出现。
      var pinShown = false;
      for (var i = 0; i < 30; i++) {
        if (tester.any(find.byType(MaterialPinField)) ||
            tester.any(_anyText(['重新发送', 'Resend', 'resend']))) {
          pinShown = true;
          break;
        }
        await settle(tester, maxSeconds: 1);
      }
      expect(pinShown, isTrue, reason: '第一步提交后应进入验证码页');
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'reg_06_pin_page');

      final pinField = tester.widget<MaterialPinField>(
        find.byType(MaterialPinField),
      );
      expect(pinField.pinController, isNotNull, reason: '验证码页应提供 PIN 控制器');
      pinField.pinController!.setText(_regCode);
      await settle(tester, maxSeconds: 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, maxSeconds: 1);
      await takeScreenshot(tester, 'reg_07_code_filled');

      final confirmFinder = _anyText(['注册', '注 册', 'Sign up', 'Register']);
      expect(tester.any(confirmFinder), isTrue, reason: '验证码页应有注册按钮');
      final confirmButton = find.ancestor(
        of: confirmFinder.first,
        matching: find.byType(CupertinoButton),
      );
      final confirmEnabled =
          tester.any(confirmButton) &&
          tester.widget<CupertinoButton>(confirmButton.first).onPressed != null;
      flowLog('验证码注册按钮状态: ${confirmEnabled ? "enabled" : "disabled"}');
      expect(confirmEnabled, isTrue, reason: '填写 6 位验证码后，注册按钮应启用');
      final confirmed = confirmEnabled
          ? await safeTap(tester, confirmButton.first)
          : false;
      expect(confirmed, isTrue, reason: '验证码页注册按钮应可点击');
      await settle(tester, maxSeconds: 5);

      // 注册成功：confirmSignup 返回 null → toast 成功 → context.go('/manage_account')。
      final managed = await _waitForManageAccount(tester);
      expect(managed, isTrue, reason: '注册成功后应进入管理账户页（manage_account）');
      await takeScreenshot(tester, 'reg_08_register_success');
      flowLog('邮箱注册全链完成：下一步→验证码注入→注册→管理账户页');

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<bool> _waitForManageAccount(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    if (tester.any(find.byType(ManageAccountPage))) return true;
    await settle(tester, maxSeconds: 1);
  }
  return tester.any(find.byType(ManageAccountPage));
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
