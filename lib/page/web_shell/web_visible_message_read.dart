import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/modules/messaging/domain/policy/visibility_read_rules.dart';

/// Only a continuously visible, foreground message may advance the read cursor.
class WebVisibleMessageRead extends StatefulWidget {
  const WebVisibleMessageRead({
    super.key,
    required this.enabled,
    required this.fraction,
    required this.delayMs,
    required this.isCurrent,
    required this.onRead,
    required this.child,
  });

  final bool enabled;
  final double fraction;
  final int delayMs;
  final bool Function() isCurrent;
  final Future<bool> Function() onRead;
  final Widget child;

  @override
  State<WebVisibleMessageRead> createState() => _WebVisibleMessageReadState();
}

class _WebVisibleMessageReadState extends State<WebVisibleMessageRead>
    with WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  Timer? _timer;
  double _visible = 0;
  bool _committed = false;
  bool _inFlight = false;
  int _attempts = 0;
  bool _frameCheckPending = false;

  bool get _eligible =>
      mounted &&
      widget.enabled &&
      !_committed &&
      !_inFlight &&
      _attempts < 3 &&
      widget.isCurrent() &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      _visible >= normalizeVisibilityFraction(widget.fraction);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_eligible) return;
    _timer = Timer(
      Duration(milliseconds: normalizeVisibilityDelayMs(widget.delayMs)),
      () => unawaited(_commit()),
    );
    _observeRenderedFrames();
  }

  void _observeRenderedFrames() {
    if (_frameCheckPending || _timer?.isActive != true || !_eligible) return;
    _frameCheckPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCheckPending = false;
      if (_timer?.isActive != true || !_eligible) return;
      // Observe intermediate scroll geometry without requesting extra frames.
      VisibilityDetectorController.instance.notifyNow();
      _observeRenderedFrames();
    });
  }

  Future<void> _commit() async {
    _timer = null;
    // Visibility notifications may be throttled longer than the read delay.
    VisibilityDetectorController.instance.notifyNow();
    _timer?.cancel();
    _timer = null;
    if (!_eligible) return;
    _inFlight = true;
    _attempts++;
    try {
      final applied = await widget.onRead();
      if (mounted && widget.isCurrent()) _committed = applied;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Web visible message read',
        ),
      );
    } finally {
      _inFlight = false;
      if (!_committed) _schedule();
    }
  }

  @override
  void didUpdateWidget(covariant WebVisibleMessageRead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.fraction != widget.fraction ||
        oldWidget.delayMs != widget.delayMs) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _schedule();

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _visibilityKey,
    onVisibilityChanged: (info) {
      _visible = info.visibleFraction;
      _schedule();
    },
    child: widget.child,
  );
}

/// Keep expiry scheduling behind a successful read and the original session.
Future<bool> commitWebVisibleMessageRead({
  required bool Function() isCurrent,
  required Future<bool> Function() markRead,
  Future<bool> Function()? markBurnRead,
}) async {
  if (!isCurrent()) return false;
  if (!await markRead() || !isCurrent()) return false;
  if (markBurnRead != null) {
    if (!await markBurnRead() || !isCurrent()) return false;
  }
  return true;
}
