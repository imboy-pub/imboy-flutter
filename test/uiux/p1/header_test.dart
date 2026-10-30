/// T10 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_embedded_has_one_navigation_back_and_identity_title
///  2. p1_standalone_back_pops_once
///  3. p1_metadata_keeps_role_count
///  4. 大字标题（standalone 完整路由）无 overflow
///
/// 复用 T07 夹具替身（P1ChannelDetailFixture 等）；页面挂在真实
/// GoRouter 栈上以验证返回职责。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/channel/widgets/channel_role_badge.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

const String kLongChannelName = '工程效率与产品发布特别特别长的频道名称';

/// 出站拦截：HeaderBar 静音态读取（getSubscription）等返回空成功载荷，
/// 并记录请求路径供断言。
class _T10NoopAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'code': 0, 'msg': 'success'}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 在真实 GoRouter 栈上挂载页面：'/' 为根占位，'/detail' 为被测页
///（initialLocation 指向它），返回键 pop 一次应回到根。
Future<void> pumpT10OnStack(
  WidgetTester tester, {
  required Widget page,
  bool longName = false,
}) async {
  // access fence 的 context.uid 取 repo.currentUser.uid（读完整用户
  // map）——只种 currentUid 会让 uid 为空、refresh 短路永 pending；
  // 必须在 StorageService.init() 之前种好（init 后再 mock 不生效）。
  SharedPreferences.setMockInitialValues(<String, Object>{
    Keys.currentUid: '100',
    Keys.currentUser: jsonEncode(<String, Object>{
      'uid': '100',
      'nickname': 'P1 用户',
      'account': 'p1_synthetic',
    }),
  });
  await StorageService.init();

  final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = _T10NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = prevAdapter);

  final P1FixtureTrace trace = P1FixtureTrace();
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('root-page')),
      ),
      GoRoute(path: '/detail', builder: (_, _) => page),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(
            () => P1ChannelDetailFixture(
              trace: trace,
              channel: p1SyntheticChannel(managed: true, longName: longName),
              messages: p1SyntheticMessages(),
            ),
          ),
          voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
          // 嵌入变体（WorkspaceChannelDetailPage 自带内层 scope+access
          // fence）需要：context/network 放行 + channelApi 桩返回
          // workspace 域频道；内层 fixture 经页面测试缝注入（见下）。
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
          channelApiProvider.overrideWith((ref) => _P1HeaderChannelApi()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  // 从根 push 被测页：让被测页真实处于导航栈上（栈底为 '/'），
  // AppBar 才会有返回键 —— pop 一次应回根。
  router.push('/detail');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // 频道详情为异步装载（fixture 的 loadChannel 走 provider 微任务/帧），
  // 仅 3 帧会在装载完成前断言（嵌入变体曾因此缺「工程效率频道」标题
  // 与 ChannelRoleBadge）——稳定泵到装载落定。
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('p1_embedded_has_one_navigation_back_and_identity_title', (
    tester,
  ) async {
    final embeddedTrace = P1FixtureTrace();
    await pumpT10OnStack(
      tester,
      page: WorkspaceChannelDetailPage(
        channelId: '1001',
        workspaceId: '990',
        channelDetailOverride: () => P1ChannelDetailFixture(
          trace: embeddedTrace,
          channel: p1SyntheticChannel(managed: true),
          messages: p1SyntheticMessages(),
        ),
      ),
    );
    // 栈上宿主 AppBar：恰一个返回键
    expect(find.byType(BackButton), findsOneWidget);
    // 频道身份标题全页恰一次（宿主 AppBar；HeaderBar 紧凑模式不再重复）
    expect(find.text('工程效率频道'), findsOneWidget);
    // HeaderBar 仍在（元信息区保留）
    expect(find.byType(ChannelHeaderBar), findsOneWidget);
  });

  testWidgets('p1_standalone_back_pops_once', (tester) async {
    await pumpT10OnStack(
      tester,
      page: const ChannelDetailPage(channelId: '1001', autoLoadStats: false),
    );
    // standalone 返回键为 GlassAppBar 的 GlassBackButton（自定义 44×44）
    expect(find.byType(GlassBackButton), findsOneWidget);
    // GlassAppBar 承载唯一身份标题
    expect(find.text('工程效率频道'), findsOneWidget);
    // 返回一次即回根
    await tester.tap(find.byType(GlassBackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('root-page'),
      findsOneWidget,
      reason: '返回键一次必须 pop 到根，不改路由栈语义',
    );
  });

  testWidgets('p1_metadata_keeps_role_count：紧凑模式保留角色/订阅数/认证', (tester) async {
    final metadataTrace = P1FixtureTrace();
    await pumpT10OnStack(
      tester,
      page: WorkspaceChannelDetailPage(
        channelId: '1001',
        workspaceId: '990',
        channelDetailOverride: () => P1ChannelDetailFixture(
          trace: metadataTrace,
          channel: p1SyntheticChannel(managed: true),
          messages: p1SyntheticMessages(),
        ),
      ),
    );
    // 角色徽章（managed=admin）
    expect(find.byType(ChannelRoleBadge), findsOneWidget);
    // 订阅数兜底（合成频道 subscriberCount=12）
    expect(find.textContaining('12'), findsWidgets);
    // 认证徽标保留（紧凑模式并入元信息行）
    expect(find.byIcon(CupertinoIcons.checkmark_seal_fill), findsOneWidget);
  });

  testWidgets('大字标题无 overflow（standalone 长名完整路由）', (tester) async {
    await pumpT10OnStack(
      tester,
      page: const ChannelDetailPage(channelId: '1001', autoLoadStats: false),
      longName: true,
    );
    // AppBar（GlassAppBar）与紧凑 HeaderBar 均不因长名产生渲染异常/溢出
    expect(tester.takeException(), isNull);
    expect(find.text(kLongChannelName), findsOneWidget);
  });
}

/// p1 header 嵌入夹具专用：access fence 的 channelApi 桩（workspace 域）。
class _P1HeaderChannelApi extends ChannelApi {
  bool longName = false;

  @override
  Future<ChannelModel> getChannelChecked(String channelId) async {
    final ChannelModel base = p1SyntheticChannel(
      managed: true,
      longName: longName,
    );
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
      // liveness GET 合同：payload['list'] 必须是 List（同 p1_fixtures）。
      IMBoyHttpResponse.success(<String, dynamic>{
        'list': <Map<String, dynamic>>[],
      });
}
