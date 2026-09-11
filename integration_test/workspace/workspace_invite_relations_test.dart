// integration_test/workspace/workspace_invite_relations_test.dart
//
// Workspace 邀请向导「可选关系失败注入」验收（批次133）：解除台账阻塞行
// 「可选关系单条失败互不影响，失败行支持单独重试」（批次W2R2 起，
// 「UI 无失败注入手段」——批次128 adapterForTest 基建即故障注入手段）。
//
// 附带产品修复（批次133）：_ResultsSection 此前接收 onRetryGroup/
// onRetryChannel 但 build 未接线——失败行只有图标+文案无重试入口；
// 修复=_ResultRow failed 态加 workspace-invite-row-retry IconButton。
//
// 场景：
//   AT-WIV1 注入 /api/v1/group_member/join 业务失败（joinGroup 被拒）→
//   搜索选中 SmokeAlice → 提交邀请 → 断言 workspace 行成功 + group 行
//   失败（互不影响）+ channel 行成功 → 解除拦截点 group 行重试按钮 →
//   group 行转成功。
//
// 载体：smoke_bob（uid=1000000056，BobWS-T27 Owner，区内有 General 群
// 与 Announcements 频道）；被邀人 SmokeAlice（uid=1000000051）。
// 红线：仅本地（9801/4323）；被邀人为 smoke 测试账号，不扰动真人。
//
// 运行（配方同 workspace_picker_failure_test）：
//   flutter test integration_test/workspace/workspace_invite_relations_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/workspace/workspace_invite_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _inviteeUid = '1000000051'; // SmokeAlice
const _wsId = '110073884375779328'; // BobWS-T27（General 群+Announcements 频道）
// BobWS-T27 的 Announcements 频道（批次152 实测 id），用于前置清理遗留邀请
const _announcementsChannelId = '110073884407236608';
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

/// 邀请向导故障注入适配器（批次153 改名符实）：
/// - failGroupAdd：拦 /api/v1/group_member/join（可选关系群加入，批次152
///   实证该端点才是真实路径，原假设 /group/add 有误）
/// - failWsInvite：拦 members/invite（必选关系主流程）
class _FailInjectionAdapter implements HttpClientAdapter {
  _FailInjectionAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failGroupAdd = false;
  bool failWsInvite = false;

  ResponseBody _inject(String msg) => ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'code': 1,
      'msg': msg,
      'payload': <String, dynamic>{},
    }),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failGroupAdd && options.uri.path == '/api/v1/group_member/join') {
      flowLog('[AT-WIV] 拦截 group_member/join（注入 joinGroup 失败）');
      return _inject('simulated_group_join_down');
    }
    if (failWsInvite && options.uri.path.endsWith('/members/invite')) {
      flowLog('[AT-WIV] 拦截 members/invite（注入必选关系失败）');
      return _inject('simulated_ws_invite_down');
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
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

Future<void> _bootAndRelogin(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  // 无条件重登（批次128 run12 配方）：拦截生效性与 401 风暴排空都依赖它
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
        (isOnMainShell(tester) ||
            tester.any(find.text('还没有工作区')) ||
            tester.any(
              find.byKey(const Key('workspace-empty-create-entry')),
            ))) {
      return;
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
}

/// 公共前置（AT-WIV1/2 共用）：fixture 清理 → 登录 → 深链向导 →
/// 搜索并选中候选。返回注入适配器，用例各自再设 fail 标志。
Future<_FailInjectionAdapter> _setupAndSelectCandidate(
  WidgetTester tester,
) async {
  final adapter = _FailInjectionAdapter();
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);

  // 前置清理：删除往轮遗留的 Announcements 频道邀请（服务端「已邀请」
  // 会把本轮 channel 行打成失败，run14 实证）
  await TestPg.execute(
    'DELETE FROM channel_invitation '
    'WHERE channel_id = @c AND invitee_uid = @u',
    {'c': _announcementsChannelId, 'u': _inviteeUid},
  );

  await _bootAndRelogin(tester);

  // 深链邀请向导（BobWS-T27：General 群 + Announcements 频道齐全）
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).go('/workspace/$_wsId/members/invite');
  expect(
    await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceInvitePage)),
      seconds: 10,
    ),
    isTrue,
    reason: '前置：邀请向导页可达',
  );

  // 搜索被邀人（批次152 收口配方）：
  // - descendant 收窄：壳层另有 CupertinoSearchTextField，byType 命中多个
  // - run9 实证：live binding 下 tester.enterText 不落控制器（读回=""，
  //   _search 空 keyword 早退）→ 控制器直写；触发路径保持真实用户路径
  // - 关键词=账号串：pg_jieba FTS 只命中精确账号 smoke_alice
  flowLog('[AT-WIV] 向导页就绪，开始搜索 smoke_alice');
  final fieldEt = tester.widget<EditableText>(
    find.descendant(
      of: find.byType(WorkspaceInvitePage),
      matching: find.byType(EditableText),
    ),
  );
  fieldEt.controller.text = 'smoke_alice';
  await _pump(tester, seconds: 1);
  flowLog(
    '[AT-WIV] 页面实例数=${find.byType(WorkspaceInvitePage).evaluate().length}，'
    '字段文本="${fieldEt.controller.text}"',
  );
  // IME done 提交（onSubmitted=真实用户回车路径）；必须在按钮 tap 之前
  // ——tap 会移走焦点使 receiveAction no-op（run4/5 实证）
  flowLog('[AT-WIV] 发起键盘 done 提交');
  try {
    await tester.testTextInput
        .receiveAction(TextInputAction.done)
        .timeout(const Duration(seconds: 5));
    flowLog('[AT-WIV] done action 已返回');
  } catch (e) {
    flowLog('[AT-WIV] done action 失败/超时：$e');
  }
  await _pump(tester, seconds: 3);
  // 按钮双 tap 兜底（批次114/128 配方）
  final searchBtn = find.descendant(
    of: find.byType(WorkspaceInvitePage),
    matching: find.byKey(const ValueKey('workspace-invite-search-btn')),
  );
  await tester.ensureVisible(searchBtn);
  await _pump(tester, seconds: 1);
  flowLog('[AT-WIV] 按钮 rect=${tester.getRect(searchBtn)}，发起 tap');
  await tester.tap(searchBtn);
  await _pump(tester, seconds: 1);
  await tester.tap(searchBtn);
  await _pump(tester, seconds: 2);
  flowLog('[AT-WIV] tap 已派发，观察搜索请求');
  final candidateSeen = await _waitFor(
    tester,
    () => tester.any(
      find.byKey(const ValueKey('workspace-invite-candidate-$_inviteeUid')),
    ),
    seconds: 15,
  );
  expect(candidateSeen, isTrue, reason: '前置：搜索应出 SmokeAlice 候选行');
  await tester.tap(
    find.byKey(const ValueKey('workspace-invite-candidate-$_inviteeUid')),
    warnIfMissed: false,
  );
  await _pump(tester, seconds: 1);
  return adapter;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-WIV1 可选关系单条失败互不影响+失败行单独重试', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    final adapter = await _setupAndSelectCandidate(tester);

    // 注入 joinGroup 失败后提交（invite 主流程与 channel 可选放行）
    adapter.failGroupAdd = true;
    await tester.ensureVisible(
      find.byKey(const ValueKey('workspace-invite-submit')),
    );
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.byKey(const ValueKey('workspace-invite-submit')),
      warnIfMissed: false,
    );

    // 结果三行：workspace 成功 + group 失败（互不影响）+ channel 成功
    final done = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining('simulated_group_join_down')) &&
          tester.any(find.byIcon(CupertinoIcons.check_mark_circled)),
      seconds: 20,
    );
    expect(
      done,
      isTrue,
      reason: 'joinGroup 失败不应影响 invite/channel 成功（AT-WIV1 主断言）',
    );
    final successRows = tester.allWidgets
        .whereType<Icon>()
        .where((w) => w.icon == CupertinoIcons.check_mark_circled)
        .length;
    expect(
      successRows,
      greaterThanOrEqualTo(2),
      reason: 'invite 与 channel 两行应成功',
    );
    flowLog('[AT-WIV] 单条失败互不影响 ✓');

    // 解除拦截 → 点 group 行重试按钮 → group 行转成功
    adapter.failGroupAdd = false;
    final retryFinder = find.byKey(
      const ValueKey('workspace-invite-row-retry'),
    );
    await tester.ensureVisible(retryFinder.first);
    await _pump(tester, seconds: 1);
    await tester.tap(retryFinder.first, warnIfMissed: false);
    final groupRecovered = await _waitFor(
      tester,
      () => !tester.any(find.textContaining('simulated_group_join_down')),
      seconds: 20,
    );
    expect(groupRecovered, isTrue, reason: '失败行重试应转成功');
    flowLog('[AT-WIV] 失败行单独重试 ✓');
    await _pump(tester, seconds: 1);

    // ---- 场景 B（AT-WIV2）：必选关系失败整单失败且可选关系不发起 ----
    // 同一 testWidgets 内顺序执行：本仓集成测试约束=每文件单 testWidgets
    // （同进程二次 app.main() 必挂，批次153 实证）。场景 A 后候选仍选中，
    // 二次提交走同一向导页面。
    adapter.failWsInvite = true;
    flowLog('[AT-WIV] 场景B：注入 members/invite 失败，再次提交');
    await tester.ensureVisible(
      find.byKey(const ValueKey('workspace-invite-submit')),
    );
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.byKey(const ValueKey('workspace-invite-submit')),
      warnIfMissed: false,
    );

    // workspace 行失败（透出注入消息）；group/channel 两可选行被
    // controller.submit 的 catch 重置回「未执行」（前置失败不发起）
    final wsFailed = await _waitFor(
      tester,
      () => tester.any(find.textContaining('simulated_ws_invite_down')),
      seconds: 20,
    );
    expect(wsFailed, isTrue, reason: '必选关系失败应在 workspace 行透出注入消息');
    final idleCount = tester.allWidgets
        .whereType<Text>()
        .where((w) => w.data == '未执行')
        .length;
    expect(idleCount, greaterThanOrEqualTo(2), reason: '可选两行应保持未执行（前置失败不再发起）');
    final successIconsB = tester.allWidgets
        .whereType<Icon>()
        .where((w) => w.icon == CupertinoIcons.check_mark_circled)
        .length;
    expect(successIconsB, 0, reason: '必选失败时不应有任何成功行');
    flowLog('[AT-WIV] 必选失败整单失败且可选不发起 ✓');
    await _pump(tester, seconds: 1);
  });
}
