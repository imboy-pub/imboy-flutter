// Offline native-driver acceptance for local database encryption. This uses
// only disposable databases and synthetic values, never application accounts.
// It does not attest OS key-store persistence or retained-data installation.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as native;

const _password = 'synthetic-database-password-for-offline-acceptance';
const _wrongPassword = 'synthetic-wrong-database-password';

String _canary() {
  final random = Random.secure();
  final suffix = List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'imboy-synthetic-plaintext-$suffix';
}

Future<native.Database> _track(Future<native.Database> opening) async {
  final database = await opening;
  addTearDown(() async {
    if (database.isOpen) await database.close();
  });
  return database;
}

Future<void> _createProofTable(native.Database database, int _) async {
  await database.execute(
    'CREATE TABLE proof (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
  );
}

Future<void> _expectEncryptedFile(
  String databasePath,
  Iterable<String> canaries,
) async {
  final bytes = await File(databasePath).readAsBytes();
  expect(bytes.length, greaterThan(16), reason: 'database must contain pages');
  expect(
    latin1.decode(bytes.take(16).toList()),
    isNot('SQLite format 3\u0000'),
    reason: 'an encrypted database must not retain the plaintext header',
  );
  final content = latin1.decode(bytes);
  for (final canary in canaries) {
    expect(content, isNot(contains(canary)), reason: databasePath);
  }
}

Future<void> _expectNoPlaintext(
  String filePath,
  Iterable<String> canaries,
) async {
  final content = latin1.decode(await File(filePath).readAsBytes());
  for (final canary in canaries) {
    expect(content, isNot(contains(canary)), reason: filePath);
  }
}

Future<void> _expectRejectedRead(
  Future<native.Database> Function() open,
) async {
  native.Database? probe;
  try {
    await expectLater(() async {
      probe = await open();
      await probe!.rawQuery('SELECT count(*) FROM sqlite_master');
    }(), throwsA(isA<native.DatabaseException>()));
  } finally {
    // Cleanup errors must fail the case, not count as password rejection.
    if (probe != null && probe!.isOpen) await probe!.close();
  }
}

Future<void> _expectUnkeyedReadRejected(String databasePath) =>
    _expectRejectedRead(
      () => native.openDatabase(
        databasePath,
        readOnly: true,
        singleInstance: false,
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    expect(
      isEncryptionSupported,
      isTrue,
      reason:
          'requires the actual Android/iOS/macOS SQLCipher plugin; '
          'host SQLite and skipped execution are not encryption evidence',
    );
    initSqfliteFactory();
    directory = await (await getTemporaryDirectory()).createTemp(
      'imboy_sqlcipher_acceptance_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
  });

  testWidgets('new database is encrypted and survives a keyed reopen', (
    tester,
  ) async {
    final databasePath = path.join(directory.path, 'new.db');
    final canary = _canary();
    var configured = false;
    var created = 0;
    final database = await _track(
      openEncryptedDatabase(
        databasePath,
        password: _password,
        version: 1,
        onConfigure: (db) async {
          final cipher = await db.rawQuery('PRAGMA cipher_version');
          expect(cipher, hasLength(1));
          expect(cipher.single.values.single, isA<String>());
          expect(cipher.single.values.single, isNot(isEmpty));
          configured = true;
        },
        onCreate: (db, version) async {
          expect(configured, isTrue);
          created++;
          await _createProofTable(db, version);
        },
      ),
    );
    await database.insert('proof', {'id': 1, 'value': canary});
    expect(created, 1);
    await database.close();

    await _expectEncryptedFile(databasePath, [canary]);
    await _expectUnkeyedReadRejected(databasePath);
    final reopened = await _track(
      openEncryptedDatabase(databasePath, password: _password, readOnly: true),
    );
    expect(await reopened.query('proof'), [
      {'id': 1, 'value': canary},
    ]);
    expect(
      (await reopened.rawQuery('PRAGMA user_version')).single.values.single,
      1,
    );
    expect(
      (await reopened.rawQuery('PRAGMA quick_check')).single.values.single,
      'ok',
    );
  });

  testWidgets('wrong key cannot borrow an open handle or replace its file', (
    tester,
  ) async {
    final databasePath = path.join(directory.path, 'existing.db');
    final canary = _canary();
    final database = await _track(
      openEncryptedDatabase(
        databasePath,
        password: _password,
        version: 1,
        onConfigure: (db) async {
          final mode = await db.rawQuery('PRAGMA journal_mode = DELETE');
          expect(mode.single.values.single, 'delete');
        },
        onCreate: _createProofTable,
      ),
    );
    await database.insert('proof', {'id': 1, 'value': canary});
    await database.close();
    final original = await File(databasePath).readAsBytes();

    final correct = await _track(
      openEncryptedDatabase(databasePath, password: _password, readOnly: true),
    );
    await _expectRejectedRead(
      () => openEncryptedDatabase(
        databasePath,
        password: _wrongPassword,
        readOnly: true,
      ),
    );
    await _expectUnkeyedReadRejected(databasePath);
    expect(correct.isOpen, isTrue);
    expect((await correct.query('proof')).single['value'], canary);
    await correct.close();

    expect(await File(databasePath).readAsBytes(), orderedEquals(original));
    expect(await File('$databasePath.plain.bak').exists(), isFalse);
    expect(await File('$databasePath.pre_encrypt.bak').exists(), isFalse);
  });

  testWidgets('missing and empty passwords fail before creating a file', (
    tester,
  ) async {
    for (final password in <String?>[null, '']) {
      final databasePath = path.join(
        directory.path,
        password == null ? 'missing-key.db' : 'empty-key.db',
      );
      var configured = false;
      await expectLater(
        openEncryptedDatabase(
          databasePath,
          password: password,
          onConfigure: (_) async {
            configured = true;
          },
        ),
        throwsStateError,
      );
      expect(configured, isFalse);
      expect(await File(databasePath).exists(), isFalse);
    }
  });

  testWidgets('a legacy plaintext database is refused and preserved', (
    tester,
  ) async {
    final databasePath = path.join(directory.path, 'legacy-plaintext.db');
    // Reuse the tracked, empty baseline database. Copy only into the test's
    // disposable directory; never open an application's retained database.
    final asset = await rootBundle.load('assets/example10.db');
    final original = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    await File(databasePath).writeAsBytes(original, flush: true);
    expect(latin1.decode(original.take(16).toList()), 'SQLite format 3\u0000');
    final plaintext = await _track(
      native.openDatabase(databasePath, readOnly: true, singleInstance: false),
    );
    expect(
      (await plaintext.rawQuery('SELECT count(*) FROM sqlite_master'))
          .single
          .values
          .single,
      greaterThan(0),
    );
    await plaintext.close();

    await _expectRejectedRead(
      () => openEncryptedDatabase(
        databasePath,
        password: _password,
        readOnly: true,
      ),
    );
    expect(await File(databasePath).readAsBytes(), orderedEquals(original));
    expect(await File('$databasePath.plain.bak').exists(), isFalse);
    expect(await File('$databasePath.pre_encrypt.bak').exists(), isFalse);
  });

  testWidgets('WAL and snapshot stay encrypted without closing the writer', (
    tester,
  ) async {
    final databasePath = path.join(directory.path, 'wal.db');
    final first = _canary();
    final inWal = _canary();
    final afterSnapshot = _canary();
    final database = await _track(
      openEncryptedDatabase(
        databasePath,
        password: _password,
        version: 1,
        onConfigure: (db) async {
          final mode = await db.rawQuery('PRAGMA journal_mode = WAL');
          expect(mode.single.values.single, 'wal');
          await db.rawQuery('PRAGMA wal_autocheckpoint = 0');
        },
        onCreate: _createProofTable,
      ),
    );
    await database.insert('proof', {'id': 1, 'value': first});
    final checkpoint = await database.rawQuery(
      'PRAGMA wal_checkpoint(TRUNCATE)',
    );
    expect(checkpoint.single['busy'], 0);
    await database.insert('proof', {'id': 2, 'value': inWal});
    final wal = File('$databasePath-wal');
    expect(await wal.exists(), isTrue);
    expect(await wal.length(), greaterThan(32));
    await _expectNoPlaintext(wal.path, [first, inWal]);

    final snapshot = await DatabaseSnapshotService.to.createSnapshot(
      sourcePath: databasePath,
      base: directory.path,
      env: 'sqlcipher_acceptance',
      uid: 'synthetic',
      password: _password,
      expectedVersion: 1,
    );
    expect(snapshot.success, isTrue, reason: snapshot.error);
    expect(snapshot.path, isNotNull);
    expect(database.isOpen, isTrue);
    expect(await database.query('proof', orderBy: 'id'), [
      {'id': 1, 'value': first},
      {'id': 2, 'value': inWal},
    ]);

    // The original writer must still work after the snapshot's private
    // source and verification connections have been closed.
    await database.insert('proof', {'id': 3, 'value': afterSnapshot});
    expect(await database.query('proof'), hasLength(3));
    final copy = await _track(
      openEncryptedDatabase(
        snapshot.path!,
        password: _password,
        readOnly: true,
      ),
    );
    expect(await copy.query('proof', orderBy: 'id'), [
      {'id': 1, 'value': first},
      {'id': 2, 'value': inWal},
    ]);
    expect(
      (await copy.rawQuery('PRAGMA user_version')).single.values.single,
      1,
    );
    await copy.close();

    await _expectEncryptedFile(snapshot.path!, [first, inWal, afterSnapshot]);
    await _expectUnkeyedReadRejected(snapshot.path!);
    await _expectRejectedRead(
      () => openEncryptedDatabase(
        snapshot.path!,
        password: _wrongPassword,
        readOnly: true,
      ),
    );
    await _expectNoPlaintext(wal.path, [first, inWal, afterSnapshot]);
    for (final suffix in ['-shm', '-journal']) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        await _expectNoPlaintext(sidecar.path, [first, inWal, afterSnapshot]);
      }
    }
    await database.close();
    await _expectEncryptedFile(databasePath, [first, inWal, afterSnapshot]);
  });
}
