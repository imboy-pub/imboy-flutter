/// T07 — P1 频道真实路由夹具（imboy-enterprise-uiux-v1）
///
/// 目标：覆盖真实频道宿主（WorkspaceChannelDetailPage / C01）与内容页
/// （ChannelDetailPage embedded / ChannelMessageFeed / C02—C04），
/// 不以测试标记组件替代被测内容。
///
/// 替身约束：仅注入既有依赖替身（channelDetailProvider /
/// voicePlaybackServiceProvider 的 override + 合成 ChannelModel /
/// ChannelMessageModel），不改生产 manifest、不 mock 微社区 feature gate
/// （真实 fail-closed 策略生效）。`ChannelService.to` 为静态单例不可
/// 替身——夹具通过 provider 覆写 + `autoLoadStats: false` 阻断挂载期
/// 网络路径；trace 只覆盖 notifier 方法面（如实登记的局限）。
library;

import 'dart:convert' show JsonEncoder, jsonEncode;
import 'dart:io' show Directory, File;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
// workspaceAccessNetworkProvider 定义在 guard 库中（harness 需覆写）。
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart'
    show workspaceAccessNetworkProvider;
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_message_feed.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

import '../support/uiux_harness.dart' show UiuxViewport;

/// 挂载期业务调用 trace（notifier 方法面）。
class P1FixtureTrace {
  final List<String> entries = <String>[];

  void add(String call) => entries.add(call);

  bool contains(String prefix) =>
      entries.any((String e) => e.startsWith(prefix));

  /// 落盘到运行时证据目录（git 内部目录，不入库）。
  String saveTo(String path) {
    final File f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(<String, Object>{
        'calls': entries,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
    return f.path;
  }
}

/// T07 场景（卡断言要求的八类构造）。
enum P1FixtureScenario {
  /// 有内容：置顶公告 + 普通消息，无更多页。
  withContent,

  /// 统计未请求：autoLoadStats:false，头部走 subscriberCount 兜底（C03）。
  statsNotRequested,

  /// 初始错误：loadChannel 失败 → 错误视图 + 重试。
  initialError,

  /// 分页错误：触底 loadMoreMessages 失败（错误并入 state.error）。
  loadMoreError,

  /// 空：无任何消息。
  empty,

  /// 无结果：搜索/标签筛选区受微社区门控——真实 fail-closed 策略下
  /// 筛选区不渲染，本场景用于验证门禁联动（不伪造 manifest）。
  noSearchResultGated,

  /// 长名：24 字频道名在头部/宿主 AppBar 的展示。
  longName,

  /// 只读：userRole=none → canPublish=false → 无发布栏。
  readOnly,
}

/// 合成频道（有内容/管理态/长名/只读等由参数控制）。
ChannelModel p1SyntheticChannel({
  bool managed = true,
  bool longName = false,
  int subscriberCount = 12,
}) {
  return ChannelModel(
    id: 1001,
    name: longName ? '工程效率与产品发布特别特别长的频道名称' : '工程效率频道',
    description: '频道介绍与使用说明。',
    tags: const ['效率', '工程'],
    subscriberCount: subscriberCount,
    visibility: 0,
    accessType: 0,
    joinPolicy: 0,
    isVerified: true,
    userRole: managed ? ChannelUserRole.admin : ChannelUserRole.none,
    creatorId: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

/// 合成消息列表（[count] 用于分页场景：内容需超一屏才能触底触发分页）。
List<ChannelMessageModel> p1SyntheticMessages({
  bool empty = false,
  int count = 2,
}) {
  if (empty) return const <ChannelMessageModel>[];
  if (count > 2) {
    return List<ChannelMessageModel>.generate(count, (int i) {
      return ChannelMessageModel(
        id: i + 1,
        channelId: 1001,
        content: '分页内容第 ${i + 1} 条：滚动加载样例。',
        msgType: ChannelMessageType.text,
        payload: const {'uri': 'def_avatar.png', 'thumb': 'def_avatar.png'},
        createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
      );
    });
  }
  return <ChannelMessageModel>[
    ChannelMessageModel(
      id: 1,
      channelId: 1001,
      content: '首条置顶内容：工程实践与产品更新。',
      msgType: ChannelMessageType.text,
      payload: const {
        'uri': 'def_avatar.png',
        'thumb': 'def_avatar.png',
        'name': 'fixture.pdf',
        'size': 1024,
        'duration_ms': 12000,
      },
      isPinned: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    ChannelMessageModel(
      id: 2,
      channelId: 1001,
      content: '第二条：本周发布清单与验收口径。',
      msgType: ChannelMessageType.text,
      payload: const {'uri': 'def_avatar.png', 'thumb': 'def_avatar.png'},
      createdAt: DateTime(2024, 1, 2),
    ),
  ];
}

/// 带调用 trace 的 ChannelDetailNotifier 替身（仅覆写挂载/交互期会被
/// 触发的方法；其余方法不触发即不落网络）。
class P1ChannelDetailFixture extends ChannelDetailNotifier {
  P1ChannelDetailFixture({
    required this.trace,
    this.channel,
    this._messages = const [],
    this.hasMore = false,
    this.initialError = false,
    this.loadMoreError = false,
  });

  final P1FixtureTrace trace;
  final ChannelModel? channel;
  final List<ChannelMessageModel> _messages;
  final bool hasMore;
  final bool initialError;
  final bool loadMoreError;

  @override
  ChannelDetailState build() {
    trace.add('build');
    return const ChannelDetailState();
  }

  @override
  Future<void> loadChannel(String channelId) async {
    trace.add('loadChannel:$channelId');
    if (initialError) {
      state = const ChannelDetailState(error: '加载失败（合成）', hasMore: false);
      return;
    }
    state = ChannelDetailState(
      channel: channel,
      messages: _messages,
      hasMore: hasMore,
    );
  }

  @override
  Future<void> loadMoreMessages() async {
    trace.add('loadMoreMessages');
    if (loadMoreError) {
      // 照真实语义：错误并入 state.error，已有列表保留（P1-03 勘察）。
      state = state.copyWith(error: '加载更多失败（合成）');
      return;
    }
    state = state.copyWith(hasMore: false);
  }

  @override
  Future<void> markAsRead(String messageId) async {
    trace.add('markAsRead:$messageId');
  }
}

/// 语音播放替身（静默，不触平台通道）。
class P1SilentPlayback extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

/// 夹具句柄。
class P1FixtureHandle {
  final P1FixtureTrace trace;
  final P1FixtureScenario scenario;
  final ProviderContainer container;

  P1FixtureHandle({
    required this.trace,
    required this.scenario,
    required this.container,
  });
}

/// 挂载真实频道夹具。
///
/// [hostInWorkspaceShell]=true 时以 WorkspaceChannelDetailPage（C01 宿主）
/// 内嵌默认真实 ChannelDetailPage；否则直接挂载 ChannelDetailPage。
Future<P1FixtureHandle> pumpP1ChannelFixture(
  WidgetTester tester, {
  P1FixtureScenario scenario = P1FixtureScenario.withContent,
  bool hostInWorkspaceShell = false,
  Size viewport = UiuxViewport.phone,
  Brightness brightness = Brightness.light,
  double scale = 1.0,
}) async {
  // ChannelPublishBar/UserRepoLocal 挂载期读 StorageService：测试环境
  // 用内存 mock 初始化（SharedPreferences mock + StorageService.init）。
  SharedPreferences.setMockInitialValues(<String, Object>{
    Keys.currentUid: '100',
    // access fence 的 context.uid 取 repo.currentUser.uid（读完整用户
    // map）——只种 currentUid 会让 uid 为空、refresh 短路永 pending。
    Keys.currentUser: jsonEncode(<String, Object>{
      'uid': '100',
      'nickname': 'P1 用户',
      'account': 'p1_synthetic',
    }),
  });
  await StorageService.init();

  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewport;

  final bool initialError = scenario == P1FixtureScenario.initialError;
  final bool readOnly = scenario == P1FixtureScenario.readOnly;
  final bool empty = scenario == P1FixtureScenario.empty;
  final bool loadMoreError = scenario == P1FixtureScenario.loadMoreError;
  final bool longName = scenario == P1FixtureScenario.longName;

  final ChannelModel channel = p1SyntheticChannel(
    managed: !readOnly,
    longName: longName,
  );

  final P1FixtureTrace trace = P1FixtureTrace();
  late final ProviderContainer container;
  final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => hostInWorkspaceShell
            ? WorkspaceChannelDetailPage(
                channelId: '1001',
                workspaceId: '990',
                channelDetailOverride: () => P1ChannelDetailFixture(
                  trace: trace,
                  channel: channel,
                  messages: p1SyntheticMessages(
                    empty: empty,
                    count: loadMoreError ? 30 : 2,
                  ),
                  hasMore: loadMoreError,
                  initialError: initialError,
                  loadMoreError: loadMoreError,
                ),
              )
            : ChannelDetailPage(
                channelId: '1001',
                // 夹具统一阻断统计请求（测试期不出站网络）；
                // statsNotRequested 场景即此语义的显式构造。
                autoLoadStats: false,
              ),
      ),
      // 对会离开被测内容的既有路由给原重定向标记页（不在本夹具断言它们）。
      for (final String path in <String>[
        '/channel/:id/edit',
        '/channel/:id/admins',
      ])
        GoRoute(
          path: path,
          builder: (_, GoRouterState state) => Scaffold(
            appBar: AppBar(),
            body: Text('${state.uri.path}\n${state.extra}'),
          ),
        ),
    ],
  );

  try {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            channelDetailProvider.overrideWith(
              () => P1ChannelDetailFixture(
                trace: trace,
                channel: channel,
                messages: p1SyntheticMessages(
                  empty: empty,
                  count: loadMoreError ? 30 : 2,
                ),
                hasMore: loadMoreError,
                initialError: initialError,
                loadMoreError: loadMoreError,
              ),
            ),
            voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
            // 嵌入变体经 WorkspaceAccessGuard 门控：access 检查要求
            // workspaceId 非空 + channelApi 返回 workspace 域频道，否则
            // 永远 pending/revoked（J18.e 期 fence 硬化的测试面）。
            workspaceAccessContextReaderProvider.overrideWith((ref) {
              final uid = ref.watch(currentUserProvider)?.uid ?? '';
              return () => (
                origin: 'https://workspace.invalid',
                uid: uid,
                session: 1,
                featureScope: 'workspace:$uid',
                featureEpoch: 1,
                featureRevision: 1,
                channelEnabled: true,
              );
            }),
            workspaceAccessNetworkProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            channelApiProvider.overrideWith((ref) => _P1ChannelApi()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: brightness == Brightness.light
                ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
            builder: (context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
  } finally {
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
  return P1FixtureHandle(
    trace: trace,
    scenario: scenario,
    container: container,
  );
}

/// trace 证据目录（git 内部运行时区，不入库）。
String p1TraceEvidenceDir() {
  const String base =
      '.dart_tool/imboy-uiux/imboy-enterprise-uiux-v1/evidence/T07';
  Directory(base).createSync(recursive: true);
  return base;
}

/// 真实内容组件断言：挂载的是真实 ChannelMessageFeed（非标记页）。
/// 宿主模式额外断言讨论引导横幅已移除（W06/F12 收敛，C01）。
void expectRealEmbeddedContent(
  WidgetTester tester, {
  bool hostInWorkspaceShell = false,
}) {
  expect(find.byType(ChannelMessageFeed), findsOneWidget);
  if (hostInWorkspaceShell) {
    expect(find.byType(WorkspaceChannelDetailPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-channel-discuss-guide')),
      findsNothing,
      reason: 'W06/F12：常驻讨论引导横幅已移除（J12 不造 General）',
    );
  }
}

/// 微社区门 fail-closed 断言：真实策略下（测试环境无 manifest）工具区
/// 不渲染 —— 夹具不绕过、不伪造 feature gate。
void expectFeatureGateFailClosed(WidgetTester tester) {
  expect(
    find.byKey(const Key('mc_post_search')),
    findsNothing,
    reason: '真实微社区门 fail-closed：筛选/搜索入口不应渲染',
  );
}

/// p1 嵌入夹具专用：access fence 的 channelApi 桩——返回 workspace 域合成
/// 频道（fence 校验 scope='workspace' 且 workspaceId 与 target 一致），
/// 消息 liveness GET 直接给成功空响应（内容走 channelDetailProvider 夹具）。
class _P1ChannelApi extends ChannelApi {
  @override
  Future<ChannelModel> getChannelChecked(String channelId) async {
    final ChannelModel base = p1SyntheticChannel(managed: true);
    return base.copyWith(scope: 'workspace', workspaceId: '990');
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async =>
      // liveness GET 合同：payload['list'] 必须是 List（产品 _loadContent
      // 校验）；空列表即通过且不注入消息——内容仍走 channelDetailProvider
      // 夹具单一真源。
      IMBoyHttpResponse.success(<String, dynamic>{
        'list': <Map<String, dynamic>>[],
      });
}
