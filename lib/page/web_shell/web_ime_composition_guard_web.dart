import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Tracks browser IME composition state at the DOM level.
///
/// MSG-01（修复窗二批）：Flutter Web 引擎不把真实浏览器 IME 组合态写入
/// `TextEditingValue.composing`（合成控制器路径全绿但真实 IME 路径守卫
/// 永不生效，runs/msg01-live-20261116 F1/F2 ≥5 探针实证），本类直接订阅
/// document 级 `compositionstart/update/end` 事件（引擎隐藏编辑元素上的
/// 组合事件会冒泡到 document）供发送入口守卫读取。
///
/// 键序事实：候选窗打开时按 Enter，DOM 先派发 `keydown(isComposing=true)`
/// 后派发 `compositionend`（提交），因此 keydown 处理时 [composing] 仍为
/// true —— 拦截组合态 Enter（选词即发送），不影响 Space/选词上屏后的
/// 正常 Enter 发送（compositionend 已先行，标志复位）。
class WebImeCompositionGuard {
  WebImeCompositionGuard() {
    _start = _keepComposing.toJS;
    _update = _keepComposing.toJS;
    _end = _endComposing.toJS;
    web.document.addEventListener('compositionstart', _start);
    web.document.addEventListener('compositionupdate', _update);
    web.document.addEventListener('compositionend', _end);
  }

  bool _composing = false;
  DateTime _lastEventAt = DateTime.now();

  /// 防御引擎中途摘除编辑元素等边缘态导致 end 事件丢失、标志卡死
  /// （组合态下每次击键都有 compositionupdate 刷新时钟；超时视为残留态）。
  static const _staleAfter = Duration(seconds: 120);

  web.EventHandler? _start;
  web.EventHandler? _update;
  web.EventHandler? _end;

  void _keepComposing(web.Event _) {
    _composing = true;
    _lastEventAt = DateTime.now();
  }

  void _endComposing(web.Event _) {
    _composing = false;
    _lastEventAt = DateTime.now();
  }

  /// True while a real browser IME composition is active (or its end event
  /// went missing and the state has not gone stale yet).
  bool get composing {
    if (!_composing) return false;
    if (DateTime.now().difference(_lastEventAt) > _staleAfter) {
      _composing = false;
      return false;
    }
    return true;
  }

  void dispose() {
    final start = _start;
    final update = _update;
    final end = _end;
    if (start != null) {
      web.document.removeEventListener('compositionstart', start);
    }
    if (update != null) {
      web.document.removeEventListener('compositionupdate', update);
    }
    if (end != null) {
      web.document.removeEventListener('compositionend', end);
    }
    _start = _update = _end = null;
  }
}
