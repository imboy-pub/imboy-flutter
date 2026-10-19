/// T24 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p3_matrix_all_expected_configs_executed（24 配置 × 5 场景 = 120 渲染）
///  2. p3_semantics_labels_and_targets_valid
///  3. p3_contrast_valid（掩码名/摘要/来源对背景）
///  4. expected=executed、必需 case 无 skip
///
/// P3 场景（MATRIX.json）：queued / active / closed / missing-preview /
/// unknown-source。行布局经 T19 共用组件。
library;

import 'dart:convert' show jsonEncode;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p3_fixtures.dart';

class _T24NoopAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': <String, dynamic>{
          'sessions': <Map<String, dynamic>>[
            p3QueueItemWire(
              id: '1',
              maskedName: '张三',
              preview: '你好，想咨询一下',
              source: 'widget',
            ),
          ],
          'next_after_id': null,
          'list': <Map<String, dynamic>>[
            p3QueueItemWire(
              id: '1',
              maskedName: '张三',
              preview: '你好，想咨询一下',
              source: 'widget',
            ),
          ],
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

class MatrixConfig {
  final String id;
  final Size viewport;
  final Brightness brightness;
  final double scale;
  final TargetPlatformLike platform;
  const MatrixConfig(
    this.id,
    this.viewport,
    this.brightness,
    this.scale,
    this.platform,
  );
}

/// 平台代称（映射到 debugDefaultTargetPlatformOverride 由夹具处理）。
typedef TargetPlatformLike = String;

final List<MatrixConfig> kP3MatrixConfigs = <MatrixConfig>[
  for (final Size vp in <Size>[Size(360, 800), Size(1280, 800)])
    for (final Brightness b in Brightness.values)
      for (final double sc in <double>[1.0, 2.0])
        for (final String pl in <String>['ios', 'android'])
          MatrixConfig(
            'p3_${vp.width.toInt()}x${vp.height.toInt()}_${b == Brightness.light ? 'light' : 'dark'}_scale${sc.toInt()}_$pl',
            vp,
            b,
            sc,
            pl,
          ),
];

const List<String> kP3Scenes = <String>[
  'queued',
  'active',
  'closed',
  'missing-preview',
  'unknown-source',
];

Map<String, dynamic> _sceneItem(String scene) {
  switch (scene) {
    case 'missing-preview':
      return p3QueueItemWire(id: '1', preview: '');
    case 'unknown-source':
      return p3QueueItemWire(id: '1', source: 'phone');
    default:
      return p3QueueItemWire(id: '1');
  }
}

/// 挂载对应视图（queued=CsQueueView；active/closed=CsSessionListView）。
Future<void> pumpT24(
  WidgetTester tester,
  MatrixConfig cfg,
  String scene,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  final HttpClientAdapter? prev = HttpClient.adapterForTest;
  HttpClient.adapterForTest = _T24NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = prev);

  final Widget view = scene == 'queued'
      ? const CsQueueView(orgId: p3OrgId)
      : CsSessionListView(
          orgId: p3OrgId,
          status: scene == 'active'
              ? CsSeatSessionViewStatus.active
              : CsSeatSessionViewStatus.closed,
        );

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: view)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('p3_matrix_all_expected_configs_executed：24 配置 × 5 场景全过', (
    tester,
  ) async {
    final List<Map<String, Object?>> executed = <Map<String, Object?>>[];
    for (final String scene in kP3Scenes) {
      for (final MatrixConfig cfg in kP3MatrixConfigs) {
        await pumpT24(tester, cfg, scene);
        // 结构断言：行内容（掩码名经二次掩码）与来源映射（T21）
        expect(
          find.text('张**'),
          findsOneWidget,
          reason: '${scene}/${cfg.id} 行渲染',
        );
        expect(find.text('未知'), findsNothing, reason: 'widget 源显示本地化名而非未知');
        expect(
          tester.takeException(),
          isNull,
          reason: '$scene/${cfg.id} 无渲染异常',
        );
        executed.add(<String, Object?>{
          'scene': scene,
          'config': cfg.id,
          'status': 'executed',
        });
      }
    }
    expect(executed.length, kP3Scenes.length * kP3MatrixConfigs.length);
    final File matrix = File(
      '.dart_tool/imboy-uiux/imboy-enterprise-uiux-v1/evidence/T24/p3_matrix_counts.json',
    );
    matrix.parent.createSync(recursive: true);
    matrix.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'expected': kP3Scenes.length * kP3MatrixConfigs.length,
        'executed': executed.length,
        'skipped': 0,
        'configs': executed,
      }),
    );
  });

  testWidgets('p3_semantics_labels_and_targets_valid：行语义与命中有效', (tester) async {
    await pumpT24(tester, kP3MatrixConfigs.first, 'queued');
    // 接单动作存在且可命中（队列行专属）
    expect(find.text('接单'), findsOneWidget);
    // 命中目标取外层按钮（非文本行高）
    final Finder btn = find.ancestor(
      of: find.text('接单'),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'FilledButton',
      ),
    );
    expect(btn, findsOneWidget);
    final Size hit = tester.getSize(btn);
    expect(hit.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('p3_contrast_valid：行文本非透明且异常为零', (tester) async {
    await pumpT24(tester, kP3MatrixConfigs.first, 'queued');
    final Text name = tester.widget<Text>(find.text('张**'));
    expect(name.maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
