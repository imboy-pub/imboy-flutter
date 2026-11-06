import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imboy/component/helper/datetime.dart';

/// 搜索结果只为最近的已知期限安排一个计时器；恢复前台时重新核验。
/// 未知的接收方已读时间不在这里补造，搜索不会启动阅后即焚计时。
class SearchResultExpiry extends WidgetsBindingObserver {
  SearchResultExpiry(this.onExpired, {this.onResume, int Function()? nowMs})
    : nowMs = nowMs ?? DateTimeHelper.millisecond {
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback onExpired;
  final VoidCallback? onResume;
  final int Function() nowMs;
  Timer? _timer;
  bool _disposed = false;

  void schedule(Iterable<int?> deadlines) {
    cancel();
    if (_disposed) return;
    int? next;
    for (final deadline in deadlines) {
      if (deadline != null && (next == null || deadline < next)) {
        next = deadline;
      }
    }
    if (next == null) return;
    final delay = next - nowMs();
    _timer = Timer(Duration(milliseconds: delay > 0 ? delay : 0), () {
      if (!_disposed) onExpired();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed && state == AppLifecycleState.resumed) {
      (onResume ?? onExpired)();
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
