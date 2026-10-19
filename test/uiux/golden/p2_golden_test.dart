/// T23.a — P2 候选 golden 生成 — imboy-enterprise-uiux-v1
///
/// MATRIX.json P2 全部 72 配置（3 场景 × 3 平台 × 2 视口 × 2 主题 ×
/// 2 缩放）。基线不存在默认失败；候选生成命令见 C-T23-a-1 证据。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/golden_font_loader.dart';

class _P2GoldenNoopAdapter implements HttpClientAdapter {
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

final List<GoldenP2Config> kP2GoldenConfigs = <GoldenP2Config>[
  for (final String scene in <String>[
    'resources-visible',
    'apps-only',
    'conditional-login',
  ])
    for (final String platform in <String>['ios', 'android', 'macos'])
      for (final List<Object?> vp in <List<Object?>>[
        <Object?>[360, 800],
        <Object?>[1280, 800],
      ])
        for (final String theme in <String>['light', 'dark'])
          for (final double scale in <double>[1.0, 2.0])
            GoldenP2Config(
              'p2/' +
                  scene +
                  '_' +
                  platform +
                  '_' +
                  (vp[0] as int).toString() +
                  'x' +
                  (vp[1] as int).toString() +
                  '_' +
                  theme +
                  '_s' +
                  (scale == 1.0 ? '1' : scale.toInt().toString()),
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

class GoldenP2Config {
  final String id;
  final String scene;
  final TargetPlatform platform;
  final Size viewport;
  final String theme;
  final double textScale;
  const GoldenP2Config(
    this.id,
    this.scene,
    this.platform,
    this.viewport,
    this.theme,
    this.textScale,
  );
}

Future<void> _pumpP2Golden(WidgetTester tester, GoldenP2Config cfg) async {
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
    HttpClient.adapterForTest = _P2GoldenNoopAdapter();
    addTearDown(() => HttpClient.adapterForTest = prevAdapter);

    final bool withWorkspace = cfg.scene == 'resources-visible';
    final bool androidInbound = cfg.scene == 'conditional-login';

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWithValue(
              withWorkspace
                  ? const WorkspaceModel(
                      id: '100',
                      name: 'synthetic-workspace',
                      ownerId: '1',
                      organizationId: '10',
                    )
                  : null,
            ),
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
              body: EnterpriseWorkbenchPage(
                entries: const [],
                accountKey: 'synthetic-account',
                organizationId: '10',
                resourceEntries: <Widget>[const CsWorkspaceEntryTile()],
              ),
            ),
          ),
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

  testWidgets('p2_golden_all_72_configs_rendered：全配置渲染并出图', (tester) async {
    expect(kP2GoldenConfigs.length, 72, reason: 'MATRIX.json P2 总数');
    for (final GoldenP2Config cfg in kP2GoldenConfigs) {
      await _pumpP2Golden(tester, cfg);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/${cfg.id}.png'),
      );
      expect(tester.takeException(), isNull, reason: '${cfg.id} 无渲染异常');
    }
  });
}
