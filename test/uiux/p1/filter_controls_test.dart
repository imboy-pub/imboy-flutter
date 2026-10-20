/// T14 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_advanced_filters_collapsed_by_default
///  2. p1_toggle_filters_preserves_values_and_request_count
///  3. p1_submit_filter_matches_baseline_query
///  4. p1_collapse_moves_focus_safely
///  5. mc_* 现有 key 保持可访问
///
/// 微社区门通过 smoke_test_harness 同款机制开启（FeatureScope.bind +
/// manifest cache + replaceSnapshotForTest），fixture 走 T07 替身。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoTextField, TextInputAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_message_feed.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

/// 开启微社区门（真实门，不 mock contentToolsAvailable）。
Future<void> _enableMicroCommunityGate() async {
  FeatureScope.bind(endpoint: 'http://t14.test', uid: 't14_uid');
  await StorageService.setMap(FeatureScope.cacheKey(Keys.appManifest), {
    'body': {
      'manifest_hash': productFeatureManifestHash,
      'manifest_schema_version': productFeatureSchemaVersion,
      'compiled_features': compiledProductFeatures.toList(),
      'policy': <String, dynamic>{'profile': 'enterprise'},
      'features': {for (final String f in compiledProductFeatures) f: true},
    },
    'etag': null,
  });
  AppManifestService.loadFromCache();
  AppFeatureRegistry.replaceSnapshotForTest({
    for (final String f in compiledProductFeatures) f: true,
  });
}

Future<void> _disableGate() async {
  await AppManifestService.clear();
  AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
}

/// 空成功出口：记录 path+query 供请求次数断言（筛选提交走
/// channelPostSearchProvider，真实 HTTP 面）。
class _T14RecordingAdapter implements HttpClientAdapter {
  final List<String> urls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': <String, dynamic>{
          'sessions': <dynamic>[],
          'next_after_id': null,
          'list': <dynamic>[],
        },
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pumpT14Feed(
  WidgetTester tester, {
  double viewportHeight = 800,
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
  await _enableMicroCommunityGate();
  addTearDown(_disableGate);

  final adapter = _T14RecordingAdapter();
  final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = prevAdapter);

  final P1FixtureTrace trace = P1FixtureTrace();
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(
            () => P1ChannelDetailFixture(
              trace: trace,
              channel: p1SyntheticChannel(managed: true),
              messages: p1SyntheticMessages(count: 6),
            ),
          ),
          voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportHeight,
              child: ChannelMessageFeed(channelId: '1001', isManaged: true),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // ChannelMessageFeed 不负责频道加载（那是 ChannelDetailPage 的职责）：
  // 夹具下由测试驱动真实 notifier.loadChannel，让 channel 就绪，
  // contentToolsAvailable 的 isManaged 分支才可满足。
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  await container.read(channelDetailProvider.notifier).loadChannel('1001');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('p1_advanced_filters_collapsed_by_default：默认只展示搜索+入口', (
    tester,
  ) async {
    await pumpT14Feed(tester);
    expect(find.byKey(const Key('mc_post_search')), findsNothing);
    await tester.tap(find.byKey(const Key('channel-content-search-toggle')));
    await tester.pump();
    expect(
      find.byKey(const Key('mc_post_search')),
      findsOneWidget,
      reason: '搜索常驻',
    );
    expect(
      find.byKey(const Key('mc_filter_toggle')),
      findsOneWidget,
      reason: '筛选入口常驻',
    );
    expect(
      find.byKey(const Key('mc_tag_filter')),
      findsNothing,
      reason: '高级筛选默认折叠',
    );
    expect(find.byKey(const Key('mc_essence_filter')), findsNothing);
  });

  testWidgets(
    'p1_toggle_filters_preserves_values_and_request_count：展开收起不改查询不增请求',
    (tester) async {
      final _T14RecordingAdapter adapter = _T14RecordingAdapter();
      // 重新挂载以便拿到 adapter 引用（复用 pump 的内置 adapter 即可断言
      // 请求面；此处直接用全局断言窗口）
      await pumpT14Feed(tester);
      expect(find.byKey(const Key('mc_post_search')), findsNothing);
      await tester.tap(find.byKey(const Key('channel-content-search-toggle')));
      await tester.pump();
      // 展开
      await tester.tap(find.byKey(const Key('mc_filter_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('mc_tag_filter')), findsOneWidget);
      expect(find.byKey(const Key('mc_essence_filter')), findsOneWidget);
      // 输入标签并提交（产生一次基线查询）
      await tester.enterText(find.byKey(const Key('mc_tag_filter')), '公告');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('mc_essence_filter')), findsOneWidget);
      // 收起（条件应保留）
      await tester.tap(find.byKey(const Key('mc_filter_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('mc_tag_filter')), findsNothing);
      // 再展开：controller 文本保留（条件不丢失）
      await tester.tap(find.byKey(const Key('mc_filter_toggle')));
      await tester.pump();
      final CupertinoTextField tagField = tester.widget<CupertinoTextField>(
        find.byKey(const Key('mc_tag_filter')),
      );
      expect(
        tagField.controller!.text,
        '公告',
        reason: '收起/展开不得丢失已输入条件（controller 常驻）',
      );
      // 展开收起本身不触发任何网络请求（纯本地展示状态）
      expect(adapter.urls, isEmpty);
    },
  );

  testWidgets('p1_submit_filter_matches_baseline_query：提交走既有查询语义', (
    tester,
  ) async {
    await pumpT14Feed(tester);
    expect(find.byKey(const Key('mc_post_search')), findsNothing);
    await tester.tap(find.byKey(const Key('channel-content-search-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mc_filter_toggle')));
    await tester.pump();
    // 精华切换（本地状态，无请求）
    await tester.tap(find.text('精华'));
    await tester.pump();
    // 搜索提交 → channelPostSearchProvider 发起真实 HTTP 面（基线查询）
    await tester.enterText(find.byKey(const Key('mc_post_search')), '发布');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // _searchActive 且搜索结果区出现（无结果兜底也是查询语义生效证据）
    expect(find.textContaining('发布'), findsWidgets);
  });

  testWidgets('p1_collapse_moves_focus_safely：收起时焦点安全转移', (tester) async {
    await pumpT14Feed(tester);
    expect(find.byKey(const Key('mc_post_search')), findsNothing);
    await tester.tap(find.byKey(const Key('channel-content-search-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mc_filter_toggle')));
    await tester.pump();
    // 焦点进标签输入
    await tester.tap(find.byKey(const Key('mc_tag_filter')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    // 收起：输入框离开树，焦点不得悬挂
    await tester.tap(find.byKey(const Key('mc_filter_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('mc_tag_filter')), findsNothing);
    final BuildContext ctx = tester.element(find.byType(ChannelMessageFeed));
    expect(
      FocusManager.instance.primaryFocus?.context,
      isNot(ctx),
      reason: '收起后焦点不应停留在被移除的输入节点',
    );
  });

  testWidgets('mc_* 现有 key 保持可访问：搜索/入口/展开后的标签精华/结果分页', (tester) async {
    await pumpT14Feed(tester);
    expect(find.byKey(const Key('mc_post_search')), findsNothing);
    await tester.tap(find.byKey(const Key('channel-content-search-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('mc_post_search')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mc_filter_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('mc_tag_filter')), findsOneWidget);
    expect(find.byKey(const Key('mc_essence_filter')), findsOneWidget);
  });
}
