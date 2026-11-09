import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Opens an independent SQLCipher connection, failing before application writes
/// if the password or native encryption implementation is unavailable.
///
/// The application owns connection reuse in SqliteService. The plugin's path
/// cache must not bypass a different password or lend its handle to a probe.
Future<sqlcipher.Database> openSqlCipherDatabase(
  String path, {
  String? password,
  int? version,
  sqlcipher.OnDatabaseConfigureFn? onConfigure,
  sqlcipher.OnDatabaseCreateFn? onCreate,
  sqlcipher.OnDatabaseVersionChangeFn? onUpgrade,
  sqlcipher.OnDatabaseVersionChangeFn? onDowngrade,
  sqlcipher.OnDatabaseOpenFn? onOpen,
  bool readOnly = false,
}) async {
  if (password == null || password.isEmpty) {
    // Never include the supplied password in an exception or log.
    throw StateError('A database encryption key is required');
  }

  final db = await sqlcipher.openDatabase(
    path,
    password: password,
    version: readOnly ? null : version,
    singleInstance: false,
    readOnly: readOnly,
    onConfigure: readOnly
        ? null
        : (db) async {
            await _verifyEncryption(db);
            await onConfigure?.call(db);
          },
    onCreate: readOnly ? null : onCreate,
    onUpgrade: readOnly ? null : onUpgrade,
    onDowngrade: readOnly ? null : onDowngrade,
    onOpen: readOnly ? null : onOpen,
  );

  // Explicitly suppress callbacks/version changes for read-only probes: the
  // SQLCipher options implementation does not discard them automatically.
  // Android's read-only corruption handler also preserves the existing file.
  if (readOnly) {
    try {
      await _verifyEncryption(db);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
  return db;
}

Future<void> _verifyEncryption(sqlcipher.Database db) async {
  final rows = await db.rawQuery('PRAGMA cipher_version');
  final cipherVersion = rows.isEmpty ? null : rows.first['cipher_version'];
  if (cipherVersion is! String || cipherVersion.trim().isEmpty) {
    throw StateError('The native database driver does not provide SQLCipher');
  }
  // Opening alone does not validate the key. Read a real database page before
  // any application configuration, schema migration or data write can run.
  await db.rawQuery('SELECT count(*) FROM sqlite_master');
}
