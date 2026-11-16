// DSN-05 negative control (golden case, item A01) — PENDING REVIEW fixture.
//
// 用途（CASES.md DSN-05 反例条款）: 在隔离测试 fixture 保留一组低于阈值的颜色组合，
// 确认对比度断言确实失败（负控）；同时证明 4.4637:1 不因四舍五入通过；
// 禁用项单列不参与 4.5 裁决；暗色辅助文字逐行评判而非一并判错。
//
// 本文件是纯 Dart 检查器 + 断言，不构造任何 widget，不修改任何产品代码。
// 数值来源（未舍入，双精度，合成先行 / composite-first）:
//   _task_packages/IMBoy_Web_MVP_V3.0/runtime/runs/g02-dsn-family-20261115/DSN-05/
//     contrast-measurements.csv / contrast-measurements.json / compositing-chains.json
// 对应 app HEAD: da7ae435e738d463c38dbd778315622d6d6987f7
//
// 合成语义: Flutter >=3.27 的 Color 分量为 double（0..1），withValues(alpha: x)
// 精确保存 x（无 8-bit alpha 量化）；渲染前的未舍入合成值即测量对象，
// 8-bit 量化 hex 仅作显示层交叉校验。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast checker (sRGB linearization threshold 0.03928).
/// The only judgment API is [passes45] on the UNROUNDED ratio.
class Dsn05ContrastChecker {
  Dsn05ContrastChecker._();

  static double _linear(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  /// WCAG 2.x relative luminance (channels 0..255, gamma-encoded).
  static double luminanceD(double r, double g, double b) =>
      0.2126 * _linear(r / 255) +
      0.7152 * _linear(g / 255) +
      0.0722 * _linear(b / 255);

  static double luminance(int r, int g, int b) =>
      luminanceD(r.toDouble(), g.toDouble(), b.toDouble());

  /// Contrast ratio from UNROUNDED composite channels — the measurement path.
  static double ratioChannelsD(List<double> c1, List<double> c2) {
    final double l1 = luminanceD(c1[0], c1[1], c1[2]);
    final double l2 = luminanceD(c2[0], c2[1], c2[2]);
    final double hi = l1 >= l2 ? l1 : l2;
    final double lo = l1 >= l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Contrast ratio, UNROUNDED, from 8-bit hex (exact for opaque pairs).
  static double ratioHex(String hex1, String hex2) => ratioChannelsD(
    <double>[_r(hex1).toDouble(), _g(hex1).toDouble(), _b(hex1).toDouble()],
    <double>[_r(hex2).toDouble(), _g(hex2).toDouble(), _b(hex2).toDouble()],
  );

  static int _r(String h) => int.parse(h.substring(1, 3), radix: 16);
  static int _g(String h) => int.parse(h.substring(3, 5), radix: 16);
  static int _b(String h) => int.parse(h.substring(5, 7), radix: 16);

  /// >= 4.5 on the unrounded value. No rounding pass is possible.
  static bool passes45(double ratioUnrounded) => ratioUnrounded >= 4.5;

  /// Flutter alphaBlend semantics in double space (NO 8-bit alpha quantization):
  /// out = a * fg + (1 - a) * bg, per gamma-encoded channel.
  static List<double> blendD(List<double> fgRgba, List<double> bgRgb) {
    final double a = fgRgba[3];
    return <double>[
      a * fgRgba[0] + (1 - a) * bgRgb[0],
      a * fgRgba[1] + (1 - a) * bgRgb[1],
      a * fgRgba[2] + (1 - a) * bgRgb[2],
    ];
  }

  /// Display-layer quantization: 8-bit hex of a composite (round to nearest).
  static String quantHex(List<double> rgb) =>
      '#' +
      rgb
          .map(
            (double v) =>
                v.round().toRadixString(16).toUpperCase().padLeft(2, '0'),
          )
          .join();
}

/// One real measured row from DSN-05 contrast-measurements.csv (opaque pair).
class MeasuredRow {
  final String id, component, theme, fontSize, state, fgHex, bgHex, ratio6dp;
  final bool countedAgainst45; // disabled/historical/candidate rows: false
  final bool expectedPass;

  const MeasuredRow(
    this.id,
    this.component,
    this.theme,
    this.fontSize,
    this.state,
    this.fgHex,
    this.bgHex,
    this.ratio6dp,
    this.countedAgainst45,
    this.expectedPass,
  );
}

/// One alpha-bearing measured row: composite FIRST (unrounded doubles),
/// then measure; quantized hexes cross-check the display layer.
class AlphaChainRow {
  final String id;
  final List<double> fgRgba; // channels 0..255, alpha 0..1 exact
  final List<double> baseRgb; // bottom of the bg stack
  final List<double>? overlayRgba; // optional alpha layer above base
  final String ratio6dp, quantFgHex, quantBgHex;
  final bool countedAgainst45, expectedPass;

  const AlphaChainRow(
    this.id,
    this.fgRgba,
    this.baseRgb,
    this.overlayRgba,
    this.ratio6dp,
    this.quantFgHex,
    this.quantBgHex,
    this.countedAgainst45,
    this.expectedPass,
  );
}

/// Opaque measured rows — composite hex pairs exactly as emitted by the engine.
const List<MeasuredRow> kMeasuredRows = <MeasuredRow>[
  // 普通正文 chat body
  MeasuredRow(
    'R01',
    'chat body',
    'light',
    'standard',
    'default',
    '#000000',
    '#FFFFFF',
    '21.000000',
    true,
    true,
  ),
  MeasuredRow(
    'R03',
    'chat body',
    'dark',
    'standard',
    'default',
    '#F2F2F7',
    '#262629',
    '13.522797',
    true,
    true,
  ),
  MeasuredRow(
    'R05',
    'chat body OLED variant',
    'dark',
    'standard',
    'default-oled-variant',
    '#F2F2F7',
    '#1A1A1A',
    '15.597080',
    true,
    true,
  ),
  // 发送气泡 send bubble
  MeasuredRow(
    'R06',
    'send-bubble text',
    'light',
    'standard',
    'default',
    '#F5F7FA',
    '#2474E5',
    '4.159170',
    true,
    false,
  ),
  MeasuredRow(
    'R08',
    'send-bubble text',
    'dark',
    'standard',
    'default',
    '#F5F7FA',
    '#1D5EC2',
    '5.700855',
    true,
    true,
  ),
  // 历史brand观察值（记录, 不参与裁决）
  MeasuredRow(
    'R10',
    'send bubble historical brand pair',
    'light',
    'baseline17px',
    'historical-observation',
    '#FFFFFF',
    '#2474E5',
    '4.463718',
    false,
    false,
  ),
  MeasuredRow(
    'R11',
    'send bubble historical dark pair',
    'dark',
    'baseline17px',
    'historical-observation',
    '#FFFFFF',
    '#3D8BF0',
    '3.414789',
    false,
    false,
  ),
  // 评审候选（记录, adopted=false）
  MeasuredRow(
    'R12',
    'send bubble review candidate',
    'candidate',
    'standard',
    'review-candidate',
    '#FFFFFF',
    '#1565C0',
    '5.746321',
    false,
    true,
  ),
  // 摘要 dark (opaque fg)
  MeasuredRow(
    'R15',
    'summary text',
    'dark',
    'standard',
    'default',
    '#98989F',
    '#1C1C1E',
    '5.936534',
    true,
    true,
  ),
  // 文字动作 text actions
  MeasuredRow(
    'R21',
    'text action (quote tip title)',
    'light',
    'standard',
    'default',
    '#007AFF',
    '#FFFFFF',
    '4.016976',
    true,
    false,
  ),
  MeasuredRow(
    'R23',
    'text action (quote tip title)',
    'dark',
    'standard',
    'default',
    '#0A84FF',
    '#1C1C1E',
    '4.664802',
    true,
    true,
  ),
  // 断网/错误提示 offline banner (opaque bg, 无dark适配)
  MeasuredRow(
    'R25',
    'offline banner text',
    'light',
    'standard',
    'error',
    '#FF3B30',
    '#F7E2E6',
    '2.867440',
    true,
    false,
  ),
  MeasuredRow(
    'R27',
    'offline banner text (no dark adaptation)',
    'dark',
    'standard',
    'error',
    '#FF3B30',
    '#F7E2E6',
    '2.867440',
    true,
    false,
  ),
  // 选中态 light 接收行在 kAlphaChainRows (S3: bg 为合成值)
  // 禁用态（单列, 仅记录）
  MeasuredRow(
    'D1',
    'disabled text',
    'light',
    'standard',
    'disabled',
    '#C7C7CC',
    '#FFFFFF',
    '1.684080',
    false,
    false,
  ),
  MeasuredRow(
    'D2',
    'disabled text',
    'dark',
    'standard',
    'disabled',
    '#636366',
    '#1C1C1E',
    '2.841564',
    false,
    false,
  ),
];

/// Alpha-bearing measured rows — composite-first on unrounded doubles.
const List<AlphaChainRow> kAlphaChainRows = <AlphaChainRow>[
  // R13/R14 摘要 light: lightTextSecondary.withValues(alpha:0.75) over lightSurface
  AlphaChainRow(
    'R13',
    <double>[60, 60, 67, 0.75],
    <double>[255, 255, 255],
    null,
    '5.163691',
    '#6D6D72',
    '#FFFFFF',
    true,
    true,
  ),
  // R17 置顶行 light: 同fg over lightSurfaceVariant #F9FAFB
  AlphaChainRow(
    'R17',
    <double>[60, 60, 67, 0.75],
    <double>[249, 250, 251],
    null,
    '5.035500',
    '#6B6C71',
    '#F9FAFB',
    true,
    true,
  ),
  // R18 置顶行 dark: darkTextSecondary over alphaBlend(overlayLight a=20/255, darkSurface)
  AlphaChainRow(
    'R18',
    <double>[152, 152, 159, 1.0],
    <double>[28, 28, 30],
    <double>[255, 255, 255, 20 / 255],
    '4.742096',
    '#98989F',
    '#2E2E30',
    true,
    true,
  ),
  // R20 频道行 dark: getTextSecondary(dark).withValues(alpha:0.75) over darkSurface
  AlphaChainRow(
    'R20',
    <double>[152, 152, 159, 0.75],
    <double>[28, 28, 30],
    null,
    '3.932103',
    '#79797F',
    '#1C1C1E',
    true,
    false,
  ),
  // S1 选中态 light 发送: sentMessageText over primary.withValues(alpha:0.2) on scaffold #F2F2F7
  AlphaChainRow(
    'S1',
    <double>[245, 247, 250, 1.0],
    <double>[242, 242, 247],
    <double>[36, 116, 229, 0.2],
    '1.332777',
    '#F5F7FA',
    '#C9D9F3',
    true,
    false,
  ),
  // S2 选中态 dark 发送: 同fg over primary.withValues(alpha:0.3) on scaffold #1C1C1E
  AlphaChainRow(
    'S2',
    <double>[245, 247, 250, 1.0],
    <double>[28, 28, 30],
    <double>[36, 116, 229, 0.3],
    '11.257330',
    '#F5F7FA',
    '#1E365A',
    true,
    true,
  ),
  // S3 选中态 light 接收: lightTextPrimary over primary.withValues(alpha:0.2) on scaffold #F2F2F7
  AlphaChainRow(
    'S3',
    <double>[0, 0, 0, 1.0],
    <double>[242, 242, 247],
    <double>[36, 116, 229, 0.2],
    '14.681546',
    '#000000',
    '#C9D9F3',
    true,
    true,
  ),
];

/// 负控组合：全部真实低于 4.5:1，检查器必须逐一拒绝。
/// 第一行就是评审稿声称 4.4637:1 的历史 brand 色对（白字 on #2474E5）。
const List<List<String>> kBelowThresholdPairs = <List<String>>[
  <String>[
    '#FFFFFF',
    '#2474E5',
    '4.463718',
    'R10 — THE 4.4637 pair (historical brand observation)',
  ],
  <String>['#F5F7FA', '#2474E5', '4.159170', 'R06 — current light send bubble'],
  <String>[
    '#FFFFFF',
    '#3D8BF0',
    '3.414789',
    'R11 — retired dark bubble (historical)',
  ],
  <String>[
    '#007AFF',
    '#FFFFFF',
    '4.016976',
    'R21 — light text action (iOS blue)',
  ],
  <String>['#FF3B30', '#F7E2E6', '2.867440', 'R25 — offline banner text'],
  <String>[
    '#C7C7CC',
    '#FFFFFF',
    '1.684080',
    'D1 — disabled text (recorded, exempt from 4.5 verdict)',
  ],
  <String>[
    '#636366',
    '#1C1C1E',
    '2.841564',
    'D2 — disabled text (recorded, exempt from 4.5 verdict)',
  ],
];

void main() {
  group('DSN-05 negative control — contrast checker must not fake-pass', () {
    test('sanity: black on white == 21.0 exactly (known-pair precision)', () {
      final double r = Dsn05ContrastChecker.ratioHex('#000000', '#FFFFFF');
      expect(r, closeTo(21.0, 1e-9));
      expect(Dsn05ContrastChecker.passes45(r), isTrue);
    });

    test('sanity: ratio is fg/bg symmetric', () {
      expect(
        Dsn05ContrastChecker.ratioHex('#F5F7FA', '#2474E5'),
        closeTo(Dsn05ContrastChecker.ratioHex('#2474E5', '#F5F7FA'), 1e-12),
      );
    });

    test('THE 4.4637 pair: #FFFFFF on #2474E5 computes 4.4637 and MUST be rejected', () {
      final double r = Dsn05ContrastChecker.ratioHex('#FFFFFF', '#2474E5');
      // 评审稿 (UI-01 source_fact) 声称 4.4637:1 — 本检查器复现该值
      expect(r.toStringAsFixed(4), '4.4637');
      expect(r, lessThan(4.5));
      expect(
        Dsn05ContrastChecker.passes45(r),
        isFalse,
        reason: '4.4637 < 4.5 unrounded — 不因四舍五入通过',
      );
    });

    test('negative probe: a 1-decimal rounding check WOULD fake-pass 4.4637; ours does not', () {
      final double r = Dsn05ContrastChecker.ratioHex('#FFFFFF', '#2474E5');
      // 暴露伪通过路径：四舍五入到 1 位小数后 >= 4.5
      final bool naiveRoundedPass = double.parse(r.toStringAsFixed(1)) >= 4.5;
      expect(
        naiveRoundedPass,
        isTrue,
        reason: 'premise: rounded check is exactly the false-pass path',
      );
      // 我们的未舍入检查必须拒绝
      expect(Dsn05ContrastChecker.passes45(r), isFalse);
    });

    test('every below-threshold combo is REJECTED by the checker', () {
      for (final List<String> p in kBelowThresholdPairs) {
        final double r = Dsn05ContrastChecker.ratioHex(p[0], p[1]);
        expect(
          r,
          lessThan(4.5),
          reason: '${p[3]}: ${r.toStringAsFixed(6)} must be < 4.5',
        );
        expect(
          Dsn05ContrastChecker.passes45(r),
          isFalse,
          reason: '${p[3]} (${p[0]} on ${p[1]}) must NOT pass 4.5',
        );
        expect(
          r.toStringAsFixed(6),
          p[2],
          reason: '${p[3]}: cross-implementation agreement with Python engine',
        );
      }
    });

    test('composite FIRST: unrounded alpha chains reproduce engine ratios and quantized hexes', () {
      for (final AlphaChainRow row in kAlphaChainRows) {
        // bg 链: 底层 base, 可选 overlay alpha 层
        final List<double> bg = row.overlayRgba == null
            ? row.baseRgb
            : Dsn05ContrastChecker.blendD(row.overlayRgba!, row.baseRgb);
        // fg 若带 alpha 则合成于最终 bg 之上
        final List<double> fg = row.fgRgba[3] == 1.0
            ? row.fgRgba.sublist(0, 3)
            : Dsn05ContrastChecker.blendD(row.fgRgba, bg);
        final double r = Dsn05ContrastChecker.ratioChannelsD(fg, bg);
        expect(
          r.toStringAsFixed(6),
          row.ratio6dp,
          reason: '${row.id}: unrounded composite ratio drift vs engine',
        );
        expect(
          Dsn05ContrastChecker.quantHex(fg),
          row.quantFgHex,
          reason: '${row.id}: quantized fg hex vs engine composite_fg_hex',
        );
        expect(
          Dsn05ContrastChecker.quantHex(bg),
          row.quantBgHex,
          reason: '${row.id}: quantized bg hex vs engine composite_bg_hex',
        );
        if (row.countedAgainst45) {
          expect(
            Dsn05ContrastChecker.passes45(r),
            row.expectedPass,
            reason: '${row.id} verdict must match CSV threshold_4_5_pass',
          );
        }
      }
    });

    test('real measured rows: per-row honest verdicts matching the CSV', () {
      for (final MeasuredRow row in kMeasuredRows) {
        final double r = Dsn05ContrastChecker.ratioHex(row.fgHex, row.bgHex);
        expect(
          r.toStringAsFixed(6),
          row.ratio6dp,
          reason: '${row.id} ratio drift vs CSV',
        );
        if (!row.countedAgainst45)
          continue; // disabled/historical/candidate: recorded only
        expect(
          Dsn05ContrastChecker.passes45(r),
          row.expectedPass,
          reason:
              '${row.id} (${row.component}) verdict must match CSV threshold_4_5_pass',
        );
      }
    });

    test('honest dark-secondary evaluation: NOT all dark secondary rows fail', () {
      // R15 (opaque dark secondary #98989F on #1C1C1E) passes;
      // R20 (same token with extra alpha 0.75 stacked) fails.
      final double r15 = Dsn05ContrastChecker.ratioHex('#98989F', '#1C1C1E');
      final AlphaChainRow r20 = kAlphaChainRows[3]; // R20
      expect(
        Dsn05ContrastChecker.passes45(r15),
        isTrue,
        reason: 'R15 = ${r15.toStringAsFixed(6)} — passing dark secondary row',
      );
      final double bgR = Dsn05ContrastChecker.ratioChannelsD(
        Dsn05ContrastChecker.blendD(r20.fgRgba, r20.baseRgb),
        r20.baseRgb,
      );
      expect(
        Dsn05ContrastChecker.passes45(bgR),
        isFalse,
        reason:
            'R20 = ${bgR.toStringAsFixed(6)} — failing dark secondary row (alpha-stacked)',
      );
      expect(
        Dsn05ContrastChecker.passes45(r15),
        isNot(Dsn05ContrastChecker.passes45(bgR)),
      );
    });

    test('review candidate #1565C0 + white: 5.746321 passes AA numerically yet adopted=false', () {
      final double r = Dsn05ContrastChecker.ratioHex('#FFFFFF', '#1565C0');
      expect(r.toStringAsFixed(6), '5.746321');
      expect(
        Dsn05ContrastChecker.passes45(r),
        isTrue,
        reason: '数值达标只是必要条件 — 仍仅为评审候选, 不视为已批准气泡色',
      );
    });
  });
}
