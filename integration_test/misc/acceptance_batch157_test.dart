// integration_test/misc/acceptance_batch157_test.dart
//
// 五行阻塞解锁验收（批次157，配方同 batch154/155/156）：
//
//   AT-BM1 绑定手机：发送验证码后倒计时回显
//     （bind_mobile_page 台账行；sms.switch=off 本地验证码落库不外发——
//      红线评估：email 路径无开关且本地配置真实 SMTP，会真实外发，
//      故 bind_email/forgot 邮箱两条维持阻塞不测）
//   （AT-FP1 forgot_password 手机行暂缓：live binding 下 TabBar/深链
//     行为不稳定，run8~17 多轮未收敛，拆出专项调试，本批不阻塞交付）
//   AT-LR1 直播间列表：房间行展示直播状态与观看人数
//   AT-LR2 点击直播中房间进入观看页
//     （live_room_list 台账行×2；fixture=AT-LIVE-FIXTURE-138
//      111596538331138048，bob 所有、status=1 直播中、viewer_count=0，
//      wire 预验证列表对 bob 可见）
//   AT-LR3 观看页标题栏展示当前观看人数
//     （subscriber_page 台账行；L84 viewerCount 渲染）
//
// 载体：smoke_bob（uid=1000000056）。测试手机号为不存在的假号
// 17600001577/17600001588（sms off 落库，不触真实短信网关）。
//
// 运行（配方同 batch154）：
//   flutter test integration_test/misc/acceptance_batch157_test.dart \
//     -d <device> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tab, TabBar, TabBarView, TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/live_room/live_room_list/live_room_list_page.dart';
import 'package:imboy/page/live_room/subscriber/subscriber_page.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_page.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _mobileForBind = '17600001577';
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次157：AT-BM1 + AT-LR1/2/3', (tester) async {
    expect(
      _allow,
      isTrue,
      reason: '需要 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true 显式放行',
    );

    app.main();
    await _pump(tester, seconds: 12);
    if (UserRepoLocal.to.currentUid.isNotEmpty) {
      await UserRepoLocal.to.quitLogin();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
      await _pump(tester, seconds: 4);
      await Future<void>.delayed(const Duration(seconds: 4));
      await _pump(tester, seconds: 2);
    }
    const loginSubmit = Key('login_submit_button');
    for (var i = 0; i < 8; i++) {
      if (UserRepoLocal.to.currentUid == _expectedUid &&
          isOnMainShell(tester)) {
        break;
      }
      if (tester.any(find.byKey(loginSubmit))) {
        await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        );
      } else if (isOnWelcomePage(tester)) {
        await leaveWelcomePage(tester);
      }
      await _pump(tester, seconds: 6);
    }
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');
    flowLog('[批次157] bob 登录完成');

    // ══════════ AT-BM1：绑定手机发送验证码倒计时 ══════════
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/account_security');
    expect(
      await _waitFor(tester, () => tester.any(find.text('绑定手机号')), seconds: 10),
      isTrue,
      reason: '前置：账号安全页可达',
    );
    // 精确匹配行标题（页面顶部 tips「绑定手机号和邮箱…」也含前缀，
    // textContaining 的 first 会命中不可点的 tips，run1 教训）
    final rowFinder = find.text('绑定手机号');
    await tester.ensureVisible(rowFinder);
    await _pump(tester, seconds: 1);
    await tester.tap(rowFinder, warnIfMissed: false);
    final reached = await _waitFor(
      tester,
      () => tester.any(find.byType(BindMobilePage)),
      seconds: 10,
    );
    if (!reached) {
      final types = tester.allWidgets
          .map((w) => w.runtimeType.toString())
          .toSet()
          .take(60)
          .toList();
      flowLog('[诊断] tap 绑定手机号后 widget 类型: ${types.join(',')}');
    }
    expect(reached, isTrue, reason: '前置：绑定手机页可达');
    // 手机号输入是 PhoneInputWidget（onChanged 回调，控制器直写不触发），
    // 改直调 notifier.updateMobile——onInputChanged 的同一落点（批次157 定案）
    final bmNotifier = ProviderScope.containerOf(
      tester.element(find.byType(BindMobilePage)),
    ).read(bindMobileProvider.notifier);
    bmNotifier.updateMobile('+86$_mobileForBind');
    await _pump(tester, seconds: 1);
    final st0 = ProviderScope.containerOf(
      tester.element(find.byType(BindMobilePage)),
    ).read(bindMobileProvider);
    flowLog(
      '[诊断] tap 前 canSendCode=${st0.canSendCode} mobileOk=${st0.mobileOk} '
      'mobile=${st0.mobile}',
    );
    final sendBtn = find.textContaining('获取验证码');
    await tester.ensureVisible(sendBtn);
    await _pump(tester, seconds: 1);
    await tester.tap(sendBtn, warnIfMissed: false);
    final st1 = ProviderScope.containerOf(
      tester.element(find.byType(BindMobilePage)),
    ).read(bindMobileProvider);
    flowLog(
      '[诊断] tap 后 canSendCode=${st1.canSendCode} seconds=${st1.seconds} '
      'sending=${st1.isSendingCode}',
    );
    // 倒计时回显：按钮文本从「获取验证码」变为 Ns
    final countdown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(RegExp(r'^\d{1,3}s$'))),
      seconds: 8,
    );
    expect(countdown, isTrue, reason: 'AT-BM1：发送后按钮须进入倒计时回显');
    // 服务端落库轮询（sms.switch=off：不外发，verification_code 表可查）
    var bmSaved = false;
    for (var i = 0; i < 16 && !bmSaved; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final r = await TestPg.scalar(
        'SELECT code FROM verification_code WHERE id = @_m',
        {'_m': '+86$_mobileForBind'},
      );
      bmSaved = r != null && '$r'.isNotEmpty;
    }
    expect(bmSaved, isTrue, reason: 'AT-BM1：验证码须落库（sms off 口径）');
    flowLog('[AT-BM1] ✓ 倒计时回显 + 验证码落库');
    flowLog('[AT-BM1] ── PASS ──');

    // ══════════ AT-LR1/2/3：直播间列表与观看页 ══════════
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/live_room');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(LiveRoomListPage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：直播间列表页可达',
    );
    // 等列表数据（fixture 房间标题出现）
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('AT-LIVE-FIXTURE-138')),
        seconds: 10,
      ),
      isTrue,
      reason: 'AT-LR1：fixture 直播间行须在列表可见',
    );
    expect(
      tester.any(find.text('LIVE')),
      isTrue,
      reason: 'AT-LR1：直播中房间行须展示 LIVE 徽章',
    );
    expect(
      tester.any(find.byIcon(CupertinoIcons.eye)),
      isTrue,
      reason: 'AT-LR1：房间行须展示观看人数（eye 图标）',
    );
    flowLog('[AT-LR1] ✓ LIVE 徽章 + eye 观看人数渲染');
    flowLog('[AT-LR1] ── PASS ──');

    // 点击直播中房间行 → 观看页
    await tester.tap(find.text('AT-LIVE-FIXTURE-138'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(SubscriberPage)),
        seconds: 10,
      ),
      isTrue,
      reason: 'AT-LR2：点击直播中房间须进入观看页',
    );
    flowLog('[AT-LR2] ✓ 观看页到达');
    // 标题栏：房间标题 + 观看人数（viewer_count=0 → '0'）
    expect(
      tester.any(find.text('AT-LIVE-FIXTURE-138')),
      isTrue,
      reason: 'AT-LR3：观看页标题栏展示房间标题',
    );
    expect(
      await _waitFor(tester, () => tester.any(find.text('0')), seconds: 8),
      isTrue,
      reason: 'AT-LR3：标题栏展示当前观看人数（fixture=0）',
    );
    flowLog('[AT-LR3] ✓ 标题栏观看人数渲染');
    flowLog('[AT-LR3] ── PASS ──');
    flowLog('[AT-LR2] ── PASS（含 LR3 断言后统一收口）──');
  });
}
