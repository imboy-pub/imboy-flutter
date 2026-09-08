// integration_test/workspace/workspace_overview_empty_members_test.dart
//
// Workspace Overview「成员预览空态」验收（批次130）：解除台账阻塞行
// 「成员预览为空时展示暂无成员提示文案」（批次W2R2 起，「工作区恒有
// Owner 成员，空态不可达」——通过 adapterForTest 注入空 overview payload
// 构造，无需删改 DB 成员行）。
//
// 场景：
//   AT-WOV1 拦截 /workspaces/{wsId}/overview 返回空 payload（code=0,
//           member_preview 缺省=[]）→ 壳 Overview 的成员预览显示
//           t.workspace.membersEmpty 文案 → 解除拦截 invalidate 重新拉取
//           → Owner 成员行出现。
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
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
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
class _EmptyOverviewAdapter implements HttpClientAdapter {
  _EmptyOverviewAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool emptyOverview = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (emptyOverview && options.uri.path.endsWith('/overview')) {
      flowLog('[AT-WOV] 拦截 overview（注入空 member_preview）');
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

  testWidgets('AT-WOV1 overview 成员预览空态与重新拉取恢复', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    final adapter = _EmptyOverviewAdapter();
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
    adapter.emptyOverview = true;
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await _pump(tester, seconds: 4);

    // 成员预览空态：t.workspace.membersEmpty 文案出现
    final emptyTextShown = await _waitFor(
      tester,
      () => tester.any(find.text(t.workspace.membersEmpty)),
      seconds: 15,
    );
    expect(
      emptyTextShown,
      isTrue,
      reason: '注入空 member_preview 后成员预览应显示空态文案（AT-WOV1 主断言）',
    );
    flowLog('[AT-WOV] 成员预览空态文案 ✓');

    // 解除拦截 → invalidate 重新拉取 → Owner 成员行出现（预览非空）
    adapter.emptyOverview = false;
    final wsId = container.read(
      workspaceShellProvider.select((s) => s.currentWorkspaceId),
    );
    container.invalidate(workspaceOverviewProvider(wsId));
    final memberShown = await _waitFor(
      tester,
      () => !tester.any(find.text(t.workspace.membersEmpty)),
      seconds: 15,
    );
    expect(memberShown, isTrue, reason: '解除拦截重新拉取后成员预览应恢复非空');
    flowLog('[AT-WOV] 重新拉取成员恢复 ✓');
    await _pump(tester, seconds: 1);
  });
}
