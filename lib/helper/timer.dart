import 'dart:async';

import 'package:xid/xid.dart';

///
class TimerHelper {
  final _xid = Xid();
  late final _timers = <String, Timer>{};

  ///
  String setTimer(
    Duration duration,
    void Function() callback, {
    bool immediate = false,
  }) {
    final id = _xid.toString();
    final timer = Timer(duration, callback);
    if (immediate) callback();
    _timers[id] = timer;
    return id;
  }

  ///
  String setPeriodicTimer(
    Duration duration,
    void Function(Timer) callback, {
    bool immediate = false,
  }) {
    final id = _xid.toString();
    final timer = Timer.periodic(duration, callback);
    if (immediate) callback.call(timer);
    _timers[id] = timer;
    return id;
  }

  ///
  void cancelTimer(String id) {
    final timer = _timers.remove(id);
    return timer?.cancel();
  }

  ///
  void cancelAllTimers() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  ///
  bool get hasTimers => _timers.isNotEmpty;
}
