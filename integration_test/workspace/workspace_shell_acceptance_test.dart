// integration_test/workspace/workspace_shell_acceptance_test.dart
//
// Workspace 壳验收（批次115）：解除 6 行阻塞。
// 数据前置（本地 PG 4323）：
//   - bob 两个工作区：110073884375779328「BobWS-T27」（群 General/频道
//     Announcements）与 110003279376943104「AT-WS-第二」（群已改名
//     AT-WS2-General/频道 at-ws2-announcements 作他区反例标记）
//   - 空工作区 100000000000000210「AT-WS-空区-115」（无群无频道）
// 覆盖：
//   AT-WG1 群列表按 scope 严格分区，他区群不出现
//   AT-WC1 频道列表按 scope 严格分区，他区频道不出现
//   AT-WG2 无群的工作区 → 空态标题+副标题
//   AT-WC2 无频道的工作区 → 空态标题+副标题
//   AT-WF  加载失败展示错误消息+重试按钮，重试重新拉取（adapterForTest 注入）
//   AT-WP  项目页下拉刷新（CupertinoSliverRefreshControl）
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _wsMain = '110073884375779328'; // BobWS-T27
const _wsEmpty = '100000000000000210'; // AT-WS-空区-115

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

/// 注入 adapter：failWsApi=true 时把 /workspaces/:id/groups 返回业务失败
class _FailoverAdapter implements HttpClientAdapter {
  _FailoverAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failWsApi = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failWsApi &&
        options.uri.path.contains('/workspaces/') &&
        options.uri.path.endsWith('/groups')) {
      flowLog('[AT-WF] 拦截 groups 请求（注入业务失败）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 1,
          'msg': 'simulated_ws_groups_down',
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

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (!tester.any(f)) {
    fail('目标文本不存在: $text');
  }
  await tester.ensureVisible(f.first);
  await _pump(tester, seconds: 1);
  await tester.tap(f.first, warnIfMissed: false);
  await _pump(tester, seconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-WG/WC/WF/WP 壳验收 6 行', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    // 注入必须先于 app.main()：WorkspaceApi 等实例构造早，晚设
    // adapterForTest 打不到已构造实例的 Dio（run4 教训：invalidate 后仍
    // AsyncData([])——拦截未命中真实请求）
    final failover = _FailoverAdapter();
    HttpClient.adapterForTest = failover;
    addTearDown(() => HttpClient.adapterForTest = null);

    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );

    // 切到工作区体验 → 壳挂载（loadMine 首帧后触发）
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    final shellReady = await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceShellPage)),
      seconds: 20,
    );
    expect(shellReady, isTrue, reason: '切换体验后工作区壳应挂载');
    flowLog('[WS] 工作区壳已挂载');

    // 明确选中主区（BobWS-T27）
    container.read(workspaceShellProvider.notifier).selectWorkspace(_wsMain);
    await _pump(tester, seconds: 4);

    // ---- AT-WG1 群列表他区反例 ----
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.groups);
    final mainGroup = await _waitFor(
      tester,
      () => tester.any(find.text('General')),
      seconds: 15,
    );
    expect(mainGroup, isTrue, reason: 'AT-WG1 本区群 General 应展示');
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text('AT-WS2-General')),
      isFalse,
      reason: 'AT-WG1 他区群 AT-WS2-General 不应出现（scope 严格分区）',
    );
    flowLog('[AT-WG1] scope 严格分区：本区 General 在、他区 AT-WS2-General 不在');

    // ---- AT-WC1 频道列表他区反例 ----
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.channels);
    final mainChannel = await _waitFor(
      tester,
      () => tester.any(find.text('Announcements')),
      seconds: 15,
    );
    expect(mainChannel, isTrue, reason: 'AT-WC1 本区频道 Announcements 应展示');
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text('at-ws2-announcements')),
      isFalse,
      reason: 'AT-WC1 他区频道不应出现（scope 严格分区）',
    );
    flowLog('[AT-WC1] scope 严格分区：本区 Announcements 在、他区不在');

    // ---- AT-WG2/WC2 空工作区空态 ----
    container.read(workspaceShellProvider.notifier).selectWorkspace(_wsEmpty);
    await _pump(tester, seconds: 4);
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.groups);
    final groupsEmpty = await _waitFor(
      tester,
      () => tester.any(find.text('还没有工作区群组')),
      seconds: 15,
    );
    expect(groupsEmpty, isTrue, reason: 'AT-WG2 空区群列表应显示空态标题');
    expect(
      tester.any(find.text('群组是工作区里的实时讨论空间（聊天唯一入口）')),
      isTrue,
      reason: 'AT-WG2 空态应含副标题',
    );
    flowLog('[AT-WG2] 空区群列表空态（标题+副标题）');

    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.channels);
    final channelsEmpty = await _waitFor(
      tester,
      () => tester.any(find.text('还没有工作区频道')),
      seconds: 15,
    );
    expect(channelsEmpty, isTrue, reason: 'AT-WC2 空区频道列表应显示空态标题');
    flowLog('[AT-WC2] 空区频道列表空态');

    // ---- AT-WF 加载失败错误态+重试（adapterForTest 注入） ----
    // 空区群页有本地空结果缓存？autoDispose+切 destination 销毁重建——
    // 离开 groups→开注入→切回 groups 触发重拉→注入失败→错误态。
    // 先切到群组目的地：IndexedStack 下错误视图渲染在 offstage 子树时
    // onstage finder 不可见（run6 教训）
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.groups);
    await _pump(tester, seconds: 2);
    failover.failWsApi = true;
    // 显式 invalidate 触发重拉（不依赖壳 destination 切换的隐式失效）
    container.invalidate(workspaceGroupsProvider(_wsEmpty));
    var asyncState = container.read(workspaceGroupsProvider(_wsEmpty));
    for (var i = 0; i < 20 && asyncState is! AsyncError; i++) {
      await _pump(tester, seconds: 1);
      asyncState = container.read(workspaceGroupsProvider(_wsEmpty));
    }
    flowLog('[DIAG-WF2] provider state=$asyncState');
    final errorShown = await _waitFor(
      tester,
      () => tester.any(find.text('重试')),
      seconds: 20,
    );
    // DIAG：区分「错误视图没渲染」vs「渲染在 offstage」
    final errOnstage = tester.any(find.text('重试'));
    final errAnywhere = tester.any(find.text('重试', skipOffstage: false));
    flowLog(
      '[DIAG-WF] 重试 onstage=$errOnstage anywhere=$errAnywhere '
      '空态标题=${tester.any(find.text('还没有工作区群组'))} '
      'anywhere=${tester.any(find.text('还没有工作区群组', skipOffstage: false))}',
    );
    expect(errorShown, isTrue, reason: 'AT-WF 注入失败后应显示错误态+重试按钮');
    flowLog('[AT-WF] 注入失败 → WorkspaceErrorView+重试按钮');
    failover.failWsApi = false;
    await _tapText(tester, '重试');
    final emptyRestored = await _waitFor(
      tester,
      () => tester.any(find.text('还没有工作区群组')),
      seconds: 15,
    );
    expect(emptyRestored, isTrue, reason: 'AT-WF 重试成功应恢复空列表态');
    flowLog('[AT-WF] 解除注入后重试恢复空列表态');

    // ---- AT-WP 项目页下拉刷新 ----
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.projects);
    await _pump(tester, seconds: 4);
    final listFinder = find.byType(Scrollable);
    if (tester.any(listFinder)) {
      await tester.drag(listFinder.first, const Offset(0, 400));
      await _pump(tester, seconds: 3);
    }
    expect(tester.takeException(), isNull, reason: 'AT-WP 下拉刷新不应异常');
    flowLog('[AT-WP] 项目页下拉刷新手势完成无异常');
  });
}
