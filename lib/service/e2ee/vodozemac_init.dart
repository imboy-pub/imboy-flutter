import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;

/// vodozemac 的 flutter_rust_bridge 初始化 —— **进程级全局，只能做一次**。
///
/// 重复调用会抛 `Bad state: Should not initialize flutter_rust_bridge twice`。
///
/// 此前 `OlmSessionService` 与 `GroupSessionService` 各自持有一份
/// `_vodReady` / `_initFuture`，却调用同一个全局 `fvod.init()`：
/// 谁先初始化成功，另一个的标志位仍是 false，于是必然再 init 一次并抛异常。
/// 真机日志：`initialize megolm failed: Bad state: Should not initialize
/// flutter_rust_bridge twice`（BUG#72 接线后两条链路首次被同时触发，暴露出来）。
///
/// 状态收口到这里一份，两个 service 都委托过来。
class VodozemacInit {
  VodozemacInit._();

  static bool _ready = false;
  static Future<void>? _initFuture;

  static bool get isReady => _ready;

  /// 幂等：已就绪直接返回；并发调用共享同一个 Future；失败则清空以便重试。
  static Future<void> ensure() async {
    if (_ready) return;
    _initFuture ??= fvod.init();
    try {
      await _initFuture;
      _ready = true;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  /// 测试专用：测试进程自行 `vod.init(libraryPath:)` 后标记就绪。
  ///
  /// 刻意不加 `@visibleForTesting`：它的两个调用方
  /// `OlmSessionService.debugMarkVodReady` / `GroupSessionService.debugMarkVodReady`
  /// 自己已标注该注解，而 analyzer 不做传递判定，加了只会在转发处报 warning。
  static void debugMarkReady() => _ready = true;

  @visibleForTesting
  static void debugReset() {
    _ready = false;
    _initFuture = null;
  }
}
