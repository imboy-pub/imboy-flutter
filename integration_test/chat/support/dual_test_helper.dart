import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class DualTestConfig {
  DualTestConfig._();

  static String get testPhone {
    return const String.fromEnvironment('TEST_PHONE', defaultValue: '');
  }

  static String get testPassword {
    return const String.fromEnvironment('TEST_PASSWORD', defaultValue: '');
  }

  static String get testCode {
    return const String.fromEnvironment('TEST_CODE', defaultValue: '');
  }

  static bool get isConfigured {
    return testPhone.isNotEmpty &&
        (testPassword.isNotEmpty || testCode.isNotEmpty);
  }
}

class DualTestHelper {
  static void log(String message) {
    print('[TEST] $message');
  }

  static bool needsLogin(WidgetTester tester) {
    return tester.any(find.text('登录')) ||
        tester.any(find.text('登 录')) ||
        tester.any(find.text('Login'));
  }

  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  static Future<bool> autoLogin(WidgetTester tester) async {
    if (!needsLogin(tester)) {
      log('✅ already logged in');
      return true;
    }

    if (!DualTestConfig.isConfigured) {
      log('⚠️ missing TEST_PHONE + TEST_PASSWORD/TEST_CODE');
      return false;
    }

    try {
      final fields = find.byType(TextField);
      if (!tester.any(fields)) return false;

      await enterText(tester, fields.first, DualTestConfig.testPhone);
      if (DualTestConfig.testPassword.isNotEmpty && tester.any(fields.at(1))) {
        await enterText(tester, fields.at(1), DualTestConfig.testPassword);
      } else if (DualTestConfig.testCode.isNotEmpty &&
          tester.any(fields.at(1))) {
        await enterText(tester, fields.at(1), DualTestConfig.testCode);
      }

      final tapped = await _tapAny(tester, <Finder>[
        find.text('登录'),
        find.text('登 录'),
        find.text('Login'),
      ]);
      if (!tapped) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (needsLogin(tester)) {
        log('⚠️ login submitted but still on login page');
        return false;
      }
      return true;
    } catch (e) {
      log('❌ autoLogin failed: $e');
      return false;
    }
  }

  static Future<void> screenshot(
    WidgetTester tester,
    String name, {
    bool waitForReady = true,
  }) async {
    if (waitForReady) {
      await tester.pumpAndSettle();
    }

    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    // Web 平台 takeScreenshot 会触发无限 App resumed 循环，跳过
    final bool isWeb = identical(0.0, 0);
    if (isWeb) {
      log('⚠️ Web skip screenshot($name)');
      return;
    }

    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      log('⚠️ screenshot failed($name): $e');
    }
  }

  static Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
    for (final finder in finders) {
      if (!tester.any(finder)) continue;
      try {
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
        return true;
      } catch (_) {}
    }
    return false;
  }
}
