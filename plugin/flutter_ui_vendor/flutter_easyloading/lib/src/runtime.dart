import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'types.dart';

enum EasyLoadingContentType {
  loading,
  progress,
  success,
  error,
  info,
  toast,
  custom,
}

@immutable
class EasyLoadingRequest {
  const EasyLoadingRequest({
    required this.type,
    required this.theme,
    required this.alignment,
    required this.constraints,
    required this.dismissOnTap,
    required this.ignoresPointer,
    this.status,
    this.indicator,
    this.progress,
    this.duration,
    this.customContent,
  });

  final EasyLoadingContentType type;
  final EasyLoadingThemeSnapshot theme;
  final String? status;
  final Widget? indicator;
  final double? progress;
  final Duration? duration;
  final AlignmentGeometry alignment;
  final BoxConstraints constraints;
  final bool dismissOnTap;
  final bool ignoresPointer;
  final Widget? customContent;

  EasyLoadingRequest preserveProgressStatus(EasyLoadingRequest previous) {
    if (type != EasyLoadingContentType.progress ||
        previous.type != EasyLoadingContentType.progress ||
        status != null) {
      return this;
    }
    return EasyLoadingRequest(
      type: type,
      theme: theme,
      status: previous.status,
      indicator: indicator,
      progress: progress,
      duration: duration,
      alignment: alignment,
      constraints: constraints,
      dismissOnTap: dismissOnTap,
      ignoresPointer: ignoresPointer,
      customContent: customContent,
    );
  }
}

@immutable
class EasyLoadingSession {
  const EasyLoadingSession({
    required this.id,
    required this.revision,
    required this.request,
  });

  final int id;
  final int revision;
  final EasyLoadingRequest request;

  EasyLoadingSession update(EasyLoadingRequest next) {
    return EasyLoadingSession(
      id: id,
      revision: revision + 1,
      request: next.preserveProgressStatus(request),
    );
  }
}

abstract interface class EasyLoadingHost {
  Future<void> dismiss(int sessionId, {required bool animate});
}

/// Internal single-session state machine used by the public static facade.
class EasyLoadingRuntime extends ChangeNotifier {
  EasyLoadingRuntime();

  EasyLoadingSession? _session;
  EasyLoadingHost? _host;
  Completer<void>? _presentationCompleter;
  Timer? _autoDismissTimer;
  final Queue<_RuntimeOperation> _operations = Queue<_RuntimeOperation>();
  final List<EasyLoadingStatusCallback> _statusCallbacks =
      <EasyLoadingStatusCallback>[];
  final List<EasyLoadingDismissCallback> _dismissCallbacks =
      <EasyLoadingDismissCallback>[];
  EasyLoadingRequest? _pendingProgress;
  bool _operationActive = false;
  bool _progressFrameScheduled = false;
  int _nextSessionId = 0;
  int? _presentedSessionId;

  EasyLoadingSession? get session => _session;
  bool get isShow => _session != null;

  void attach(EasyLoadingHost host) {
    if (identical(_host, host)) {
      return;
    }
    if (_host != null) {
      throw StateError(
        'EasyLoading supports one active Host. Add EasyLoading.init() only '
        'once at the application root.',
      );
    }
    _host = host;
  }

  void detach(EasyLoadingHost host) {
    if (!identical(_host, host)) {
      return;
    }
    _host = null;
    _clearPendingProgress();
    _cancelAutoDismiss();

    final current = _session;
    final wasPresented = current != null && _presentedSessionId == current.id;
    _session = null;
    _presentedSessionId = null;
    if (!(_presentationCompleter?.isCompleted ?? true)) {
      _presentationCompleter!.complete();
    }
    _presentationCompleter = null;
    if (current != null) {
      notifyListeners();
    }
    if (wasPresented) {
      _dispatchStatus(EasyLoadingStatus.dismiss);
      _dispatchDismiss(EasyLoadingDismissReason.hostDetached);
    }
  }

  void didPresent(int sessionId) {
    if (_session?.id == sessionId &&
        !(_presentationCompleter?.isCompleted ?? true)) {
      _presentationCompleter!.complete();
    }
  }

  Future<void> show(EasyLoadingRequest request) {
    _requireHost();
    _clearPendingProgress();
    final presenting = _presentationCompleter;
    final current = _session;
    if (current != null &&
        presenting != null &&
        !presenting.isCompleted &&
        _operations.isEmpty) {
      _cancelAutoDismiss();
      _session = current.update(request);
      notifyListeners();
      return presenting.future;
    }
    return _enqueue(() => _show(request));
  }

  Future<void> showProgress(EasyLoadingRequest request) {
    _requireHost();
    final current = _session;
    if (current == null ||
        current.request.type != EasyLoadingContentType.progress ||
        _presentedSessionId != current.id ||
        _operationActive ||
        _operations.isNotEmpty) {
      return show(request);
    }

    _pendingProgress = request;
    if (!_progressFrameScheduled) {
      _progressFrameScheduled = true;
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _progressFrameScheduled = false;
        final pending = _pendingProgress;
        _pendingProgress = null;
        if (pending == null) {
          return;
        }
        unawaited(
          show(pending).catchError((Object error, StackTrace stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'flutter_easyloading',
                context: ErrorDescription('while updating progress'),
              ),
            );
          }),
        );
      });
      SchedulerBinding.instance.scheduleFrame();
    }
    return Future<void>.value();
  }

  Future<void> dismiss({
    bool animation = true,
    EasyLoadingDismissReason reason = EasyLoadingDismissReason.programmatic,
  }) {
    _clearPendingProgress();
    _cancelAutoDismiss();
    return _enqueue(
      () => _dismissCurrent(animate: animation, dismissReason: reason),
    );
  }

  void addStatusCallback(EasyLoadingStatusCallback callback) {
    if (!_statusCallbacks.contains(callback)) {
      _statusCallbacks.add(callback);
    }
  }

  void removeStatusCallback(EasyLoadingStatusCallback callback) {
    _statusCallbacks.remove(callback);
  }

  void clearStatusCallbacks() {
    _statusCallbacks.clear();
  }

  void addDismissCallback(EasyLoadingDismissCallback callback) {
    if (!_dismissCallbacks.contains(callback)) {
      _dismissCallbacks.add(callback);
    }
  }

  void removeDismissCallback(EasyLoadingDismissCallback callback) {
    _dismissCallbacks.remove(callback);
  }

  void clearDismissCallbacks() {
    _dismissCallbacks.clear();
  }

  Future<void> _show(EasyLoadingRequest request) async {
    _cancelAutoDismiss();
    final current = _session;
    if (current != null) {
      _session = current.update(request);
      notifyListeners();
      final updated = _session!;
      if (_presentedSessionId == updated.id) {
        _scheduleAutoDismiss(updated);
      }
      return;
    }

    final created = EasyLoadingSession(
      id: ++_nextSessionId,
      revision: 0,
      request: request,
    );
    final presented = Completer<void>();
    _presentationCompleter = presented;
    _presentedSessionId = null;
    _session = created;
    notifyListeners();

    await presented.future;
    final active = _session;
    if (active?.id != created.id) {
      return;
    }
    _presentedSessionId = active!.id;
    _dispatchStatus(EasyLoadingStatus.show);
    _scheduleAutoDismiss(active);
  }

  Future<void> _dismissCurrent({
    required bool animate,
    required EasyLoadingDismissReason dismissReason,
  }) async {
    final current = _session;
    if (current == null) {
      return;
    }

    final host = _host;
    if (host != null) {
      await host.dismiss(current.id, animate: animate);
    }
    if (_session?.id != current.id) {
      return;
    }

    final wasPresented = _presentedSessionId == current.id;
    _session = null;
    _presentedSessionId = null;
    _presentationCompleter = null;
    notifyListeners();
    if (wasPresented) {
      _dispatchStatus(EasyLoadingStatus.dismiss);
      _dispatchDismiss(dismissReason);
    }
  }

  void _scheduleAutoDismiss(EasyLoadingSession session) {
    _cancelAutoDismiss();
    final duration = session.request.duration;
    if (duration == null) {
      return;
    }
    final sessionId = session.id;
    final revision = session.revision;
    _autoDismissTimer = Timer(duration, () {
      _autoDismissTimer = null;
      unawaited(
        _enqueue(() async {
          final active = _session;
          if (active?.id != sessionId || active?.revision != revision) {
            return;
          }
          await _dismissCurrent(
            animate: true,
            dismissReason: EasyLoadingDismissReason.timeout,
          );
        }),
      );
    });
  }

  void _cancelAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _clearPendingProgress() {
    _pendingProgress = null;
  }

  void _dispatchStatus(EasyLoadingStatus status) {
    for (final callback in List<EasyLoadingStatusCallback>.of(
      _statusCallbacks,
    )) {
      _invokeSafely(
        () => callback(status),
        'while dispatching a status callback',
      );
    }
  }

  void _dispatchDismiss(EasyLoadingDismissReason reason) {
    for (final callback in List<EasyLoadingDismissCallback>.of(
      _dismissCallbacks,
    )) {
      _invokeSafely(
        () => callback(reason),
        'while dispatching a dismiss callback',
      );
    }
  }

  void _invokeSafely(VoidCallback callback, String context) {
    try {
      callback();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'flutter_easyloading',
          context: ErrorDescription(context),
        ),
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final queued = _RuntimeOperation(operation);
    _operations.addLast(queued);
    _drainOperations();
    return queued.completer.future;
  }

  void _drainOperations() {
    if (_operationActive || _operations.isEmpty) {
      return;
    }
    _operationActive = true;
    final queued = _operations.removeFirst();
    Future<void> result;
    try {
      result = queued.operation();
    } catch (error, stackTrace) {
      queued.completer.completeError(error, stackTrace);
      _finishOperation();
      return;
    }
    result
        .then(
          (_) => queued.completer.complete(),
          onError: (Object error, StackTrace stackTrace) {
            queued.completer.completeError(error, stackTrace);
          },
        )
        .whenComplete(_finishOperation);
  }

  void _finishOperation() {
    _operationActive = false;
    _drainOperations();
  }

  void _requireHost() {
    if (_host == null) {
      throw StateError(
        'EasyLoading is not initialized. Add EasyLoading.init() to the '
        'builder of your MaterialApp or CupertinoApp.',
      );
    }
  }
}

class _RuntimeOperation {
  _RuntimeOperation(this.operation);

  final Future<void> Function() operation;
  final Completer<void> completer = Completer<void>();
}

final EasyLoadingRuntime easyLoadingRuntime = EasyLoadingRuntime();
