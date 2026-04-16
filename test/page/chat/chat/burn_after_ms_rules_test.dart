/// Characterization tests for [parseBurnAfterMs].
///
/// slice-C-9: `chat_page.dart` L472-478 内联的 `burn_after_ms` 字段解析
/// ```dart
/// final raw = payload?['burn_after_ms'];
/// if (raw is int && raw > 0) {
///   _burnAfterMs = raw;
/// } else if (raw is String) {
///   final v = int.tryParse(raw);
///   if (v != null && v > 0) _burnAfterMs = v;
/// }
/// ```
/// 仅接受 > 0 的正整数，否则保留调用方的默认值（此处返回 null 表示"不更新"）。
///
/// 契约（钉死）：
///   - raw 为正 int → 返回该值
///   - raw 为 0 → null（不视为有效时长）
///   - raw 为负 int → null
///   - raw 为正 String 数字 → 返回解析值
///   - raw 为 "0" → null
///   - raw 为负 String 数字 → null
///   - raw 为非数字 String → null
///   - raw 为 null → null
///   - raw 为 double → null（不视为 int）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/burn_after_ms_rules.dart';

void main() {
  group('parseBurnAfterMs', () {
    test('正 int → 返回原值', () {
      expect(parseBurnAfterMs(5000), 5000);
    });

    test('int 0 → null（不接受零时长）', () {
      expect(parseBurnAfterMs(0), isNull);
    });

    test('负 int → null', () {
      expect(parseBurnAfterMs(-1), isNull);
    });

    test('正 String 数字 → 解析返回', () {
      expect(parseBurnAfterMs('3000'), 3000);
    });

    test('String "0" → null', () {
      expect(parseBurnAfterMs('0'), isNull);
    });

    test('负 String 数字 → null', () {
      expect(parseBurnAfterMs('-500'), isNull);
    });

    test('非数字 String → null', () {
      expect(parseBurnAfterMs('abc'), isNull);
    });

    test('null 值 → null', () {
      expect(parseBurnAfterMs(null), isNull);
    });

    test('double 值 → null（非 int 类型）', () {
      expect(parseBurnAfterMs(3000.5), isNull);
    });

    test('bool 值 → null', () {
      expect(parseBurnAfterMs(true), isNull);
    });
  });
}
