/// Account changes block synchronous commands before asynchronous native teardown.
library;

import 'dart:async';

class TalkRecordPlaybackAccountSession {
  TalkRecordPlaybackAccountSession({
    required this.accountKey,
    required this.addListener,
    required this.removeListener,
    required this.stop,
    required this.disposeNative,
    required this.onBlocked,
    required this.onFailure,
  }) : _initialAccount = accountKey() {
    addListener(_changed);
  }

  final String Function() accountKey;
  final void Function(void Function()) addListener;
  final void Function(void Function()) removeListener;
  final Future<void> Function() stop;
  final Future<void> Function() disposeNative;
  final void Function() onBlocked;
  final void Function(Object, StackTrace) onFailure;
  final String _initialAccount;
  bool blocked = false;
  Future<void>? _closing;

  void check() {
    if (blocked || accountKey() != _initialAccount) {
      throw StateError('Playback account changed');
    }
  }

  void _changed() {
    // Dedicated auth events fire before UID/token persistence has finished.
    // Even a same-UID re-login revokes the old native source immediately.
    if (blocked) return;
    unawaited(close().catchError(onFailure));
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    blocked = true;
    onBlocked();
    removeListener(_changed);
    return _closing = _shutdown();
  }

  Future<void> _shutdown() async {
    try {
      await stop();
    } finally {
      await disposeNative();
    }
  }
}
