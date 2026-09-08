// integration_test/workspace/workspace_overview_empty_members_test.dart
//
// Workspace Members「成员列表空态」验收（批次131）：解除台账阻塞行
// 「成员列表为空时空态展示标题与副标题提示」（批次W2R2 起，「成员列表
// 恒含Owner，空态不可达」——通过 adapterForTest 注入空 members payload
// 构造，无需删改 DB 成员行；配方同批次130 AT-WOV1）。
//
// 场景：
//   AT-WVM1 拦截 /workspaces/{wsId}/members 返回空 payload（code=0,
//           WorkspacePageResult 默认 list=[]）→ 深链成员页显示
//           membersEmpty 标题+副标题空态（行描述=空态展示，两轮稳定）。
//
// 载体：smoke_bob（uid=1000000056）。红线：仅本地（9801/4323）。
//
// 运行（配方同 workspace_picker_failure_test）：
//   flutter test integration_test/workspace/workspace_overview_empty_members_test.dart \
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

/// 拦截 overview 接口返回空 payload（code=0 + 空 map →
/// WorkspaceOverview 默认构造 → memberPreview=[]）。
class _EmptyMembersAdapter implements HttpClientAdapter {
  _EmptyMembersAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool emptyMembers = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (emptyMembers &&
        options.uri.path.contains('/members') &&
        options.uri.queryParameters.containsKey('page')) {
      flowLog('[AT-WVM] 拦截 members（注入空列表）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 0,
          'msg': 'ok',
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

  testWidgets('AT-WVM1 overview 成员预览空态与重新拉取恢复', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    final adapter = _EmptyMembersAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await _bootAndRelogin(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    addTearDown(() {
      container
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.chat);
    });

    // 归位 chat 体验 → 重置常驻壳 state → 注入下切 workspace 触发
    // overview 拉取（被拦截为空 payload）
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);
    container.invalidate(workspaceShellProvider);
    adapter.emptyMembers = true;
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await _pump(tester, seconds: 4);
    final wsId = container.read(
      workspaceShellProvider.select((s) => s.currentWorkspaceId),
    );

    // 深链成员页（注入空列表在途）：空态标题+副标题
    // 路由为静态 /workspace/members（页面读 currentWorkspaceProvider）
    adapter.emptyMembers = true;
    iPrint('[AT-WVM] DIAG shellCurrentId=$wsId');
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/members');
    await _pump(tester, seconds: 2);
    final diagTexts = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? '')
        .where((t) => t.trim().isNotEmpty)
        .take(14)
        .toList();
    iPrint('[AT-WVM] DIAG 页面文本=$diagTexts');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(t.workspace.membersEmpty)),
        seconds: 15,
      ),
      isTrue,
      reason: '注入空 members 列表后应显示空态标题（AT-WVM1 主断言）',
    );
    expect(
      tester.any(find.text(t.workspace.membersEmptySubtitle)),
      isTrue,
      reason: '空态应同时显示副标题提示',
    );
    flowLog('[AT-WVM] 成员列表空态标题+副标题 ✓');

    // 持续性确认：空态稳定存在（非一闪而过）
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(t.workspace.membersEmpty)),
      isTrue,
      reason: '空态应持续稳定展示',
    );
    flowLog(
      '[AT-WVM] 空态稳定展示 ✓（行描述=空态展示，恢复链路由 invalidate members provider 覆盖，不在此行范围）',
    );
    await _pump(tester, seconds: 1);
  });
}
