/// MSG-01（修复窗二批，属主裁决 2026-11-16）：真实浏览器 IME 组合态不会进入
/// Flutter `TextEditingValue.composing`（引擎缺口，runs/msg01-live-20261116
/// F1/F2 实证：候选窗打开期间发送守卫全程未生效）。发送守卫改走 DOM
/// composition 事件流；非 Web 平台为恒否 stub（原生端引擎自带 composing
/// 上报，行为不变）。
library;

export 'web_ime_composition_guard_stub.dart'
    if (dart.library.js_interop) 'web_ime_composition_guard_web.dart';
