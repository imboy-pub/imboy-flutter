import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/login_page.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';

/// LoginPage widget test
///
/// 覆盖：
///   - 渲染 PassportTitle 品牌锚点（含 Hero kBrandLogoHeroTag）
///   - 3 个 Tab：账号 / 手机 / 邮箱
///   - 默认在第 0 个 Tab（账号登录）渲染输入框
///   - "忘记密码？" 链接渲染
///   - tab 切换 → TabBarView 切换

/// 跳过 JVerify SDK 初始化的假 Notifier——避免 platform channel 回调
/// timer 泄漏触发 !timersPending 断言
class _FakePassportNotifier extends PassportNotifier {
  @override
  PassportState build() {
    return PassportState(loginAccountCtl: TextEditingController());
  }
}

class _HistoryPassportNotifier extends _FakePassportNotifier {
  final calls = <(String, String)>[];
  final Completer<void>? completion;
  final Object? failure;

  _HistoryPassportNotifier({this.completion, this.failure});

  @override
  PassportState build() => PassportState(
    loginAccountCtl: TextEditingController(),
    accountHistory: const ['alice', 'bob'],
    emailHistory: const ['alice@example.com', 'bob@example.com'],
  );

  @override
  void initLoginHistory() {}

  @override
  Future<void> clearHistoryAccountData(String type, String value) async {
    calls.add((type, value));
    if (completion != null) await completion!.future;
    if (failure != null) throw failure!;
    state = state.copyWith(
      accountHistory: const ['bob'],
      emailHistory: const ['bob@example.com'],
    );
  }
}

class _LoginPassportNotifier extends _FakePassportNotifier {
  _LoginPassportNotifier({
    this.loginError,
    this.loginFailure,
    this.loginResult,
    this.failHistory = false,
  });

  final String? loginError;
  final Object? loginFailure;
  final Future<String?>? loginResult;
  final bool failHistory;
  final notices = <String>[];
  final savedHistories = <(String, String)>[];
  int loginCalls = 0;

  @override
  Future<String?> loginUser(
    String type,
    String account,
    String password,
  ) async {
    loginCalls++;
    if (loginFailure != null) throw loginFailure!;
    return loginResult == null ? loginError : await loginResult;
  }

  @override
  Future<void> saveHistory(String type, String value) async {
    savedHistories.add((type, value));
    if (failHistory) throw StateError('synthetic history persistence failure');
    await super.saveHistory(type, value);
  }

  @override
  void snackBar(dynamic message, {Icon? icon}) =>
      notices.add(message.toString());
}

GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/sign_in',
    routes: [
      GoRoute(path: '/sign_in', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot_password', builder: (_, _) => stub('forgot stub')),
      GoRoute(path: '/sign_up', builder: (_, _) => stub('sign_up stub')),
      GoRoute(
        path: '/bottom_navigation',
        builder: (_, _) => stub('signed-in home'),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, {PassportNotifier? notifier}) async {
  // LoginPage 渲染含 BezierContainer + 表单 + Tab + button，需充足画布
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        passportProvider.overrideWith(
          () => notifier ?? _FakePassportNotifier(),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('LoginPage layout', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)', (tester) async {
      await _pump(tester);

      expect(find.byType(PassportTitle), findsOneWidget);
      // Hero tag 接力起点（welcome → 此处）
      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders 3 个 Tab：账号 / 手机 / 邮箱', (tester) async {
      await _pump(tester);

      // i18n: account / mobile / email
      expect(find.text('账号'), findsAtLeastNWidgets(1));
      expect(find.text('手机'), findsAtLeastNWidgets(1));
      expect(find.text('邮箱'), findsAtLeastNWidgets(1));

      // 至少 1 个 TabBar
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders "忘记密码？" 链接', (tester) async {
      await _pump(tester);
      expect(find.text('忘记密码？'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 登录按钮（i18n buttonLogin="登录"）', (tester) async {
      await _pump(tester);
      // 默认 Tab 0（账号）展示登录按钮
      expect(find.text('登录'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('renders 支付宝登录入口（第三方登录区）', (tester) async {
      await _pump(tester);

      expect(find.byKey(const Key('alipay_login_button')), findsOneWidget);
      expect(find.text('其他登录方式'), findsOneWidget);
      expect(find.text('支'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('LoginPage tab switching', () {
    testWidgets('default Tab 0 → 账号 + 密码 输入框可见', (tester) async {
      await _pump(tester);

      // 默认账号 Tab，至少 2 个 TextField（账号 + 密码）
      expect(
        find.byType(TextField).evaluate().length,
        greaterThanOrEqualTo(2),
        reason: '账号 Tab 应有账号 + 密码 2 个 TextField',
      );

      await _unmount(tester);
    });

    testWidgets('tap mobile Tab → TabController 切换', (tester) async {
      await _pump(tester);

      // tap "手机" tab（找最里层 Tab widget 上的 text）
      await tester.tap(find.text('手机').last);
      await tester.pumpAndSettle();

      // 切换后页面仍能渲染（不抛错）
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('tap email Tab → TabController 切换', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('邮箱').last);
      await tester.pumpAndSettle();

      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('LoginPage navigation', () {
    testWidgets('tap 忘记密码 → /forgot_password', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('忘记密码？'));
      await tester.pumpAndSettle();

      expect(find.text('forgot stub'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('LoginPage account data cleanup', () {
    for (final password in ['', 'manually-entered-password']) {
      testWidgets(
        'selecting history preserves the existing password "$password"',
        (tester) async {
          await StorageService.to.setList(Keys.loginHistoryAccount, [
            'alice',
            'bob',
          ]);
          final notifier = _LoginPassportNotifier();
          await _pump(tester, notifier: notifier);
          final passwordInput = find.byKey(const Key('login_password_input'));
          await tester.enterText(passwordInput, password);
          await tester.tap(find.byKey(const Key('login_history_toggle')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('login_history_item_bob')),
          );
          await tester.pumpAndSettle();

          expect(find.text('bob'), findsOneWidget);
          expect(
            tester.widget<TextField>(passwordInput).controller!.text,
            password,
          );
          expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
          expect(notifier.loginCalls, 0);
          expect(notifier.savedHistories, isEmpty);
          expect(StorageService.to.getList(Keys.loginHistoryAccount), [
            'alice',
            'bob',
          ]);
          await _unmount(tester);
        },
      );
    }

    for (final throwsError in [false, true]) {
      testWidgets(
        'failed login does not record history (throws: $throwsError)',
        (tester) async {
          await StorageService.to.setList(Keys.loginHistoryAccount, ['bob']);
          final notifier = _LoginPassportNotifier(
            loginError: throwsError ? null : 'Synthetic invalid credentials',
            loginFailure: throwsError
                ? StateError('synthetic auth failure')
                : null,
          );
          await _pump(tester, notifier: notifier);
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('login_phone_input')),
              matching: find.byType(TextField),
            ),
            'alice',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_input')),
            'password',
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('login_submit_button')));
          await tester.pumpAndSettle();

          expect(notifier.loginCalls, 1);
          expect(notifier.savedHistories, isEmpty);
          expect(StorageService.to.getList(Keys.loginHistoryAccount), ['bob']);
          expect(find.byType(LoginPage), findsOneWidget);
          expect(notifier.notices, [
            throwsError
                ? t.common.operationFailedAgainLater
                : 'Synthetic invalid credentials',
          ]);
          expect(
            tester
                .widget<CupertinoButton>(
                  find.byKey(const Key('login_submit_button')),
                )
                .onPressed,
            isNotNull,
          );
          await _unmount(tester);
        },
      );
    }

    testWidgets('history is persisted only after authentication succeeds', (
      tester,
    ) async {
      await StorageService.to.setList(Keys.loginHistoryAccount, ['bob']);
      final completion = Completer<String?>();
      addTearDown(() {
        if (!completion.isCompleted) {
          completion.complete('synthetic aborted login');
        }
      });
      final notifier = _LoginPassportNotifier(loginResult: completion.future);
      await _pump(tester, notifier: notifier);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login_phone_input')),
          matching: find.byType(TextField),
        ),
        'alice',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'password',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(notifier.savedHistories, isEmpty);
      expect(StorageService.to.getList(Keys.loginHistoryAccount), ['bob']);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('login_submit_button')),
            )
            .onPressed,
        isNull,
      );
      completion.complete(null);
      await tester.pumpAndSettle();
      expect(notifier.savedHistories, [('account', 'alice')]);
      expect(StorageService.to.getList(Keys.loginHistoryAccount), [
        'alice',
        'bob',
      ]);
      expect(find.text('signed-in home'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets(
      'cancelling cleanup preserves the account, password and storage',
      (tester) async {
        await StorageService.to.setList(Keys.loginHistoryAccount, [
          'alice',
          'bob',
        ]);
        await StorageService.to.setString(
          'synthetic-other-account',
          'retained',
        );
        final beforeKeys = StorageService.to.getKeys();
        final notifier = _HistoryPassportNotifier();
        await _pump(tester, notifier: notifier);
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'typed-password',
        );
        await tester.tap(find.byKey(const Key('login_history_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('login_history_item_alice')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_clear')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_clear_cancel')));
        await tester.pumpAndSettle();

        expect(notifier.calls, isEmpty);
        expect(find.text('alice'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_password_input')))
              .controller!
              .text,
          'typed-password',
        );
        expect(StorageService.to.getList(Keys.loginHistoryAccount), [
          'alice',
          'bob',
        ]);
        expect(
          StorageService.to.getString('synthetic-other-account'),
          'retained',
        );
        expect(StorageService.to.getKeys(), beforeKeys);
        await _unmount(tester);
      },
    );

    testWidgets('history persistence failure still enters the signed-in home', (
      tester,
    ) async {
      final notifier = _LoginPassportNotifier(failHistory: true);
      await _pump(tester, notifier: notifier);
      final accountInput = find.descendant(
        of: find.byKey(const Key('login_phone_input')),
        matching: find.byType(TextField),
      );
      await tester.enterText(accountInput, 'alice');
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'test-password',
      );
      // Controller listeners schedule a rebuild; enterText does not paint the
      // now-enabled submit button before the following pointer event.
      await tester.pump();
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('login_submit_button')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(notifier.loginCalls, 1);
      expect(notifier.savedHistories, [('account', 'alice')]);
      expect(find.text('signed-in home'), findsOneWidget);
      expect(notifier.notices, [t.common.operationFailedAgainLater]);
      await _unmount(tester);
    });

    testWidgets(
      'selected account cleanup reaches notifier and blocks login until complete',
      (tester) async {
        final completion = Completer<void>();
        final notifier = _HistoryPassportNotifier(completion: completion);
        await _pump(tester, notifier: notifier);
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'test-password',
        );
        await tester.tap(find.byKey(const Key('login_history_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('login_history_item_alice')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_clear')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_clear_confirm')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(notifier.calls, [('account', 'alice')]);
        final submit = tester.widget<CupertinoButton>(
          find.byKey(const Key('login_submit_button')),
        );
        expect(submit.onPressed, isNull);
        expect(
          tester
              .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
              .any((widget) => widget.absorbing),
          isTrue,
        );

        completion.complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_password_input')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.tap(find.byKey(const Key('login_history_toggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('login_history_item_alice')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('login_history_item_bob')),
          findsOneWidget,
        );
        await _unmount(tester);
      },
    );

    for (final (failure, message) in <(Exception, String)>[
      (
        const LoginAccountIdentityUnavailableException(),
        t.account.loginHistoryIdentityUnavailable,
      ),
      (
        const AccountLocalDataOwnershipException(),
        t.account.loginHistoryOwnershipUnavailable,
      ),
    ]) {
      testWidgets(
        'email history retains the selected account after ${failure.runtimeType}',
        (tester) async {
          final notifier = _HistoryPassportNotifier(failure: failure);
          await _pump(tester, notifier: notifier);
          await tester.tap(find.text('邮箱').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('login_history_toggle')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('login_history_item_alice@example.com')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('login_history_toggle')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('login_history_clear')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('login_history_clear_confirm')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(notifier.calls, [('email', 'alice@example.com')]);
          expect(find.text(message), findsOneWidget);
          await tester.tap(
            find.byKey(const Key('login_history_clear_error_close')),
          );
          await tester.pumpAndSettle();
          expect(find.text('alice@example.com'), findsOneWidget);
          await _unmount(tester);
        },
      );
    }
  });
}
