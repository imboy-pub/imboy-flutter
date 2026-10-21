/// T24.a — P3 候选 golden 生成 — imboy-enterprise-uiux-v1
///
/// MATRIX.json P3 全部 120 配置（5 场景 × 3 平台 × 2 视口 × 2 主题 ×
/// 2 缩放）。基线不存在默认失败；候选生成命令见 C-T24-a-1 证据。
///
/// 场景轴分化（GOLDEN_COVERAGE_CORRECTION.md 残余债务②）：字节死由两因
/// 叠加——① closed / missing-preview / unknown-source 注入相同夹具状态；
/// ② 同型 StatefulWidget 无 key 连续 pump 时 State 复用，后续场景根本
/// 不重新拉数据（渲染停留在首个同型场景）。现五场景各注入与语义相符的
/// 可见状态（见 [_p3SceneItems]），并按配置 ValueKey 强制重建。
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

import '../../golden_baseline_guard.dart';
import '../p3/p3_fixtures.dart' show p3OrgId, p3QueueItemWire;
import '../support/golden_font_loader.dart';

/// P3 五场景的夹具状态分化表（对齐 p2_golden_test 的场景分化模式：
/// 不同 scene 注入不同可见状态，使渲染真实分化）。
///
/// 各场景语义与可见差异（行内容 = 掩码名 → 摘要 → 来源 → 尾部动作）：
/// - queued：待接队列行（等待时长 + 接单按钮；沿用既有基线形态不改）；
/// - active：处理中会话行（chevron + 网页渠道 + 真实摘要）；
/// - closed：已关闭会话行，渠道 wire 缺省为空 → 行内不渲染渠道标识
///   （结构差异：行高少一行）；
/// - missing-preview：末条消息存在但摘要不可用（附件-only / 解密降级，
///   preview=null）→ csQueuePreviewText 中间态，摘要区不渲染文本；
/// - unknown-source：来源 wire 未映射（非 widget 的 'app'）→ 通用
///   「未知」展示名（csSourceDisplayLabel 兜底分支）。
///
/// 中文样张仅复用既有字符串或由已覆盖汉字与全角标点组合。
List<Map<String, dynamic>> _p3SceneItems(String scene) {
  switch (scene) {
    case 'queued':
      return <Map<String, dynamic>>[p3QueueItemWire()];
    case 'active':
      return <Map<String, dynamic>>[p3QueueItemWire(status: 'active')];
    case 'closed':
      return <Map<String, dynamic>>[
        p3QueueItemWire(
          status: 'closed',
          maskedName: '测试姓名',
          preview: '中文系统消息。',
          source: '',
        ),
      ];
    case 'missing-preview':
      return <Map<String, dynamic>>[
        p3QueueItemWire(status: 'closed', maskedName: '文艺姓名', preview: null),
      ];
    default:
      return <Map<String, dynamic>>[
        p3QueueItemWire(
          status: 'closed',
          maskedName: '消息频道',
          preview: '频道消息测试！',
          source: 'app',
        ),
      ];
  }
}

class _P3GoldenNoopAdapter implements HttpClientAdapter {
  _P3GoldenNoopAdapter(this.items);

  final List<Map<String, dynamic>> items;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': <String, dynamic>{
          'sessions': items,
          'list': items,
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
    final String scene = cfg.scene;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
    HttpClient.adapterForTest = _P3GoldenNoopAdapter(_p3SceneItems(scene));
    addTearDown(() => HttpClient.adapterForTest = prevAdapter);

    final Widget view = scene == 'queued'
        ? CsQueueView(
            // 场景轴字节死的根因：连续 pump 同型 StatefulWidget（无 key）
            // 时 Flutter 复用 Element/State——initState 不重跑、fetchPage
            // 闭包与首拉数据停留在上一配置，后续场景渲染的仍是第一个
            // 同型场景的数据。ValueKey(cfg.id) 强制每配置重建 State，
            // 场景夹具状态才真正进入渲染。
            key: ValueKey<String>(cfg.id),
            orgId: p3OrgId,
          )
        : CsSessionListView(
            key: ValueKey<String>(cfg.id),
            orgId: p3OrgId,
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

  testWidgets(
    'p3_golden_all_120_configs_rendered：全配置渲染并出图',
    skip: !goldenBaselinesReady(
      kP3GoldenConfigs.map(
        (GoldenP3Config cfg) => 'test/uiux/golden/goldens/${cfg.id}.png',
      ),
    ),
    (tester) async {
      expect(kP3GoldenConfigs.length, 120, reason: 'MATRIX.json P3 总数');
      for (final GoldenP3Config cfg in kP3GoldenConfigs) {
        await _pumpP3Golden(tester, cfg);
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile('goldens/${cfg.id}.png'),
        );
        expect(tester.takeException(), isNull, reason: '${cfg.id} 无渲染异常');
      }
    },
  );
}
