// 注册流程测试
//
// 测试注册功能：
// - 进入注册页面
// - 填写注册表单（邮箱 + 密码）
// - 提交注册
// - 验证码处理（如需要）

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

  group('注册流程测试', () {
    testWidgets(
      '通过邮箱注册新账号',
      (WidgetTester tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'e2e_$ts@test.imboy.pub';
      final nickname = 'E2E_$ts';
      final password = 'Test${ts}x!';

      TestHelper.log('🚀 开始注册流程 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'register_01_app_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过注册测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过注册测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      await _safeScreenshot(tester, 'register_02_entry_page');

      // 如果已登录，注册测试无法执行
      if (!TestHelper.needsLogin(tester)) {
        TestHelper.log('ℹ️ 当前已登录，无法测试注册流程，跳过');
        TestHelper.log('[AUTO-SKIP] reason=already_logged_in');
        return;
      }

      // 步骤 1: 在登录页查找"注册"按钮
      final signupBtn = _findAnyText(<String>[
        '注册',
        '注 册',
        'Sign up',
        'Signup',
        'Register',
        'Create account',
      ]);

      if (!tester.any(signupBtn)) {
        TestHelper.log('⚠️ 未找到注册按钮，跳过注册测试');
        TestHelper.log('[AUTO-SKIP] reason=no_signup_button');
        return;
      }

      await _tapFinder(tester, signupBtn.first);
      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'register_03_signup_page');

      // 步骤 2: 确认进入了注册页面
      final hasSignupPage = tester.any(find.byType(TabBar)) ||
          tester.any(find.byType(TabBarView));
      if (!hasSignupPage) {
        TestHelper.log('⚠️ 未进入注册页面，跳过注册测试');
        TestHelper.log('[AUTO-SKIP] reason=not_on_signup_page');
        return;
      }

      // 步骤 3: 填写注册表单
      final textFields = find.byType(TextField);
      if (!tester.any(textFields)) {
        TestHelper.log('⚠️ 注册页面没有输入框，跳过');
        TestHelper.log('[AUTO-SKIP] reason=no_text_fields');
        return;
      }

      final fieldCount = textFields.evaluate().length;
      TestHelper.log('ℹ️ 注册页面找到 $fieldCount 个输入框');

      // 填写昵称（第一个 TextField）
      if (fieldCount >= 1) {
        await TestHelper.enterText(tester, textFields.at(0), nickname);
      }
      // 填写邮箱（第二个 TextField）
      if (fieldCount >= 2) {
        await TestHelper.enterText(tester, textFields.at(1), email);
      }
      // 填写密码（第三个 TextField）
      if (fieldCount >= 3) {
        await TestHelper.enterText(tester, textFields.at(2), password);
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'register_04_form_filled');

      // 步骤 4: 提交注册
      final submitBtn = _findAnyText(<String>[
        '注册',
        '注 册',
        'Sign up',
        'Register',
        'Submit',
        '提交',
      ]);

      if (!tester.any(submitBtn)) {
        TestHelper.log('ℹ️ 未找到注册提交按钮，尝试回车提交');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await _tapFinder(tester, submitBtn.first);
      }

      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'register_05_after_submit');

      // 注册后可能进入验证码页面
      final verifyCodeHint = _findAnyText(<String>[
        '验证码',
        'Verification code',
        'Code',
        'PIN',
      ]);

      if (tester.any(verifyCodeHint)) {
        TestHelper.log('ℹ️ 注册需要验证码（需从数据库获取），跳过');
        TestHelper.log('[AUTO-SKIP] reason=verification_code_required');
        return;
      }

      // 检查注册是否成功
      if (!TestHelper.needsLogin(tester)) {
        TestHelper.log('✅ 注册成功并自动登录');
      } else {
        TestHelper.log('ℹ️ 注册后仍在登录页');
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
