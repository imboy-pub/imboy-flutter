/// T05.a 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest，全部不得 skip）：
///  1. golden_font_has_required_cjk_glyphs
///  2. golden_rejects_ahem_or_missing_font
///  3. golden_environment_hash_changes_on_font_sdk_change
///  4. fixture_emojis_have_explicit_policy
///  5. golden_missing_font_is_visual_blocked_only
library;

import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';

import '../support/golden_font_loader.dart';

/// 合成字体字节：非 TrueType 魔数，仅用于"缺字体/hash 不匹配"分支。
final Uint8List fakeFontBytes = Uint8List.fromList(<int>[0, 1, 2, 3]);

void main() {
  test('golden_font_has_required_cjk_glyphs：登记字体覆盖全部必需 CJK 码点', () async {
    final GoldenFontResolution r = resolveGoldenFont();
    // 本机探测登记了 Arial Unicode；换机器缺字体时此用例按 VISUAL_BLOCKED
    // 语义允许失败前置——但 CI/本开发机必须有字体证据，故直接断言 ok。
    expect(
      r.status,
      GoldenFontStatus.ok,
      reason: '开发机必须具备登记字体；缺字体环境见 GOLDEN_ENV.md 第 4 节',
    );
    expect(r.asset, isNotNull);
    final String? missing = missingRequiredGlyphs(
      File(r.asset!.path).readAsBytesSync(),
    );
    expect(missing, isNull, reason: '必需 CJK 码点必须全部有非 0 glyph id');
    // 真实可渲染性：FontLoader 注册成功（字节可被引擎解析）。
    await loadGoldenFont(r);
  });

  test('golden_rejects_ahem_or_missing_font：hash 不匹配或缺失一律拒绝', () {
    // Ahem/被替换字体场景：路径真实但 hash 不是登记值 → 拒绝。
    final GoldenFontAsset wrongHash = GoldenFontAsset(
      path: kGoldenFontAssets.first.path,
      sha256Hex: '0' * 64,
      licenseNote: 'synthetic negative case (simulated tamper/Ahem)',
    );
    final GoldenFontResolution tampered = resolveGoldenFontFromAssets(
      <GoldenFontAsset>[wrongHash],
    );
    expect(tampered.status, GoldenFontStatus.visualBlocked);
    expect(tampered.reason, contains('hash mismatch'));
    expect(goldenVisualAllowed(tampered), isFalse);

    // 字体缺失场景：路径不存在 → 拒绝（非异常）。
    final GoldenFontAsset absent = GoldenFontAsset(
      path: '/nonexistent/UiuxFake.ttf',
      sha256Hex: 'a' * 64,
      licenseNote: 'synthetic negative case (missing file)',
    );
    final GoldenFontResolution missing = resolveGoldenFontFromAssets(
      <GoldenFontAsset>[absent],
    );
    expect(missing.status, GoldenFontStatus.visualBlocked);
    expect(goldenVisualAllowed(missing), isFalse);
  });

  test(
    'golden_environment_hash_changes_on_font_sdk_change：字体或 SDK 变化改变环境 hash',
    () {
      final GoldenFontResolution ok = resolveGoldenFont();
      final GoldenFontResolution other = GoldenFontResolution(
        status: GoldenFontStatus.ok,
        asset: GoldenFontAsset(
          path: '/synthetic/other.ttf',
          sha256Hex: 'b' * 64,
          licenseNote: 'synthetic positive case (different registered font)',
        ),
        fontBytes: null,
        reason: 'ok',
      );
      final String base = goldenEnvironmentHash(resolution: ok);
      // 换字体
      expect(goldenEnvironmentHash(resolution: other), isNot(base));
      // 换 SDK 版本钉
      expect(
        goldenEnvironmentHash(resolution: ok, flutterVersion: '9.9.9'),
        isNot(base),
      );
      // 换 DPR / locale 同样改变（栅格环境一致性）
      expect(
        goldenEnvironmentHash(resolution: ok, devicePixelRatio: 2.0),
        isNot(base),
      );
      expect(
        goldenEnvironmentHash(resolution: ok, locale: 'en-US'),
        isNot(base),
      );
    },
  );

  test('fixture_emojis_have_explicit_policy：emoji 策略显式登记', () {
    expect(kEmojiPolicy, isNotEmpty);
    expect(kEmojiPolicy, startsWith('forbidden-in-golden-fixtures'));
    // 策略针对的样例码点必须非空且都被策略明示覆盖
    expect(kKnownEmojiSampleCodepoints, isNotEmpty);
    for (final int cp in kKnownEmojiSampleCodepoints) {
      // 超出登记字体承诺的 BMP CJK 覆盖（>0xFFFF 或符号区），正是
      // 依赖系统 fallback 的不可复现字形 —— 与策略理由一致。
      final bool outsideBmpCjkPromise =
          cp > 0xFFFF || (cp >= 0x2600 && cp <= 0x27BF);
      expect(
        outsideBmpCjkPromise,
        isTrue,
        reason: '样例 U+${cp.toRadixString(16)} 应属于系统 fallback 字形',
      );
    }
  });

  test('golden_missing_font_is_visual_blocked_only：缺字体只阻塞视觉、不影响结构', () {
    final GoldenFontResolution blocked = resolveGoldenFontFromAssets(
      <GoldenFontAsset>[
        GoldenFontAsset(
          path: '/nonexistent/UiuxFake.ttf',
          sha256Hex: 'c' * 64,
          licenseNote: 'synthetic blocked case',
        ),
      ],
    );
    expect(blocked.status, GoldenFontStatus.visualBlocked);
    // 不抛异常、不产生字体字节，视觉被拒
    expect(goldenVisualAllowed(blocked), isFalse);
    expect(blocked.fontBytes, isNull);
    // 环境 hash 在缺字体时仍可计算（登记 none），供状态记录用
    expect(goldenEnvironmentHash(resolution: blocked), isNotEmpty);
    // 结构测试入口不触碰本文件：这里只验证契约——缺字体 resolution
    // 不携带任何可让非视觉测试误用的东西
    expect(
      () => loadGoldenFont(blocked),
      throwsStateError,
      reason: '非 ok resolution 不得进入 FontLoader（契约错误即抛）',
    );
  });
}
