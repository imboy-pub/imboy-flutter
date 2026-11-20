import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

class GeoPlatformStorage {
  static const _store = 'resources';

  Future<T> _run<T>(
    String mode,
    Future<T> Function(ObjectStore) operation,
  ) async {
    final db = await idbFactoryBrowser.open(
      'imboy-geo-regions-v1',
      version: 1,
      onUpgradeNeeded: (event) => event.database.createObjectStore(_store),
    );
    try {
      final txn = db.transaction(_store, mode);
      final result = await Future.wait<Object?>([
        operation(txn.objectStore(_store)),
        txn.completed,
      ]);
      return result.first as T;
    } finally {
      db.close();
    }
  }

  Future<Uint8List?> read(String key) async =>
      await _run<Object?>('readonly', (store) => store.getObject(key))
          as Uint8List?;

  Future<void> write(String key, Uint8List bytes) async {
    await _run<Object>('readwrite', (store) => store.put(bytes, key));
  }

  Future<void> remove(String key) =>
      _run<void>('readwrite', (store) => store.delete(key));

  Future<List<String>> keys() async => (await _run<List<Object>>(
    'readonly',
    (store) => store.getAllKeys(),
  )).whereType<String>().toList();

  Future<void> clear() => _run<void>('readwrite', (store) => store.clear());
}
