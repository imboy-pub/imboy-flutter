/// SseClient Web 实现（PR-4β，package:web 的 EventSource 封装）。
///
/// 锚定后端 `imboy/src/api/qr_login_sse_handler.erl` 的输出：
///   - 每帧形如 `data: <json>\n\n`
///   - browser EventSource 自动按 `\n\n` 切帧并触发 `message` 事件
///   - `event.data` 已剥离 `data:` 前缀和 `\n\n` 尾部
///
/// 但 PR-4α 的 `parseSseFrame` 期望含 `data:` 前缀的原始帧 — 为兼容，
/// 本封装在 frames Stream 中**重新加上** `data: ` 前缀，保持与
/// 后端原始格式一致，让 parseSseFrame 同一份解析逻辑覆盖两端。
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:imboy/page/passport/sse_client.dart';

/// Web 平台真实 EventSource 包装。
class SseClientImpl implements SseClient {
  web.EventSource? _eventSource;
  final StreamController<String> _framesCtrl = StreamController<String>.broadcast();
  final StreamController<Object> _errorsCtrl = StreamController<Object>.broadcast();
  bool _isOpen = false;
  bool _closed = false;

  @override
  bool get isOpen => _isOpen;

  @override
  Stream<String> get frames => _framesCtrl.stream;

  @override
  Stream<Object> get errors => _errorsCtrl.stream;

  @override
  Future<void> connect(String url) async {
    if (_closed) {
      throw StateError('SseClientImpl 已 close，不可重连，请新建实例');
    }
    if (_eventSource != null) {
      throw StateError('SseClientImpl 已 connect，不可重复连接');
    }

    final es = web.EventSource(url);

    es.onopen = ((web.Event _) {
      _isOpen = true;
    }).toJS;

    es.onmessage = ((web.MessageEvent event) {
      // event.data 是 String（已剥离 SSE 协议字段）
      final data = (event.data as JSString?)?.toDart;
      if (data == null) return;
      // 重新加 data: 前缀以匹配 parseSseFrame 契约
      _framesCtrl.add('data: $data');
    }).toJS;

    es.onerror = ((web.Event event) {
      _isOpen = false;
      _errorsCtrl.add(event);
    }).toJS;

    _eventSource = es;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _isOpen = false;
    _eventSource?.close();
    _eventSource = null;
    await _framesCtrl.close();
    await _errorsCtrl.close();
  }
}
