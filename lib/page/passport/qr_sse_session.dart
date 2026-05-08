/// QR SSE 会话服务（PR-4γ：抽出订阅+watcher+cleanup 逻辑，不动 Notifier）。
///
/// 职责：
///   - 订阅 [SseClient] 的 frames（→ parseSseFrame → onEvent）+ errors
///   - 启动 fallback watcher（每秒 tick，达条件调 onFallback）
///   - stop 时清理所有 subscriptions / timer / client
///
/// PR-4δ 由 `QRLogin` Notifier 创建本会话实例，传入两个 callback：
///   - `onEvent(QrStatusEvent)` → Notifier 调 `derivePollingDecision` 转 state
///   - `onFallback()` → Notifier 调 `_startPolling()` 走 2 秒轮询路径
///
/// 解耦理由：让 SSE 编排逻辑可在不依赖 Riverpod / Notifier / dart:html 的情况下
/// 单元测试（FakeSseClient + fakeAsync 即可全覆盖）。
library;

import 'dart:async';

import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/page/passport/qr_login_sse_rules.dart';
import 'package:imboy/page/passport/sse_client.dart';

/// QR SSE 会话编排器。
class QrSseSession {
  QrSseSession({
    required SseClient client,
    required void Function(QrStatusEvent event) onEvent,
    required void Function() onFallback,
  }) : _client = client,
       _onEvent = onEvent,
       _onFallback = onFallback;

  final SseClient _client;
  final void Function(QrStatusEvent) _onEvent;
  final void Function() _onFallback;

  StreamSubscription<String>? _framesSub;
  StreamSubscription<Object>? _errorsSub;
  Timer? _watcher;
  bool _attemptFailed = false;
  int _silentSeconds = 0;
  bool _stopped = false;
  bool _fallbackFired = false;

  /// 启动会话：订阅 frames/errors + connect + watcher。
  ///
  /// gracePeriodSeconds 透传给 [shouldFallbackToPolling]，默认 3 秒。
  Future<void> start(String url, {int gracePeriodSeconds = 3}) async {
    // 1. 先订阅，避免 connect 后立即收到的 frame 丢失
    _framesSub = _client.frames.listen((raw) {
      if (_stopped) return;
      _silentSeconds = 0; // frame 重置静默计数
      _onEvent(parseSseFrame(raw));
    });
    _errorsSub = _client.errors.listen((_) {
      if (_stopped) return;
      _attemptFailed = true;
    });

    // 2. watcher：每秒 tick，达条件触发 fallback
    _watcher = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopped || _fallbackFired) return;
      _silentSeconds += 1;
      if (shouldFallbackToPolling(
        sseConnected: _client.isOpen,
        sseAttemptFailed: _attemptFailed,
        silentSeconds: _silentSeconds,
        gracePeriodSeconds: gracePeriodSeconds,
      )) {
        _fallbackFired = true;
        _watcher?.cancel();
        _onFallback();
      }
    });

    // 3. connect 失败也不抛，由 watcher 转 fallback
    try {
      await _client.connect(url);
    } catch (_) {
      _attemptFailed = true;
    }
  }

  /// 浏览器从后台 tab 切回前台时调用，重置 silent 计数。
  ///
  /// **背景 / Background**：Chrome/Firefox 后台 tab 会节流 `Timer.periodic`
  /// （后台最低 1min/tick），导致 `_silentSeconds` 异常累积可能误判 fallback。
  /// 切回前台时 widget visibilitychange callback 应调用本方法重置计数。
  ///
  /// 设计：仅重置 `_silentSeconds`，不重启 watcher / 不重连 SSE
  /// （SSE 连接由浏览器层维持，重连决策交给 EventSource onerror 路径）。
  void onResume() {
    if (_stopped) return;
    _silentSeconds = 0;
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _watcher?.cancel();
    _watcher = null;
    await _framesSub?.cancel();
    _framesSub = null;
    await _errorsSub?.cancel();
    _errorsSub = null;
    await _client.close();
  }
}
