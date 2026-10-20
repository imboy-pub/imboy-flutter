/// T24.a — P3 候选 golden 生成 — imboy-enterprise-uiux-v1
///
/// MATRIX.json P3 全部 120 配置（5 场景 × 3 平台 × 2 视口 × 2 主题 ×
/// 2 缩放）。基线不存在默认失败；候选生成命令见 C-T24-a-1 证据。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/golden_font_loader.dart';

class _P3GoldenNoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> item = <String, dynamic>{
      'id': '1',
      'contact_id': '7266418340025500099',
      'contact': <String, dynamic>{'masked_name': '张三'},
      'queued_at':
          (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 65 * 60)
              .toString(),
      'version': 3,
      'status': 'queued',
      'source': 'widget',
      'organization_id': '7266418340025468901',
      'conversation_id': '7266418340025468950',
      'business_identity_id': '',
      'last_message': <String, dynamic>{
        'id': '7266418340025500777',
        'preview': '你好，想咨询一下',
      },
    };
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': <String, dynamic>{
          'sessions': <Map<String, dynamic>>[item],
          'list': <Map<String, dynamic>>[item],
          'next_after_id': null,
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

final List<GoldenP3Config> kP3GoldenConfigs = <GoldenP3Config>[
  for (final String scene in <String>[
    'queued',
    'active',
    'closed',
    'missing-preview',
    'unknown-source',
  ])
    for (final String platform in <String>['ios', 'android', 'macos'])
      for (final List<Object?> vp in <List<Object?>>[
        <Object?>[360, 800],
        <Object?>[1280, 800],
      ])
        for (final String theme in <String>['light', 'dark'])
          for (final double scale in <double>[1.0, 2.0])
            GoldenP3Config(
              'p3/${scene}_${platform}_${vp[0] as int}x${vp[1] as int}_${theme}_s${scale == 1.0 ? '1' : scale.toInt().toString()}',
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

class GoldenP3Config {
  final String id;
  final String scene;
  final TargetPlatform platform;
  final Size viewport;
  final String theme;
  final double textScale;
  const GoldenP3Config(
    this.id,
    this.scene,
    this.platform,
    this.viewport,
    this.theme,
    this.textScale,
  );
}

Future<void> _pumpP3Golden(WidgetTester tester, GoldenP3Config cfg) async {
  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = cfg.platform;
  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = cfg.viewport;
  try {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
    HttpClient.adapterForTest = _P3GoldenNoopAdapter();
    addTearDown(() => HttpClient.adapterForTest = prevAdapter);

    final String scene = cfg.scene;
    final Widget view = scene == 'queued'
        ? const CsQueueView(orgId: '7266418340025468901')
        : CsSessionListView(
            orgId: '7266418340025468901',
            status: scene == 'active'
                ? CsSeatSessionViewStatus.active
                : CsSeatSessionViewStatus.closed,
          );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: applyGoldenFont(
            cfg.theme == 'light'
                ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
          ),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(cfg.textScale)),
            child: child!,
          ),
          home: Scaffold(body: view),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  } finally {
    debugDefaultTargetPlatformOverride = prevPlatform;
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = resolveGoldenFont();
    if (r.status == GoldenFontStatus.ok) {
      await loadGoldenFont(r);
    } else {
      fail('GOLDEN_ENV 缺确定性字体：${r.reason}');
    }
  });

  testWidgets('p3_golden_all_120_configs_rendered：全配置渲染并出图', (tester) async {
    expect(kP3GoldenConfigs.length, 120, reason: 'MATRIX.json P3 总数');
    for (final GoldenP3Config cfg in kP3GoldenConfigs) {
      await _pumpP3Golden(tester, cfg);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/${cfg.id}.png'),
      );
      expect(tester.takeException(), isNull, reason: '${cfg.id} 无渲染异常');
    }
  });
}
