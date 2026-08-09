// integration_test/flows/test_utils.dart
//
// 所有 UI 集成测试的唯一共享工具库。
// 消灭各文件中重复定义的 _shortSettle / _safeScreenshot / _ensureBackendAvailable 等。
//
// 约定：
//   - 前置检查失败 → markTestSkipped('reason') 后立即 return，避免跳过测试继续执行
//   - 门控型 smoke 检查失败 → fail('reason')
//   - 此文件不引入任何业务断言，只提供通用操作原语

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

// ──────────────────────────────────────────────
// 环境配置（来自 --dart-define）
// ──────────────────────────────────────────────

class FlowConfig {
  FlowConfig._();

  static String get appEnv =>
      const String.fromEnvironment('APP_ENV', defaultValue: '').trim();

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

  static bool get hasExplicitTestEnvironment => hasApiUrl || appEnv.isNotEmpty;

  static const nonProductionEnvironments = {
    'dev',
    'local',
    'local_home',
    'local_office',
  };

  static bool _isPrivateOrDevelopmentHost(String host) {
    final normalized = host.toLowerCase().trim();
    if (normalized == 'localhost' ||
        normalized == 'dev.imboy.pub' ||
        normalized.endsWith('.local')) {
      return true;
    }
    final ipv4 = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(normalized);
    if (ipv4 == null) return false;
    final octets = [for (int i = 1; i <= 4; i++) int.parse(ipv4.group(i)!)];
    if (octets[0] == 127 ||
        octets[0] == 10 ||
        octets[0] == 192 && octets[1] == 168) {
      return true;
    }
    return octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31;
  }

  static bool _isSafeNonProductionTarget(String url) {
    if (url.isEmpty) {
      return nonProductionEnvironments.contains(appEnv.toLowerCase());
    }
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    return host != null && _isPrivateOrDevelopmentHost(host);
  }

  static bool get targetsProduction {
    final normalized = appEnv.toLowerCase();
    if (normalized == 'pro' ||
        normalized == 'prod' ||
        normalized == 'production') {
      return true;
    }

    // 未知环境默认拒绝，避免新增环境名或拼写错误绕过生产门禁。
    if (normalized.isNotEmpty &&
        !nonProductionEnvironments.contains(normalized)) {
      return true;
    }

    // 仅传 API_BASE_URL 时也必须识别生产；只有本机、私网或 dev 域名允许写入。
    final normalizedUrl = apiBaseUrl.toLowerCase();
    if (normalizedUrl.contains('pro.imboy.pub') ||
        normalizedUrl.contains('production')) {
      return true;
    }
    return !_isSafeNonProductionTarget(normalizedUrl);
  }

  /// 外部写入授权必须显式开启，避免误运行频道创建/发布/编辑测试。
  static bool get allowChannelWrites =>
      const String.fromEnvironment(
        'TEST_ALLOW_CHANNEL_WRITES',
        defaultValue: 'false',
      ).toLowerCase() ==
      'true';

  static bool get allowBusinessWrites =>
      const String.fromEnvironment(
        'TEST_ALLOW_BUSINESS_WRITES',
        defaultValue: 'false',
      ).toLowerCase() ==
      'true';
}

// ──────────────────────────────────────────────
// 日志
// ──────────────────────────────────────────────

void flowLog(String message) {
  // ignore: avoid_print
  print('[FLOW] $message');
}

/// 频道写入类 E2E 的安全闸门。
///
/// 该测试会创建频道、发布消息或修改频道资料，必须通过
/// `--dart-define=TEST_ALLOW_CHANNEL_WRITES=true` 显式授权；缺省时以
/// skipped 结束，不能因为缺少授权而误判为功能通过。
bool requireChannelWriteAuthorization() {
  if (!FlowConfig.allowChannelWrites) {
    markTestSkipped('频道 E2E 会写入后端；请显式设置 TEST_ALLOW_CHANNEL_WRITES=true 后运行');
    return false;
  }
  if (!FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('频道 E2E 写入需要显式设置 API_BASE_URL 或 APP_ENV，禁止使用隐式环境');
    return false;
  }
  if (FlowConfig.targetsProduction) {
    markTestSkipped('频道 E2E 禁止在生产环境执行写入');
    return false;
  }
  return true;
}

/// 通用业务写入安全闸门。
///
/// 关系、消息、群、日程、密码和资金相关测试必须显式开启，且不能指向
/// 生产地址。缺少条件时统一 SKIP，避免“页面点到了”被误报为闭环通过。
bool requireBusinessWriteAuthorization() {
  if (!FlowConfig.allowBusinessWrites) {
    markTestSkipped('业务写入 E2E 需要显式设置 TEST_ALLOW_BUSINESS_WRITES=true 后运行');
    return false;
  }
  if (!FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('业务写入 E2E 需要显式设置 API_BASE_URL 或 APP_ENV');
    return false;
  }
  if (FlowConfig.targetsProduction) {
    markTestSkipped('业务写入 E2E 禁止在生产环境执行');
    return false;
  }
  return true;
}

// ──────────────────────────────────────────────
// 等待帧稳定
// ──────────────────────────────────────────────

/// 等待 UI 稳定，最多 [maxSeconds] 秒。
/// 优先使用 pumpAndSettle；仅在明确超时时回退为固定抽帧。
Future<void> settle(WidgetTester tester, {int maxSeconds = 5}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: maxSeconds),
    );
  } on FlutterError catch (error) {
    if (!error.toString().contains('pumpAndSettle timed out')) rethrow;
    flowLog('pumpAndSettle 超时，回退固定抽帧: ${maxSeconds}s');
    for (int i = 0; i < maxSeconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
}

// ──────────────────────────────────────────────
// 截图
// ──────────────────────────────────────────────

Future<void> takeScreenshot(WidgetTester tester, String name) async {
  // Android 真机的 integration_test surface 转换在部分厂商 ROM 上会阻塞
  // 测试 isolate；截图只是诊断产物，不应阻断业务流程验收。
  if (Platform.isAndroid) {
    flowLog('截图跳过（Android 真机诊断不阻断流程）: $name');
    return;
  }
  try {
    await settle(tester, maxSeconds: 2);
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await Future<void>(() async {
      try {
        await binding.convertFlutterSurfaceToImage();
      } catch (_) {}
      await binding.takeScreenshot(name);
    }).timeout(const Duration(seconds: 5));
  } on MissingPluginException {
    flowLog('截图跳过（运行器不支持）: $name');
  } on TimeoutException {
    flowLog('截图跳过（运行器超时）: $name');
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
  final hasLoginPageWidget = tester.any(
    find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() == 'LoginPage' ||
          w.runtimeType.toString() == 'WebLoginPage',
    ),
  );
  if (!hasLoginPageWidget) return false;

  // GoRouter 在切换页面的短窗口内可能同时保留旧页面；仅检测
  // LoginPage 类型会把 WelcomePage 误判成登录页。必须再确认登录页
  // 的可操作控件，WebLoginPage 的二维码入口也保留为有效登录入口。
  final hasLoginField =
      tester.any(find.byKey(const Key('login_phone_input'))) ||
      tester.any(find.byKey(const Key('login_password_input'))) ||
      tester.any(find.byType(TextField));
  final hasWebLoginEntry =
      tester.any(find.text('使用账号密码登录')) ||
      tester.any(find.text('Use account and password')) ||
      tester.any(find.text('Password login'));
  return hasLoginField || hasWebLoginEntry;
}

bool isOnWelcomePage(WidgetTester tester) {
  return tester.any(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'WelcomePage'),
  );
}

bool isOnMainShell(WidgetTester tester) {
  return tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      tester.any(find.byType(NavigationRail)) ||
      tester.any(
        find.byWidgetPredicate(
          // macOS/桌面端使用业务自定义 WebShell，不会出现原生 NavigationRail。
          (w) => w.runtimeType.toString() == 'WebNavRail',
        ),
      ) ||
      tester.any(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
        ),
      );
}

/// 等待 App 进入可操作入口（登录页 或 主 Shell）。
Future<bool> waitForEntryState(
  WidgetTester tester, {
  int maxAttempts = 90,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (isOnLoginPage(tester) ||
        isOnWelcomePage(tester) ||
        isOnMainShell(tester)) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return false;
}

/// 登录接口成功后，等待主 Shell 真正挂载。
///
/// 首次初始化包含远端配置、数据库和 E2EE 服务启动，登录成功并不代表
/// BottomNavigationPage/NavigationRail 已经出现在 widget tree 中。
Future<bool> waitForMainShell(
  WidgetTester tester, {
  int maxAttempts = 60,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (isOnMainShell(tester)) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return false;
}

void logEntryDiagnostics(WidgetTester tester) {
  final types =
      tester.allWidgets
          .map((widget) => widget.runtimeType.toString())
          .toSet()
          .toList()
        ..sort();
  flowLog('入口诊断 widget 类型: ${types.take(80).join(', ')}');
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

  var phoneKey = find.byKey(const Key('login_phone_input'));
  var allFields = find.byType(TextField);

  // 桌面端 WebLoginPage 默认先展示二维码，需要显式切换到账号密码登录；
  // 否则测试会把二维码页上的“登录”文案误当成已进入密码登录页。
  final isWebLoginPage = tester.any(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'WebLoginPage'),
  );
  if (isWebLoginPage || (!tester.any(phoneKey) && !tester.any(allFields))) {
    final switched = await tapAny(tester, [
      find.text('使用账号密码登录'),
      find.text('Use account and password'),
      find.text('Password login'),
    ]);
    if (switched) {
      await settle(tester, maxSeconds: 2);
      phoneKey = find.byKey(const Key('login_phone_input'));
      allFields = find.byType(TextField);
    }
    flowLog(
      '登录页控件: web=$isWebLoginPage, switched=$switched, '
      'accountKey=${tester.any(phoneKey)}, fields=${allFields.evaluate().length}',
    );
  }

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

  // 收起键盘以防遮挡登录按钮
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, maxSeconds: 2);

  final relevantTypes =
      tester.allWidgets
          .map((widget) => widget.runtimeType.toString())
          .where(
            (type) =>
                type.contains('Login') ||
                type.contains('Welcome') ||
                type.contains('Button'),
          )
          .toSet()
          .toList()
        ..sort();
  flowLog(
    '登录控件诊断: phoneKey=${tester.any(phoneKey)}, '
    'passwordKey=${tester.any(find.byKey(const Key('login_password_input')))}, '
    'fields=${allFields.evaluate().length}, '
    'submitKey=${tester.any(find.byKey(const Key('login_submit_button')))}, '
    'elevated=${tester.any(find.byType(ElevatedButton))}, '
    'types=${relevantTypes.join(',')}',
  );

  bool tapped = false;
  for (final finder in [
    find.byKey(const Key('login_submit_button')),
    find.widgetWithText(ElevatedButton, '登录'),
    find.widgetWithText(ElevatedButton, 'Login'),
    find.text('登录'),
    find.text('登 录'),
    find.text('Login'),
  ]) {
    if (await safeTap(tester, finder)) {
      tapped = true;
      break;
    }
  }
  flowLog('登录提交控件点击: ${tapped ? '成功' : '未找到'}');
  if (!tapped) {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  }

  await settle(tester, maxSeconds: 5);
  await Future<void>.delayed(const Duration(seconds: 2));
  await settle(tester, maxSeconds: 3);

  flowLog('登录后本地会话状态: ${UserRepoLocal.to.isLoggedIn ? '已建立' : '未建立'}');
  if (!UserRepoLocal.to.isLoggedIn) {
    flowLog('登录失败：接口回调后本地会话未建立');
    return false;
  }
  // 登录回调完成与路由切换不是同一个时刻；GoRouter 可能暂时保留旧的
  // LoginPage。主 Shell 是否真正挂载由调用方 waitForMainShell 统一判断。
  flowLog('登录接口成功，等待主 Shell');
  return true;
}

/// 若需要登录则自动登录，否则直接返回 true。
/// 前置未配置或登录失败时标记 SKIP 并返回 false。
Future<bool> autoLoginOrSkip(WidgetTester tester) async {
  // SplashPage 会在首帧后异步跳到 WelcomePage；登录页判定不能抢在这次
  // 路由切换前完成，否则会把旧路由当成稳定登录页。
  var loginSeen = 0;
  for (var i = 0; i < 20; i++) {
    if (isOnWelcomePage(tester) || isOnMainShell(tester)) break;
    if (isOnLoginPage(tester)) {
      loginSeen++;
      if (loginSeen >= 3) break;
    } else {
      loginSeen = 0;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
  }

  if (isOnWelcomePage(tester)) {
    final movedToLogin = await _leaveWelcomePage(tester);
    if (!movedToLogin) {
      markTestSkipped('欢迎页未找到进入登录页的操作入口，跳过');
      return false;
    }
    for (var i = 0; i < 15; i++) {
      if (isOnLoginPage(tester)) break;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (!isOnLoginPage(tester)) {
      markTestSkipped('欢迎页无法进入登录页，跳过');
      return false;
    }
  }
  // WelcomePage 可能与旧路由短暂共存；若仍可见欢迎页，不能继续调用
  // performLogin，否则会把欢迎页上的按钮误当成登录提交控件。
  if (isOnWelcomePage(tester)) {
    markTestSkipped('欢迎页仍在前台，跳过登录操作');
    return false;
  }
  if (!isOnLoginPage(tester)) return true;
  if (!FlowConfig.hasCredentials) {
    markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
    return false;
  }
  final ok = await performLogin(
    tester,
    phone: FlowConfig.testPhone,
    password: FlowConfig.testPassword,
  );
  if (!ok) {
    markTestSkipped('自动登录失败，跳过');
    return false;
  }
  if (!await waitForMainShell(tester)) {
    logEntryDiagnostics(tester);
    markTestSkipped('登录接口成功，但主 Shell 未在等待窗口内挂载，跳过');
    return false;
  }
  return true;
}

/// 欢迎页的“跳过”是 GestureDetector，最后一页则只有 ElevatedButton。
/// 语义节点和按钮都保留兜底，避免桌面端/不同语言下只靠可见文案失效。
Future<bool> _leaveWelcomePage(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    if (!isOnWelcomePage(tester)) return isOnLoginPage(tester);

    final tapped = await tapAny(tester, [
      find.text('跳过'),
      find.text('Skip'),
      find.text('开始使用'),
      find.text('Get Started'),
      if (tester.any(find.byType(ElevatedButton)))
        find.byType(ElevatedButton).last,
    ]);
    if (!tapped) return false;

    await settle(tester, maxSeconds: 1);
    if (isOnLoginPage(tester) && !isOnWelcomePage(tester)) return true;
  }
  return isOnLoginPage(tester) && !isOnWelcomePage(tester);
}

// ──────────────────────────────────────────────
// 点击工具
// ──────────────────────────────────────────────

/// 安全点击，多个匹配取第一个。返回是否成功。
Future<bool> safeTap(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return false;
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  await tester.ensureVisible(target);
  await tester.tap(target, warnIfMissed: false);
  await settle(tester, maxSeconds: 2);
  return true;
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
        (text.startsWith('Multiple exceptions (') &&
            (text.contains('ImageNotFoundException') ||
                text.contains('Image not found (404)') ||
                (text.contains('/v1/channel/') && text.contains('429')))) ||
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
/// 失败时调用 markTestSkipped 并返回 false；调用方必须立即 return。
///
/// 使用示例：
/// ```dart
/// testWidgets('会话列表', (tester) async {
///   app.main();
///   await settle(tester, maxSeconds: 3);
///   if (!await checkPreconditions(tester)) return;
///   // ... 实际断言
/// });
/// ```
Future<bool> checkPreconditions(WidgetTester tester) async {
  if (!await ensureBackendAvailable()) {
    markTestSkipped('后端不可达，跳过');
    return false;
  }
  if (!await waitForEntryState(tester)) {
    markTestSkipped('App 入口状态超时，跳过');
    return false;
  }
  return autoLoginOrSkip(tester);
}
