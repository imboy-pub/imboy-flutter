import 'package:synchronized/synchronized.dart';

import 'account_local_task_registry.dart';
import 'auth_session_scope.dart';
import 'storage.dart';

/// Preferences belong to the session which created their page/provider.
/// Legacy global values are deliberately neither imported nor removed here.
class AccountPreferences {
  AccountPreferences.capture({this.isActive})
    : owner = AccountLocalTaskOwner.capture(),
      session = authSessionReader.current;

  final AccountLocalTaskOwner owner;
  final AuthSessionScope session;
  final bool Function()? isActive;
  final _lock = Lock();

  bool get isCurrent =>
      (isActive?.call() ?? true) &&
      authSessionReader.isCurrent(session) &&
      AccountLocalTaskOwner.capture() == owner;

  List<String> readList(String key) => isCurrent
      ? StorageService.to.getStringList(owner.preferenceKey(key)) ?? []
      : [];

  Future<List<String>?> updateList(
    String key,
    List<String> Function(List<String> current) update,
  ) => _run(() async {
    final values = update(readList(key));
    await StorageService.to.persistPreference(
      () => StorageService.to.setList(owner.preferenceKey(key), values),
    );
    return values;
  });

  Future<void> writeList(String key, List<String> values) async {
    final snapshot = List<String>.of(values);
    await updateList(key, (_) => snapshot);
  }

  Future<void> remove(String key) async {
    await _run(
      () => StorageService.to.persistPreference(
        () => StorageService.to.remove(owner.preferenceKey(key)),
      ),
    );
  }

  Future<T?> _run<T>(Future<T> Function() operation) async {
    if (!isCurrent) return null;
    try {
      return await AccountLocalTaskRegistry.instance.run<T?>(
        owner,
        operation: (task) => _lock.synchronized(() async {
          if (!isCurrent || task.isCancelled) return null;
          final result = await operation();
          return isCurrent && !task.isCancelled ? result : null;
        }),
      );
    } on AccountLocalTaskCancelledException {
      // A queued UI callback during account cleanup must not recreate data.
      return null;
    }
  }
}
