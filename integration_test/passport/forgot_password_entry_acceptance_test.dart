// integration_test/passport/forgot_password_entry_acceptance_test.dart
//
// 忘记密码【入口页】验收（批次158）：解锁 forgot_password_page.md 剩余
// 可自动化行。批次24续3 已过 7 行纯 UI + 批次80 回归 3 行；批次124 已
// 收口验证码页 12 行；入口页剩两行中——
//   - 「邮箱发送重置码并跳验证页」= 真实 SMTP 外发（红线，永不自动化）
//   - 「手机发送重置码并跳验证页」= 本场景 AT-FPE1（sms.switch=off 落库
//     不外发，TestPg 直读，全链自包含可重跑）
// 外加 bind_mobile_page.md「发送验证码失败弹出错误提示」= AT-BM2
// （HttpClient.client.dio 直换单例 adapter 拦 /passport/getcode 注入
// 业务失败；静态 adapterForTest 只在构造时生效，对 serviceContainer
// 单例无效——批次158 定案的新注入口径）。
//
// 此前 AT-FP1 八轮失败全部发生在真机 live binding（tap/enterText 不落，
// 见批次128/152 教训）；macOS 通道从未试过——批次124 深链/enterText 在
// macOS 全部可靠，本文件即 macOS 通道验证。
//
// 载体：AT-FPE1 用 51730（uid=111174215241304064，mobile=+8619900001234，
// 与批次124 同源）；AT-BM2 用 smoke_bob（未绑手机——已绑账号点「绑定手机号」
// 行弹解绑 sheet，按设计不进绑定页，批次158 实证）。本文件不改密码不消费
// 码，无 tearDown 恢复需求。
//
// 服务端契约（passport_logic getcode + verification_code_ds）：
//   - getcode 匿名可调（_publicEndpoints）；sms.switch=off → 码落库不外发
//   - per_minute_once 60s 节流（key={send_code, mobile}）→ 重跑前等窗
//
// 运行（--plain-name 单场景；define 与批次124 同配方）：
//   flutter test integration_test/passport/forgot_password_entry_acceptance_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/mine/account_security/bind_mobile_page.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_provider.dart';
import 'package:imboy/page/passport/forgot_password_page.dart';
import 'package:imboy/page/passport/forgot_password_pin_code_page.dart'
    show PinCodeVerificationPage;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

// AT-FPE1 载体（与批次124 同源，mobile=+8619900001234 契约已验证）
const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '111174215241304064',
);
// 与批次124 同载体手机号（契约已验证）；节流 key={send_code, +86…}
const _mobile = '+8619900001234';
// AT-BM2 载体：必须用未绑手机账号（smoke_bob）——已绑账号点「绑定手机号」
// 行弹解绑 action sheet，按设计不进绑定页（批次158 实证）。本地固定
// 测试号，凭据硬编码与既有验收文件同惯例。
const _bmUid = '1000000056';
const _bmPhone = 'smoke_bob';
const _bmPwd = 'admin888';
// AT-BM2 注入用：任意合法长度号码，请求被 adapter 拦截零服务端副作用
const _bmFailMobile = '+8619900001567';

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

Future<bool> _boot(
  WidgetTester tester, {
  String uid = _uid,
  String? phone,
  String? password,
}) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  // macOS flutter_tester 容器持久化上次运行登录态：非目标账号先登出
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != uid) {
    await UserRepoLocal.to.quitLogin();
    final navCtx = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  final loginPhone = phone ?? FlowConfig.testPhone;
  final loginPwd = password ?? FlowConfig.testPassword;
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(tester, phone: loginPhone, password: loginPwd);
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == uid) {
      // 上场景把 app 留在验证码页等深链页：已登录但不在主 Shell，
      // 强制回壳（批次154 shell 绕行同款路径）
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, uid, reason: '登录账号必须是目标载体');
  return true;
}

/// 距上次发码秒数（per_minute_once=60s 节流窗）
/// PG numeric 经驱动回 String，必须双路解析（`is num` 恒 false 的坑）
Future<int> _secondsSinceCodeIssued(String idWithCc) async {
  final secs = await TestPg.scalar(
    'SELECT COALESCE(EXTRACT(EPOCH FROM (now() - created_at)), 9999) '
    'FROM verification_code WHERE id = @id LIMIT 1',
    {'id': idWithCc},
  );
  if (secs is num) return secs.toInt();
  // PG numeric 回 String 且带小数（'24.731'），int.tryParse 会 null
  return double.tryParse('$secs')?.toInt() ?? 9999;
}

Future<void> _waitForThrottleWindow(String idWithCc) async {
  for (var i = 0; i < 18; i++) {
    if (await _secondsSinceCodeIssued(idWithCc) > 55) return;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

/// AT-BM2 注入适配器：只拦 /passport/getcode 注入业务失败，其余透传
class _FailGetCodeAdapter implements HttpClientAdapter {
  _FailGetCodeAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  int intercepted = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.contains('/passport/getcode')) {
      intercepted++;
      flowLog('[AT-BM2] 拦截 getcode（注入失败 #$intercepted）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 1,
          'msg': 'simulated_send_code_down',
          'payload': <String, dynamic>{},
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-FPE1 手机发送重置码并跳验证页', (tester) async {
    if (!await _boot(tester)) return;

    // 入口页深链可达（批次124：登录态下 passport 公开路由不被重定向拦截）
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/forgot_password');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(ForgotPasswordPage)),
        seconds: 10,
      ),
      isTrue,
      reason: '深链应直达找回密码入口页',
    );

    // 默认邮箱 tab：邮箱输入在、手机输入不在
    expect(
      tester.any(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '请输入邮箱',
        ),
      ),
      isTrue,
      reason: '默认应停在邮箱 tab',
    );

    // 切手机 tab：animateTo 直驱（真机 live binding tap 不稳，macOS 通道
    // controller 直驱确定性等价；tab 切换本身批次24续3 已单独过）
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    tabBar.controller!.animateTo(1);
    await _pump(tester, seconds: 2);
    flowLog('[诊断] tab index=${tabBar.controller!.index}');
    final mobileField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '请输入手机',
    );
    expect(
      tester.any(mobileField),
      isTrue,
      reason: '切手机 tab 后应渲染手机号输入（PhoneInputWidget）',
    );

    // 输入手机号（enterText 触发 onChanged → _fullMobile='+8619900001234'）
    await tester.enterText(mobileField.first, '19900001234');
    await _pump(tester, seconds: 1);

    // 重跑安全：等发码节流窗（60s）过去再点下一步
    await _waitForThrottleWindow(_mobile);

    // 下一步：TabBarView settle 后仅当前页在树，若同名按钮残留取 last
    final nextBtns = find.text('下一步');
    flowLog('[诊断] 下一步按钮数=${nextBtns.evaluate().length}');
    await tester.ensureVisible(nextBtns.last);
    await _pump(tester, seconds: 1);
    await tester.tap(nextBtns.last, warnIfMissed: false);

    // 跳验证码页（sendCode 成功 → context.push('/forgot_password/pin')）
    final onPin = await _waitFor(
      tester,
      () => tester.any(find.byType(PinCodeVerificationPage)),
      seconds: 10,
    );
    expect(onPin, isTrue, reason: '发码成功应跳验证码页');

    // 验证码页展示发送目标（mobile 分支文案）
    final shown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(_mobile, findRichText: true)),
      seconds: 8,
    );
    expect(shown, isTrue, reason: '验证码页应展示发送目标 $_mobile');
    expect(
      tester.any(find.textContaining('验证码已发送到手机', findRichText: true)),
      isTrue,
      reason: 'mobile 类型应走「已发送到手机」文案分支',
    );

    // DB 闭环：码落库且新鲜（sms.switch=off 不外发）
    final code = (await TestPg.scalar(
      'SELECT code FROM verification_code WHERE id = @id LIMIT 1',
      {'id': _mobile},
    )).toString();
    expect(code.length, 6, reason: '验证码应落库（sms off 口径）');
    final age = await _secondsSinceCodeIssued(_mobile);
    expect(age, lessThan(90), reason: '落库码应是本次 UI 发出（<90s），实际 ${age}s');
    flowLog('[AT-FPE1] PASS：入口页手机发码 → 跳验证码页 + DB 码新鲜');
  });

  testWidgets('AT-BM2 发送验证码失败弹出错误提示', (tester) async {
    // 未绑手机载体 smoke_bob：已绑账号（51730）点行弹解绑 sheet 不可达
    if (!await _boot(tester, uid: _bmUid, phone: _bmPhone, password: _bmPwd)) {
      return;
    }

    // 直换单例 adapter（静态 adapterForTest 对已构造实例无效——批次158 定案）
    final adapter = _FailGetCodeAdapter();
    final original = HttpClient.client.dio.httpClientAdapter;
    HttpClient.client.dio.httpClientAdapter = adapter;
    addTearDown(() => HttpClient.client.dio.httpClientAdapter = original);

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/account_security');
    expect(
      await _waitFor(tester, () => tester.any(find.text('绑定手机号')), seconds: 10),
      isTrue,
      reason: '前置：账号安全页可达',
    );
    final rowFinder = find.text('绑定手机号');
    await tester.ensureVisible(rowFinder);
    await _pump(tester, seconds: 1);
    await tester.tap(rowFinder, warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(BindMobilePage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：绑定手机页可达',
    );

    // PhoneInputWidget onChanged 回调控制器直写不触发 → 直调 notifier
    // （批次157 AT-BM1 定案配方）
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BindMobilePage)),
    );
    container.read(bindMobileProvider.notifier).updateMobile(_bmFailMobile);
    await _pump(tester, seconds: 1);
    final st0 = container.read(bindMobileProvider);
    expect(st0.canSendCode, isTrue, reason: '前置：合法手机号后发码钮可用');

    final sendBtn = find.textContaining('获取验证码');
    await tester.ensureVisible(sendBtn);
    await _pump(tester, seconds: 1);
    await tester.tap(sendBtn, warnIfMissed: false);

    // 失败 toast（AppLoading.showError → EasyLoading，3s 展示窗内可查）
    final toast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('simulated_send_code_down')),
      seconds: 8,
    );
    expect(toast, isTrue, reason: '发码失败应弹错误提示（含注入错误串）');
    expect(adapter.intercepted, greaterThanOrEqualTo(1), reason: '请求应被拦截');
    expect(
      tester.any(find.textContaining('获取验证码')),
      isTrue,
      reason: '失败后不应进入倒计时（按钮回退可用态）',
    );

    // wire 级闭环：拦截=零服务端副作用，DB 无该号码的码
    await _pump(tester, seconds: 2);
    final row = await TestPg.scalar(
      'SELECT code FROM verification_code WHERE id = @id LIMIT 1',
      {'id': _bmFailMobile},
    );
    expect(row, isNull, reason: '注入失败路径不应产生验证码落库');
    flowLog('[AT-BM2] PASS：发码失败 toast + 无倒计时 + DB 零副作用');
  });
}
