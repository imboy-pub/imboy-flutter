import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_overview_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _fakeWsId = '999999999';

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

/// 新登录默认 personal，工作区空态由独立子页展示。
Future<bool> _bootstrapWorkspace(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  if (!await checkPreconditions(tester)) return false;
  if (!await autoLoginOrSkip(tester)) return false;
  expect(UserRepoLocal.to.currentUid, _expectedUid);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
    listen: false,
  );
  expect(container.read(workspaceShellProvider).organizationId, isEmpty);
  expect(container.read(productExperienceProvider), ProductExperience.personal);
  expect(find.byKey(const Key('workspace-shell-bottom-nav')), findsNothing);
  return true;
}

Future<void> _openPage(WidgetTester tester, Widget page) async {
  Navigator.of(tester.element(find.byType(Navigator).first))
      .push(CupertinoPageRoute<void>(builder: (_) => page));
  await _pump(tester, seconds: 3);
}

/// 向壳状态注入一个「幽灵工作区」（id 不存在于服务端）：
/// 独立子页据此请求不存在的工作区；列表请求
/// 的列表请求将真实打到服务端并被 403 拒绝——驱动 ErrorView 路径。
void _injectGhostWorkspace(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
    listen: false,
  );
  container.read(workspaceShellProvider.notifier).state = WorkspaceShellState(
    workspaces: [
      WorkspaceModel(id: _fakeWsId, name: 'ghost-ws', ownerId: _expectedUid),
    ],
    currentWorkspaceId: _fakeWsId,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in <String, Widget>{
    'AT-WS1 概览': const WorkspaceOverviewPage(),
    'AT-WS2 频道': const WorkspaceChannelsPage(),
    'AT-WS3 群组': const WorkspaceGroupsPage(),
    'AT-WS4 项目': const WorkspaceProjectsPage(),
  }.entries) {
    testWidgets('${entry.key}：无当前工作区整页空态', (tester) async {
      if (!_allow) {
        markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
        return;
      }
      if (!await _bootstrapWorkspace(tester)) return;
      await _openPage(tester, entry.value);
      expect(find.byType(WorkspaceEmptyView), findsOneWidget);
      expect(find.byKey(const Key('workspace-shell-bottom-nav')), findsNothing);
    });
  }

  testWidgets('AT-WS5 成员页：无当前工作区整页空态（独立路由深链）', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.go('/workspace/members');
    await _pump(tester, seconds: 3);

    final emptyView = await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceEmptyView)),
      seconds: 10,
    );
    expect(emptyView, isTrue, reason: '成员页应渲染整页空态');
    expect(
      tester.any(find.text('请先选择或创建一个工作区')),
      isTrue,
      reason: '成员页空态应提示先加入或创建工作区',
    );
  });

  testWidgets('AT-WS6 频道页加载失败：服务端 403 透出+重试按钮可点', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    _injectGhostWorkspace(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    await _openPage(tester, const WorkspaceChannelsPage());
    await _pump(tester, seconds: 4);

    // ErrorView + 服务端错误消息透出（403 秒回；若 dio 超时链路则 30s 转错误）
    final errorView = await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceErrorView)),
      seconds: 30,
    );
    if (!errorView) {
      final shellState = container.read(workspaceShellProvider);
      final av = container.read(workspaceChannelsProvider(_fakeWsId));
      final texts = <String>{};
      for (final w in tester.widgetList(find.bySubtype<Text>())) {
        final t = (w as Text).data;
        if (t != null && t.isNotEmpty) texts.add(t);
      }
      // ignore: avoid_print
      print(
        'DIAG WS6: current=${shellState.current?.id} '
        'providerState=$av 页面文本(${texts.length}): '
        '${texts.take(20).join(" | ")}',
      );
    }
    expect(errorView, isTrue, reason: '非法 wsId 应渲染错误视图');
    expect(
      tester.any(find.textContaining('非工作区成员')),
      isTrue,
      reason: '应透出服务端 403 错误消息（非通用兜底）',
    );

    // 重试按钮：invalidate 重新拉取（仍 403，按钮仍可点=重试链路活着）
    final retryBtn = find.byKey(const Key('workspace-error-retry'));
    expect(tester.any(retryBtn), isTrue, reason: '应渲染重试按钮');
    await tester.tap(retryBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(WorkspaceErrorView)),
      isTrue,
      reason: '点重试后重新拉取（仍 403）应保持错误视图',
    );
  });

  testWidgets('AT-WS7 成员页加载失败：服务端 403 透出+重试按钮可点', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    _injectGhostWorkspace(tester);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.go('/workspace/members');
    await _pump(tester, seconds: 4);

    // members 页 provider 是分页拉取（size:50），错误视图渲染比 channels 慢，
    // 与 WS6 同款放宽到 30s。
    final errorView = await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceErrorView)),
      seconds: 30,
    );
    if (!errorView) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      final av = container.read(workspaceMembersProvider(_fakeWsId));
      // ignore: avoid_print
      print('DIAG WS7: providerState=$av');
    }
    expect(errorView, isTrue, reason: '非法 wsId 应渲染成员页错误视图');
    expect(
      tester.any(find.textContaining('非工作区成员')),
      isTrue,
      reason: '应透出服务端 403 错误消息',
    );

    final retryBtn = find.byKey(const Key('workspace-error-retry'));
    expect(tester.any(retryBtn), isTrue, reason: '应渲染重试按钮');
    await tester.tap(retryBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(WorkspaceErrorView)),
      isTrue,
      reason: '点重试后重新拉取（仍 403）应保持错误视图',
    );
  });

  testWidgets('AT-WS8 项目页加载失败：服务端 403 透出+重试按钮可点', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    _injectGhostWorkspace(tester);
    await _openPage(tester, const WorkspaceProjectsPage());
    await _pump(tester, seconds: 4);

    final errorView = await _waitFor(
      tester,
      () => tester.any(find.byType(WorkspaceErrorView)),
      seconds: 12,
    );
    expect(errorView, isTrue, reason: '非法 wsId 应渲染项目页错误视图');
    expect(
      tester.any(find.textContaining('非工作区成员')),
      isTrue,
      reason: '应透出服务端 403 错误消息',
    );

    final retryBtn = find.byKey(const Key('workspace-error-retry'));
    expect(tester.any(retryBtn), isTrue, reason: '应渲染重试按钮');
    await tester.tap(retryBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(WorkspaceErrorView)),
      isTrue,
      reason: '点重试后重新拉取（仍 403）应保持错误视图',
    );
  });
}
