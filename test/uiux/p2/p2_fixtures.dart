/// T08 — P2 工作台入口夹具（imboy-enterprise-uiux-v1）
///
/// 目标：挂载真实 EnterpriseWorkbenchPage（C05）与 shell 同构的资源
/// 入口构建（C06：CsWorkspaceEntryTile + workspace/feature 条件项），
/// 确定性验证资源有无、CS gate 与 Android 辅助入口。
///
/// seam 约束：测试只透传已有输入——resourceEntries 按生产 shell 的
/// 同一表达式组装（真实 CsWorkspaceEntryTile，不手拼普通 ListTile）；
/// 不新增权限逻辑；feature gate 走真实 AppFeatureRegistry（测试环境
/// snapshot 为空 = fail-closed 关闭）。
///
/// 网络出口：HttpClient.adapterForTest 注入（与 cs_seat_contexts_test
/// 同款机制），seat-contexts 按场景返回合格/空/失败载荷。
library;

import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoListTile;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart'
    show kCsWorkspacePath;
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';
import 'package:imboy/page/workspace_shell/enterprise_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 场景（卡要求的六类输入）。
enum P2WorkbenchScenario {
  /// 无工作区：currentWorkspace=null → 仅 CS tile（gate 决定显隐）。
  noWorkspace,

  /// 普通成员：workspace 有 + seat-contexts 空 → CS tile 隐藏。
  memberNoSeat,

  /// 有坐席：workspace 有 + 合格 seat-contexts → CS tile 显示。
  memberWithSeat,

  /// feature 关闭：真实 AppFeatureRegistry fail-closed（snapshot 空）→
  /// 项目入口隐藏、群组等入口仍在。
  featureClosed,

  /// 有 OA 配置：entries 含合法 inbound 配置。
  withOaConfig,

  /// Android inbound 开启：android 平台 + 合法 inbound 配置 → 确认登录入口。
  androidInboundOn,
}

/// 导航/请求 trace 基线（点击产生的 push 与出站请求路径）。
class P2FixtureTrace {
  final List<String> pushes = <String>[];
  final List<String> requests = <String>[];

  void addPush(String name) => pushes.add(name);

  void addRequest(String path) => requests.add(path);

  bool containsPush(String pattern) =>
      pushes.any((String e) => e.contains(pattern));

  bool containsRequest(String path) => requests.contains(path);
}

/// 记录请求并按场景返回 seat-contexts 载荷的出口。
class P2RecordingAdapter implements HttpClientAdapter {
  P2RecordingAdapter(this.trace, this.seatContextsPayload);

  final P2FixtureTrace trace;
  final Map<String, dynamic>? seatContextsPayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    trace.addRequest(options.uri.path);
    final Map<String, dynamic> body = <String, dynamic>{
      'code': 0,
      'msg': 'success',
      'payload': seatContextsPayload,
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 合格 seat-contexts 载荷（active assignment + enabled seat）。
Map<String, dynamic> p2EligibleSeatContextsPayload() => <String, dynamic>{
  'contexts': <Map<String, dynamic>>[
    <String, dynamic>{
      'organization_id': 7266418340025468901,
      'organization_name': '合成企业',
      'business_identity_id': 7266418340025468902,
      'seat_enabled': true,
    },
  ],
};

/// 导航记录 observer。
class _P2NavObserver extends NavigatorObserver {
  _P2NavObserver(this.trace);

  final P2FixtureTrace trace;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    trace.addPush(route.settings.name ?? route.runtimeType.toString());
  }
}

/// workspace 合成模型。
const WorkspaceModel p2SyntheticWorkspace = WorkspaceModel(
  id: '100',
  name: 'synthetic-workspace',
  ownerId: '1',
  organizationId: '10',
);

/// 合法 inbound OA 配置（与 oa_login_flow_test 同款输入）。
EnterpriseOaRuntimeConfig p2InboundOaConfig() =>
    EnterpriseOaRuntimeConfig.fromMap(const <String, String>{
      'IMBOY_WL_OA_ORIGIN': 'https://oa.example',
      'IMBOY_WL_OA_APPLICATION_KEY': 'oa-source-key',
      'IMBOY_WL_OA_LOGIN_START_URI': 'https://oa.example/login',
    });

/// 夹具句柄。
class P2FixtureHandle {
  final P2FixtureTrace trace;
  final P2WorkbenchScenario scenario;

  P2FixtureHandle({required this.trace, required this.scenario});
}

/// 挂载真实工作台（EnterpriseWorkbenchPage + shell 同构资源入口）。
Future<P2FixtureHandle> pumpP2WorkbenchFixture(
  WidgetTester tester, {
  P2WorkbenchScenario scenario = P2WorkbenchScenario.noWorkspace,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  const MethodChannel secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (call) async {
        if (call.method == 'readAll') return <String, String>{};
        return null;
      });

  final P2FixtureTrace trace = P2FixtureTrace();
  final bool withWorkspace = scenario != P2WorkbenchScenario.noWorkspace;
  final bool withSeat = scenario == P2WorkbenchScenario.memberWithSeat;
  final bool androidInbound = scenario == P2WorkbenchScenario.androidInboundOn;
  final bool withOa =
      scenario == P2WorkbenchScenario.withOaConfig || androidInbound;

  final P2RecordingAdapter adapter = P2RecordingAdapter(
    trace,
    withSeat ? p2EligibleSeatContextsPayload() : null,
  );
  final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = adapter;

  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  if (androidInbound) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  final List<EnterpriseOaRuntimeConfig> oaEntries = <EnterpriseOaRuntimeConfig>[
    if (withOa) p2InboundOaConfig(),
  ];

  final GoRouter router = GoRouter(
    observers: <NavigatorObserver>[_P2NavObserver(trace)],
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            // 生产 shell（enterprise_shell_page._page workbench 分支）的
            // resourceEntries 表达式透传：真实 CsWorkspaceEntryTile +
            // workspace 存在条件 + project 真实 feature 门。
            final List<Widget> resourceEntries = <Widget>[
              const CsWorkspaceEntryTile(),
              if (ref.watch(currentWorkspaceProvider) != null) ...<Widget>[
                if (AppFeatureRegistry.isEnabled(FeatureKeys.project))
                  _p2ResourceEntry(
                    context.t.workspace.navProjects,
                    const Key('p2-entry-projects'),
                  ),
                _p2ResourceEntry(
                  context.t.workspace.navGroups,
                  const Key('p2-entry-groups'),
                ),
              ],
            ];
            return EnterpriseWorkbenchPage(
              entries: oaEntries,
              accountKey: 'synthetic-account',
              organizationId: '10',
              resourceEntries: resourceEntries,
            );
          },
        ),
      ),
      GoRoute(
        path: '$kCsWorkspacePath',
        name: 'csWorkspace',
        builder: (_, _) => const Scaffold(body: Text('cs-workspace-dest')),
      ),
    ],
  );

  try {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWithValue(
              withWorkspace ? p2SyntheticWorkspace : null,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    if (androidInbound) {
      debugDefaultTargetPlatformOverride = prevPlatform;
    }
    HttpClient.adapterForTest = prevAdapter;
  }
  return P2FixtureHandle(trace: trace, scenario: scenario);
}

/// 资源入口等价包装（CupertinoListTile；仅透传 title/key，无业务逻辑）。
Widget _p2ResourceEntry(String title, Key key) {
  return CupertinoListTile(
    key: key,
    leading: const Icon(CupertinoIcons.folder),
    title: Text(title),
    onTap: () {},
  );
}
