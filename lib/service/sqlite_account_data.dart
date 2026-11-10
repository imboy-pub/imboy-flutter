part of 'sqlite.dart';

Future<void> _waitForAccountDatabaseInitialization(SqliteService service) =>
    service._dbLock.synchronized(
      () => service._initLock.synchronized(() async {}),
    );

Future<void> _withClosedAccountDatabase(
  SqliteService service,
  String uid,
  String? environment,
  Future<void> Function(String name) operation,
) async {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return;
  final selectedEnvironment = environment ?? currentEnv;
  if (normalizedUid.contains('/') ||
      normalizedUid.contains('\\') ||
      normalizedUid == '.' ||
      normalizedUid == '..') {
    throw ArgumentError.value(uid, 'uid', 'must be a filename component');
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(selectedEnvironment)) {
    throw ArgumentError.value(
      environment,
      'environment',
      'invalid environment',
    );
  }
  await service._dbLock.synchronized(
    () => service._initLock.synchronized(() async {
      if (UserRepoLocal.to.currentUid == normalizedUid &&
          currentEnv == selectedEnvironment) {
        throw StateError('Cannot delete the active account database');
      }
      if (SqliteService._openUid == normalizedUid &&
          SqliteService._openEnv == selectedEnvironment) {
        // _initLock is already held: public close() would acquire it again.
        // Keep lifecycle's close-failure bookkeeping intact for an explicit retry.
        await service._closeCachedDatabase();
        service.clearQueryCache();
      }
      await operation('${selectedEnvironment}_$normalizedUid.db');
    }),
  );
}

Future<void> _closeAccountDatabase(
  SqliteService service,
  String uid, {
  String? environment,
}) => _withClosedAccountDatabase(service, uid, environment, (_) async {});

Future<void> _deleteAccountDatabase(
  SqliteService service,
  String uid, {
  String? environment,
}) => _withClosedAccountDatabase(service, uid, environment, (name) async {
  if (kIsWeb) {
    // A cold-start login page has not opened a database yet. Initialize
    // the Web factory instead of invoking SQLCipher's native channel.
    initSqfliteFactory();
    await common.databaseFactory.deleteDatabase(name);
    return;
  }
  final path = join(await getDatabasesPath(), name);
  // Restore backups and partially restored copies contain account data too.
  for (final artifact in ['', '.pre_restore.bak', '.restoring.tmp']) {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      await _deleteAccountDatabaseArtifact('$path$artifact$suffix');
    }
  }

  // Snapshot recovery preserves original.db/replacement.db and sidecars
  // here when rollback or final cleanup fails. The full basename binds the
  // directory to this exact environment and UID; never follow its links.
  final directory = Directory(dirname(path));
  final prefix = '$name.restore.';
  if (await directory.exists()) {
    await for (final entry in directory.list(followLinks: false)) {
      final entryName = basename(entry.path);
      if (entryName.startsWith(prefix) && entryName.length > prefix.length) {
        await _deleteAccountDatabaseArtifact(entry.path, recursive: true);
      }
    }
  }
});

Future<void> _deleteAccountDatabaseArtifact(
  String path, {
  bool recursive = false,
}) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.link) {
    await Link(path).delete();
  } else if (type == FileSystemEntityType.directory) {
    await Directory(path).delete(recursive: recursive);
  } else if (type != FileSystemEntityType.notFound) {
    await File(path).delete();
  }
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw FileSystemException('Database artifact still exists', path);
  }
}
