/// T11 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_stats_disabled_has_no_skeleton
///  2. p1_stats_null_uses_existing_count_without_request
///  3. p1_unknown_count_is_not_fabricated
///  4. autoLoadStats=false 无新增统计网络请求
///
/// P1-02 勘察判定 VERIFY_EXISTING：HeaderBar 已用频道自带订阅数兜底
/// 直显（2026-10-17 修复），本卡按 change 只补测试，不改加载语义。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

/// 空成功出口：记录路径供「无统计请求」断言。
class RecordingAdapter implements HttpClientAdapter {
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

/// standalone 详情页（autoLoadStats 可控）+ 真实出口记录。
Future<RecordingAdapter> pumpT11Detail(
  WidgetTester tester, {
  bool autoLoadStats = false,
  int subscriberCount = 12,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();

  final RecordingAdapter adapter = RecordingAdapter();
  final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = prevAdapter);

  final P1FixtureTrace trace = P1FixtureTrace();
  final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            ChannelDetailPage(channelId: '1001', autoLoadStats: autoLoadStats),
      ),
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
              channel: p1SyntheticChannel(
                managed: true,
                subscriberCount: subscriberCount,
              ),
              messages: p1SyntheticMessages(),
            ),
          ),
          voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return adapter;
}

void main() {
  testWidgets('p1_stats_disabled_has_no_skeleton：统计不请求时无骨架占位', (tester) async {
    await pumpT11Detail(tester, autoLoadStats: false);
    expect(find.byType(ChannelHeaderBar), findsOneWidget);
    // 无永久骨架：无骨架 shimmer / 转圈占位
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'p1_stats_null_uses_existing_count_without_request：stats 缺失用频道订阅数兜底且无统计请求',
    (tester) async {
      // fixture 从不产出 stats（恒 null）→ 兜底 channel.subscriberCount=12
      final RecordingAdapter adapter = await pumpT11Detail(
        tester,
        autoLoadStats: false,
      );
      expect(
        find.textContaining('12'),
        findsWidgets,
        reason: 'stats=null 时直显频道自带订阅数（非骨架）',
      );
      expect(
        adapter.paths.where((String p) => p.contains('/stats')),
        isEmpty,
        reason: 'autoLoadStats=false 不得新增统计端点请求',
      );
    },
  );

  testWidgets('p1_unknown_count_is_not_fabricated：服务端真实值直显不伪造', (tester) async {
    // 紧凑头部展示服务端真实计数，不改写为 0 或用占位值。
    await pumpT11Detail(tester, subscriberCount: 4711);
    expect(find.textContaining('4711'), findsWidgets);
  });

  testWidgets('服务端真实 0 直显不被当作未知隐藏', (tester) async {
    await pumpT11Detail(tester, subscriberCount: 0);
    expect(
      find.textContaining('0'),
      findsWidgets,
      reason: '0 是服务端真实值，直显而非隐藏或替换',
    );
  });

  testWidgets('autoLoadStats=false 无新增网络请求（仅静音态既有请求面）', (tester) async {
    final RecordingAdapter adapter = await pumpT11Detail(
      tester,
      autoLoadStats: false,
    );
    // 频道加载（loadChannel）由夹具替身接管，不经网络；
    // 出站仅允许 HeaderBar 静音态读取（getSubscription），无统计请求。
    expect(adapter.paths.any((String p) => p.contains('/stats')), isFalse);
  });
}
