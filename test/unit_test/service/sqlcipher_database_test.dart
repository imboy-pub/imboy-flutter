import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlcipher_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

// Exercise the real sqflite_sqlcipher factory and callback handling with its
// native MethodChannel protocol. These tests do not prove encryption at rest.
class _NativeDatabaseChannel {
  final calls = <MethodCall>[];
  final events = <String>[];
  final closedIds = <int>[];
  final unreadablePasswords = <String>{};
  final _passwords = <int, String>{};
  List<Object?> cipherVersions = ['4.6.1-synthetic'];
  int userVersion = 0;
  int _nextId = 1;

  List<Map<Object?, Object?>> get opens => calls
      .where((call) => call.method == 'openDatabase')
      .map((call) => call.arguments as Map<Object?, Object?>)
      .toList();

  Iterable<MethodCall> get writes =>
      calls.where((call) => call.method == 'execute');

  Map<String, Object> _rows(String column, List<Object?> values) => {
    'columns': [column],
    'rows': values.map((value) => [value]).toList(),
  };

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    final arguments = call.arguments as Map<Object?, Object?>;
    switch (call.method) {
      case 'openDatabase':
        final id = _nextId++;
        _passwords[id] = arguments['password'] as String;
        events.add('native-open');
        return {'id': id};
      case 'closeDatabase':
        closedIds.add(arguments['id'] as int);
        events.add('native-close');
        return null;
      case 'query':
        final sql = arguments['sql'] as String;
        switch (sql) {
          case 'PRAGMA cipher_version':
            events.add('cipher-version');
            return _rows('cipher_version', cipherVersions);
          case 'SELECT count(*) FROM sqlite_master':
            events.add('schema-read');
            if (unreadablePasswords.contains(_passwords[arguments['id']])) {
              throw PlatformException(
                code: 'sqlite_error',
                message: 'synthetic database is unreadable',
              );
            }
            return _rows('count(*)', [1]);
          case 'PRAGMA user_version':
            return _rows('user_version', [userVersion]);
          default:
            throw StateError('Unexpected query in native fixture: $sql');
        }
      case 'execute':
        final sql = arguments['sql'] as String;
        final version = RegExp(r'^PRAGMA user_version = (\d+)$')
            .firstMatch(sql);
        if (version != null) userVersion = int.parse(version.group(1)!);
        return null;
      default:
        throw StateError('Unexpected native method: ${call.method}');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const key = 'synthetic-database-password';
  late _NativeDatabaseChannel native;
  late String databasePath;
  var sequence = 0;

  setUp(() {
    native = _NativeDatabaseChannel();
    databasePath = path.join(
      Directory.systemTemp.path,
      'imboy-sqlcipher-contract-${sequence++}.db',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final password in <String?>[null, '']) {
    test(
      'rejects an absent or empty key before native open: $password',
      () async {
        await expectLater(
          openSqlCipherDatabase(databasePath, password: password),
          throwsStateError,
        );
        expect(native.calls, isEmpty);
      },
    );
  }

  for (final versions in <List<Object?>>[
    [],
    [''],
    ['  '],
    [null],
  ]) {
    test(
      'rejects missing SQLCipher capability before application callbacks: $versions',
      () async {
        native.cipherVersions = versions;
        final callbacks = <String>[];

        await expectLater(
          openSqlCipherDatabase(
            databasePath,
            password: key,
            version: 3,
            onConfigure: (_) async => callbacks.add('configure'),
            onCreate: (_, version) async => callbacks.add('create'),
            onUpgrade: (_, oldVersion, newVersion) async =>
                callbacks.add('upgrade'),
            onOpen: (_) async => callbacks.add('open'),
          ),
          throwsStateError,
        );

        expect(callbacks, isEmpty);
        expect(native.closedIds, [1]);
        expect(native.writes, isEmpty);
        expect(native.events, isNot(contains('schema-read')));
      },
    );
  }

  for (final readOnly in [false, true]) {
    test(
      'rejects an unreadable database and closes the handle (readOnly=$readOnly)',
      () async {
        native.unreadablePasswords.add(key);
        final callbacks = <String>[];

        await expectLater(
          openSqlCipherDatabase(
            databasePath,
            password: key,
            readOnly: readOnly,
            onConfigure: (_) async => callbacks.add('configure'),
            onOpen: (_) async => callbacks.add('open'),
          ),
          throwsA(isA<DatabaseException>()),
        );

        expect(callbacks, isEmpty);
        expect(
          native.events,
          containsAllInOrder(['cipher-version', 'schema-read', 'native-close']),
        );
        expect(native.closedIds, [1]);
        expect(native.writes, isEmpty);
        expect(native.opens.single['readOnly'] == true, readOnly);
      },
    );
  }

  test(
    'read-only probes ignore application callbacks and schema version',
    () async {
      native.userVersion = 2;
      final callbacks = <String>[];
      final db = await openSqlCipherDatabase(
        databasePath,
        password: key,
        readOnly: true,
        version: 3,
        onConfigure: (_) async => callbacks.add('configure'),
        onCreate: (_, version) async => callbacks.add('create'),
        onUpgrade: (_, oldVersion, newVersion) async =>
            callbacks.add('upgrade'),
        onDowngrade: (_, oldVersion, newVersion) async =>
            callbacks.add('downgrade'),
        onOpen: (_) async => callbacks.add('open'),
      );
      try {
        expect(db.isOpen, isTrue);
        expect(native.opens.single['readOnly'], isTrue);
        expect(native.events, ['native-open', 'cipher-version', 'schema-read']);
        expect(callbacks, isEmpty);
        expect(native.userVersion, 2);
        expect(native.writes, isEmpty);
      } finally {
        await db.close();
      }
      expect(native.closedIds, [1]);
    },
  );

  test('read-only probe still rejects a non-SQLCipher driver', () async {
    native.cipherVersions = [];
    await expectLater(
      openSqlCipherDatabase(databasePath, password: key, readOnly: true),
      throwsStateError,
    );
    expect(native.opens.single['readOnly'], isTrue);
    expect(native.closedIds, [1]);
    expect(native.writes, isEmpty);
  });

  test(
    'another password opens independently instead of reusing a live handle',
    () async {
      const wrongKey = 'synthetic-wrong-password';
      native.unreadablePasswords.add(wrongKey);
      final live = await openSqlCipherDatabase(databasePath, password: key);
      try {
        await expectLater(
          openSqlCipherDatabase(
            databasePath,
            password: wrongKey,
            readOnly: true,
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(native.opens, hasLength(2));
        expect(native.opens.map((args) => args['password']), [key, wrongKey]);
        expect(
          native.opens.every((args) => args['singleInstance'] == false),
          isTrue,
        );
        expect(native.closedIds, [2]);
        expect(live.isOpen, isTrue);
        expect(await live.rawQuery('SELECT count(*) FROM sqlite_master'), [
          {'count(*)': 1},
        ]);
      } finally {
        await live.close();
      }
      expect(native.closedIds, [2, 1]);
    },
  );

  for (final fromVersion in [0, 2, 4]) {
    test(
      'preserves configure, version callback and open order from v$fromVersion',
      () async {
        native.userVersion = fromVersion;
        final callbacks = <String>[];
        final db = await openSqlCipherDatabase(
          databasePath,
          password: key,
          version: 3,
          onConfigure: (_) async {
            expect(native.events, [
              'native-open',
              'cipher-version',
              'schema-read',
            ]);
            callbacks.add('configure');
          },
          onCreate: (_, version) async => callbacks.add('create:$version'),
          onUpgrade: (_, oldVersion, newVersion) async =>
              callbacks.add('upgrade:$oldVersion:$newVersion'),
          onDowngrade: (_, oldVersion, newVersion) async =>
              callbacks.add('downgrade:$oldVersion:$newVersion'),
          onOpen: (_) async {
            expect(native.userVersion, 3);
            callbacks.add('open');
          },
        );
        try {
          expect(callbacks, [
            'configure',
            if (fromVersion == 0)
              'create:3'
            else if (fromVersion < 3)
              'upgrade:$fromVersion:3'
            else
              'downgrade:$fromVersion:3',
            'open',
          ]);
          expect(native.opens.single['password'], key);
          expect(native.opens.single['singleInstance'], isFalse);
        } finally {
          await db.close();
        }
        expect(native.closedIds, [1]);
      },
    );
  }
}
