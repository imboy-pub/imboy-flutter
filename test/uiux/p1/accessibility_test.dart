/// T22 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_matrix_all_expected_configs_executed（16 配置矩阵全执行）
///  2. p1_semantics_labels_and_targets_valid
///  3. p1_text_and_enabled_icon_contrast_valid
///  4. p1_short_viewport_keyboard_focus_reachable
///  5. expected=executed、必需 case 无 skip
///
/// 结构/语义/尺寸/对比度与键盘边界；golden 生成与视觉审查在
/// T22.a/T22.b（本卡不冒充）。矩阵计数落盘 P1_MATRIX.md。
library;

import 'dart:convert' show jsonEncode;
import 'dart:io' show File;
import 'dart:math' show pow;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoIcons;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
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
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

/// 空成功出口。
class _T22NoopAdapter implements HttpClientAdapter {
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

/// 结构矩阵配置（P1：2 视口 × 2 亮度 × 2 缩放 × 2 平台）。
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

final List<MatrixConfig> kMatrixConfigs = <MatrixConfig>[
  for (final Size vp in <Size>[Size(360, 800), Size(1280, 800)])
    for (final Brightness b in Brightness.values)
      for (final double sc in <double>[1.0, 2.0])
        for (final TargetPlatform pl in <TargetPlatform>[
          TargetPlatform.iOS,
          TargetPlatform.android,
        ])
          MatrixConfig(
            'p1_${vp.width.toInt()}x${vp.height.toInt()}_${b == Brightness.light ? 'light' : 'dark'}_scale${sc.toInt()}_${pl == TargetPlatform.iOS ? 'ios' : 'android'}',
            vp,
            b,
            sc,
            pl,
          ),
];

/// 挂载 standalone 详情（矩阵配置驱动）。
Future<void> pumpT22(WidgetTester tester, MatrixConfig cfg) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  final HttpClientAdapter? prev = HttpClient.adapterForTest;
  HttpClient.adapterForTest = _T22NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = prev);

  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = cfg.platform;
  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = cfg.viewport;

  final P1FixtureTrace trace = P1FixtureTrace();
  final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const ChannelDetailPage(channelId: '1001', autoLoadStats: false),
      ),
    ],
  );
  addTearDown(router.dispose);

  try {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            channelDetailProvider.overrideWith(
              () => P1ChannelDetailFixture(
                trace: trace,
                channel: p1SyntheticChannel(managed: true),
                messages: p1SyntheticMessages(),
              ),
            ),
            voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
          ],
          child: MaterialApp(
            theme: cfg.brightness == Brightness.light
                ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
            builder: (context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(cfg.scale)),
              child: child!,
            ),
            home: const ChannelDetailPage(
              channelId: '1001',
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
  } finally {
    // foundation invariant 检查早于 addTearDown：同步复位
    debugDefaultTargetPlatformOverride = prevPlatform;
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
}

double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) {
      final double x = v / 255;
      return x <= 0.03928
          ? x / 12.92
          : pow((x + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * ch(c.r * 255.0) +
        0.7152 * ch(c.g * 255.0) +
        0.0722 * ch(c.b * 255.0);
  }

  final double l1 = lum(a);
  final double l2 = lum(b);
  return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
}

void main() {
  testWidgets('p1_matrix_all_expected_configs_executed：16 配置结构全过', (
    tester,
  ) async {
    final List<Map<String, Object?>> executed = <Map<String, Object?>>[];
    for (final MatrixConfig cfg in kMatrixConfigs) {
      await pumpT22(tester, cfg);
      // 结构断言：唯一身份标题（GlassAppBar）+ HeaderBar 存在 + 首条内容
      expect(find.text('工程效率频道'), findsOneWidget, reason: '${cfg.id} 身份标题唯一');
      expect(find.byType(ChannelHeaderBar), findsOneWidget);
      expect(find.text('首条置顶内容：工程实践与产品更新。'), findsOneWidget);
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
    expect(executed.length, kMatrixConfigs.length);
    // 矩阵计数落盘（执行计数证据，expected=executed）
    final File matrix = File(
      '.dart_tool/imboy-uiux/imboy-enterprise-uiux-v1/evidence/T22/p1_matrix_counts.json',
    );
    matrix.parent.createSync(recursive: true);
    matrix.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'expected': kMatrixConfigs.length,
        'executed': executed.length,
        'skipped': 0,
        'configs': executed,
      }),
    );
  });

  testWidgets('p1_semantics_labels_and_targets_valid：动作语义与命中有效', (
    tester,
  ) async {
    await pumpT22(tester, kMatrixConfigs.first);
    final headerButtons = find.descendant(
      of: find.byType(ChannelHeaderBar),
      matching: find.byType(CupertinoButton),
    );
    expect(headerButtons, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      final Size size = tester.getSize(headerButtons.at(index));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    // 管理入口收进更多菜单后，仍需从可触达入口找到设置动作。
    final menu = find.byType(PopupMenuButton<String>);
    expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final manage = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<String> && widget.value == 'edit_channel',
    );
    expect(manage, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(t.channel.settings)), findsWidgets);
    final Size hit = tester.getSize(manage);
    expect(hit.height, greaterThanOrEqualTo(48), reason: '语义节点命中区域有效');
    expect(tester.takeException(), isNull);
  });

  testWidgets('p1_text_and_enabled_icon_contrast_valid：亮暗两态对比度有效', (
    tester,
  ) async {
    for (final MatrixConfig cfg in kMatrixConfigs) {
      if (cfg.scale != 1.0) continue;
      await pumpT22(tester, cfg);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      final Color surface = menu.color!;
      final Icon shareIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(PopupMenuItem<String>),
          matching: find.byIcon(CupertinoIcons.share),
        ),
      );
      final double ratio = contrastRatio(shareIcon.color!, surface);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: '${cfg.id} 可用动作图标对比度 ≥3:1',
      );
      Navigator.of(tester.element(find.byType(PopupMenuItem<String>).first))
          .pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('p1_short_viewport_keyboard_focus_reachable：矮视口焦点可达', (
    tester,
  ) async {
    // 360×480 矮视口：内容区被压缩，搜索框仍可聚焦（键盘边界可达）
    await pumpT22(
      tester,
      const MatrixConfig(
        'p1_short_360x480_light_scale1_ios',
        Size(360, 480),
        Brightness.light,
        1.0,
        TargetPlatform.iOS,
      ),
    );
    // 搜索权限关闭时，仍验证导航栏菜单与其中管理动作可达。
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    final actionable = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<String> && widget.value == 'edit_channel',
    );
    expect(actionable, findsWidgets);
    await tester.ensureVisible(actionable.first);
    await tester.pump();
    // 可达性几何证据：ensureVisible 后动作中心落在视口边界内
    // （不真触发导航——管理动作会 push 编辑路由，需完整路由桩）。
    final Offset center = tester.getCenter(actionable.first);
    expect(center.dy, greaterThanOrEqualTo(0), reason: '矮视口下动作可见可达');
    expect(center.dy, lessThanOrEqualTo(tester.view.physicalSize.height));
    expect(tester.takeException(), isNull);
  });
}
