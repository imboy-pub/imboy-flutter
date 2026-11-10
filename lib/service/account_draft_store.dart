import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:synchronized/synchronized.dart';

/// A composer keeps its original account, route and login generation.
/// Native preference writes are drained before account cleanup deletes drafts.
class AccountDraftStore {
  factory AccountDraftStore.capture(
    String type,
    String peerId, {
    AuthSessionReader? sessionReader,
  }) {
    final reader = sessionReader ?? authSessionReader;
    final session = reader.current;
    return AccountDraftStore._(
      reader,
      session,
      AccountLocalTaskOwner.capture(uid: session.uid),
      chatDraftKeys(session.uid, type, peerId),
    );
  }

  AccountDraftStore._(this._reader, this._session, this.owner, this._keys);

  final AuthSessionReader _reader;
  final AuthSessionScope _session;
  final AccountLocalTaskOwner owner;
  final ({String text, String cursor})? _keys;
  final _writes = Lock();

  bool get isCurrent =>
      _reader.isCurrent(_session) &&
      AccountLocalTaskOwner.capture(uid: _session.uid) == owner;

  ({String text, int? cursor}) read() {
    final keys = _keys;
    if (keys == null || !isCurrent) return (text: '', cursor: null);
    return (
      text: StorageService.to.getString(keys.text),
      cursor: int.tryParse(StorageService.to.getString(keys.cursor)),
    );
  }

  Future<void> save(String text, {int? cursor}) {
    if (text.isEmpty) return clear();
    return _write((task, keys) async {
      await StorageService.to.persistPreference(
        () => StorageService.to.setString(keys.text, text),
      );
      if (!isCurrent || task.isCancelled) return;
      if (cursor != null && cursor >= 0) {
        await StorageService.to.persistPreference(
          () => StorageService.to.setString(keys.cursor, cursor.toString()),
        );
      }
    });
  }

  Future<void> clear() => _write((task, keys) async {
    await StorageService.to.persistPreference(
      () => StorageService.to.remove(keys.text),
    );
    if (!isCurrent || task.isCancelled) return;
    await StorageService.to.persistPreference(
      () => StorageService.to.remove(keys.cursor),
    );
  });

  Future<void> _write(
    Future<void> Function(
      AccountLocalTask task,
      ({String text, String cursor}) keys,
    )
    operation,
  ) async {
    final keys = _keys;
    if (keys == null || !isCurrent) return;
    try {
      await AccountLocalTaskRegistry.instance.run<void>(
        owner,
        operation: (task) => _writes.synchronized(() async {
          if (!isCurrent || task.isCancelled) return;
          await operation(task, keys);
        }),
      );
    } on AccountLocalTaskCancelledException {
      // A delayed debounce/dispose callback may race with cleanup's barrier.
    }
  }
}
