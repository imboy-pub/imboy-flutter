/// Characterization tests for [parseBurnReadAtMs].
///
/// slice-C-8: `chat_page.dart` L2028-2032 内联的 `burn_read_at` 字段类型安全解析
/// ```dart
/// (message.metadata?['burn_read_at'] is int)
///     ? message.metadata!['burn_read_at'] as int
///     : int.tryParse('${message.metadata?['burn_read_at'] ?? 0}') ?? 0
/// ```
/// 依赖 `Map<String, dynamic>? metadata` 单一输入，零 Widget 依赖，
/// 可独立单测钉死所有类型分支与边界契约。
///
/// 契约（钉死）：
///   - metadata 为 null → 0
///   - burn_read_at 键缺失 → 0
///   - burn_read_at 为 int → 原值
///   - burn_read_at 为 String 数字 → 解析为 int
///   - burn_read_at 为 String 非数字 → 0
///   - burn_read_at 为 double → 0（非 int 且 tryParse 失败）
///   - burn_read_at 为 0 → 0
///   - burn_read_at 为负数 → 原值（不做范围限制，调用方决定语义）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/burn_read_at_rules.dart';

void main() {
  group('parseBurnReadAtMs', () {
    test('metadata 为 null → 0', () {
      expect(parseBurnReadAtMs(null), 0);
    });

    test('metadata 空 Map（键缺失）→ 0', () {
      expect(parseBurnReadAtMs({}), 0);
    });

    test('burn_read_at 为 int 正值 → 原值', () {
      expect(parseBurnReadAtMs({'burn_read_at': 1713000000000}), 1713000000000);
    });

    test('burn_read_at 为 int 0 → 0', () {
      expect(parseBurnReadAtMs({'burn_read_at': 0}), 0);
    });

    test('burn_read_at 为负 int → 原值（不做范围限制）', () {
      expect(parseBurnReadAtMs({'burn_read_at': -1}), -1);
    });

    test('burn_read_at 为 String 数字 → 解析为 int', () {
      expect(parseBurnReadAtMs({'burn_read_at': '1713000000000'}), 1713000000000);
    });

    test('burn_read_at 为 String "0" → 0', () {
      expect(parseBurnReadAtMs({'burn_read_at': '0'}), 0);
    });

    test('burn_read_at 为 String 非数字 → 0', () {
      expect(parseBurnReadAtMs({'burn_read_at': 'invalid'}), 0);
    });

    test('burn_read_at 为 double → 0（不视为 int，tryParse 也失败）', () {
      expect(parseBurnReadAtMs({'burn_read_at': 1713000000000.5}), 0);
    });

    test('burn_read_at 为 null 值 → 0', () {
      expect(parseBurnReadAtMs({'burn_read_at': null}), 0);
    });
  });
}
