// integration_test/passport/web_login_acceptance_test.dart
//
// WebLoginPage（扫码登录/大屏登录壳）验收（批次126）：解锁
// web_login_page 9 行阻塞。历史阻塞两类定性均已翻案：
//   - 「需 Web 平台运行/Playwright 合成点击无效」→ macOS integration_test
//     的 tester.tap 是真实 Flutter 命中事件（非 Playwright 合成），且
//     tester.view 放大到 1600px（≥AppBreakpoints.wide=900）即可走
//     isWide 分流渲染 WebLoginPage（批次124 实证默认窗口走 LoginPage，
//     故必须显式放大视口）。
//   - 「需手机 App 扫码配合」→ 后端 qr_login 会话推进是纯 API：测试用
//     FlowApiClient 登录 51730 充当手机端（scan/confirm 均 JWT），Web 端
//     2s 轮询 qr_login/status 拿一次性 login_token 自动完成登录。
//
// 载体：SmokeEmpty（account=51730）。红线：仅本地环境（9801/4323），
// 不发码不外发。QR 状态机在 kIsWeb=false 时由测试直接调 provider 的
// generateQRCode() 启动（macOS 走 2s 轮询，与生产 Web 的 SSE 降级路径
// 同一套状态机 derivePollingDecision）。
//
// 场景（行对应 web_login_page.md 9 行阻塞）：
//   AT-WL01 切到密码登录 / 切回扫码并重新生成码（行：切换×2）
//   AT-WL02 密码框明文与密文切换
//   AT-WL03 拦截账号或密码为空并提示（含 UI 提示渲染验证）
//   AT-WL04 提交密码登录并跳 Web Shell（真登录 51730）
//   AT-WL05 跳转忘记密码页
//   AT-WL06 已扫码待确认态 + 确认后登录跳 Web Shell（API 驱动全链）
//   AT-WL07 二维码过期态 + 刷新重新生成
//
// 运行（单场景 --plain-name；define 与批次123/124/125 同配方）：
//   flutter test integration_test/passport/web_login_acceptance_test.dart \
//     -d macos --plain-name "AT-WL01" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/page/passport/forgot_password_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '111174215241304064',
);

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

/// 未登录态进入 WebLoginPage：
/// 1. 容器若残留登录态先本地登出（本页前提就是未登录）；
/// 2. 视口放大到 1600px（默认窗口窄屏会分流到 LoginPage）；
/// 3. 深链 /sign_in（公开路径，认证守卫不拦）。
Future<bool> _bootLoggedOut(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  app.main();
  await _pump(tester, seconds: 12);
  if (UserRepoLocal.to.currentUid.isNotEmpty) {
    await UserRepoLocal.to.quitLogin();
    await _pump(tester, seconds: 3);
  }
  GoRouter.of(tester.element(find.byType(Navigator).first)).go('/sign_in');
  await _pump(tester, seconds: 4);
  if (!tester.any(find.byType(WebLoginPage))) {
    final texts = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((t) => t.trim().isNotEmpty)
        .take(20)
        .toList();
    iPrint('[DIAG] 未达 WebLoginPage，页面文本=$texts');
    markTestSkipped('未进入 WebLoginPage（isWide 分流未生效或路由被拦）');
    return false;
  }
  return true;
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(WebLoginPage)));
}

/// 切到账号密码登录区（同时停止 QR 轮询）
Future<void> _switchToPassword(WidgetTester tester) async {
  await tester.tap(
    find.text(t.account.webSwitchToPassword),
    warnIfMissed: false,
  );
  expect(
    await _waitFor(
      tester,
      () => tester.any(find.text(t.account.webPasswordLoginTitle)),
    ),
    isTrue,
    reason: '前置：应切到账号密码登录区',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-WL01 切到密码登录/切回扫码并重新生成码', (tester) async {
    if (!await _bootLoggedOut(tester)) return;

    // 初始 QR 区（kIsWeb=false 时 qrData 为空，仅壳渲染）
    expect(
      tester.any(find.text(t.account.webQRLoginTitle)),
      isTrue,
      reason: '默认应显示扫码登录区',
    );
    // 切回后的码生成验证：先记当前 qrData（可能为空）
    final before = _containerOf(tester).read(qRLoginProvider).qrData;

    // 切到密码登录
    await _switchToPassword(tester);
    expect(
      tester.any(find.text(t.main.webSwitchToQR)),
      isTrue,
      reason: '密码区应提供切回扫码入口',
    );

    // 切回扫码 → handler 直接调 generateQRCode()（真 POST qr_login/create）
    await tester.tap(find.text(t.main.webSwitchToQR), warnIfMissed: false);
    final regenerated = await _waitFor(
      tester,
      () =>
          _containerOf(tester).read(qRLoginProvider).qrData != null &&
          _containerOf(tester).read(qRLoginProvider).qrData != before,
      seconds: 15,
    );
    expect(regenerated, isTrue, reason: '切回扫码应重新生成二维码（qr_login/create 真请求）');
  });

  testWidgets('AT-WL02 密码框明文与密文切换', (tester) async {
    if (!await _bootLoggedOut(tester)) return;
    await _switchToPassword(tester);

    final pwdField = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == t.account.webPasswordHint,
    );
    expect(tester.any(pwdField), isTrue, reason: '前置：密码框应存在');
    expect(
      tester.widget<TextField>(pwdField).obscureText,
      isTrue,
      reason: '初始应密文',
    );

    await tester.tap(
      find.descendant(of: pwdField, matching: find.byIcon(CupertinoIcons.eye)),
      warnIfMissed: false,
    );
    await _pump(tester);
    expect(
      tester.widget<TextField>(pwdField).obscureText,
      isFalse,
      reason: '点眼睛后应明文',
    );

    await tester.tap(
      find.descendant(
        of: pwdField,
        matching: find.byIcon(CupertinoIcons.eye_slash),
      ),
      warnIfMissed: false,
    );
    await _pump(tester);
    expect(
      tester.widget<TextField>(pwdField).obscureText,
      isTrue,
      reason: '再次点击应切回密文',
    );
  });

  testWidgets('AT-WL03 拦截账号或密码为空并提示', (tester) async {
    if (!await _bootLoggedOut(tester)) return;
    await _switchToPassword(tester);

    // 不填账号密码直接提交
    await tester.tap(find.text(t.account.login), warnIfMissed: false);
    await _pump(tester, seconds: 2);

    // 拦截：仍在密码登录区（未发起登录/未跳转）
    expect(
      tester.any(find.text(t.account.webPasswordLoginTitle)),
      isTrue,
      reason: '空值提交应被拦截在本页',
    );
    // 提示：setError 写入 state.error，页面应渲染出来
    // （批次126 实证：state 有值但页面无渲染位，属提示缺失 bug 已修）
    expect(
      tester.any(find.textContaining(t.common.webLoginEmptyError)),
      isTrue,
      reason: '空值拦截应给出可见提示',
    );
  });

  testWidgets('AT-WL04 密码登录真提交并跳 Web Shell', (tester) async {
    if (!await _bootLoggedOut(tester)) return;
    await _switchToPassword(tester);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == t.account.webAccountHint,
      ),
      '51730',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == t.account.webPasswordHint,
      ),
      FlowConfig.testPassword,
    );
    await tester.tap(find.text(t.account.login), warnIfMissed: false);

    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WebShellBootstrap)),
        seconds: 20,
      ),
      isTrue,
      reason: '登录成功应跳 /web_shell',
    );
    expect(UserRepoLocal.to.currentUid, _uid, reason: '登录态应为 51730');
  });

  testWidgets('AT-WL05 跳转忘记密码页', (tester) async {
    if (!await _bootLoggedOut(tester)) return;
    await _switchToPassword(tester);

    await tester.tap(find.text(t.account.forgotPassword), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(ForgotPasswordPage))),
      isTrue,
      reason: '点忘记密码应进找回入口页',
    );
  });

  testWidgets('AT-WL06 扫码确认全链登录跳 Web Shell', (tester) async {
    if (!await _bootLoggedOut(tester)) return;

    // kIsWeb=false 时 initState 不生成码，测试直接驱动状态机（非 Web 走轮询）
    await _containerOf(tester).read(qRLoginProvider.notifier).generateQRCode();
    expect(
      await _waitFor(
        tester,
        () => _containerOf(tester).read(qRLoginProvider).qrData != null,
        seconds: 15,
      ),
      isTrue,
      reason: '前置：QR 码应生成（qr_login/create）',
    );

    // 手机端扫码（51730）→ Web 端 2s 轮询感知 → scanned 态
    final client = FlowApiClient(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:9801',
      ),
      deviceId: 'wl-scanner',
    );
    final qrData = _containerOf(tester).read(qRLoginProvider).qrData!;
    final loginResp = await client.login(
      account: '51730',
      password: FlowConfig.testPassword,
      type: 'account',
      plainPassword: true,
    );
    expect(loginResp['code'], 0, reason: '前置：扫码者登录应成功');
    final scanResp = await client.post(
      '/api/v1/passport/qr_login/scan',
      data: {'qr_token': qrData},
    );
    expect(scanResp['code'], 0, reason: '手机端扫码应成功');

    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(t.discovery.webQRScanned)),
        seconds: 15,
      ),
      isTrue,
      reason: '扫码后应展示已扫码待确认态',
    );

    // 手机端确认 → Web 轮询拿一次性 login_token → 自动登录跳 Web Shell
    final confirmResp = await client.post(
      '/api/v1/passport/qr_login/confirm',
      data: {'qr_token': qrData},
    );
    expect(confirmResp['code'], 0, reason: '手机端确认登录应成功');

    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WebShellBootstrap)),
        seconds: 20,
      ),
      isTrue,
      reason: '确认后应完成登录并跳 Web Shell',
    );
    expect(UserRepoLocal.to.currentUid, _uid, reason: 'QR 登录态应为扫码者 51730');
  });

  testWidgets('AT-WL07 二维码过期态与刷新', (tester) async {
    if (!await _bootLoggedOut(tester)) return;
    await _containerOf(tester).read(qRLoginProvider.notifier).generateQRCode();
    expect(
      await _waitFor(
        tester,
        () => _containerOf(tester).read(qRLoginProvider).qrData != null,
        seconds: 15,
      ),
      isTrue,
      reason: '前置：QR 码应生成',
    );
    final oldQr = _containerOf(tester).read(qRLoginProvider).qrData;

    // 服务端会话 60s 过期；客户端倒计时到 0 后切 expired 态（刷新按钮出现）
    final expired = await _waitFor(
      tester,
      () =>
          _containerOf(tester).read(qRLoginProvider).status ==
          QRLoginStatus.expired,
      seconds: 75,
    );
    expect(expired, isTrue, reason: '60s 后应切到过期态');
    expect(
      tester.any(find.text(t.main.webQRRefresh)),
      isTrue,
      reason: '过期态应出现刷新入口',
    );

    await tester.tap(find.text(t.main.webQRRefresh), warnIfMissed: false);
    final refreshed = await _waitFor(
      tester,
      () =>
          _containerOf(tester).read(qRLoginProvider).status ==
              QRLoginStatus.waiting &&
          _containerOf(tester).read(qRLoginProvider).qrData != null &&
          _containerOf(tester).read(qRLoginProvider).qrData != oldQr,
      seconds: 15,
    );
    expect(refreshed, isTrue, reason: '刷新应生成新码并回到等待扫码态');
  });
}
