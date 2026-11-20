// integration_test/passport/web_login_acceptance_test.dart
//
// Native wide-screen acceptance against the isolated real backend. The execution
// contract launches AT-WL01–07 separately, so password login cannot warm the QR
// case's socket or singleton state. Every case uses real isolated native storage.
// AT-WL06 uses an API scanner (not camera coverage), and observes the App's own
// polling, credentials, profile, protected HTTP and automatic socket handshake.
// Fixture requirements live in native_qr_acceptance_support.dart and the contract.

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/init.dart' show AppInitializer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/page/passport/forgot_password_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../enterprise/macos_storage_isolation.dart';
import 'native_qr_acceptance_support.dart';

Future<void> _nativeCase(Future<void> Function() run) async {
  try {
    await run();
  } on NativeQrBlocked catch (error) {
    // Unexpected skips are BLOCKED in the unified runner, never PASS.
    markTestSkipped('BLOCKED: ${error.reason}');
  }
}

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) => waitForNativeQr(tester, cond, timeout: Duration(seconds: seconds));

/// A fresh real storage scope must be anonymous; do not repair it by logout.
Future<void> _bootLoggedOut(WidgetTester tester) async {
  requireNativeQrFixture();
  final scope = await isolateNativeStorage();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await AppInitializer.dispose();
    await SqliteService.to.close();
    await clearMacosStorage(scope);
  });
  await bootNativeQrApp(tester);
  expect(
    UserRepoLocal.to.currentUid.isEmpty,
    isTrue,
    reason: 'Fresh anonymous scope',
  );
  expect(
    (await UserRepoLocal.to.accessToken).isEmpty,
    isTrue,
    reason: 'Fresh scope must not inherit a credential',
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).go('/sign_in');
  expect(
    await _waitFor(tester, () => tester.any(find.byType(WebLoginPage))),
    isTrue,
    reason: 'Native wide login page must mount',
  );
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

  testWidgets(
    'AT-WL01 切到密码登录/切回扫码并重新生成码',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);

      // Native 页面必须自动生成二维码，测试不直接启动 provider。
      expect(
        tester.any(find.text(t.account.webQRLoginTitle)),
        isTrue,
        reason: '默认应显示扫码登录区',
      );
      expect(
        await _waitFor(
          tester,
          () =>
              _containerOf(tester).read(qRLoginProvider).qrData?.isNotEmpty ??
              false,
        ),
        isTrue,
        reason: '进入页面应自动出码',
      );
      // 记住真实初始二维码，切换回来必须重新生成。
      final before = _containerOf(tester).read(qRLoginProvider).qrData;

      // 切到密码登录
      await _switchToPassword(tester);
      expect(
        tester.any(find.text(t.main.webSwitchToQR)),
        isTrue,
        reason: '密码区应提供切回扫码入口',
      );

      // 仅通过 UI 切回扫码，由页面请求新码。
      await tester.tap(find.text(t.main.webSwitchToQR), warnIfMissed: false);
      final regenerated = await _waitFor(
        tester,
        () =>
            _containerOf(tester).read(qRLoginProvider).qrData != null &&
            _containerOf(tester).read(qRLoginProvider).qrData != before,
        seconds: 15,
      );
      expect(regenerated, isTrue, reason: '切回扫码应重新生成二维码（qr_login/create 真请求）');
    }),
  );

  testWidgets(
    'AT-WL02 密码框明文与密文切换',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
      await _switchToPassword(tester);

      final pwdField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == t.account.webPasswordHint,
      );
      expect(tester.any(pwdField), isTrue, reason: '前置：密码框应存在');
      expect(
        tester.widget<TextField>(pwdField).obscureText,
        isTrue,
        reason: '初始应密文',
      );

      await tester.tap(
        find.descendant(
          of: pwdField,
          matching: find.byIcon(CupertinoIcons.eye),
        ),
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
    }),
  );

  testWidgets(
    'AT-WL03 拦截账号或密码为空并提示',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
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
    }),
  );

  testWidgets(
    'AT-WL04 密码登录真提交并跳 Native Shell',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
      await _switchToPassword(tester);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == t.account.webAccountHint,
        ),
        NativeQrFixture.account,
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == t.account.webPasswordHint,
        ),
        NativeQrFixture.password,
      );
      await tester.tap(find.text(t.account.login), warnIfMissed: false);

      expect(
        await _waitFor(
          tester,
          () =>
              tester.any(find.byType(WebShellBootstrap)) &&
              GoRouter.of(tester.element(find.byType(Navigator).first))
                      .routeInformationProvider
                      .value
                      .uri
                      .path ==
                  '/bottom_navigation',
          seconds: 20,
        ),
        isTrue,
        reason: 'Native 登录成功应跳 /bottom_navigation',
      );
      expect(
        UserRepoLocal.to.currentUid,
        NativeQrFixture.expectedUid,
        reason: '登录态应为配置的 fixture',
      );
    }),
  );

  testWidgets(
    'AT-WL05 跳转忘记密码页',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
      await _switchToPassword(tester);

      await tester.tap(
        find.text(t.account.forgotPassword),
        warnIfMissed: false,
      );
      expect(
        await _waitFor(
          tester,
          () => tester.any(find.byType(ForgotPasswordPage)),
        ),
        isTrue,
        reason: '点忘记密码应进找回入口页',
      );
    }),
  );

  testWidgets(
    'AT-WL06 Native QR confirmation, credentials, HTTP and automatic WS',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
      final evidence = NativeQrEvidence('AT-WL06');
      final session = await completeNativeQrLogin(tester, evidence);
      if (session == null) {
        evidence.blocked(
          'session',
          'QR session unavailable; dependent checks did not execute',
        );
        evidence.finish();
        return;
      }
      await assertNativeQrSession(tester, evidence, expected: session);
      await assertNativeQrAuthNegatives(evidence);
      evidence.finish();
    }),
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets(
    'AT-WL07 二维码过期态与刷新',
    (tester) => _nativeCase(() async {
      await _bootLoggedOut(tester);
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
    }),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
