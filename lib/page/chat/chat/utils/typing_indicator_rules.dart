/// Typing indicator 节流决策 —— 纯函数(零外部依赖)
///
/// slice-C-2:从 `chat_page.dart:_handleInputChanged` 抽出决策内核,
/// 将 Timer/WebSocket IO 与节流判定解耦,让契约(3 秒节流 / 空文本立即停止)
/// 可被单测钉死。
///
/// 行为契约(见 typing_indicator_rules_test.dart):
///   - text 为空 → 立刻 stop,**压过** lastSentAt 的新鲜度判断
///   - lastSentAt=null + 非空文本 → start + 回传 newLastSentAt=now
///   - 节流窗口内(`now - lastSentAt <= throttle`) → 仅重置 idle 定时器
///   - 节流窗口外 → start + 回传 newLastSentAt=now
///
/// **注意**:空白字符(如 `'   '`)按当前实现视作"非空",与原 `text.isEmpty` 一致。
library;

sealed class TypingDecision {
  const TypingDecision();
}

/// 输入为空 → 立刻停止 typing。
final class TypingStopImmediately extends TypingDecision {
  const TypingStopImmediately();
}

/// 首次或节流窗口过后 → 发送 start,并返回应写入的新 lastSentAt 时戳,
/// 调用方同时需重置 idle 定时器。
final class TypingStartAndResetIdle extends TypingDecision {
  const TypingStartAndResetIdle(this.newLastSentAt);
  final DateTime newLastSentAt;
}

/// 节流窗口内 → 不发 start,但重置 idle 定时器(延长停止的触发时间)。
final class TypingResetIdleOnly extends TypingDecision {
  const TypingResetIdleOnly();
}

/// 决策纯函数。
///
/// - [text] 当前输入框内容
/// - [lastSentAt] 上次发出 typing.start 的时戳(未发过传 `null`)
/// - [now] 当前时戳(注入以便单测 fake 时间)
/// - [throttle] 节流窗口,默认 3 秒
TypingDecision decideTypingIndicator({
  required String text,
  required DateTime? lastSentAt,
  required DateTime now,
  Duration throttle = const Duration(seconds: 3),
}) {
  if (text.isEmpty) {
    return const TypingStopImmediately();
  }
  if (lastSentAt == null || now.difference(lastSentAt) > throttle) {
    return TypingStartAndResetIdle(now);
  }
  return const TypingResetIdleOnly();
}
