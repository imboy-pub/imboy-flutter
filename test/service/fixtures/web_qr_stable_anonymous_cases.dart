import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/web_writer_gate.dart';

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  bool get hasSessionListeners => hasListeners;
  @override
  bool transitionFailed = false;
  @override
  AuthSessionScope current = (uid: '', generation: 1, transitioning: true);
  void publish(AuthSessionScope scope) {
    current = scope;
    notifyListeners();
  }

  @override
  bool isCurrent(AuthSessionScope scope) =>
      throw StateError('anonymous must use equality');
}

class _Qr extends QRLogin {
  _Qr(this.sessions);
  final _Sessions sessions;
  bool profilePending = false;
  @override
  bool get hasPendingProfile => profilePending;
  @override
  bool get canRetryProfile =>
      profilePending &&
      sessions.current.uid == 'synthetic-hydration-owner' &&
      !sessions.current.transitioning;
  @override
  void cancelQRCode() {
    profilePending = false;
    super.cancelQRCode();
  }

  int calls = 0;
  bool fail = false;
  @override
  QRLoginState build() => const QRLoginState();
  @override
  Future<void> generateQRCode() async {
    calls++;
    state = fail
        ? const QRLoginState(
            status: QRLoginStatus.failed,
            errorMessage: 'synthetic refused',
          )
        : const QRLoginState(qrData: 'synthetic-qr');
  }

  QRLoginStatus get status => state.status;
  void confirming() =>
      state = const QRLoginState(status: QRLoginStatus.confirming);
}

class _Passport extends PassportNotifier {
  @override
  PassportState build() {
    final controller = TextEditingController();
    ref.onDispose(controller.dispose);
    return PassportState(loginAccountCtl: controller);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareWebWriter);
  late _Sessions sessions;
  late _Qr qr;
  late GoRouter router;
  Future<void> mount(WidgetTester tester) async {
    sessions = _Sessions();
    qr = _Qr(sessions);
    // Real login success deliberately navigates immediately on a committed
    // owner; this fixture needs a router rather than a MaterialApp home.
    router = GoRouter(
      initialLocation: '/sign_in',
      routes: [
        GoRoute(
          path: '/sign_in',
          builder: (_, _) => WebLoginPage(sessionReader: sessions),
        ),
        GoRoute(
          path: '/web_shell',
          builder: (_, _) =>
              const Scaffold(body: Text('synthetic authenticated shell')),
        ),
        GoRoute(
          path: '/bottom_navigation',
          builder: (_, _) =>
              const Scaffold(body: Text('synthetic native shell')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qRLoginProvider.overrideWith(() => qr),
          passportProvider.overrideWith(_Passport.new),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> retire(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sessions.hasSessionListeners, isFalse);
    router.dispose();
    sessions.dispose();
  }

  const stable = (uid: '', generation: 1, transitioning: false);

  // 以下用例依赖 WebLoginPage initState 的 kIsWeb 挂载分支（会话监听器、
  // 页面写入失败订阅与匿名 QR 自动启动）。VM 直扫（kIsWeb=false）下该分支
  // 物理上不会执行，断言只会空转；真正的覆盖在 chrome 驱动
  // （web_human_device_qr_ws_chrome_test，@TestOn('chrome')）上完成。
  if (kIsWeb) {
    testWidgets(
      'logout held: zero create; stable notification creates exactly once',
      (tester) async {
        await mount(tester);
        expect(qr.calls, 0);
        expect(find.text('synthetic refused'), findsNothing);
        sessions.publish(stable);
        await tester.pump();
        await tester.pump();
        expect(qr.calls, 1);
        sessions.publish(stable);
        sessions.publish(stable);
        await tester.pump();
        await tester.pump();
        expect(qr.calls, 1);
        await retire(tester);
      },
    );
  }
  if (kIsWeb) {
    testWidgets(
      'queued logout generation change starts only the final stable scope',
      (tester) async {
        await mount(tester);
        sessions.publish((uid: '', generation: 2, transitioning: true));
        await tester.pump();
        expect(qr.calls, 0);
        sessions.publish((uid: '', generation: 2, transitioning: false));
        await tester.pump();
        await tester.pump();
        expect(qr.calls, 1);
        await retire(tester);
      },
    );
  }
  testWidgets('password selection cancels waiting; return to QR creates once', (
    tester,
  ) async {
    await mount(tester);
    await tester.ensureVisible(
      find.widgetWithText(CupertinoButton, t.account.webSwitchToPassword),
    );
    await tester.tap(
      find.widgetWithText(CupertinoButton, t.account.webSwitchToPassword),
    );
    await tester.pump();
    sessions.publish(stable);
    await tester.pump();
    expect(qr.calls, 0);
    await tester.ensureVisible(
      find.widgetWithText(CupertinoButton, t.main.webSwitchToQR),
    );
    await tester.tap(
      find.widgetWithText(CupertinoButton, t.main.webSwitchToQR),
    );
    await tester.pump();
    await tester.pump();
    expect(qr.calls, 1);
    await retire(tester);
  });
  // 以下用例依赖 WebLoginPage initState 的 kIsWeb 挂载分支（会话监听器、
  // 页面写入失败订阅与匿名 QR 自动启动）。VM 直扫（kIsWeb=false）下该分支
  // 物理上不会执行，断言只会空转；真正的覆盖在 chrome 驱动
  // （web_human_device_qr_ws_chrome_test，@TestOn('chrome')）上完成。
  if (kIsWeb) {
    testWidgets(
      'unmount removes listener and scheduled callback cannot create',
      (tester) async {
        await mount(tester);
        sessions.publish(stable);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(sessions.hasSessionListeners, isFalse);
        expect(qr.calls, 0);
        sessions.publish((uid: '', generation: 2, transitioning: false));
        await tester.pump();
        expect(qr.calls, 0);
        sessions.dispose();
      },
    );
    testWidgets('actual create failure is shown without automatic retry', (
      tester,
    ) async {
      await mount(tester);
      qr.fail = true;
      sessions.publish(stable);
      await tester.pump();
      await tester.pump();
      expect(qr.calls, 1);
      expect(find.text('synthetic refused'), findsWidgets);
      sessions.publish(stable);
      await tester.pump();
      expect(qr.calls, 1);
      await tester.ensureVisible(
        find.widgetWithText(CupertinoButton, t.main.webQRRefresh),
      );
      await tester.tap(
        find.widgetWithText(CupertinoButton, t.main.webQRRefresh),
      );
      await tester.pump();
      await tester.pump();
      expect(qr.calls, 2);
      await retire(tester);
    });
  }
  // 以下用例依赖 WebLoginPage initState 的 kIsWeb 挂载分支（会话监听器、
  // 页面写入失败订阅与匿名 QR 自动启动）。VM 直扫（kIsWeb=false）下该分支
  // 物理上不会执行，断言只会空转；真正的覆盖在 chrome 驱动
  // （web_human_device_qr_ws_chrome_test，@TestOn('chrome')）上完成。
  if (kIsWeb) {
    testWidgets(
      'auth failure publishes existing failure and releases wait listener',
      (tester) async {
        await mount(tester);
        sessions.transitionFailed = true;
        sessions.publish((uid: '', generation: 1, transitioning: true));
        await tester.pump();
        expect(qr.calls, 0);
        expect(find.text(t.common.webQRGenerateFailed), findsWidgets);
        expect(sessions.hasSessionListeners, isFalse);
        sessions.transitionFailed = false;
        sessions.publish(stable);
        await tester.pump();
        expect(qr.calls, 0);
        await retire(tester);
      },
    );
    testWidgets(
      'own confirming transition does not cancel or start another QR',
      (tester) async {
        await mount(tester);
        sessions.publish(stable);
        await tester.pump();
        await tester.pump();
        qr.confirming();
        sessions.publish((uid: '123', generation: 2, transitioning: true));
        sessions.publish((uid: '123', generation: 2, transitioning: false));
        // GoRouter updates its page stack on a subsequent frame. Let the
        // committed-owner navigation settle before asserting the destination.
        await tester.pumpAndSettle();
        expect(qr.calls, 1);
        expect(find.text('synthetic authenticated shell'), findsOneWidget);
        await retire(tester);
      },
    );
    testWidgets(
      'profile pending owner revocation cancels confirming and allows anonymous QR',
      (tester) async {
        await mount(tester);
        // Keep the owner in transition: a fully committed owner correctly
        // navigates away, so revocation must race the pending transition.
        sessions.publish((
          uid: 'synthetic-hydration-owner',
          generation: 2,
          transitioning: true,
        ));
        qr.profilePending = true;
        qr.confirming();
        await tester.pump();
        expect(qr.status, QRLoginStatus.confirming);
        expect(qr.calls, 0);
        // Host transport fixture covers actual HTTP401-driven owned logout.
        sessions.publish((
          uid: 'synthetic-hydration-owner',
          generation: 2,
          transitioning: true,
        ));
        sessions.publish((uid: '', generation: 3, transitioning: true));
        sessions.publish((uid: '', generation: 3, transitioning: false));
        await tester.pump();
        await tester.pump();
        expect(qr.status, QRLoginStatus.waiting);
        expect(qr.hasPendingProfile, isFalse);
        expect(qr.calls, 1);
        await retire(tester);
      },
    );
  }
}
