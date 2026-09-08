// integration_test/workspace/workspace_picker_loading_test.dart
//
// Workspace Picker「首屏 loading→列表」验收（批次129）：解除台账阻塞行
// 「无任何工作区数据时首屏显示加载视图（转圈），加载完成后切换为列表」
// （批次W2R2 起，「列表恒有缓存」定性——picker 数据来自常驻
// WorkspaceShellNotifier 的 state，invalidate 归零后 loadMine 在途窗口内
// 进页即见 WorkspaceLoadingView，放行后切列表）。
//
// 场景：
//   AT-WPF2 delayMine=6s 挂住 loadMine → select(workspace) 触发首载 →
//   立即深链 /workspace → 断言 WorkspaceLoadingView → 延迟放行后真实
//   成功 → 断言列表（BobWS 行）。
//
// 载体：smoke_bob（uid=1000000056）。红线：仅本地（9801/4323）。
//
// 运行（配方同 workspace_picker_failure_test）：
//   flutter test integration_test/workspace/workspace_picker_loading_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_picker_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
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

/// 可延迟放行的 mine 适配器（批次128 _MineFailAdapter 同构+延迟档）。
class _DelayedMineAdapter implements HttpClientAdapter {
  _DelayedMineAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  int delayMineSeconds = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delayMineSeconds > 0 && options.uri.path.endsWith('/workspaces/mine')) {
      flowLog('[AT-WPF2] 延迟 ${delayMineSeconds}s 放行 workspaces/mine');
      await Future<void>.delayed(Duration(seconds: delayMineSeconds));
      flowLog('[AT-WPF2] 延迟放行完成');
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

  testWidgets('AT-WPF2 picker 首屏 loading 视图与加载完成切列表', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    final adapter = _DelayedMineAdapter();
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

    // 归位 chat 体验（清持久化），重置常驻 Notifier 的 state
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);
    container.invalidate(workspaceShellProvider);

    // delayMine 挂住首载：切 workspace → 壳 loadMine 在途（isLoading=true）
    adapter.delayMineSeconds = 6;
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await _pump(tester, seconds: 1);

    // 在途窗口内深链进 picker：isLoading && 空列表 → 首屏 loading 视图
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/workspace');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspacePickerPage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：picker 页可达',
    );
    expect(
      tester.any(find.byType(WorkspaceLoadingView)),
      isTrue,
      reason: 'loadMine 在途且无缓存应显示首屏 loading 视图（AT-WPF2 主断言）',
    );
    flowLog('[AT-WPF2] 首屏 loading 视图 ✓');

    // 延迟放行 → loadMine 成功 → isLoading=false + 列表填充
    final listShown = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining('BobWS')) &&
          !tester.any(find.byType(WorkspaceLoadingView)),
      seconds: 20,
    );
    expect(listShown, isTrue, reason: '加载完成后应切换为工作区列表');
    flowLog('[AT-WPF2] 加载完成切列表 ✓');
    await _pump(tester, seconds: 1);
  });
}
