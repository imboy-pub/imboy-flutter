/// QR 登录 SSE 帧解析 + 降级决策（PR-4α 纯函数）。
///
/// 锚定后端 `imboy/src/api/qr_login_sse_handler.erl` 的输出格式：
///   - 每帧形如 `data: {"status":"...","token":"..."}\n\n`
///   - status ∈ {waiting, scanned, confirmed, expired, cancelled}
///   - 仅 confirmed 时附 token
///
/// 复用 PR-3 sealed `QrStatusEvent`（同 web_login_page Notifier 决策语义），
/// 让 SSE 路径与轮询路径共用 `derivePollingDecision`，避免双套状态机漂移。
library;

import 'dart:convert';

import 'package:imboy/page/passport/qr_login_response_rules.dart';

// ---------------------------------------------------------------------------
// parseSseFrame: 解析单帧 SSE 文本 → QrStatusEvent
// ---------------------------------------------------------------------------

/// 解析 SSE `data:` 行，返回与 `parseQrStatusResponse` 同构的 `QrStatusEvent`。
///
/// 容错策略（与轮询解析层一致）：
///   - 非 `data:` 前缀 / JSON 解析失败 / 空帧 → [QrStatusStopPolling]
///     调用方收到此值应停止订阅并切回轮询（同 web_login_page:166 行为）
///   - confirmed 但 token 缺失/空白 → [QrStatusUnknown]('confirmed')
///     由 derivePollingDecision 升级为 ProtocolViolation
///   - 未知 status → [QrStatusUnknown](rawStatus 透传)
///
/// 不处理多帧拼接 / SSE id / event 字段：后端只发单行 data，简化解析。
/// 多帧拼接由调用方按 `\n\n` 切分后逐帧调用本函数。
QrStatusEvent parseSseFrame(String rawFrame) {
  if (rawFrame.isEmpty) return const QrStatusStopPolling();
  // SSE 规范：以 ":" 开头是 comment / heartbeat，不是 event
  if (rawFrame.startsWith(':')) return const QrStatusStopPolling();
  if (!rawFrame.startsWith('data:')) return const QrStatusStopPolling();

  // 提取 data: 之后的 JSON 部分（兼容 "data:" 与 "data: " 两种风格）
  final jsonPart = rawFrame.substring(5).trimLeft();
  if (jsonPart.isEmpty) return const QrStatusStopPolling();

  final dynamic decoded;
  try {
    decoded = json.decode(jsonPart);
  } catch (_) {
    return const QrStatusStopPolling();
  }
  if (decoded is! Map) return const QrStatusStopPolling();

  final status = decoded['status'];
  if (status is! String) return QrStatusUnknown(status?.toString());

  switch (status) {
    case 'waiting':
      return const QrStatusWaiting();
    case 'scanned':
      return const QrStatusScanned();
    case 'expired':
      return const QrStatusExpired();
    case 'cancelled':
      return const QrStatusCancelled();
    case 'confirmed':
      final token = decoded['token'];
      if (token is String && token.trim().isNotEmpty) {
        return QrStatusConfirmed(token);
      }
      // confirmed 但 token 缺失：协议违反，由 derivePollingDecision 升级处理
      return const QrStatusUnknown('confirmed');
    default:
      return QrStatusUnknown(status);
  }
}

// ---------------------------------------------------------------------------
// shouldFallbackToPolling: SSE 失败时是否降级到 2 秒轮询
// ---------------------------------------------------------------------------

/// SSE 降级决策（sealed 风格但布尔够用）。
///
/// 触发降级条件（任一）：
///   - `sseAttemptFailed == true`：EventSource 连接异常 / 立刻断开
///   - `!sseConnected && silentSeconds >= gracePeriodSeconds`：超过宽限期未连上
///
/// 不降级条件：
///   - 已连上（`sseConnected == true`）：即使长时间无 event 也可能正常（waiting）
///   - 还在宽限期：避免企业代理 SSE 慢启动被误判
///
/// gracePeriodSeconds 默认 3 秒，对齐 #4 规划简报中的"3 秒未收到任何 event"。
bool shouldFallbackToPolling({
  required bool sseConnected,
  required bool sseAttemptFailed,
  required int silentSeconds,
  int gracePeriodSeconds = 3,
}) {
  // attemptFailed 优先：连接出过问题视为不可信，立即降级
  if (sseAttemptFailed) return true;
  // 已连接：信任 SSE 通道，长时间无 event 也可能是 waiting 阶段
  if (sseConnected) return false;
  // 未连接：检查是否超出宽限期
  return silentSeconds >= gracePeriodSeconds;
}
