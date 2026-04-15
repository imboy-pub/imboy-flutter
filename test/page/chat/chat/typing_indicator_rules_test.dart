/// Characterization tests for [decideTypingIndicator].
///
/// slice-C-2 (TDD): `_handleInputChanged` 当前混杂 Timer 副作用 + `_sendTypingStatus`
/// IO 调用 + 节流判定，且零测试覆盖。本套件钉死：
///   - 3 秒节流窗口契约
///   - text 空 → stop 优先（即便 lastSentAt 刚写入）
///   - lastSentAt=null 视作"首次输入"
///   - 窗口边界（==3s 算已过）
///
/// **不依赖**：Widget / Timer / WebSocket。纯 Dart 决策。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/typing_indicator_rules.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);

  group('text 为空 → TypingStopImmediately', () {
    test('空字符串 + lastSentAt=null → stop', () {
      final d = decideTypingIndicator(
        text: '',
        lastSentAt: null,
        now: base,
      );
      expect(d, isA<TypingStopImmediately>());
    });

    test('空字符串 + lastSentAt 刚写入 → 仍然 stop（空优先）', () {
      final d = decideTypingIndicator(
        text: '',
        lastSentAt: base.subtract(const Duration(milliseconds: 10)),
        now: base,
      );
      expect(d, isA<TypingStopImmediately>());
    });
  });

  group('lastSentAt=null → TypingStartAndResetIdle', () {
    test('首次输入（任意非空文本）→ start，newLastSentAt == now', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: null,
        now: base,
      );
      expect(d, isA<TypingStartAndResetIdle>());
      expect((d as TypingStartAndResetIdle).newLastSentAt, base);
    });
  });

  group('节流窗口内 → TypingResetIdleOnly', () {
    test('2.9 秒前已发 → 窗口内，仅重置 idle', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(milliseconds: 2900)),
        now: base,
      );
      expect(d, isA<TypingResetIdleOnly>());
    });

    test('刚刚（0ms 前）已发 → 窗口内', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base,
        now: base,
      );
      expect(d, isA<TypingResetIdleOnly>());
    });
  });

  group('节流窗口边界（默认 3s）', () {
    test('2999ms 前 → 窗口内（resetIdleOnly）', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(milliseconds: 2999)),
        now: base,
      );
      expect(d, isA<TypingResetIdleOnly>());
    });

    test('3000ms 前 → 窗口内（>，严格超过才越界；契约钉死）', () {
      // 当前实现 `now.difference(last) > 3s` 严格大于,等于 3s 仍在窗口内
      // 与既有 `_handleInputChanged` 行为一致
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(milliseconds: 3000)),
        now: base,
      );
      expect(d, isA<TypingResetIdleOnly>());
    });

    test('3001ms 前 → 越界 → start', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(milliseconds: 3001)),
        now: base,
      );
      expect(d, isA<TypingStartAndResetIdle>());
      expect((d as TypingStartAndResetIdle).newLastSentAt, base);
    });
  });

  group('自定义 throttle 参数', () {
    test('throttle=1s + 1.5s 前 → 越界 → start', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(milliseconds: 1500)),
        now: base,
        throttle: const Duration(seconds: 1),
      );
      expect(d, isA<TypingStartAndResetIdle>());
    });

    test('throttle=10s + 5s 前 → 窗口内 → resetIdleOnly', () {
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: base.subtract(const Duration(seconds: 5)),
        now: base,
        throttle: const Duration(seconds: 10),
      );
      expect(d, isA<TypingResetIdleOnly>());
    });
  });

  group('newLastSentAt 语义（start 分支始终回传传入的 now）', () {
    test('越界场景回传 now（即便 lastSentAt 非 null）', () {
      final long = base.subtract(const Duration(hours: 1));
      final d = decideTypingIndicator(
        text: 'hi',
        lastSentAt: long,
        now: base,
      );
      expect((d as TypingStartAndResetIdle).newLastSentAt, base);
    });
  });

  group('空白字符与非空字符契约', () {
    test("只含空格的文本被视为'非空'（与当前 text.isEmpty 语义一致）", () {
      // 钉死当前实现:用 `text.isEmpty` 判空,不 trim
      // 若未来想把"仅空格"视作"未输入",需显式改代码
      final d = decideTypingIndicator(
        text: '   ',
        lastSentAt: null,
        now: base,
      );
      expect(d, isA<TypingStartAndResetIdle>());
    });
  });
}
