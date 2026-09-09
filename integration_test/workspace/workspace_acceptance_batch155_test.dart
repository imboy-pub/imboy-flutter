// integration_test/workspace/workspace_acceptance_batch155_test.dart
//
// Workspace 域两行阻塞解锁验收（批次155，配方同 batch154）：
//
//   AT-WIDEM 服务端幂等命中时 toast 提示幂等命中文案并同样进入 Overview
//     （workspace_create_page 台账行；fixture=AT-WS-IDEM-148
//      111613416917174272，语义键幂等 owner+name；⚠须 bob active<100——
//      服务端 count 检查先于 semantic idempotent，100 满时同名创建返回
//      409 而非幂等命中）
//   AT-WBR1 非 Owner 保存被服务端拒绝并透出错误消息（仅 Owner 可改）
//     （workspace_branding_page 台账行；alice 已是 BobWS-T27 成员
//      （批次153 WIV1 转绿产物），服务端 403「仅工作区 Owner 可执行该
//      操作」已 wire 锚定）
//
// 载体：smoke_bob（uid=1000000056）→ AT-WIDEM；
//       smoke_alice（uid=1000000051）→ AT-WBR1（测试内切换登录）。
// 红线：仅本地（9801/4323）；不触碰真人。
//
// 运行（配方同 batch154）：
//   flutter test integration_test/workspace/workspace_acceptance_batch155_test.dart \
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
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/workspace/workspace_branding_page.dart';
import 'package:imboy/page/workspace/workspace_create_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _wsT27 = '110073884375779328'; // BobWS-T27
const _wsIdem = '111613416917174272'; // AT-WS-IDEM-148
const _idemName = 'AT-WS-IDEM-148';
const _aliceUid = '1000000051';
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

/// 登录循环：欢迎页→登录页→performLogin，直到 uid 就位且离开登录页。
Future<void> _loginUntil(
  WidgetTester tester, {
  required String account,
  required String password,
  required String uid,
}) async {
  const loginSubmit = Key('login_submit_button');
  for (var i = 0; i < 8; i++) {
    if (UserRepoLocal.to.currentUid == uid && isOnMainShell(tester)) {
      return;
    }
    if (tester.any(find.byKey(loginSubmit))) {
      await performLogin(tester, phone: account, password: password);
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    }
    await _pump(tester, seconds: 6);
  }
  expect(UserRepoLocal.to.currentUid, uid, reason: '登录切换失败：$account');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次155：AT-WIDEM（bob）+ AT-WBR1（alice）', (tester) async {
    expect(
      _allow,
      isTrue,
      reason: '需要 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true 显式放行（业务写入红线）',
    );

    // ══════════ 场景一 AT-WIDEM（smoke_bob）══════════
    app.main();
    await _pump(tester, seconds: 12);
    if (UserRepoLocal.to.currentUid.isNotEmpty) {
      await UserRepoLocal.to.quitLogin();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
      await _pump(tester, seconds: 4);
      await Future<void>.delayed(const Duration(seconds: 4));
      await _pump(tester, seconds: 2);
    }
    await _loginUntil(
      tester,
      account: FlowConfig.testPhone,
      password: FlowConfig.testPassword,
      uid: _expectedUid,
    );
    flowLog('[批次155] bob 登录完成 uid=${UserRepoLocal.to.currentUid}');

    // 前置：active<100（count 检查先于语义幂等，见文件头）
    final cnt = int.parse(
      '${await TestPg.scalar("SELECT count(*) FROM workspace "
      "WHERE owner_id = 1000000056 AND status = 'active'")}',
    );
    expect(cnt < 100, isTrue, reason: '前置：幂等行须 active<100（当前=$cnt）');

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/create');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspaceCreatePage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：创建页可达',
    );

    final nameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(WorkspaceCreatePage),
        matching: find.byType(EditableText),
      ),
    );
    nameField.controller.text = _idemName;
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.byKey(const ValueKey('workspace-create-submit')),
      warnIfMissed: false,
    );
    // 幂等命中 toast（「已存在同名工作区，直接进入」）+ 进入 Overview
    final idemToast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('已存在同名工作区')),
      seconds: 5,
    );
    expect(idemToast, isTrue, reason: 'AT-WIDEM：幂等命中 toast 未出现');
    expect(
      await _waitFor(
        tester,
        () => !tester.any(find.byType(WorkspaceCreatePage)),
        seconds: 8,
      ),
      isTrue,
      reason: 'AT-WIDEM：幂等命中应同样进入 Overview（创建页须关闭）',
    );
    flowLog('[AT-WIDEM] ✓ toast + 进入 Overview');

    // wire 锚：异 request_id 同名再创建返回 status=existing 且 id 不变
    // （节流 three_second_once 窗口 3s，先等待）
    await Future<void>.delayed(const Duration(seconds: 4));
    final resp = await HttpClient.client
        .post(
          '/api/v1/workspaces',
          data: <String, dynamic>{
            'name': _idemName,
            'request_id': 'at155-idem-wire',
          },
        )
        .timeout(const Duration(seconds: 8));
    expect(resp.ok, isTrue, reason: 'AT-WIDEM：语义幂等命中须成功返回');
    expect(
      '${resp.payload['status']}',
      'existing',
      reason: 'AT-WIDEM：envelope status=existing',
    );
    expect(
      '${resp.payload['workspace']['id']}',
      _wsIdem,
      reason: 'AT-WIDEM：命中既有工作区 id（未新建）',
    );
    final cntAfter = int.parse(
      '${await TestPg.scalar("SELECT count(*) FROM workspace "
      "WHERE owner_id = 1000000056 AND status = 'active'")}',
    );
    expect(cntAfter, cnt, reason: 'AT-WIDEM：幂等命中不新建，active 计数不变');
    flowLog('[AT-WIDEM] ✓ wire status=existing id=$_wsIdem 计数不变');
    flowLog('[AT-WIDEM] ── PASS ──');

    // ══════════ 场景二 AT-WBR1（切换 smoke_alice）══════════
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 4);
    await Future<void>.delayed(const Duration(seconds: 4));
    await _pump(tester, seconds: 2);
    await _loginUntil(
      tester,
      account: 'smoke_alice',
      password: 'admin888',
      uid: _aliceUid,
    );
    flowLog('[批次155] alice 登录完成 uid=${UserRepoLocal.to.currentUid}');

    // 深链 branding 编辑页（非 Owner 深链可达性本身即本行验证点）
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/$_wsT27/branding');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspaceBrandingPage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：非 Owner 深链 branding 编辑页可达',
    );
    final wizardId = tester.widget<WorkspaceBrandingPage>(
      find.byType(WorkspaceBrandingPage),
    );
    expect(
      wizardId.workspaceId.toString(),
      _wsT27,
      reason: '前置：编辑页实例绑定 BobWS-T27（go 换页防回归）',
    );
    await _pump(tester, seconds: 2); // 等字段初始化

    // 非 Owner 保存 → 403 消息透出 + 页面停留
    final saveFinder = find.byKey(const ValueKey('workspace-branding-save'));
    await tester.ensureVisible(saveFinder);
    await _pump(tester, seconds: 1);
    await tester.tap(saveFinder, warnIfMissed: false);
    final denyToast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('Owner')),
      seconds: 5,
    );
    expect(
      denyToast,
      isTrue,
      reason: 'AT-WBR1：服务端 403「仅工作区 Owner 可执行该操作」须 toast 透出',
    );
    expect(
      tester.any(find.byType(WorkspaceBrandingPage)),
      isTrue,
      reason: 'AT-WBR1：拒绝后停留编辑页（不 pop）',
    );
    flowLog('[AT-WBR1] ✓ 403 toast 透出 + 停留编辑页');

    // wire 锚：alice 直发 branding 写 = 403 + 名字未被改（DB 锚定）
    final resp2 = await HttpClient.client
        .post(
          '/api/v1/workspaces/$_wsT27/branding',
          data: <String, dynamic>{
            'branding': <String, dynamic>{'name': 'AT155-HACK'},
          },
        )
        .timeout(const Duration(seconds: 8));
    expect(resp2.ok, isFalse, reason: 'AT-WBR1：非 Owner 写必须被拒');
    expect(resp2.code, 403, reason: 'AT-WBR1：envelope code=403');
    expect(resp2.msg, '仅工作区 Owner 可执行该操作', reason: 'AT-WBR1：服务端消息与 toast 文案同源');
    final wsName =
        '${await TestPg.scalar("SELECT name FROM workspace WHERE id = $_wsT27")}';
    expect(wsName, 'BobWS-T27', reason: 'AT-WBR1：写被拒，工作区名未变');
    flowLog('[AT-WBR1] ✓ wire code=403 msg 同源 + DB 名未变');
    flowLog('[AT-WBR1] ── PASS ──');
  });
}
