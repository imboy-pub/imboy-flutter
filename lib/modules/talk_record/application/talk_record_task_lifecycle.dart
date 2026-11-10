part of 'talk_record_recording_coordinator.dart';

extension _TalkRecordTaskLifecycle on TalkRecordRecordingCoordinator {
  AccountLocalTaskOwner _owner(TalkRecordAccount account) =>
      AccountLocalTaskOwner(
        uid: account.userId,
        environment: currentEnv.isEmpty ? 'pro' : currentEnv,
        endpoint: account.endpoint,
      );

  void _ownRecording(TalkRecordAccount account) {
    if (_recordingTask != null) return;
    _recordingGeneration = UserRepoLocal.to.sessionGeneration;
    _recordingTask = AccountLocalTaskRegistry.instance.register(
      _owner(account),
      onCancel: () => _stopOwnedRecording(account),
    );
  }

  Future<void> _stopOwnedRecording(
    TalkRecordAccount account, {
    bool close = true,
  }) {
    final previous = _stoppingRecorder;
    final operation = _activeOperation;
    final task = _recordingTask;
    late final Future<void> stopping;
    var closed = false;
    stopping =
        () async {
          try {
            try {
              await previous;
            } on Object {
              // A subsequent cleanup retries an earlier unconfirmed stop.
            }
            await operation;
            if (_binding?.account != account) {
              closed = _recorder == null;
              return;
            }
            final recorder = _recorder;
            if (recorder == null) {
              closed = true;
              return;
            }
            try {
              await recorder.markInterrupted('account_changed');
            } on Object {
              if (recorder.snapshot.isActive) await recorder.end();
            }
            if (close) {
              await recorder.dispose();
              closed = true;
            }
            if (recorder.snapshot.stopUnconfirmed) {
              _updates.add(recorder.snapshot);
              throw const TalkRecordStopUnconfirmedException();
            }
            if (close) {
              await _subscription?.cancel();
              _subscription = null;
              _recorder = null;
              _recoverable = null;
              _snapshot = const TalkRecordRecorderSnapshot();
            }
            _updates.add(const TalkRecordRecorderSnapshot());
          } finally {
            if (close && closed) {
              task?.finish();
              if (identical(_recordingTask, task)) _recordingTask = null;
            }
          }
        }().whenComplete(() {
          if (identical(_stoppingRecorder, stopping)) _stoppingRecorder = null;
        });
    _stoppingRecorder = stopping;
    return stopping;
  }

  void _check(TalkRecordAccount expected) {
    _operationTask?.throwIfCancelled();
    if (_operationCancel?.isCancelled == true) {
      throw StateError('Recording operation cancelled');
    }
    final generation = _operationGeneration;
    if ((generation != null &&
            !UserRepoLocal.to.isCurrentSession(generation)) ||
        (_operationEnvironment != null &&
            _operationEnvironment != currentEnv)) {
      throw StateError('Recording session changed');
    }
    if (_binding?.account == expected) {
      _recordingTask?.throwIfCancelled();
      final recordingGeneration = _recordingGeneration;
      if (_recordingTask != null &&
          recordingGeneration != null &&
          !UserRepoLocal.to.isCurrentSession(recordingGeneration)) {
        throw StateError('Recording session changed');
      }
    }
    if (!expected.valid || currentAccount() != expected) {
      throw StateError('Recording account changed');
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    if (_busy || _stoppingRecorder != null) {
      throw StateError('Recording operation in progress');
    }
    final account = currentAccount();
    _check(account);
    final actor = UserRepoLocal.to;
    final generation = actor.sessionGeneration;
    final environment = currentEnv;
    final cancel = CancelToken();
    final task = AccountLocalTaskRegistry.instance.register(
      _owner(account),
      onCancel: () => cancel.cancel('account local data cleanup'),
    );
    _busy = true;
    _operationTask = task;
    _operationGeneration = generation;
    _operationEnvironment = environment;
    _operationCancel = cancel;
    final settled = Completer<void>();
    _activeOperation = settled.future;
    void onAuthChanged() {
      if (cancel.isCancelled) return;
      if (actor.isAuthTransitioning ||
          !actor.isCurrentSession(generation) ||
          currentEnv != environment ||
          currentAccount() != account) {
        cancel.cancel('recording account changed');
      }
    }

    // Recovered uploads have no live recorder binding. Their token still owns
    // every inner direct request and must be revoked as soon as auth changes.
    _authChanges.addListener(onAuthChanged);
    try {
      onAuthChanged();
      _check(account);
      final result = await work();
      _check(account);
      return result;
    } finally {
      _authChanges.removeListener(onAuthChanged);
      _busy = false;
      _operationTask = null;
      _operationGeneration = null;
      _operationEnvironment = null;
      _operationCancel = null;
      _activeOperation = null;
      task.finish();
      settled.complete();
    }
  }
}
