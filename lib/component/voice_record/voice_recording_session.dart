import 'dart:async';

import 'package:imboy/service/account_local_task_registry.dart';

/// Owns a recording from its first permission request through the final native
/// stop/flush. Stopping joins a pending start before touching either recorder.
class VoiceRecordingSession {
  VoiceRecordingSession({
    required AccountLocalTaskOwner owner,
    required bool Function() isCurrent,
    required Future<void> Function(VoiceRecordingSession session) start,
    required Future<String?> Function() stop,
    AccountLocalTaskRegistry? registry,
  }) : _isCurrent = isCurrent,
       _stopNative = stop {
    if (!isCurrent()) throw const AccountLocalTaskCancelledException();
    task = (registry ?? AccountLocalTaskRegistry.instance).register(
      owner,
      onCancel: cancel,
    );
    _startup = Future<void>.microtask(() async {
      try {
        checkActive();
        await start(this);
        checkActive();
      } catch (error, stack) {
        _discarded = true;
        Error.throwWithStackTrace(error, stack);
      }
    });
  }

  final bool Function() _isCurrent;
  final Future<String?> Function() _stopNative;
  late final AccountLocalTask task;
  late final Future<void> _startup;
  Future<String?>? _stopping;
  bool _stopRequested = false;
  bool _discarded = false;
  bool _finished = false;

  Future<void> get started => _startup;
  bool get finished => _finished;
  bool get isCurrent => _isCurrent();
  bool get canPublish => isCurrent && !_discarded && !task.isCancelled;
  bool get canRecord => canPublish && !_stopRequested && !_finished;

  void checkActive() {
    if (!canRecord) throw const AccountLocalTaskCancelledException();
  }

  Future<void> cancel() async {
    await stop(discard: true);
  }

  Future<String?> stop({bool discard = false}) {
    if (discard) _discarded = true;
    _stopRequested = true;
    return _stopping ??= _settleAndStop();
  }

  Future<String?> _settleAndStop() async {
    try {
      await _startup;
    } catch (_) {
      // Even a failed/late start can have opened a native writer.
    }
    try {
      final path = await _stopNative();
      _finished = true;
      task.finish();
      return canPublish ? path : null;
    } catch (error, stack) {
      // Keep the task registered until a retry confirms every writer stopped.
      _stopping = null;
      Error.throwWithStackTrace(error, stack);
    }
  }
}
