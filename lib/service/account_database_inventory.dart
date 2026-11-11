import 'package:idb_shim/idb.dart';
import 'package:path/path.dart' as p;

import 'account_database_inventory_stub.dart'
    if (dart.library.js_interop) 'account_database_inventory_web.dart';

/// Read the pinned sqflite_common_ffi_web/sqlite3 IndexedDB file catalogue.
/// Do not open SQLite or use databaseExists: that API suppresses read errors.
/// An unsupported catalogue is unknown, never evidence of an empty namespace.
Future<Set<String>> readWebAccountDatabaseArtifacts({
  IdbFactory? factory,
}) async {
  final source = factory ?? accountInventoryIdbFactory;
  var absent = false;
  late Database database;
  try {
    database = await source.open(
      'sqflite_databases',
      onUpgradeNeeded: (event) {
        absent = event.oldVersion == 0;
        // Roll back creation: an inventory must not initialize or upgrade storage.
        event.transaction.abort();
      },
    );
  } on Object {
    if (absent) return <String>{};
    rethrow;
  }
  try {
    if (database.version != 1 ||
        database.objectStoreNames.length != 2 ||
        !database.objectStoreNames.contains('files') ||
        !database.objectStoreNames.contains('blocks')) {
      throw StateError('Unknown Web SQLite file catalogue');
    }
    final transaction = database.transaction([
      'files',
      'blocks',
    ], idbModeReadOnly);
    final entriesRequest = transaction.objectStore('files').getAll();
    final blocksRequest = transaction.objectStore('blocks').count();
    final entries = await entriesRequest;
    final blockCount = await blocksRequest;
    await transaction.completed;
    if (entries.isEmpty && blockCount != 0) {
      throw StateError('Unattributed Web SQLite blocks');
    }
    final names = <String>{};
    for (final entry in entries) {
      final length = entry is Map ? entry['length'] : null;
      if (entry is! Map ||
          entry['name'] is! String ||
          (entry['name'] as String).isEmpty ||
          length is! num ||
          !length.isFinite ||
          length < 0 ||
          length != length.floorToDouble()) {
        throw StateError('Invalid Web SQLite file entry');
      }
      names.add(p.posix.basename(entry['name'] as String));
    }
    return names;
  } finally {
    database.close();
  }
}
