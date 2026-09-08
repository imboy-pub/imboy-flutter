// integration_test/workspace/workspace_picker_failure_test.dart
//
// Workspace Picker「失败+无缓存」验收（批次128）：解除台账阻塞行
// 「加载失败且无缓存数据时显示错误视图，点重试按钮重新拉取我的工作区
// 列表」（批次W2R2 起，「清数据则卡登录不可达」定性推翻——provider 层
// workspaces 仅在 loadMine 成功时填充（初始 const []），**首次 loadMine
// 即失败=天然无缓存**，无需清任何本地数据；正常流程「恒有缓存」只是因为
// 进 picker 前壳已 loadMine 成功过）。
//
// 场景：
//   AT-WPF1 注入 /workspaces/mine 业务失败 → 切 workspace 体验触发
//           loadMine 首载失败 → 深链 /workspace → picker 显示错误视图
//           （WorkspaceErrorView + workspace-error-retry）且无任何工作区行
//           → 解除拦截点重试 → 列表恢复（bob 工作区行出现）。
//
// 载体：smoke_bob（uid=1000000056，本地已有工作区 BobWS-T27 等）。
// 红线：仅本地（9801/4323）；拦截仅覆盖 /workspaces/mine 路径，其余放行。
//
// 运行（配方同批次115 workspace_shell_acceptance）：
//   flutter test integration_test/workspace/workspace_picker_failure_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
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
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_picker_page.dart';
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

/// 只拦 /workspaces/mine 的故障注入适配器（AT-WF _FailoverAdapter 同构）。
class _MineFailAdapter implements HttpClientAdapter {
  _MineFailAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failMine = false;
  int delayMineSeconds = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isMine = options.uri.path.endsWith('/workspaces/mine');
    if (failMine && isMine) {
      flowLog('[AT-WPF] 拦截 workspaces/mine（注入业务失败）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 1,
          'msg': 'simulated_ws_mine_down',
          'payload': <String, dynamic>{},
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    if (delayMineSeconds > 0 && isMine) {
      // 延迟放行：让 loadMine 在途（isLoading=true）窗口足够长，
      // 供 picker 首屏 loading 视图断言（AT-WPF2）。
      flowLog('[AT-WPF] 延迟 ${delayMineSeconds}s 放行 workspaces/mine');
      await Future<void>.delayed(Duration(seconds: delayMineSeconds));
      flowLog('[AT-WPF] 延迟放行完成');
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-WPF1 picker 失败+无缓存错误视图与重试恢复', (tester) async {
    if (!_allow) {
      markTestSkipped('需 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true');
      return;
    }
    // 注入必须先于 app.main()（批次115 run4 教训：实例构造早，晚设打不到）
    final adapter = _MineFailAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    app.main();
    await _pump(tester, seconds: 12);
    // 无条件重登（face_to_face _boot 同款）：①容器可能残留其他账号
    // （批次127 载体 51730）②沿用已登录态启动链时 adapterForTest 拦截
    // 曾实测不生效（run4：mine 请求绕过注入直连成功），quitLogin 重登
    // 路径已实证拦截必生效（run3）。
    if (UserRepoLocal.to.currentUid.isNotEmpty) {
      await UserRepoLocal.to.quitLogin();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
      await _pump(tester, seconds: 4);
      // 排空残留 token 的异步 401 链（report_device_key 等）：否则
      // http_auth_expired_callback 的 navigateToSignIn(in-flight) 与
      // performLogin 互踩，登录成功回调后新会话被踢（run5/6 实证，
      // 批次120「启动期 401 风暴踢会话」同款）。
      await Future<void>.delayed(const Duration(seconds: 4));
      await _pump(tester, seconds: 2);
    }
    // 循环重试登录（批次125 _boot 模式）：单次 performLogin 可能被
    // 401 风暴踢掉，循环至到达登录稳定态为止。
    const loginSubmit = Key('login_submit_button');
    var loggedIn = false;
    for (var i = 0; i < 8; i++) {
      if (UserRepoLocal.to.currentUid == _expectedUid &&
          (isOnMainShell(tester) ||
              tester.any(find.text('还没有工作区')) ||
              tester.any(
                find.byKey(const Key('workspace-empty-create-entry')),
              ))) {
        loggedIn = true;
        break;
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
    if (!loggedIn) {
      markTestSkipped('未到达登录稳定态（401 风暴或环境未就绪），下轮重试');
      return;
    }
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    addTearDown(() {
      container
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.chat);
    });

    // 构造「error 非空 + hasWorkspace=false」：
    // ①登录后先归位 chat 体验（清持久化体验，避免启动恢复期抢先首载）
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);
    // ②WorkspaceShellNotifier 常驻（keepAlive），启动期成功首载过的
    //   workspaces 会一直保留（hasWorkspace=true 永走列表分支）——
    //   invalidate 强制 Notifier 重建，state 归零。
    // ③failMine=true 下切回 workspace 触发壳首载 → 拦截 → error+空列表。
    container.invalidate(workspaceShellProvider);
    adapter.failMine = true;
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await _pump(tester, seconds: 4);
    // 兜底：若壳首载发生在拦截切换前，手动再触发一次必被拦截的 loadMine
    await container.read(workspaceShellProvider.notifier).loadMine();
    await _pump(tester, seconds: 2);
    flowLog(
      '[AT-WPF] error=${container.read(workspaceShellProvider).error} '
      'hasWs=${container.read(workspaceShellProvider).hasWorkspace} '
      'n=${container.read(workspaceShellProvider).workspaces.length}',
    );

    // 深链进 picker：error 非空 + hasWorkspace=false → 错误视图（非空态/列表）
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
    final errInView = await _waitFor(
      tester,
      () => tester.any(find.byKey(const ValueKey('workspace-error-retry'))),
      seconds: 10,
    );
    expect(errInView, isTrue, reason: '失败且无缓存应显示错误视图与重试按钮（AT-WPF1 主断言）');
    // 无缓存反证：列表行不应存在（bob 有 BobWS-T27，出现即说明缓存被用）
    expect(
      tester.any(find.textContaining('BobWS')),
      isFalse,
      reason: '无缓存断言：工作区列表行不应出现',
    );
    flowLog('[AT-WPF] 错误视图+重试按钮 ✓，无缓存反证 ✓');

    // 解除拦截 → 点重试 → loadMine 成功 → 列表恢复
    // 壳与 picker 两层都渲染错误视图（同 Key×2），限定 picker 页内定位；
    // 单次 tap 可能被 Overlay/toast 吞（批次114 教训）：ensureVisible+
    // 缓冲+双 tap。
    adapter.failMine = false;
    final retryFinder = find.descendant(
      of: find.byType(WorkspacePickerPage),
      matching: find.byKey(const ValueKey('workspace-error-retry')),
    );
    await tester.ensureVisible(retryFinder.first);
    await _pump(tester, seconds: 1);
    await tester.tap(retryFinder.first, warnIfMissed: false);
    await _pump(tester, seconds: 2);
    var listRestored = await _waitFor(
      tester,
      () => tester.any(find.textContaining('BobWS')),
      seconds: 8,
    );
    if (!listRestored) {
      flowLog('[AT-WPF] 首次 tap 未触发重试，补一次 tap');
      await tester.tap(retryFinder.first, warnIfMissed: false);
      listRestored = await _waitFor(
        tester,
        () => tester.any(find.textContaining('BobWS')),
        seconds: 15,
      );
    }
    expect(listRestored, isTrue, reason: '点重试应重新拉取并恢复工作区列表');
    flowLog('[AT-WPF] 重试后列表恢复 ✓');
    await _pump(tester, seconds: 1);
  });
}
