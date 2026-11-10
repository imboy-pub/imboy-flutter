import 'dart:convert';

import 'package:synchronized/synchronized.dart';

import 'login_account_history_service.dart';
import 'storage.dart';

/// One lock for every pending-action writer and account cleanup.
class PendingChatActions {
  PendingChatActions._();
  static final instance = PendingChatActions._();
  static const readReceiptsKey = 'imboy.pending_read_receipts.v1';
  static const reactionsKey = 'imboy.pending_reactions.v1';
  static const _keys = [readReceiptsKey, reactionsKey];
  final _lock = Lock();

  List<dynamic> _validate(Object? decoded) {
    if (decoded is! List ||
        decoded.any(
          (item) =>
              item is! Map ||
              item['from'] is! String ||
              (item['from'] as String).trim().isEmpty,
        )) {
      throw const AccountLocalDataOwnershipException();
    }
    return List<dynamic>.of(decoded);
  }

  List<dynamic> _read(String key) {
    if (!_keys.contains(key)) throw ArgumentError.value(key, 'key');
    try {
      final raw = StorageService.to.getString(key);
      if (raw.isEmpty) return [];
      return _validate(jsonDecode(raw));
    } on Object {
      throw const AccountLocalDataOwnershipException();
    }
  }

  Future<List<dynamic>> snapshot(String key) =>
      _lock.synchronized(() => _read(key));

  Future<List<dynamic>> update(
    String key,
    void Function(List<dynamic>) change, {
    required bool Function() isCurrent,
  }) => _lock.synchronized(() async {
    if (!isCurrent()) return [];
    final items = _read(key);
    change(items);
    _validate(items);
    if (!isCurrent()) return [];
    await StorageService.to.persistPreference(
      () => StorageService.to.setString(key, jsonEncode(items)),
    );
    return isCurrent() ? List<dynamic>.of(items) : [];
  });

  Future<void> validateAccountRemoval(String uid) => _lock.synchronized(() {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid');
    for (final key in _keys) {
      _read(key);
    }
  });

  Future<void> removeAccount(String uid) => _lock.synchronized(() async {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid');
    // Validate both queues before changing either; unknown owners are retained.
    final queues = {for (final key in _keys) key: _read(key)};
    for (final entry in queues.entries) {
      final remaining = entry.value
          .where((item) => (item as Map)['from'] != uid)
          .toList();
      if (remaining.length == entry.value.length) continue;
      await StorageService.to.persistPreference(
        () => remaining.isEmpty
            ? StorageService.to.remove(entry.key)
            : StorageService.to.setString(entry.key, jsonEncode(remaining)),
      );
    }
  });
}
