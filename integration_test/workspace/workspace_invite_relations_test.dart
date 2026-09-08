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
//   AT-WIV1 注入 /api/v1/group/add 业务失败（joinGroup 被拒）→
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/workspace/workspace_invite_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _inviteeUid = '1000000051'; // SmokeAlice
const _wsId = '110073884375779328'; // BobWS-T27（General 群+Announcements 频道）
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

/// 只拦 /api/v1/group/add（joinGroup 可选关系）的故障注入适配器。
class _FailGroupAddAdapter implements HttpClientAdapter {
  _FailGroupAddAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failGroupAdd = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failGroupAdd && options.uri.path == '/api/v1/group/add') {
      flowLog('[AT-WIV] 拦截 group/add（注入 joinGroup 失败）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 1,
          'msg': 'simulated_group_join_down',
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-WIV1 可选关系单条失败互不影响+失败行单独重试', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    final adapter = _FailGroupAddAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

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

    // 搜索被邀人（SmokeAlice）→ 点搜索按钮 → 选中候选
    await tester.enterText(find.byType(CupertinoSearchTextField), 'SmokeAlice');
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.byKey(const ValueKey('workspace-invite-search-btn')),
      warnIfMissed: false,
    );
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
  });
}
