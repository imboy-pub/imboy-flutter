import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// LoginPage authentication lifecycle tests (A01-NC-1/2/3).
///
/// Keep the request gate across page instances to exercise duplicate submits,
/// failed requests and callbacks that arrive after the login page is disposed.

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

/// UX-01:LOCAL:01 spy：预置账号历史（alice/bob），用于切换身份时
/// 钉住「无旧身份/凭据投影」。initLoginHistory 置空以免真实实现把
/// mock 存储里的空列表覆盖掉预置历史。
class _HistorySpyPassportNotifier extends PassportNotifier {
  _HistorySpyPassportNotifier(this.gate, this.calls, this.snackbars);

  final _LoginGate gate;
  final List<String> calls;
  final List<String> snackbars;

  @override
  PassportState build() {
    return PassportState(
      loginAccountCtl: TextEditingController(),
      accountHistory: const ['alice_acct', 'bob_acct'],
    );
  }

  @override
  void initLoginHistory() {}

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
      expect(gating.onPressed, isNull, reason: '请求中 login_submit_button 必须禁用');
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

      await _unmount(tester);
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

      await _unmount(tester);
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

      // 网络此刻才返回失败；异步登录回调继续执行。
      // 关键回归点是 `if (mounted)` 守卫——守卫若丢失，
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

      // 中途退出，先让本次请求失败，再创建新的页面实例重试。
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

      await _unmount(tester);
    });

    testWidgets('PD-1 请求在途退出页面后收到成功响应：历史保存异常被接住且不导航', (tester) async {
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
      // The disposed provider cannot save history. The completion handler
      // catches that failure and must not navigate or rebuild the old page.
      gate.completeWith(null);
      await tester.pump();
      await tester.pump();

      expect(calls, ['erin_account']);
      expect(tester.takeException(), isNull);
      expect(find.text('bottom_nav stub'), findsNothing);
      expect(snacks, isEmpty, reason: '卸载后的历史保存失败不得再弹提示');
      expect(StorageService.to.getStringList(Keys.loginHistoryAccount), isNull);
      _expectNoAuthStateOnDisk();
    });
  });

  group('LoginPage keyboard completion (UX-01:LOCAL:02 键盘可完成)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('键盘 done 提交：password 字段动作直接发起登录并成功导航', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      // 纯键盘路径：enterText 模拟键盘输入，全程不点击提交按钮
      await tester.enterText(_accountField, 'kate_account');
      await tester.enterText(_passwordField, 'kbd_secret');
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(calls, ['kate_account'], reason: '键盘 done 必须能完成登录提交');
      gate.completeWith(null);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('bottom_nav stub'),
        findsOneWidget,
        reason: '键盘提交成功后与触控提交同权，正常进入主界面',
      );

      await _unmount(tester);
    });

    testWidgets('键盘连按 done：在途门闸拦截，不得重复发起登录请求', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'kbd_dup_account');
      await tester.enterText(_passwordField, 'kbd_secret');
      await tester.pump();

      // 连按两次 done：第二次发生在第一次 setState(_isLoading=true) 之后、
      // 重建之前，验证键盘路径不能绕过按钮禁用态
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(calls.length, 1, reason: '键盘重复 done 与双击同罪，必须被门闸拦下');

      gate.completeWith('密码错误');
      await tester.pump();
      await tester.pump();
      expect(find.text('bottom_nav stub'), findsNothing);

      await _unmount(tester);
    });
  });

  group('LoginPage error recovery (UX-01:LOCAL:02 错误状态真实恢复入口)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('登录失败：输入保留、按钮恢复，修正后重试成功', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      await tester.enterText(_accountField, 'retain_account');
      await tester.enterText(_passwordField, 'typed_wrong_pwd');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      gate.completeWith('账号或密码错误');
      await tester.pump();
      await tester.pump();

      expect(snacks, isNotEmpty, reason: '失败必须反馈用户');
      expect(find.byType(LoginPage), findsOneWidget, reason: '失败停留登录页');
      String fieldText(Finder f) => tester
          .widget<EditableText>(
            find.descendant(of: f, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      expect(
        fieldText(find.byKey(const Key('login_phone_input'))),
        'retain_account',
        reason: '恢复入口：失败后账号输入必须保留（免全部重输）',
      );
      expect(
        fieldText(_passwordField),
        'typed_wrong_pwd',
        reason: '恢复入口：失败后密码输入必须保留',
      );
      final afterFail = tester.widget<CupertinoButton>(_submitBtn);
      expect(afterFail.onPressed, isNotNull, reason: '失败后立即可重试');

      // 真实恢复：只修正密码，重试即成功
      await tester.enterText(_passwordField, 'typed_right_pwd');
      await tester.pump();
      await tester.tap(_submitBtn);
      await tester.pump();
      expect(calls, ['retain_account', 'retain_account']);
      gate.completeWith(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('bottom_nav stub'), findsOneWidget, reason: '重试成功进入主界面');

      await _unmount(tester);
    });
  });

  group('LoginPage stale identity projection (UX-01:LOCAL:01 切账号)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    testWidgets('切换历史账号：无凭据注入/自动登录，提交身份=当前字段值', (tester) async {
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _HistorySpyPassportNotifier spyFactory() =>
          _HistorySpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);

      // alice 的输入现场（旧身份）
      await tester.enterText(_accountField, 'alice_acct');
      await tester.enterText(_passwordField, 'alice_typed_pwd');
      await tester.pump();

      // 打开历史下拉切换到 bob（账号切换）
      await tester.tap(find.byKey(const Key('login_history_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login_history_item_bob_acct')));
      await tester.pump();

      String fieldText(Finder f) => tester
          .widget<EditableText>(
            find.descendant(of: f, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      expect(
        fieldText(find.byKey(const Key('login_phone_input'))),
        'bob_acct',
        reason: '切换后账号字段必须是新选身份',
      );
      expect(
        fieldText(_passwordField),
        'alice_typed_pwd',
        reason: '密码字段只能保留用户亲手输入的内容，不得注入任何缓存凭据投影',
      );
      expect(calls, isEmpty, reason: '切换身份本身不得自动发起登录');
      expect(
        find.text('bottom_nav stub'),
        findsNothing,
        reason: '切换不得触发导航（假成功）',
      );

      // 键盘提交：提交的必须是当前字段中的 bob，不得串用旧身份 alice
      await tester.enterText(_passwordField, 'alice_typed_pwd');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(calls, ['bob_acct'], reason: '提交身份取当前字段值，无旧身份串用');

      gate.completeWith('密码错误');
      await tester.pump();
      await tester.pump();
      _expectNoAuthStateOnDisk();

      await _unmount(tester);
    });
  });

  group('LoginPage alipay interrupted residue (UX-01:LOCAL:01 假成功)', () {
    testWidgets('支付宝登录被杀残留：提示重试而非假成功，标记清除', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        Keys.alipayLoginInProgress: true,
      });
      await StorageService.init();
      final calls = <String>[];
      final snacks = <String>[];
      final gate = _LoginGate();
      _SpyPassportNotifier spyFactory() =>
          _SpyPassportNotifier(gate, calls, snacks);
      await _pump(tester, notifier: spyFactory);
      await tester.pump();

      expect(snacks, isNotEmpty, reason: '中断残留必须给出重试提示，而非静默假成功');
      expect(
        find.text('bottom_nav stub'),
        findsNothing,
        reason: '残留标记不得造成假登录导航',
      );
      expect(
        StorageService.to.getBool(Keys.alipayLoginInProgress),
        isNot(true),
        reason: '提示一次后标记必须清除（再次进入不得重复投影旧中断）',
      );
      expect(calls, isEmpty, reason: '恢复提示不等于自动登录');
      _expectNoAuthStateOnDisk();

      // 真实恢复入口：中断提示不锁死表单，输入后即可正常提交
      await tester.enterText(_accountField, 'retry_after_interrupt');
      await tester.enterText(_passwordField, 'secret123');
      await tester.pump();
      final btn = tester.widget<CupertinoButton>(_submitBtn);
      expect(btn.onPressed, isNotNull, reason: '提示后登录表单保持可用（真实恢复入口）');

      await _unmount(tester);
    });
  });
}
