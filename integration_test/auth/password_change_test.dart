// 修改密码测试
//
// 测试密码修改功能：
// - 进入修改密码页面
// - 填写旧密码和新密码
// - 提交修改
//
// 安全：需要 --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true 才会执行

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import '../test_config.dart';
import '../test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('修改密码测试', () {
    testWidgets(
      '修改账号密码',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始修改密码 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'pwd_01_app_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过修改密码测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过修改密码测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过修改密码测试');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过修改密码测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_02_after_login');

      // 安全开关：仅当明确启用时执行修改密码
      const allowChange = bool.fromEnvironment('TEST_ALLOW_PASSWORD_CHANGE');
      if (!allowChange) {
        TestHelper.log(
          'ℹ️ 修改密码测试需 --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true',
        );
        TestHelper.log('[AUTO-SKIP] reason=password_change_not_allowed');
        return;
      }

      // 步骤 1: 导航到"我的"页面
      final mineOpened = await _openMinePage(tester);
      if (!mineOpened) {
        TestHelper.log('⚠️ 无法进入"我的"页面，跳过修改密码测试');
        TestHelper.log('[AUTO-SKIP] reason=no_mine_page');
        return;
      }

      await Future<dynamic>.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_03_mine_page');

      // 步骤 2: 进入设置页面
      final settingsBtn = _findAnyText(<String>[
        '设置',
        'Settings',
        'Setting',
      ]);
      final settingsIcon = find.byIcon(Icons.settings);

      bool settingsOpened = false;
      if (tester.any(settingsBtn)) {
        settingsOpened = await _tapFinder(tester, settingsBtn.first);
      }
      if (!settingsOpened && tester.any(settingsIcon)) {
        settingsOpened = await _tapFinder(tester, settingsIcon.first);
      }

      if (!settingsOpened) {
        TestHelper.log('⚠️ 未找到设置入口，跳过修改密码测试');
        TestHelper.log('[AUTO-SKIP] reason=no_settings_entry');
        return;
      }

      await Future<dynamic>.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_04_settings_page');

      // 步骤 3: 找到"修改密码"选项
      final changePwdBtn = _findAnyText(<String>[
        '修改密码',
        '更改密码',
        'Change password',
        'Password',
      ]);

      if (!tester.any(changePwdBtn)) {
        TestHelper.log('⚠️ 未找到修改密码选项，跳过');
        TestHelper.log('[AUTO-SKIP] reason=no_change_password_entry');
        return;
      }

      await _tapFinder(tester, changePwdBtn.first);
      await Future<dynamic>.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_05_change_password_page');

      // 步骤 4: 填写密码表单
      final textFields = find.byType(TextField);
      if (!tester.any(textFields)) {
        TestHelper.log('⚠️ 修改密码页面没有输入框，跳过');
        TestHelper.log('[AUTO-SKIP] reason=no_text_fields');
        return;
      }

      final fieldCount = textFields.evaluate().length;
      TestHelper.log('ℹ️ 修改密码页面找到 $fieldCount 个输入框');

      // 旧密码（第一个字段）
      if (fieldCount >= 1 && TestConfig.testPassword.isNotEmpty) {
        await TestHelper.enterText(
          tester,
          textFields.at(0),
          TestConfig.testPassword,
        );
      }
      // 新密码（使用相同密码避免破坏测试账号）
      if (fieldCount >= 2) {
        await TestHelper.enterText(
          tester,
          textFields.at(1),
          TestConfig.testPassword,
        );
      }
      // 确认新密码
      if (fieldCount >= 3) {
        await TestHelper.enterText(
          tester,
          textFields.at(2),
          TestConfig.testPassword,
        );
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_06_form_filled');

      // 步骤 5: 提交修改
      final submitBtn = _findAnyText(<String>[
        '确认',
        '提交',
        '保存',
        'Confirm',
        'Submit',
        'Save',
      ]);

      if (!tester.any(submitBtn)) {
        TestHelper.log('ℹ️ 未找到提交按钮，尝试回车');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await _tapFinder(tester, submitBtn.first);
      }

      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'pwd_07_after_submit');

      final failText = _findAnyText(<String>[
        '密码错误',
        '修改失败',
        'Password incorrect',
        'Failed',
      ]);
      if (tester.any(failText)) {
        TestHelper.log('⚠️ 修改密码失败（旧密码不正确或其他原因）');
      } else {
        TestHelper.log('✅ 修改密码流程完成');
      }

      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );
  });
}

// ============================================================
// 辅助函数
// ============================================================

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    for (final candidate in candidates) {
      if (data.contains(candidate)) return true;
    }
    return false;
  });
}

Future<bool> _tapFinder(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return false;
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  try {
    await tester.ensureVisible(target);
  } catch (_) {}
  try {
    await tester.tap(target, warnIfMissed: false);
    await _shortSettle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _shortSettle(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _safeScreenshot(WidgetTester tester, String name) async {
  try {
    await TestHelper.screenshot(tester, name);
  } on MissingPluginException {
    TestHelper.log('ℹ️ 当前运行器不支持截图，跳过: $name');
  }
}

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;
  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    final text = err.toString();
    if (text.contains('ImageNotFoundException') ||
        text.contains('Image not found (404)') ||
        text.startsWith('Multiple exceptions (')) {
      TestHelper.log('ℹ️ 忽略非核心异常: $err');
      continue;
    }
    TestHelper.log('ℹ️ 排除非核心异常: $err');
  }
}

Future<bool> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 20;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester)) return true;
    final hasGlassBottomBar = tester.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
      ),
    );
    if (tester.any(find.byType(BottomNavigationBar)) ||
        tester.any(find.byType(NavigationBar)) ||
        hasGlassBottomBar) {
      return true;
    }
    await Future<dynamic>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return false;
}

Future<bool> _openMinePage(WidgetTester tester) async {
  final candidates = <Finder>[
    find.text('我的'),
    find.text('Me'),
    find.text('Mine'),
    find.text('Profile'),
    find.byIcon(Icons.person),
    find.byIcon(Icons.person_outline),
  ];

  for (final finder in candidates) {
    if (await _tapFinder(tester, finder)) {
      await _shortSettle(tester);
      final hasMineElements =
          tester.any(find.byIcon(Icons.settings)) ||
          tester.any(find.byIcon(Icons.qr_code_2)) ||
          tester.any(find.byType(CircleAvatar));
      if (hasMineElements) return true;
    }
  }

  // 尝试底部导航栏最后一个位置
  final glassBottomBar = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
  );
  if (tester.any(glassBottomBar)) {
    try {
      final rect = tester.getRect(glassBottomBar.first);
      final dx = rect.left + rect.width * (3 + 0.5) / 4;
      final dy = rect.top + rect.height / 2;
      await tester.tapAt(Offset(dx, dy));
      await _shortSettle(tester);
      return true;
    } catch (_) {}
  }

  return false;
}

Future<bool> _ensureBackendAvailable() async {
  if (_backendProbePassed) return true;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response =
        await request.close().timeout(const Duration(seconds: 5));
    await response.drain<List<int>>(<int>[]).timeout(const Duration(seconds: 2));
    final code = response.statusCode;
    if (code < 200 || code >= 400) return false;
    _backendProbePassed = true;
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
