import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/store/repository/user_repo_local.dart';

/// Stable account ownership, independent of a particular login generation.
class AccountLocalTaskOwner {
  const AccountLocalTaskOwner({
    required this.uid,
    required this.environment,
    required this.endpoint,
  });

  factory AccountLocalTaskOwner.capture({String? uid}) => AccountLocalTaskOwner(
    uid: uid ?? UserRepoLocal.to.currentUid,
    environment: currentEnv.isEmpty ? 'pro' : currentEnv,
    endpoint: Env().apiBaseUrl,
  );

  final String uid;
  final String environment;
  final String endpoint;

  /// Stable, filesystem-safe identity; the endpoint is intentionally not
  /// normalised because two configured servers must never share local data.
  String get storageDigest => sha256
      .convert(utf8.encode(jsonEncode([environment, endpoint, uid])))
      .toString();

  String preferenceKey(String key) => '$key:account_v1:$storageDigest';

  @override
  bool operator ==(Object other) =>
      other is AccountLocalTaskOwner &&
      uid == other.uid &&
      environment == other.environment &&
      endpoint == other.endpoint;

  @override
  int get hashCode => Object.hash(uid, environment, endpoint);
}

class AccountLocalTaskCancelledException implements Exception {
  const AccountLocalTaskCancelledException();
}

/// Tracks complete workflows, including file writes after a network request.
/// Cleanup cancels an owner's work and awaits its finally blocks before unlinking
/// files. Other accounts and anonymous device resources are not stopped.
class AccountLocalTaskRegistry {
  static final instance = AccountLocalTaskRegistry();

  final Map<AccountLocalTaskOwner, Set<AccountLocalTask>> _tasks = {};
  final Set<AccountLocalTaskOwner> _cleaning = {};

  AccountLocalTask register(
    AccountLocalTaskOwner owner, {
    FutureOr<void> Function()? onCancel,
  }) {
    if (owner.uid.isEmpty ||
        owner.environment.isEmpty ||
        owner.endpoint.isEmpty) {
      throw ArgumentError('An account task requires a complete owner');
    }
    if (_cleaning.contains(owner)) {
      throw const AccountLocalTaskCancelledException();
    }
    final task = AccountLocalTask._(this, owner, onCancel);
    (_tasks[owner] ??= {}).add(task);
    return task;
  }

  Future<T> run<T>(
    AccountLocalTaskOwner owner, {
    FutureOr<void> Function()? onCancel,
    required Future<T> Function(AccountLocalTask task) operation,
  }) {
    final task = register(owner, onCancel: onCancel);
    return Future<T>.sync(() => operation(task)).whenComplete(task.finish);
  }

  /// Call before entering a session-write queue: a stopped upload may itself
  /// need that queue to finish discarding a partial secret or cache write.
  AccountLocalTaskCleanup beginCleanup(AccountLocalTaskOwner owner) {
    if (!_cleaning.add(owner)) {
      throw StateError('Account cleanup is already in progress');
    }
    final tasks = _tasks[owner]?.toList() ?? const <AccountLocalTask>[];
    final cancellations = [for (final task in tasks) task._cancel()];
    final stopped = Future.wait(cancellations).then<void>((_) async {
      await Future.wait([for (final task in tasks) task._finished.future]);
    });
    return AccountLocalTaskCleanup._(stopped, () => _cleaning.remove(owner));
  }

  void _finish(AccountLocalTask task) {
    final tasks = _tasks[task.owner];
    tasks?.remove(task);
    if (tasks?.isEmpty ?? false) _tasks.remove(task.owner);
  }
}

class AccountLocalTask {
  AccountLocalTask._(this._registry, this.owner, this._onCancel);

  final AccountLocalTaskRegistry _registry;
  final AccountLocalTaskOwner owner;
  final FutureOr<void> Function()? _onCancel;
  final Completer<void> _finished = Completer<void>();
  Future<void>? _cancellation;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void throwIfCancelled() {
    if (_cancelled) throw const AccountLocalTaskCancelledException();
  }

  Future<void> _cancel() {
    _cancelled = true;
    return _cancellation ??= Future<void>.sync(() => _onCancel?.call())
        .catchError((Object error, StackTrace stack) {
          // A device/plugin cancellation can fail transiently. Keep the task
          // cancelled, but let an explicit cleanup retry call the stop again.
          _cancellation = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  /// Finish only after all file, key and checkpoint cleanup has settled.
  void finish() {
    if (_finished.isCompleted) return;
    _registry._finish(this);
    _finished.complete();
  }
}

class AccountLocalTaskCleanup {
  AccountLocalTaskCleanup._(this.stopped, this._release);

  final Future<void> stopped;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
