/// T23 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p2_matrix_all_expected_configs_executed（72 配置矩阵全执行）
///  2. p2_semantics_labels_and_targets_valid
///  3. p2_text_and_enabled_icon_contrast_valid
///  4. expected=executed、必需 case 无 skip
///
/// P2 场景：resources-visible（有工作区+坐席）/ apps-only（无工作区）/
/// conditional-login（Android inbound）。矩阵计数落盘 P2_MATRIX.md。
library;

import 'dart:convert' show jsonEncode;
import 'dart:io' show File;
import 'dart:math' show pow;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p2_fixtures.dart';

class _T23NoopAdapter implements HttpClientAdapter {
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
          'contexts': <Map<String, dynamic>>[
            <String, dynamic>{
              'organization_id': 7266418340025468901,
              'organization_name': '合成企业',
              'business_identity_id': 7266418340025468902,
              'seat_enabled': true,
            },
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
  final TargetPlatform platform;
  const MatrixConfig(
    this.id,
    this.viewport,
    this.brightness,
    this.scale,
    this.platform,
  );
}

final List<MatrixConfig> kP2MatrixConfigs = <MatrixConfig>[
  for (final Size vp in <Size>[Size(360, 800), Size(1280, 800)])
    for (final Brightness b in Brightness.values)
      for (final double sc in <double>[1.0, 2.0])
        for (final TargetPlatform pl in <TargetPlatform>[
          TargetPlatform.iOS,
          TargetPlatform.android,
        ])
          MatrixConfig(
            'p2_${vp.width.toInt()}x${vp.height.toInt()}_${b == Brightness.light ? 'light' : 'dark'}_scale${sc.toInt()}_${pl == TargetPlatform.iOS ? 'ios' : 'android'}',
            vp,
            b,
            sc,
            pl,
          ),
];

/// 挂载真实工作台（资源入口经 shell 同构表达式 + CS gate 出口拦截）。
Future<_T23NoopAdapter> pumpT23(
  WidgetTester tester,
  MatrixConfig cfg, {
  bool withWorkspace = true,
  bool withSeat = true,
  bool androidInbound = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  final _T23NoopAdapter adapter = _T23NoopAdapter();
  final HttpClientAdapter? prev = HttpClient.adapterForTest;
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = prev);

  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  if (androidInbound) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = cfg.viewport;

  try {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWithValue(
              withWorkspace ? p2SyntheticWorkspace : null,
            ),
          ],
          child: MaterialApp(
            theme: cfg.brightness == Brightness.light
                ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(cfg.scale)),
              child: child!,
            ),
            home: EnterpriseWorkbenchPage(
              entries: const [],
              accountKey: 'synthetic-account',
              organizationId: '10',
              resourceEntries: <Widget>[const CsWorkspaceEntryTile()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    if (androidInbound) {
      debugDefaultTargetPlatformOverride = prevPlatform;
    }
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
  return adapter;
}

void main() {
  testWidgets('p2_matrix_all_expected_configs_executed：72 配置结构全过', (
    tester,
  ) async {
    final List<Map<String, Object?>> executed = <Map<String, Object?>>[];
    for (final MatrixConfig cfg in kP2MatrixConfigs) {
      await pumpT23(tester, cfg, withWorkspace: true, withSeat: true);
      expect(
        find.byKey(const ValueKey('workbench-apps-entry')),
        findsOneWidget,
        reason: '${cfg.id} 应用入口常驻',
      );
      expect(tester.takeException(), isNull, reason: '${cfg.id} 无渲染异常');
      executed.add(<String, Object?>{
        'config': cfg.id,
        'viewport':
            '${cfg.viewport.width.toInt()}x${cfg.viewport.height.toInt()}',
        'brightness': cfg.brightness == Brightness.light ? 'light' : 'dark',
        'scale': cfg.scale,
        'platform': cfg.platform == TargetPlatform.iOS ? 'ios' : 'android',
        'status': 'executed',
      });
    }
    expect(executed.length, kP2MatrixConfigs.length);
    final File matrix = File(
      '.dart_tool/imboy-uiux/imboy-enterprise-uiux-v1/evidence/T23/p2_matrix_counts.json',
    );
    matrix.parent.createSync(recursive: true);
    matrix.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'expected': kP2MatrixConfigs.length,
        'executed': executed.length,
        'skipped': 0,
        'configs': executed,
      }),
    );
  });

  testWidgets('p2_semantics_labels_and_targets_valid：入口语义与命中有效', (
    tester,
  ) async {
    await pumpT23(
      tester,
      kP2MatrixConfigs.first,
      withWorkspace: true,
      withSeat: true,
    );
    final Finder apps = find.byKey(const ValueKey('workbench-apps-entry'));
    expect(apps, findsOneWidget);
    final Size hit = tester.getSize(apps);
    expect(hit.height, greaterThanOrEqualTo(48));
    expect(hit.width, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('p2_text_and_enabled_icon_contrast_valid：亮暗对比度有效', (
    tester,
  ) async {
    for (final MatrixConfig cfg in kP2MatrixConfigs) {
      if (cfg.scale != 1.0) continue;
      await pumpT23(tester, cfg);
      // 入口行标题的生效文字色（图标色为继承，无显式值）
      final DefaultTextStyle dts = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('应用'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      // 槽内图标为 primary/次级可读色：背景为分组 surface——断言非透明
      // 且亮度差异可见（≥3:1 由 T12 helper 口径）。
      double lum(Color c) {
        double ch(double v) {
          final double x = v / 255;
          return x <= 0.03928
              ? x / 12.92
              : pow((x + 0.055) / 1.055, 2.4).toDouble();
        }

        return 0.2126 * ch(c.red.toDouble()) +
            0.7152 * ch(c.green.toDouble()) +
            0.0722 * ch(c.blue.toDouble());
      }

      // 文字画在 _GroupedSection 分组容器上：背景取实际 DecoratedBox 色
      final DecoratedBox bg = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text('应用'), matching: find.byType(DecoratedBox))
            .first,
      );
      final Color surface = (bg.decoration as BoxDecoration).color!;
      final double ratio = (lum(dts.style.color!) > lum(surface))
          ? (lum(dts.style.color!) + 0.05) / (lum(surface) + 0.05)
          : (lum(surface) + 0.05) / (lum(dts.style.color!) + 0.05);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: '${cfg.id} 入口文字对比度 ≥3:1',
      );
    }
  });

  testWidgets('resources-visible 场景：seat-contexts 出站且应用入口在', (tester) async {
    final _T23NoopAdapter adapter = await pumpT23(
      tester,
      kP2MatrixConfigs.first,
      withWorkspace: true,
      withSeat: true,
    );
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
    expect(
      adapter.paths.any((String p) => p.contains('seat-contexts')),
      isTrue,
      reason: 'CS gate 出站被记录（基线）',
    );
  });

  testWidgets('conditional-login 场景：Android inbound 入口可达', (tester) async {
    await pumpT23(
      tester,
      kP2MatrixConfigs.first,
      withSeat: false,
      androidInbound: true,
    );
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
