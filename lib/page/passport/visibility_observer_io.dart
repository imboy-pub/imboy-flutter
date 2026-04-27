/// VisibilityObserver IO stub（PR-5β-1）。
///
/// 用于非 Web 平台（iOS / Android / macOS / Linux / Windows）。
/// 移动端无浏览器 tab 概念（OS 直接挂起/恢复进程），无需 visibility 事件流。
/// 永远返回 isVisible=true，visibilityChanges 是空流。
library;

import 'visibility_observer.dart';

/// 非 Web 平台 stub 实现。
class VisibilityObserverImpl implements VisibilityObserver {
  @override
  bool get isVisible => true;

  @override
  Stream<bool> get visibilityChanges => const Stream.empty();

  @override
  Future<void> close() async {}
}
