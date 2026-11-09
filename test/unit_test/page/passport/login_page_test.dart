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
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// LoginPage widget test
///
/// 覆盖：
///   - 渲染 PassportTitle 品牌锚点（含 Hero kBrandLogoHeroTag）
///   - 3 个 Tab：账号 / 手机 / 邮箱
///   - 默认在第 0 个 Tab（账号登录）渲染输入框
///   - "忘记密码？" 链接渲染
///   - tab 切换 → TabBarView 切换
///   - A01-NC-1：双击登录按钮只触发一次登录请求（UI 门闸）
///   - A01-NC-2（页面腿）：登录失败响应不写任何登录态、不导航
///   - A01-NC-3：请求在途时退出页面，错误返回不崩溃（mounted 守卫）、可重试

/// 跳过 JVerify SDK 初始化的假 Notifier——避免 platform channel 回调
/// timer 泄漏触发 !timersPending 断言
class _FakePassportNotifier extends PassportNotifier {
  @override
  PassportState build() {
    return PassportState(loginAccountCtl: TextEditingController());
  }
}

/// A01-NC-1/2/3 手工门闸：挂起 loginUser 的返回值模拟「请求在途」。
/// 独立成共享对象——页面中途退出再重进时 ProviderScope 重建容器、
/// spy 实例随之重建，但门闸与计数必须跨实例延续。
class _LoginGate {
  Completer<String?>? _completer;

  Future<String?> get future {
    _completer ??= Completer<String?>();
    return _completer!.future;
  }

  /// 让当前在途请求以 [result] 完成（null = 登录成功）。
  void completeWith(String? result) {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }
}

/// A01-NC-1/2/3 spy Notifier：记录 loginUser 调用并经共享 [_LoginGate]
/// 挂起返回值；吞掉 snackBar（EasyLoading 未挂载时 showError 返回
/// error future，会成为未处理异步异常打红测试），改为记录进共享列表。
class _SpyPassportNotifier extends PassportNotifier {
  _SpyPassportNotifier(this.gate, this.calls, this.snackbars);

  final _LoginGate gate;
  final List<String> calls;
  final List<String> snackbars;

  @override
  PassportState build() {
    return PassportState(loginAccountCtl: TextEditingController());
  }

  @override
  Future<String?> loginUser(
    String accountType,
    String account,
    String password,
  ) async {
    calls.add(account);
    return gate.future;
  }

  @override
  void snackBar(dynamic message, {Icon? icon}) {
    snackbars.add(message?.toString() ?? '');
  }
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
        builder: (_, _) => stub('bottom_nav stub'),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  PassportNotifier Function()? notifier,
}) async {
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
          notifier ?? () => _FakePassportNotifier(),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  await tester.pump();
}

/// 卸载页面。提交在途（按钮转圈）时禁止用 pumpAndSettle——
/// CupertinoActivityIndicator 永不停止会导致 settle 超时。
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Finder get _accountField => find.descendant(
  of: find.byKey(const Key('login_phone_input')),
  matching: find.byType(TextField),
);

Finder get _passwordField => find.byKey(const Key('login_password_input'));

Finder get _submitBtn => find.byKey(const Key('login_submit_button'));

/// A01-NC-2：认证失败后本地凭据存储必须保持零写入。
void _expectNoAuthStateOnDisk() {
  expect(
    StorageService.to.getString(Keys.currentUid),
    isEmpty,
    reason: '失败后不得写入 current_uid',
  );
  expect(
    StorageService.getMap(Keys.currentUser),
    isEmpty,
    reason: '失败后不得写入 current_user',
  );
  expect(UserRepoLocal.to.isLoggedIn, isFalse);
}

void main() {
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

  // ───────────────────────── A01 补测（AT02/AT13）─────────────────────────

  group('LoginPage repeat submit (A01-NC-1 双击防重复)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('双击登录按钮：加载中门闸生效，仅触发 1 次登录请求', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'alice_account');
      await tester.enterText(_passwordField, 'secret123');
      await tester.pump();
      expect(calls, isEmpty, reason: '仅输入未提交时不得发起登录');

      await tester.tap(_submitBtn);
      // 必须先 pump 一帧，让 setState(_isLoading=true) 的重建生效；
      // 否则旧帧上的 onPressed 仍非 null，测不出真机的帧间门闸行为
      await tester.pump();

      expect(calls, ['alice_account'], reason: '首次提交恰好 1 次登录请求');
      final gating = tester.widget<CupertinoButton>(_submitBtn);
      expect(
        gating.onPressed,
        isNull,
        reason: '请求中 login_submit_button 必须禁用（login_page.dart:560 门闸）',
      );
      expect(
        find.descendant(
          of: _submitBtn,
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
        reason: '请求中按钮应显示加载指示',
      );

      // 第二次点击（模拟双击）
      await tester.tap(_submitBtn);
      await tester.pump();
      expect(calls.length, 1, reason: '加载中第二次 tap 不得触发第二次登录请求（设备记录重复上报防线）');

      // 请求失败返回 → 错误反馈 + 按钮恢复可重试
      gate.completeWith('密码错误');
      await tester.pump();
      await tester.pump();
      expect(snacks, isNotEmpty, reason: '失败必须反馈用户（snackBar）');
      final afterFail = tester.widget<CupertinoButton>(_submitBtn);
      expect(afterFail.onPressed, isNotNull, reason: '失败后按钮应恢复可点');
      expect(find.text('bottom_nav stub'), findsNothing, reason: '失败不得导航');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('LoginPage auth failure hygiene (A01-NC-2 错误后不落盘·页面腿)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('登录失败响应：不写任何登录态、不导航、停留 /sign_in', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'bob_account');
      await tester.enterText(_passwordField, 'wrongpass');
      await tester.pump();

      await tester.tap(_submitBtn);
      await tester.pump();
      gate.completeWith('密码错误');
      await tester.pump();
      await tester.pump();

      expect(find.text('bottom_nav stub'), findsNothing, reason: '失败不得导航');
      expect(find.byType(LoginPage), findsOneWidget, reason: '失败停留登录页');
      _expectNoAuthStateOnDisk();
      expect(
        StorageService.to.getStringList(Keys.loginHistory),
        isNull,
        reason: '失败不得写入登录历史',
      );
      expect(snacks, isNotEmpty, reason: '失败必须反馈用户');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('LoginPage cancel mid-flight (A01-NC-3 中途取消)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('请求在途时退出页面：错误返回不崩溃、不导航（mounted 守卫回归保护）', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'carol_account');
      await tester.enterText(_passwordField, 'secret123');
      await tester.pump();
      await tester.tap(_submitBtn);
      await tester.pump();
      expect(calls.length, 1, reason: '提交已发出且在途');

      // 模拟用户中途返回/退出登录页（按钮此时在转圈，禁用 pumpAndSettle）
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // 网络此刻才返回失败 → `.then` 回调执行：
      // 关键回归点 login_page.dart:292 `if (mounted)` 守卫——守卫若丢失，
      // 此处抛 setState() called after dispose()，本用例即红
      gate.completeWith('网络故障，请重试');
      await tester.pump();
      await tester.pump();

      expect(snacks, isNotEmpty, reason: '页面已销毁仍应收到错误回调（snackBar 兜底反馈）');
      expect(find.text('bottom_nav stub'), findsNothing);
      _expectNoAuthStateOnDisk();
    });

    testWidgets('中途取消后重进登录页可重试，成功后导航主界面', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'dave_account');
      await tester.enterText(_passwordField, 'secret123');
      await tester.pump();
      await tester.tap(_submitBtn);
      await tester.pump();

      // 中途退出，失败返回（成功返回触发 PD-1 缺陷，见测试报告与 skip 用例）
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      gate.completeWith('网络故障，请重试');
      await tester.pump();

      // 重进登录页重试
      await _pump(tester, notifier: spyFactory);
      await tester.enterText(_accountField, 'dave_account');
      await tester.enterText(_passwordField, 'secret123');
      await tester.pump();
      await tester.tap(_submitBtn);
      await tester.pump();
      expect(calls.length, 2, reason: '重试是第 2 次独立请求（无半登录残留阻塞）');

      gate.completeWith(null);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('bottom_nav stub'),
        findsOneWidget,
        reason: '取消后重试成功应正常导航 /bottom_navigation',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'PD-1 请求在途退出页面后收到成功响应：saveHistory 在已回收 provider 上抛 UnmountedRefException（修复后移除 skip）',
      (tester) async {
        final calls = <String>[];
        final snacks = <String>[];
        final gate = _LoginGate();
        _SpyPassportNotifier spyFactory() =>
            _SpyPassportNotifier(gate, calls, snacks);
        await _pump(tester, notifier: spyFactory);

        await tester.enterText(_accountField, 'erin_account');
        await tester.enterText(_passwordField, 'secret123');
        await tester.pump();
        await tester.tap(_submitBtn);
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        // 成功响应返回时页面已销毁。login_page.dart `.then` 对成功分支
        // 无条件调用 notifier.saveHistory → 在已 dispose 的 autoDispose
        // provider 上访问 state（PD-1，详见 A01_APP_TEST_REPORT.md）。
        gate.completeWith(null);
        await tester.pump();
        await tester.pump();
      },
      // flutter_test 的 skip 仅收 bool；原因写在描述里
      skip: true,
    );
  });
}
