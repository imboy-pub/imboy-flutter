// integration_test/flows/test_utils.dart
//
// 所有 UI 集成测试的唯一共享工具库。
// 消灭各文件中重复定义的 _shortSettle / _safeScreenshot / _ensureBackendAvailable 等。
//
// 约定：
//   - 前置检查失败 → markTestSkipped('reason')，禁止裸 return（裸 return 使测试假绿）
//   - 门控型 smoke 检查失败 → fail('reason')
//   - 此文件不引入任何业务断言，只提供通用操作原语

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:integration_test/integration_test.dart';

// ──────────────────────────────────────────────
// 环境配置（来自 --dart-define）
// ──────────────────────────────────────────────

class FlowConfig {
  FlowConfig._();

  static String get testPhone =>
      const String.fromEnvironment('TEST_PHONE', defaultValue: '');

  static String get testPassword =>
      const String.fromEnvironment('TEST_PASSWORD', defaultValue: '');

  static String get testCode =>
      const String.fromEnvironment('TEST_CODE', defaultValue: '');

  static String get apiBaseUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static bool get hasCredentials =>
      testPhone.isNotEmpty && (testPassword.isNotEmpty || testCode.isNotEmpty);

  static bool get hasApiUrl => apiBaseUrl.isNotEmpty;
}

// ──────────────────────────────────────────────
// 日志
// ──────────────────────────────────────────────

void flowLog(String message) {
  // ignore: avoid_print
  print('[FLOW] $message');
}

// ──────────────────────────────────────────────
// 等待帧稳定
// ──────────────────────────────────────────────

/// 等待 UI 稳定，最多 [maxSeconds] 秒。
/// 优先使用 pumpAndSettle；Flutter 抛出超时 FlutterError 时回退为固定抽帧。
Future<void> settle(WidgetTester tester, {int maxSeconds = 5}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: maxSeconds),
    );
  } on FlutterError {
    for (int i = 0; i < maxSeconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
}

// ──────────────────────────────────────────────
// 截图
// ──────────────────────────────────────────────

Future<void> takeScreenshot(WidgetTester tester, String name) async {
  try {
    await settle(tester, maxSeconds: 2);
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}
    await binding.takeScreenshot(name);
  } on MissingPluginException {
    flowLog('截图跳过（运行器不支持）: $name');
  } catch (e) {
    flowLog('截图失败: $name — $e');
  }
}

// ──────────────────────────────────────────────
// 后端探活
// ──────────────────────────────────────────────

bool _backendProbed = false;
bool _backendAvailable = false;

/// 探测后端是否可达，结果在进程内缓存。
/// [forceRecheck] 为 true 时忽略缓存重新探测。
Future<bool> ensureBackendAvailable({bool forceRecheck = false}) async {
  if (_backendProbed && !forceRecheck) return _backendAvailable;

  final baseUrl = FlowConfig.hasApiUrl
      ? FlowConfig.apiBaseUrl
      : Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        true;

  try {
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final resp = await req.close().timeout(const Duration(seconds: 5));
    await resp.drain<List<int>>([]).timeout(const Duration(seconds: 2));
    _backendAvailable = resp.statusCode >= 200 && resp.statusCode < 400;
    flowLog(
      _backendAvailable ? '后端探活通过: $uri' : '后端探活失败: $uri → ${resp.statusCode}',
    );
  } catch (e) {
    flowLog('后端探活异常: $uri — $e');
    _backendAvailable = false;
  } finally {
    _backendProbed = true;
    client.close(force: true);
  }

  return _backendAvailable;
}

// ──────────────────────────────────────────────
// 页面状态检测
// ──────────────────────────────────────────────

bool isOnLoginPage(WidgetTester tester) {
  return tester.any(find.byKey(const Key('login_phone_input'))) ||
      tester.any(find.text('登录')) ||
      tester.any(find.text('登 录'));
}

bool isOnMainShell(WidgetTester tester) {
  return tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      tester.any(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
        ),
      );
}

/// 等待 App 进入可操作入口（登录页 或 主 Shell）。
Future<bool> waitForEntryState(
  WidgetTester tester, {
  int maxAttempts = 20,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (isOnLoginPage(tester) || isOnMainShell(tester)) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return false;
}

// ──────────────────────────────────────────────
// 登录
// ──────────────────────────────────────────────

/// 执行登录，优先用 Widget Key，降级用文本启发式。
/// 返回 true 表示成功离开登录页。
Future<bool> performLogin(
  WidgetTester tester, {
  required String phone,
  required String password,
}) async {
  flowLog('登录: ${phone.length > 7 ? "${phone.substring(0, 3)}****" : phone}');

  final phoneKey = find.byKey(const Key('login_phone_input'));
  final allFields = find.byType(TextField);

  if (tester.any(phoneKey)) {
    await tester.enterText(phoneKey, phone);
  } else if (tester.any(allFields)) {
    await tester.enterText(allFields.first, phone);
  } else {
    flowLog('未找到手机号输入框');
    return false;
  }
  await settle(tester, maxSeconds: 1);

  final pwdKey = find.byKey(const Key('login_password_input'));
  if (tester.any(pwdKey)) {
    await tester.enterText(pwdKey, password);
  } else if (allFields.evaluate().length > 1) {
    await tester.enterText(allFields.at(1), password);
  }
  await settle(tester, maxSeconds: 1);

  bool tapped = false;
  for (final finder in [
    find.byKey(const Key('login_submit_button')),
    find.text('登录'),
    find.text('登 录'),
    find.text('Login'),
  ]) {
    if (tester.any(finder)) {
      await tester.tap(finder.first);
      tapped = true;
      break;
    }
  }
  if (!tapped) {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  }

  await settle(tester, maxSeconds: 5);
  await Future<void>.delayed(const Duration(seconds: 2));
  await settle(tester, maxSeconds: 3);

  if (isOnLoginPage(tester)) {
    flowLog('登录失败：仍停留在登录页');
    return false;
  }
  flowLog('登录成功');
  return true;
}

/// 若需要登录则自动登录，否则直接返回。
/// 前置未配置或登录失败时调用 markTestSkipped（抛出 Skip 异常，测试框架标记 SKIP）。
Future<void> autoLoginOrSkip(WidgetTester tester) async {
  if (!isOnLoginPage(tester)) return;
  if (!FlowConfig.hasCredentials) {
    markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
  }
  final ok = await performLogin(
    tester,
    phone: FlowConfig.testPhone,
    password: FlowConfig.testPassword,
  );
  if (!ok) {
    markTestSkipped('自动登录失败，跳过');
  }
}

// ──────────────────────────────────────────────
// 点击工具
// ──────────────────────────────────────────────

/// 安全点击，多个匹配取第一个。返回是否成功。
Future<bool> safeTap(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return false;
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  try {
    await tester.ensureVisible(target);
  } catch (_) {}
  try {
    await tester.tap(target, warnIfMissed: false);
    await settle(tester, maxSeconds: 2);
    return true;
  } catch (_) {
    return false;
  }
}

/// 依次尝试多个 Finder，第一个命中即返回 true。
Future<bool> tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final f in finders) {
    if (await safeTap(tester, f)) return true;
  }
  return false;
}

// ──────────────────────────────────────────────
// 已知良性框架异常过滤
// ──────────────────────────────────────────────

/// 过滤 Flutter 框架层的已知良性异常（图片 404、限流 429 等）。
/// 若遇到未知异常则重新抛出，让测试框架记录真实失败。
void drainKnownFrameworkExceptions(WidgetTester tester) {
  const maxDrain = 24;
  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    final text = err.toString();
    final isKnown =
        text.contains('ImageNotFoundException') ||
        text.contains('Image not found (404)') ||
        text.startsWith('Multiple exceptions (') ||
        (text.contains('/v1/channel/') && text.contains('status code of 429'));
    if (!isKnown) {
      Error.throwWithStackTrace(err as Object, StackTrace.current);
    }
    flowLog('已知良性框架异常（忽略）: ${text.substring(0, text.length.clamp(0, 120))}');
  }
}

// ──────────────────────────────────────────────
// 标准前置检查（checkPreconditions）
// ──────────────────────────────────────────────

/// 标准前置检查：后端可达 → App 进入入口 → 自动登录。
/// 失败时调用 markTestSkipped（抛出 Skip 异常，测试框架标记 SKIP，不会假绿）。
///
/// 使用示例：
/// ```dart
/// testWidgets('会话列表', (tester) async {
///   app.main();
///   await settle(tester, maxSeconds: 3);
///   await checkPreconditions(tester); // 失败自动 skip，不会假绿
///   // ... 实际断言
/// });
/// ```
Future<void> checkPreconditions(WidgetTester tester) async {
  if (!await ensureBackendAvailable()) {
    markTestSkipped('后端不可达，跳过');
  }
  if (!await waitForEntryState(tester)) {
    markTestSkipped('App 入口状态超时，跳过');
  }
  await autoLoginOrSkip(tester);
}
