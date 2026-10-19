/// T22.a — P1 候选 golden 生成测试 — imboy-enterprise-uiux-v1
///
/// 覆盖 MATRIX.json P1 全部 120 配置（5 场景 × 3 平台 × 2 视口 × 2 主题
/// × 2 缩放）。基线不存在时本测试**默认失败**（合同：新测试必需
/// baseline 不存在即失败）；候选生成仅经
/// baseline 不存在即失败）。候选生成命令记录于 C-T22-a-1 证据的 run.manifest。
/// 执行，输出写 versioned 候选目录，不覆盖已封存 baseline。
///
/// 环境冻结（GOLDEN_ENV.md）：确定性 CJK 字体（Arial Unicode 登记 hash）、
/// DPR=1、locale=zh-CN、合成数据无真实客户信息、日期取绝对格式避免
/// 相对漂移。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_message_feed.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../p1/p1_fixtures.dart';
import '../support/golden_font_loader.dart';

// ---- MATRIX P1 配置（与 _task_packages/MATRIX.json 同步） ----

class GoldenConfig {
  final String id;
  final String scene;
  final TargetPlatform platform;
  final Size viewport;
  final String theme;
  final double textScale;

  const GoldenConfig(
    this.id,
    this.scene,
    this.platform,
    this.viewport,
    this.theme,
    this.textScale,
  );
}

const List<String> _p1Scenes = <String>[
  'content-long-name',
  'stats-disabled',
  'initial-error',
  'empty',
  'filters-expanded',
];

final List<GoldenConfig> kP1GoldenConfigs = <GoldenConfig>[
  for (final String scene in _p1Scenes)
    for (final String platform in <String>['ios', 'android', 'macos'])
      for (final List<Object?> vp in <List<Object?>>[
        <Object?>[360, 800],
        <Object?>[1280, 800],
      ])
        for (final String theme in <String>['light', 'dark'])
          for (final double scale in <double>[1.0, 2.0])
            GoldenConfig(
              'p1/${scene}_${platform}_${vp[0] as int}x${vp[1] as int}_${theme}_s${scale == 1.0 ? '1' : scale.toInt().toString()}',
              scene,
              platform == 'ios'
                  ? TargetPlatform.iOS
                  : platform == 'android'
                  ? TargetPlatform.android
                  : TargetPlatform.macOS,
              Size((vp[0] as num).toDouble(), (vp[1] as num).toDouble()),
              theme,
              scale,
            ),
];

/// 空成功出口。
class _GoldenNoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

/// 开启微社区门（filters-expanded 场景需要；T14 同款接线）。
Future<void> _enableGate() async {
  FeatureScope.bind(endpoint: 'http://golden.test', uid: 'golden_uid');
  await StorageService.setMap(
    FeatureScope.cacheKey(Keys.appManifest),
    <String, dynamic>{
      'body': <String, dynamic>{
        'manifest_hash': productFeatureManifestHash,
        'manifest_schema_version': productFeatureSchemaVersion,
        'compiled_features': compiledProductFeatures.toList(),
        'policy': <String, dynamic>{'profile': 'enterprise'},
        'features': <String, dynamic>{
          for (final String f in compiledProductFeatures) f: true,
        },
      },
      'etag': null,
    },
  );
  AppManifestService.loadFromCache();
  AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
    for (final String f in compiledProductFeatures) f: true,
  });
}

Future<void> _disableGate() async {
  await AppManifestService.clear();
  AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
}

Future<void> _pumpGolden(WidgetTester tester, GoldenConfig cfg) async {
  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = cfg.platform;
  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = cfg.viewport;

  final bool initialError = cfg.scene == 'initial-error';
  final bool empty = cfg.scene == 'empty';
  final bool filtersExpanded = cfg.scene == 'filters-expanded';

  try {
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
    if (filtersExpanded) {
      await _enableGate();
      addTearDown(_disableGate);
    }

    final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
    HttpClient.adapterForTest = _GoldenNoopAdapter();
    addTearDown(() => HttpClient.adapterForTest = prevAdapter);

    final P1FixtureTrace trace = P1FixtureTrace();
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ChannelDetailPage(
            channelId: '1001',
            autoLoadStats: cfg.scene == 'stats-disabled' ? false : false,
          ),
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
                  longName: cfg.scene == 'content-long-name',
                ),
                messages: p1SyntheticMessages(
                  empty: empty,
                  count: filtersExpanded ? 6 : 2,
                ),
                initialError: initialError,
              ),
            ),
            voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
          ],
          child: MaterialApp(
            theme: cfg.theme == 'light'
                ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(cfg.textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: filtersExpanded
                  ? SizedBox(
                      height: cfg.viewport.height,
                      child: ChannelMessageFeed(
                        channelId: '1001',
                        isManaged: true,
                      ),
                    )
                  : const ChannelDetailPage(
                      channelId: '1001',
                      autoLoadStats: false,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    if (filtersExpanded) {
      await tester.tap(find.byKey(const Key('mc_filter_toggle')));
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  } finally {
    // foundation invariant 检查早于 addTearDown：同步复位
    debugDefaultTargetPlatformOverride = prevPlatform;
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // GOLDEN_ENV：确定性 CJK 字体（缺字体时字体加载失败 → 全部金图失败，
    // 属预期 fail-closed；登记路径见 GOLDEN_ENV.md）
    final r = resolveGoldenFont();
    if (r.status == GoldenFontStatus.ok) {
      await loadGoldenFont(r);
    } else {
      fail('GOLDEN_ENV 缺确定性字体：${r.reason}（VISUAL_BLOCKED，不生成候选）');
    }
  });

  testWidgets('p1_golden_all_120_configs_rendered：全配置渲染并出图', (tester) async {
    expect(kP1GoldenConfigs.length, 120, reason: 'MATRIX.json P1 总数');
    for (final GoldenConfig cfg in kP1GoldenConfigs) {
      await _pumpGolden(tester, cfg);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/${cfg.id}.png'),
      );
      expect(tester.takeException(), isNull, reason: '${cfg.id} 无渲染异常');
    }
  });
}
