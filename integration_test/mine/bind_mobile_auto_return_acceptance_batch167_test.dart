// integration_test/mine/bind_mobile_auto_return_acceptance_batch167_test.dart
//
// bind_mobile_page「提交成功后自动返回上一页」行解锁（批次167，automation
// 第四十轮）。原阻塞理由「待环境恢复执行」按批次146 本地一次性账号口径解阻：
// API 创建一次性账号（sms 沙盒码查表，批次160 配方）→ app 登录 →
// /account_security → 绑定手机号 tile → action sheet「更换手机号」→
// BindMobilePage → 输入新手机号 → 获取验证码（沙盒落库）→ 查表填码 →
// 确认更换 → 断言自动 pop 回账号安全页 + DB mobile 已改绑。
//
// 链路：BindMobilePage.submit → userApi.changeMobile(PUT /api/v1/user/update
// field=mobile+code) → 服务端 user_logic:update→passport_logic:consume_code
// 查 verification_code + 新号占用校验 → ok → 页面 Navigator.pop()。
//
//   AT-BM1  改绑提交成功后自动返回上一页（本行功能点）
//   AT-BM1  DB 断言：一次性账号 mobile 已改为新号
//
// 改动仅及本地 4323 测试库的一次性账号（每跑新建），不触碰 smoke 账号绑定关系。
//
// 运行（define 与批次162 同配方）：
//   flutter test integration_test/mine/bind_mobile_auto_return_acceptance_batch167_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

final _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:9801',
);
const _throwawayPwd = 'Bm167#throwaway';

/// 每跑新建一次性账号：11 位手机号（1[3-9]xxxxxxxxx），尾段取毫秒保证唯一
String _newMobile(String prefix) {
  final tail = (DateTime.now().microsecondsSinceEpoch % 100000000)
      .toString()
      .padLeft(8, '7');
  return '$prefix$tail';
}

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

Future<String> _getCodeFromPg(String mobile) async {
  for (var i = 0; i < 20; i++) {
    final code = await TestPg.scalar(
      'SELECT code FROM verification_code WHERE id = @_id '
      'AND created_at > now() - interval \'90 seconds\' LIMIT 1',
      {'_id': mobile},
    );
    if (code != null && '$code'.length == 6) return '$code';
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return '';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次167：AT-BM1 改绑提交成功后自动返回上一页', (tester) async {
    // ── 前置：API 创建一次性账号（mobile A 已绑定）+ 准备改绑目标 B ──
    final mobileA = _newMobile('167');
    final mobileB = _newMobile('168');
    flowLog('[AT-BM1] 一次性账号 A=$mobileA，改绑目标 B=$mobileB');

    final client = FlowApiClient(baseUrl: _baseUrl, deviceId: 'bm167-setup');
    final getcode = await client.post(
      '/api/v1/passport/getcode',
      data: {'type': 'sms', 'scene': 'signup', 'account': mobileA},
    );
    expect(getcode['code'], 0, reason: '前置：getcode(A) 应成功: ${getcode['msg']}');
    final signupCode = await _getCodeFromPg(mobileA);
    expect(signupCode.length, 6, reason: '前置：signup 码应落库可读（sms 沙盒口径）');

    final signup = await client.post(
      '/api/v1/passport/signup',
      data: {
        'type': 'mobile',
        'account': mobileA,
        'pwd': _throwawayPwd,
        'rsa_encrypt': '0',
        'code': signupCode,
        'nickname': 'bm167_throwaway',
        'sys_version': 'macos-integration-test',
      },
    );
    expect(
      signup['code'],
      0,
      reason: '前置：一次性账号注册应成功: ${signup['msg']}',
    );
    final throwawayUid = '${(signup['payload'] as Map?)?['uid'] ?? ''}';
    expect(throwawayUid.isNotEmpty, isTrue, reason: '前置：signup 应返回 uid');
    flowLog('[AT-BM1] 一次性账号已创建 uid=$throwawayUid');

    // ── app 登录为一次性账号 ──
    app.main();
    await _pump(tester, seconds: 12);
    if (UserRepoLocal.to.currentUid.isNotEmpty &&
        UserRepoLocal.to.currentUid != throwawayUid) {
      await UserRepoLocal.to.quitLogin();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
      await _pump(tester, seconds: 6);
    }
    for (var i = 0; i < 12; i++) {
      if (UserRepoLocal.to.currentUid == throwawayUid &&
          (tester.any(find.byKey(const Key('workspace-empty-create-entry'))) ||
              tester.any(find.text('还没有工作区')) ||
              isOnMainShell(tester))) {
        break;
      }
      if (tester.any(find.byKey(const Key('login_submit_button')))) {
        await performLogin(tester, phone: mobileA, password: _throwawayPwd);
      } else if (isOnWelcomePage(tester)) {
        await leaveWelcomePage(tester);
      } else if (UserRepoLocal.to.currentUid.isNotEmpty &&
          UserRepoLocal.to.currentUid != throwawayUid) {
        await UserRepoLocal.to.quitLogin();
        GoRouter.of(tester.element(find.byType(Navigator).first))
            .go('/welcome');
        await _pump(tester, seconds: 6);
      }
      await _pump(tester, seconds: 6);
    }
    expect(
      UserRepoLocal.to.currentUid,
      throwawayUid,
      reason: '登录账号必须是一次性账号',
    );
    await _pump(tester, seconds: 5);

    // ── 进入账号安全页 → 绑定手机号 tile → action sheet 更换手机号 ──
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/account_security');
    final tileShown = await _waitFor(
      tester,
      () => tester.any(find.text('绑定手机号')),
      seconds: 10,
    );
    expect(tileShown, isTrue, reason: '前置：账号安全页应有「绑定手机号」tile');
    await tester.tap(find.text('绑定手机号').first, warnIfMissed: false);
    final sheetShown = await _waitFor(
      tester,
      () => tester.any(find.text('更换手机号')),
      seconds: 8,
    );
    expect(sheetShown, isTrue, reason: '前置：已绑定账号点 tile 应弹 action sheet');
    await tester.tap(find.text('更换手机号').first, warnIfMissed: false);
    final pageShown = await _waitFor(
      tester,
      () => tester.any(find.text('当前手机号')),
      seconds: 10,
    );
    expect(pageShown, isTrue, reason: '前置：应进入更换手机号页（当前手机号 tile 可见）');
    flowLog('[AT-BM1] 已进入更换手机号页');

    // ── 输入新手机号 → 获取验证码（沙盒）→ 查表填码 ──
    final phoneField = find.byType(TextField).first;
    await tester.enterText(phoneField, mobileB);
    await _pump(tester, seconds: 1);

    await tester.tap(find.text('获取验证码'), warnIfMissed: false);
    final countdownShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(RegExp(r'\d+s'))),
      seconds: 10,
    );
    expect(countdownShown, isTrue, reason: '点击获取验证码后应进入倒计时（请求已发出）');
    final bmCode = await _getCodeFromPg(mobileB);
    expect(bmCode.length, 6, reason: '改绑验证码应落库可读（sms 沙盒口径）');
    flowLog('[AT-BM1] 验证码已落库获取');

    final codeField = find.byType(CupertinoTextField);
    await tester.enterText(codeField.first, bmCode);
    await _pump(tester, seconds: 1);

    // ── 核心断言：确认更换 → 提交成功 → 自动 pop 回账号安全页 ──
    await tester.tap(find.text('确认更换'), warnIfMissed: false);
    final returned = await _waitFor(
      tester,
      () =>
          tester.any(find.text('绑定手机号')) &&
          !tester.any(find.text('当前手机号')),
      seconds: 15,
    );
    expect(
      returned,
      isTrue,
      reason:
          'BUG 修复点验证：提交成功后应 Navigator.pop 自动返回账号安全页'
          '（绑定手机号 tile 可见且更换手机号页已退出）',
    );
    flowLog('[AT-BM1] PASS：提交成功自动返回账号安全页');

    // ── DB 断言：一次性账号 mobile 已改为 B ──
    final dbMobile = await TestPg.scalar(
      'SELECT mobile FROM "user" WHERE id = @_uid',
      {'_uid': int.parse(throwawayUid)},
    );
    expect(
      '$dbMobile',
      mobileB,
      reason: '改绑后服务端 mobile 应为新号 $mobileB，实际: $dbMobile',
    );
    // 本地登录态缓存的 mobile 也应已刷新
    expect(
      UserRepoLocal.to.current.mobile,
      mobileB,
      reason: '本地用户信息的 mobile 应同步为新号',
    );
    flowLog('[AT-BM1] DB 断言 OK：mobile 已改绑为 $mobileB');
  });
}
