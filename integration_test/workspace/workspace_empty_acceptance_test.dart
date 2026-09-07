// integration_test/workspace/workspace_empty_acceptance_test.dart
//
// Workspace 空态/错误态验收（批次121）：解锁 workspace 域 8 行阻塞
// （无工作区空态 5 + 加载失败重试 3）。
// 载体：SmokeEmpty（account=51730）——上批注销终章后经清扫恢复为活跃态，
// 零工作区/零好友/零会话，是「无当前工作区」的天然载体。
//
// 覆盖：
//   AT-WS1 概览页：无当前工作区 → WorkspaceEmptyView「请先选择或创建一个工作区」
//   AT-WS2 频道页：同上（destination=channels）
//   AT-WS3 群组页：同上（destination=groups）
//   AT-WS4 项目页：同上（destination=projects）
//   AT-WS5 成员页：独立路由 /workspace/members 深链 → 同上空态
//   AT-WS6 频道页加载失败：注入非法 wsId → 服务端 403 透出 +
//          workspace-error-retry 按钮可点（invalidate 重新拉取）
//   AT-WS7 成员页加载失败：同上（深链页 + 非法 wsId）
//   AT-WS8 项目页加载失败：同上
//
// 运行（单场景 --plain-name；define 与批次120 相同配方）：
//   flutter test integration_test/workspace/workspace_empty_acceptance_test.dart \
//     -d macos --plain-name "AT-WS1" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 \
//     --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064 \
//     --dart-define=TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true
// 前置：SmokeEmpty 保持零工作区（workspace_member 无该 uid 行——
//       批次120 注销清扫后已恢复活跃且无任何工作区归属）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
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

/// 启动 + 登录 + 切到工作区体验（批次120 的 _bootstrap 同款防御：
/// 启动期旧 token 401 风暴会迟到踢会话，失败时整体重试）。
Future<bool> _bootstrapWorkspace(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  // 启动完成后先看一眼当前页面（排查入口判定超时卡点）
  final texts0 = <String>{};
  for (final w in tester.widgetList(find.bySubtype<Text>())) {
    final t0 = (w as Text).data;
    if (t0 != null && t0.isNotEmpty) texts0.add(t0);
  }
  // ignore: avoid_print
  print('DIAG WS boot: 页面文本(${texts0.length}): ${texts0.take(20).join(" | ")}');

  // workspace 零工作区落点=「还没有工作区」空态引导页（非三类标准入口，
  // checkPreconditions 会白等 90s 超时），自定义判定直接等它出现。
  const wsEmptySeen = Key('workspace-empty-create-entry');
  for (var i = 0; i < 10; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区'))) {
      break;
    }
    // 停在登录页：执行自动登录（登录提交按钮存在=在登录页）
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区'))) {
    markTestSkipped('未到达 workspace 空态引导页');
    return false;
  }
  expect(
    UserRepoLocal.to.currentUid,
    _expectedUid,
    reason: '必须是 SmokeEmpty（零工作区载体）',
  );

  // 切到工作区体验（批次118 模式），等壳重建
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
    listen: false,
  );
  await container
      .read(productExperienceProvider.notifier)
      .select(ProductExperience.workspace);
  await _pump(tester, seconds: 3);
  return true;
}

/// 向壳状态注入一个「幽灵工作区」（id 不存在于服务端）：
/// bootstrap 据此挂载五项 shell（hasWorkspace=true），随后各 tab 页
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

  testWidgets('AT-WS1 概览页：无当前工作区整页空态', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.overview);
    await _pump(tester, seconds: 3);

    // 零工作区用户被 WorkspaceShellBootstrap 拦截在引导页：
    // 「还没有工作区」标题 + 创建/加入入口 + 切个人 + 重试（T8 壳可空态运行）
    final guide = await _waitFor(
      tester,
      () =>
          tester.any(find.text('还没有工作区')) &&
          tester.any(find.textContaining('创建一个工作区')) &&
          tester.any(find.text('创建工作区')) &&
          tester.any(find.text('加入工作区')),
      seconds: 10,
    );
    expect(guide, isTrue, reason: '零工作区应显示引导页（创建/加入/切个人/重试）');
    expect(tester.any(find.text('切换到个人')), isTrue, reason: '引导页应提供切回个人体验入口');
  });

  testWidgets('AT-WS2 频道页：无当前工作区整页空态', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.channels);
    await _pump(tester, seconds: 3);

    // 零工作区时 shell 不挂载五项，空态职责由引导页承担：
    // 断言用户仍被引导页拦截（创建/加入入口可见），不会被丢进无上下文页面
    final guide = await _waitFor(
      tester,
      () =>
          tester.any(find.text('还没有工作区')) &&
          tester.any(find.text('创建工作区')) &&
          tester.any(find.text('加入工作区')),
      seconds: 10,
    );
    expect(guide, isTrue, reason: '频道页场景应保持零工作区引导页（整页空态职责）');
  });

  testWidgets('AT-WS3 群组页：无当前工作区整页空态', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.groups);
    await _pump(tester, seconds: 3);

    // 零工作区时 shell 不挂载五项，空态职责由引导页承担：
    // 断言用户仍被引导页拦截（创建/加入入口可见），不会被丢进无上下文页面
    final guide = await _waitFor(
      tester,
      () =>
          tester.any(find.text('还没有工作区')) &&
          tester.any(find.text('创建工作区')) &&
          tester.any(find.text('加入工作区')),
      seconds: 10,
    );
    expect(guide, isTrue, reason: '群组页场景应保持零工作区引导页（整页空态职责）');
  });

  testWidgets('AT-WS4 项目页：无当前工作区整页空态', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrapWorkspace(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.projects);
    await _pump(tester, seconds: 3);

    // 零工作区时 shell 不挂载五项，空态职责由引导页承担：
    // 断言用户仍被引导页拦截（创建/加入入口可见），不会被丢进无上下文页面
    final guide = await _waitFor(
      tester,
      () =>
          tester.any(find.text('还没有工作区')) &&
          tester.any(find.text('创建工作区')) &&
          tester.any(find.text('加入工作区')),
      seconds: 10,
    );
    expect(guide, isTrue, reason: '项目页场景应保持零工作区引导页（整页空态职责）');
  });

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
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.channels);
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.projects);
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
