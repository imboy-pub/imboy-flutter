// DEPRECATED: 此文件已无 import 引用，请勿新增依赖。
// 共享工具请使用 integration_test/flows/test_utils.dart。

import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_config.dart';

class TestHelper {
  /// 等待 Widget 出现
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(finder)) {
        return;
      }
    }
    // ignore: deprecated_member_use
    throw TimeoutException('等待 Widget 超时: ${finder.description}', timeout);
  }

  /// 等待文本出现
  static Future<void> waitForText(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await waitForWidget(tester, find.text(text), timeout: timeout);
  }

  /// 安全点击（如果存在则点击）
  static Future<bool> safeTap(WidgetTester tester, Finder finder) async {
    if (!tester.any(finder)) return false;

    // 当 Finder 匹配多个组件时，优先点击第一个，避免 ambiguous finder 异常。
    final target = finder.evaluate().length > 1 ? finder.first : finder;
    await tester.tap(target);
    await tester.pumpAndSettle();
    return true;
  }

  /// 输入文本到指定字段
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// 截图并保存
  static Future<void> screenshot(
    WidgetTester tester,
    String name, {
    bool waitForReady = true,
  }) async {
    if (waitForReady) {
      await tester.pumpAndSettle();
    }
    final binding = IntegrationTestWidgetsFlutterBinding.instance;

    // Android 设备截图前通常需要先转换渲染表面；其他平台会忽略该步骤。
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    // Web 平台 takeScreenshot 会触发无限 App resumed 循环，跳过
    final bool isWeb = identical(0.0, 0);
    if (isWeb) {
      log('⚠️ Web 平台跳过截图($name)');
      return;
    }

    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      log('⚠️ 截图失败($name): $e');
    }
  }

  /// 打印测试步骤
  static void log(String message) {
    print('[TEST] $message');
  }

  /// 重试操作
  static Future<T> retry<T>(
    T Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        return operation();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;
        await Future<dynamic>.delayed(delay);
      }
    }
    throw StateError('重试失败');
  }

  // ============================================================
  // 登录辅助方法
  // ============================================================

  /// 执行登录流程
  ///
  /// [phone] 手机号
  /// [password] 密码（可选）
  /// [code] 验证码（可选）
  /// Returns: 登录是否成功
  static Future<bool> performLogin(
    WidgetTester tester, {
    required String phone,
    String? password,
    String? code,
  }) async {
    log('🔐 开始登录流程: phone=$phone');

    try {
      // 1. 查找手机号输入框（通常是第一个 TextField）
      final phoneFields = find.byType(TextField);
      if (!tester.any(phoneFields)) {
        log('❌ 未找到输入框');
        return false;
      }

      // 2. 输入手机号
      final phoneField = phoneFields.first;
      await enterText(tester, phoneField, phone);
      log('✅ 已输入手机号');
      await tester.pumpAndSettle();

      // 3. 如果有密码，输入密码
      if (password != null && password.isNotEmpty) {
        // 查找密码输入框（通常是第二个 TextField）
        if (tester.any(phoneFields.at(1))) {
          await enterText(tester, phoneFields.at(1), password);
          log('✅ 已输入密码');
        }
      }

      // 4. 如果有验证码，输入验证码
      if (code != null && code.isNotEmpty) {
        // 查找验证码输入框
        if (tester.any(phoneFields.at(1))) {
          await enterText(tester, phoneFields.at(1), code);
          log('✅ 已输入验证码');
        }
      }

      // 5. 点击登录按钮
      final loginButton = find.text('登录');
      final loginButton2 = find.text('登 录');
      final loginButton3 = find.text('Login');

      bool tapped = false;
      if (await safeTap(tester, loginButton)) {
        log('✅ 已点击登录按钮');
        tapped = true;
      } else if (await safeTap(tester, loginButton2)) {
        log('✅ 已点击登录按钮');
        tapped = true;
      } else if (await safeTap(tester, loginButton3)) {
        log('✅ 已点击登录按钮');
        tapped = true;
      }

      if (!tapped) {
        log('⚠️ 未找到登录按钮，尝试按回车提交');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }

      // 6. 等待登录完成
      await tester.pumpAndSettle();
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 登录动作提交后若仍停留在登录页，视为登录失败，避免误判成功。
      if (needsLogin(tester)) {
        log('❌ 登录后仍停留在登录页，判定登录失败');
        return false;
      }

      return true;
    } catch (e) {
      log('❌ 登录流程失败: $e');
      return false;
    }
  }

  /// 检查是否需要登录
  ///
  /// Returns: true 如果需要登录
  static bool needsLogin(WidgetTester tester) {
    final loginButton = find.text('登录');
    final loginButton2 = find.text('登 录');
    return tester.any(loginButton) || tester.any(loginButton2);
  }

  /// 执行自动登录（使用 TestConfig 配置）
  ///
  /// Returns: true 如果登录成功或已登录
  static Future<bool> autoLogin(WidgetTester tester) async {
    // 检查是否需要登录
    if (!needsLogin(tester)) {
      log('✅ 已登录，无需重新登录');
      return true;
    }

    // 检查配置
    if (!TestConfig.isConfigured) {
      log('⚠️ 测试账号未配置，跳过自动登录');
      TestConfig.printHelp();
      return false;
    }

    // 执行登录
    return performLogin(
      tester,
      phone: TestConfig.testPhone,
      password: TestConfig.testPassword.isNotEmpty
          ? TestConfig.testPassword
          : null,
      code: TestConfig.testCode.isNotEmpty ? TestConfig.testCode : null,
    );
  }

  // ============================================================
  // 后端 API 验证辅助方法
  // ============================================================

  /// 探活后端是否可达
  ///
  /// [baseUrl] 后端基地址，默认 http://127.0.0.1:9800
  /// [path] 探活路径，默认 /v1/app/init_config
  /// [timeoutSeconds] 超时秒数
  /// Returns: HTTP 状态码，null 表示连接失败
  static Future<int?> probeBackend({
    String baseUrl = 'http://127.0.0.1:9800',
    String path = '/v1/app/init_config',
    int timeoutSeconds = 5,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSeconds)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    try {
      final request =
          await client.getUrl(uri).timeout(Duration(seconds: timeoutSeconds));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request
          .close()
          .timeout(Duration(seconds: timeoutSeconds));
      await response.drain<List<int>>(<int>[]).timeout(
        const Duration(seconds: 2),
      );
      log('后端探活: $uri → ${response.statusCode}');
      return response.statusCode;
    } on async.TimeoutException {
      log('后端探活超时: $uri');
      return null;
    } on SocketException catch (e) {
      log('后端探活连接失败: $uri - $e');
      return null;
    } catch (e) {
      log('后端探活异常: $uri - $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 发送 GET 请求到后端 API
  ///
  /// [baseUrl] 后端基地址
  /// [path] API 路径
  /// [token] 可选的 Bearer token
  /// Returns: 解析后的 JSON Map，失败返回 null
  static Future<Map<String, dynamic>?> apiGet({
    required String baseUrl,
    required String path,
    String? token,
    int timeoutSeconds = 10,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSeconds)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    try {
      final request =
          await client.getUrl(uri).timeout(Duration(seconds: timeoutSeconds));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request
          .close()
          .timeout(Duration(seconds: timeoutSeconds));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(body) as Map<String, dynamic>;
      }
      log('API GET $path → ${response.statusCode}: $body');
      return null;
    } catch (e) {
      log('API GET $path 异常: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration duration;

  TimeoutException(this.message, this.duration);

  @override
  String toString() => '$message (超时: ${duration.inSeconds}秒)';
}
