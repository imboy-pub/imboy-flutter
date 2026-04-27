/// VisibilityObserver Web 实现（PR-5β-1，package:web document.visibilitychange）。
///
/// 浏览器原生 `document.visibilityState` 返回 'visible' | 'hidden' | 'prerender'：
///   - 'visible' → emit true
///   - 'hidden' → emit false
///   - 'prerender' → 当作 hidden（不可见用户）
///
/// 浏览器节流细节（生产监控的依据）：
///   - Chrome 后台 tab：Timer.periodic 最低 1min/tick（vs 前台 1ms 精度）
///   - Firefox 类似行为
///   - Safari 11+ 在 hidden 时直接 throttle 到 1s
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:imboy/page/passport/visibility_observer.dart';

/// Web 平台真实 visibility 监听包装。
class VisibilityObserverImpl implements VisibilityObserver {
  final StreamController<bool> _ctrl = StreamController<bool>.broadcast();
  bool _closed = false;
  JSFunction? _listener;

  VisibilityObserverImpl() {
    final cb = ((web.Event _) {
      if (_closed) return;
      _ctrl.add(_currentVisibility());
    }).toJS;
    _listener = cb;
    web.document.addEventListener('visibilitychange', cb);
  }

  @override
  bool get isVisible => _currentVisibility();

  @override
  Stream<bool> get visibilityChanges => _ctrl.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_listener != null) {
      web.document.removeEventListener('visibilitychange', _listener);
      _listener = null;
    }
    await _ctrl.close();
  }

  bool _currentVisibility() {
    // document.visibilityState: 'visible' | 'hidden' | 'prerender'
    return web.document.visibilityState == 'visible';
  }
}
