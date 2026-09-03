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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/account_security/account_security_page.dart';
import 'package:imboy/page/mine/change_password/change_password_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '',
);

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
      if (_expectedUid.isEmpty) {
        markTestSkipped('需显式 TEST_EXPECTED_UID，禁止对未知账号执行改密流程');
        return;
      }
      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'pwd_01_launch');

      if (!await checkPreconditions(tester)) return;
      final actualUid = UserRepoLocal.to.currentUid;
      if (actualUid != _expectedUid) {
        fail('登录账号 UID=$actualUid 与授权账号 $_expectedUid 不一致');
      }

      await settle(tester, maxSeconds: 2);
      // pm clear 后首登必弹 E2EE 恢复指南（CupertinoAlertDialog），
      // 不关掉会挡住底部 Tab 导致 MinePage 永远不挂载。
      await dismissRecoveryGuide(tester);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pwd_02_after_login');

      await _openChangePasswordPage(tester);
      await takeScreenshot(tester, 'pwd_04_change_page');

      final page = find.byType(ChangePasswordPage);
      final fields = find.descendant(
        of: page,
        matching: find.byType(CupertinoTextField),
      );
      expect(fields, findsNWidgets(3), reason: '修改密码页面应有旧密码、新密码、确认密码三个输入框');

      if (!allowChange) {
        flowLog('TEST_ALLOW_PASSWORD_CHANGE=false，仅验收页面可访问性');
        drainKnownFrameworkExceptions(tester);
        return;
      }

      if (newPassword.isEmpty) {
        markTestSkipped('未配置 TEST_NEW_PASSWORD，跳过提交');
        return;
      }

      if (!requireBusinessWriteAuthorization()) return;
      await tester.enterText(fields.at(0), FlowConfig.testPassword);
      await tester.enterText(fields.at(1), newPassword);
      await tester.enterText(fields.at(2), newPassword);
      await settle(tester, maxSeconds: 1);

      final saveButton = find.ancestor(
        of: _anyText(['保存', 'Save']),
        matching: find.byType(CupertinoButton),
      );
      expect(saveButton, findsOneWidget, reason: '修改密码页面应有唯一保存按钮');
      expect(
        tester.widget<CupertinoButton>(saveButton).onPressed,
        isNotNull,
        reason: '三个密码字段有效后保存按钮应启用',
      );
      await tester.tap(saveButton);

      final success = _anyText([
        '修改成功',
        '登录密码已更新',
        'Changed successfully',
        'Login password updated',
      ]);
      for (var i = 0; i < 20 && !tester.any(success); i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await takeScreenshot(tester, 'pwd_05_after_submit');
      expect(success, findsWidgets, reason: '提交后必须出现明确的密码修改成功提示');

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<void> _openChangePasswordPage(WidgetTester tester) async {
  if (!tester.any(find.byType(MinePage))) {
    // 诊断：记录当前可见文本与弹窗，便于定位 Tab 不可达的原因。
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.trim().isNotEmpty)
        .take(40)
        .join(' | ');
    flowLog('导航前可见文本: $texts');
    flowLog(
      '弹窗存在: ${tester.any(find.byType(CupertinoAlertDialog))}, '
      'tab_mine存在: ${tester.any(find.byKey(const Key('tab_mine')))}',
    );
    final openedMine = await tapAny(tester, [
      find.byKey(const Key('tab_mine')),
      find.byKey(const Key('tab_profile')),
      find.byKey(const Key('tab_me')),
      find.byIcon(Icons.person),
      find.byIcon(Icons.person_outline),
      find.text('我'),
      find.text('Profile'),
      find.text('Me'),
    ]);
    expect(openedMine, isTrue, reason: '主导航应提供“我的”入口');
    await settle(tester, maxSeconds: 2);
  }
  expect(find.byType(MinePage), findsOneWidget, reason: '应进入“我的”页面');

  expect(
    await tapAny(tester, [
      _anyText(['设置', 'Settings']),
      find.byIcon(CupertinoIcons.settings),
    ]),
    isTrue,
    reason: '“我的”页面应提供设置入口',
  );
  await settle(tester, maxSeconds: 2);
  expect(find.byType(SettingPage), findsOneWidget, reason: '应进入设置页面');
  await takeScreenshot(tester, 'pwd_03_settings');

  expect(
    await tapAny(tester, [
      _anyText(['账号安全', 'Account security']),
    ]),
    isTrue,
    reason: '设置页面应提供账号安全入口',
  );
  await settle(tester, maxSeconds: 2);
  expect(find.byType(AccountSecurityPage), findsOneWidget, reason: '应进入账号安全页面');

  expect(
    await tapAny(tester, [
      _anyText(['修改登录密码', '修改密码', 'Change login password']),
    ]),
    isTrue,
    reason: '账号安全页面应提供修改登录密码入口',
  );
  await settle(tester, maxSeconds: 2);
  expect(
    find.byType(ChangePasswordPage),
    findsOneWidget,
    reason: '应进入修改登录密码页面',
  );
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
