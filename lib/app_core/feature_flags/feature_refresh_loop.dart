import 'dart:async';

import 'package:flutter/foundation.dart';

/// Retry transient configuration failure even when the network type is stable.
class FeatureRefreshLoop {
  FeatureRefreshLoop({required this.refresh});

  final Future<bool> Function() refresh;
  static const _delays = [2, 4, 8, 16, 32, 60];
  Future<bool>? _inFlight;
  Timer? _timer;
  int _failures = 0;
  bool _disposed = false;
  bool _trailing = false;

  Future<bool> request() {
    if (_disposed) return Future.value(false);
    final active = _inFlight;
    if (active != null) {
      _trailing = true;
      return active;
    }
    _timer?.cancel();
    _timer = null;
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  Future<bool> _run() async {
    var succeeded = false;
    try {
      succeeded = await refresh();
      if (!_disposed && _trailing) {
        _trailing = false;
        succeeded = await refresh();
      }
    } on Object catch (error) {
      succeeded = false;
      debugPrint('[feature_refresh] failed: ${error.runtimeType}');
    }
    if (_disposed) return false;
    if (succeeded && !_trailing) {
      _failures = 0;
      return true;
    }
    final index = _failures < _delays.length ? _failures : _delays.length - 1;
    _failures++;
    _timer = Timer(Duration(seconds: _delays[index]), () {
      _trailing = false;
      unawaited(request());
    });
    return false;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
