/// QR 登录 Notifier 状态转换决策器（零外部依赖纯函数）。
///
/// 抽出 `lib/page/passport/web_login_page.dart` 的 `QRLogin` Notifier 中
/// 三个决策面（轮询 tick / 倒计时 tick / token 落地），便于：
///   - 单元测试覆盖状态转换矩阵（无需 fake_async / Riverpod / HTTP）
///   - Notifier 保留 Timer + HTTP 副作用，纯决策抽出
///
/// 设计：所有决策器**不**含 i18n 文案 / 副作用 / 类型转换；i18n 由调用方根据
/// sealed case 自行映射，保持纯函数特性（dart/coding-style.md 第 7 节）。
library;

import 'package:imboy/page/passport/qr_login_response_rules.dart';

// ---------------------------------------------------------------------------
// PollingDecision: derivePollingDecision 结果
// ---------------------------------------------------------------------------

/// 轮询 tick 决策（sealed）。调用方接收 case 后执行 Timer / Notifier 副作用。
sealed class PollingDecision {
  const PollingDecision();
}

/// 继续轮询，不改 state（`waiting` 或可忽略的 `unknown`）。
final class KeepPolling extends PollingDecision {
  const KeepPolling();
}

/// 转入 `scanned` 状态，继续轮询等待 confirmed。
final class TransitionToScanned extends PollingDecision {
  const TransitionToScanned();
}

/// 收到合法 `confirmed + token`，调用方应转 `confirming` 并落地 token。
final class RequestCompleteLogin extends PollingDecision {
  const RequestCompleteLogin(this.token);
  final String token;
}

/// 转入 `expired`，停止轮询。
final class TransitionToExpired extends PollingDecision {
  const TransitionToExpired();
}

/// 转入 `waiting` 并触发 `generateQRCode()` 重生 QR（cancelled 路径）。
final class TransitionToCancelledThenRefresh extends PollingDecision {
  const TransitionToCancelledThenRefresh();
}

/// 协议违反（如 `confirmed` 但 token 为空）。调用方转 `failed` + i18n + 停止轮询。
final class ProtocolViolation extends PollingDecision {
  const ProtocolViolation();
}

/// 静默停止轮询（HTTP 错误 / sessionToken 缺失）。
final class StopSilently extends PollingDecision {
  const StopSilently();
}

/// 轮询 tick 决策器。
///
/// **关键守卫**：sessionToken null/空 → StopSilently（对齐 web_login_page.dart:143
/// 的 `if (state.sessionToken == null) timer.cancel()`）。
PollingDecision derivePollingDecision({
  required String? sessionToken,
  required QrStatusEvent event,
}) {
  // 守卫优先：sessionToken 缺失 → 静默停止，无论 event 是什么。
  if (sessionToken == null || sessionToken.isEmpty) {
    return const StopSilently();
  }
  return switch (event) {
    QrStatusStopPolling() => const StopSilently(),
    QrStatusWaiting() => const KeepPolling(),
    QrStatusScanned() => const TransitionToScanned(),
    QrStatusConfirmed(:final token) => RequestCompleteLogin(token),
    QrStatusExpired() => const TransitionToExpired(),
    QrStatusCancelled() => const TransitionToCancelledThenRefresh(),
    QrStatusUnknown(:final rawStatus) => rawStatus == 'confirmed'
        ? const ProtocolViolation()
        : const KeepPolling(),
  };
}

// ---------------------------------------------------------------------------
// ExpireTickDecision: deriveExpireTickDecision 结果
// ---------------------------------------------------------------------------

/// 倒计时 tick 决策（sealed）。
sealed class ExpireTickDecision {
  const ExpireTickDecision();
}

/// 减 1 秒，新值 = `newRemainingSeconds`（保证 ≥ 0）。
final class DecrementRemaining extends ExpireTickDecision {
  const DecrementRemaining(this.newRemainingSeconds);
  final int newRemainingSeconds;
}

/// 倒计时归零，转 `expired` 并停止 timer。
final class MarkExpired extends ExpireTickDecision {
  const MarkExpired();
}

/// 倒计时 tick 决策器。
///
/// **关键守卫**：`remainingSeconds <= 0` → `MarkExpired`（对齐 web_login_page.dart:203）；
/// 防御负数（如外部 state 异常）。
ExpireTickDecision deriveExpireTickDecision({
  required int remainingSeconds,
}) {
  if (remainingSeconds <= 0) {
    return const MarkExpired();
  }
  return DecrementRemaining(remainingSeconds - 1);
}

// ---------------------------------------------------------------------------
// CompleteLoginDecision: deriveCompleteLoginDecision 结果
// ---------------------------------------------------------------------------

/// Token 落地决策（sealed）。
sealed class CompleteLoginDecision {
  const CompleteLoginDecision();
}

/// Token 无效（null / 空字符串），调用方转 `failed` + i18n。
final class RejectInvalidToken extends CompleteLoginDecision {
  const RejectInvalidToken();
}

/// Token 有效，调用方应调 `SecureTokenStorageService.saveToken`。
final class ProceedWithToken extends CompleteLoginDecision {
  const ProceedWithToken(this.token);
  final String token;
}

/// Token 落地决策器。
///
/// **守卫语义**：与 web_login_page.dart:214 一致 — 仅 `token == null || token.isEmpty`
/// 视为无效；**不 trim 空白**（保留原 Notifier 行为，避免引入语义漂移）。
CompleteLoginDecision deriveCompleteLoginDecision({
  required String? token,
}) {
  if (token == null || token.isEmpty) {
    return const RejectInvalidToken();
  }
  return ProceedWithToken(token);
}
