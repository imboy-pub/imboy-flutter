/// 页面可见性观察者抽象 + 平台工厂（PR-5β-1 基础设施层）。
///
/// 设计目标：
///   - 让 PR-5β-2 的 `QRLogin` Notifier 在 widget 层注入此抽象，监听浏览器
///     `document.visibilityState` 切换；切回前台时调 `_sseSession?.onResume()`
///     防 Timer.periodic 后台节流误判 fallback（已在 PR-4γ+ 提供 onResume）
///   - 移动端编译不报错（IO stub 永远 visible，空流）
///   - 测试可注入 `FakeVisibilityObserver` 模拟切换
///
/// 平台路由（参考 `lib/service/rsa.dart` 与 `sse_client.dart` 同模式）：
///   - 非 Web 平台 → `visibility_observer_io.dart` stub
///   - Web 平台 → `visibility_observer_web.dart` 真实 document.visibilitychange
library;

import 'visibility_observer_io.dart'
    if (dart.library.html) 'visibility_observer_web.dart';

/// 页面可见性观察者契约。
///
/// 调用流程（PR-5β-2 widget 用法）：
/// ```dart
/// final observer = createVisibilityObserver();
/// final sub = observer.visibilityChanges.listen((isVisible) {
///   if (isVisible) ref.read(qRLoginProvider.notifier).onPageResume();
/// });
/// ...
/// await observer.close();
/// sub.cancel();
/// ```
abstract class VisibilityObserver {
  /// 当前页面是否可见（同步访问，IO 平台永远 true）
  bool get isVisible;

  /// 可见性变化流（true = visible / false = hidden）
  /// broadcast：支持多订阅不抛
  Stream<bool> get visibilityChanges;

  /// 释放资源（取消 DOM 监听 + 关闭 controller）
  /// 多次调用安全（idempotent）
  Future<void> close();
}

/// 创建当前平台的 VisibilityObserver 实例。
///
/// - Web 平台：`VisibilityObserverImpl` 来自 `visibility_observer_web.dart`
///   监听 `document.visibilitychange` 事件
/// - 非 Web：`VisibilityObserverImpl` 来自 `visibility_observer_io.dart`
///   永远 visible（移动端无后台 tab 概念，由 OS 直接挂起进程）
VisibilityObserver createVisibilityObserver() => VisibilityObserverImpl();
