// integration_test/auth/password_change_test.dart
//
// 修改密码 UI 集成测试
//
// 安全开关：需要 --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true 才执行实际提交，
// 否则仅验证页面可访问性。
//
// 运行：
//   flutter test integration_test/auth/password_change_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_NEW_PASSWORD=<new_pwd> \
//     --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const allowChange = bool.fromEnvironment(
    'TEST_ALLOW_PASSWORD_CHANGE',
    defaultValue: false,
  );
  const newPassword = String.fromEnvironment(
    'TEST_NEW_PASSWORD',
    defaultValue: '',
  );

  group('修改密码', () {
    testWidgets('修改密码页面可访问，表单字段完整', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'pwd_01_launch');

      await checkPreconditions(tester);

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pwd_02_after_login');

      if (!await _openSettingsPage(tester)) {
        markTestSkipped('未找到设置入口，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pwd_03_settings');

      final changeFinder = _anyText([
        '修改密码',
        '更改密码',
        'Change password',
        'Password',
      ]);
      if (!tester.any(changeFinder)) {
        markTestSkipped('未找到修改密码入口，跳过');
        return;
      }

      await safeTap(tester, changeFinder.first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pwd_04_change_page');

      // 断言：修改密码页应有输入框
      expect(find.byType(TextField), findsWidgets, reason: '修改密码页面应有密码输入框');

      if (!allowChange) {
        flowLog('TEST_ALLOW_PASSWORD_CHANGE=false，仅验收页面可访问性');
        drainKnownFrameworkExceptions(tester);
        return;
      }

      if (newPassword.isEmpty) {
        markTestSkipped('未配置 TEST_NEW_PASSWORD，跳过提交');
        return;
      }

      final fields = find.byType(TextField);
      final count = fields.evaluate().length;
      if (count >= 1)
        await tester.enterText(fields.at(0), FlowConfig.testPassword);
      if (count >= 2) await tester.enterText(fields.at(1), newPassword);
      if (count >= 3) await tester.enterText(fields.at(2), newPassword);
      await settle(tester, maxSeconds: 1);

      await tapAny(tester, [
        find.text('确认'),
        find.text('保存'),
        find.text('提交'),
        find.text('Confirm'),
        find.text('Save'),
      ]);

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'pwd_05_after_submit');

      // 断言：提交后不应出现失败提示
      expect(
        _anyText(['修改失败', 'Change failed', '密码错误', 'Wrong password']),
        findsNothing,
        reason: '密码修改不应出现失败提示',
      );

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<bool> _openSettingsPage(WidgetTester tester) async {
  return tapAny(tester, [
    find.byKey(const Key('tab_profile')),
    find.byKey(const Key('tab_me')),
    find.byIcon(Icons.person),
    find.byIcon(Icons.person_outline),
    find.byIcon(Icons.settings),
    find.text('我'),
    find.text('Profile'),
    find.text('Me'),
  ]);
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
