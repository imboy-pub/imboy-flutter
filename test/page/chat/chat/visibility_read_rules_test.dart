/// Characterization tests for [normalizeVisibilityFraction] and
/// [normalizeVisibilityDelayMs].
///
/// slice-C-5: L2110-2119 的内联 IIFE 把 UserSetting 字段
/// `visibilityReadFraction` / `visibilityReadDelayMs` 归一化为安全值。
/// 存在 NaN / 超范围 / 零负数 三类边界，全是魔法常数（0.6 / 0.1 / 1.0 / 400），
/// 目前零测试覆盖。提取为纯函数后可注入原始值单测钉死。
///
/// 契约（钉死）：
///   normalizeVisibilityFraction：
///     - NaN → 0.6（默认比例）
///     - < 0.1 → 0.1（最小可用阈值）
///     - > 1.0 → 1.0（最大有效比例）
///     - [0.1, 1.0] → 原值
///   normalizeVisibilityDelayMs：
///     - <= 0 → 400（默认延迟）
///     - > 0  → 原值
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/visibility_read_rules.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // normalizeVisibilityFraction
  // ─────────────────────────────────────────────────────────
  group('normalizeVisibilityFraction', () {
    // NaN 守卫
    test('NaN → 0.6（默认阈值）', () {
      expect(normalizeVisibilityFraction(double.nan), 0.6);
    });

    // 下界
    test('0.0 → 0.1（低于最小值 clamp 到 0.1）', () {
      expect(normalizeVisibilityFraction(0.0), 0.1);
    });

    test('0.05 → 0.1（仍低于 0.1）', () {
      expect(normalizeVisibilityFraction(0.05), 0.1);
    });

    test('恰好 0.1 → 0.1（边界值保留）', () {
      expect(normalizeVisibilityFraction(0.1), 0.1);
    });

    // 上界
    test('1.5 → 1.0（高于 1.0 clamp）', () {
      expect(normalizeVisibilityFraction(1.5), 1.0);
    });

    test('恰好 1.0 → 1.0（边界值保留）', () {
      expect(normalizeVisibilityFraction(1.0), 1.0);
    });

    // 正常范围
    test('0.6 → 0.6（区间内原样返回）', () {
      expect(normalizeVisibilityFraction(0.6), 0.6);
    });

    test('0.5 → 0.5（区间内原样返回）', () {
      expect(normalizeVisibilityFraction(0.5), 0.5);
    });

    // 负数
    test('负数 → 0.1（低于 0.1）', () {
      expect(normalizeVisibilityFraction(-0.5), 0.1);
    });

    // infinity
    test('正无穷 → 1.0', () {
      expect(normalizeVisibilityFraction(double.infinity), 1.0);
    });

    test('负无穷 → 0.1', () {
      expect(normalizeVisibilityFraction(double.negativeInfinity), 0.1);
    });
  });

  // ─────────────────────────────────────────────────────────
  // normalizeVisibilityDelayMs
  // ─────────────────────────────────────────────────────────
  group('normalizeVisibilityDelayMs', () {
    test('0 → 400（零值 → 默认延迟）', () {
      expect(normalizeVisibilityDelayMs(0), 400);
    });

    test('负数 → 400', () {
      expect(normalizeVisibilityDelayMs(-1), 400);
      expect(normalizeVisibilityDelayMs(-9999), 400);
    });

    test('正数原样返回', () {
      expect(normalizeVisibilityDelayMs(300), 300);
      expect(normalizeVisibilityDelayMs(1000), 1000);
      expect(normalizeVisibilityDelayMs(1), 1);
    });
  });
}
