/// T23.a — P2 候选 golden 生成 — imboy-enterprise-uiux-v1
///
/// MATRIX.json P2 全部 72 配置（3 场景 × 3 平台 × 2 视口 × 2 主题 ×
/// 2 缩放）。基线不存在默认失败；候选生成命令见 C-T23-a-1 证据。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoListTile, CupertinoListTileChevron;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/enterprise_oa/domain/enterprise_oa_brand_config.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
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
              'p2/${scene}_${platform}_${vp[0] as int}x${vp[1] as int}_${theme}_s${scale == 1.0 ? '1' : scale.toInt().toString()}',
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

/// conditional-login 场景的合成 OA 条目：inboundLoginEnabled=true 的
/// 最小合法形态（applicationKey 8..128 可打印 + loginStartUri 与
/// oaOrigin https exact 同源），用于捕获 P2-04 辅助登录行（24px 图标槽）。
const EnterpriseOaRuntimeConfig _syntheticInboundEntry =
    EnterpriseOaRuntimeConfig(
      brand: EnterpriseOaBrandConfig(
        flavorId: 'synthetic',
        applicationIdOverride: '',
        displayName: 'Synthetic OA',
        iconAssetKey: '',
        splashAssetKey: '',
        primaryColor: AppColors.primary,
        accentColor: null,
        oaLabel: 'Synthetic OA',
        oaOrigin: 'https://oa.synthetic.example',
        oaEntryEnabled: false,
      ),
      applicationKey: 'synthetic-key-01',
      redirectUri: 'https://oa.synthetic.example/oa/redirect',
      loginStartUri: 'https://oa.synthetic.example/oa/login',
    );

/// 资源行合成件：对齐 enterprise_shell 的 24px 图标槽 + ≥48 命中形态。
class _SyntheticResourceTile extends StatelessWidget {
  const _SyntheticResourceTile(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(vertical: 10),
      leading: const SizedBox.square(
        dimension: 24,
        child: Center(
          widthFactor: 1,
          child: Icon(CupertinoIcons.folder_fill, size: 20),
        ),
      ),
      title: Text(title),
      trailing: const CupertinoListTileChevron(),
    );
  }
}

Future<void> _pumpP2Golden(WidgetTester tester, GoldenP2Config cfg) async {
  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = cfg.platform;
  // conditional-login 场景以 android 平台形态出图（入口行含图标槽）
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

    // 第四轮 review 修正：三场景必须渲染出可区分状态（此前三个场景
    // 逐字节相同，P2-04 辅助登录行/多行资源区从未被任何 golden 捕获，
    // 见 GOLDEN_COVERAGE_CORRECTION.md）。
    // - apps-only：仅页面内置的"应用"联调区（resourceEntries 为空）；
    // - resources-visible：CS 入口 + 两条合成资源行（多子项分组容器，
    //   兼作分隔线/自然收缩的视觉基线）；
    // - conditional-login：注入 inboundLoginEnabled 的合成 OA 条目
    //   （android 平台形态渲染 24px 图标槽辅助登录行）。
    final bool withWorkspace = cfg.scene == 'resources-visible';
    final bool withInboundLogin = cfg.scene == 'conditional-login';

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
            home: Scaffold(
              body: EnterpriseWorkbenchPage(
                entries: withInboundLogin
                    ? const <EnterpriseOaRuntimeConfig>[_syntheticInboundEntry]
                    : const <EnterpriseOaRuntimeConfig>[],
                accountKey: 'synthetic-account',
                organizationId: '10',
                resourceEntries: withWorkspace
                    ? <Widget>[
                        const CsWorkspaceEntryTile(),
                        const _SyntheticResourceTile('合成资源入口-项目'),
                        const _SyntheticResourceTile('合成资源入口-OA'),
                      ]
                    : const <Widget>[],
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
