import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

import 'package:imboy/service/account_database_inventory.dart';

void main() {
  late IdbFactory factory;
  setUp(() {
    factory = newIdbFactoryMemory();
  });

  Future<Database> create({int version = 1, bool complete = true}) =>
      factory.open(
        'sqflite_databases',
        version: version,
        onUpgradeNeeded: (event) {
          final files = event.database.createObjectStore(
            'files',
            autoIncrement: true,
          );
          files.createIndex('fileName', 'name', unique: true);
          if (complete) event.database.createObjectStore('blocks');
        },
      );

  test('absence inspection leaves no initialized Web database', () async {
    expect(await readWebAccountDatabaseArtifacts(factory: factory), isEmpty);
    var oldVersion = -1;
    final database = await factory.open(
      'sqflite_databases',
      onUpgradeNeeded: (event) {
        oldVersion = event.oldVersion;
      },
    );
    database.close();
    expect(oldVersion, 0);
  });

  test(
    'reads all environment file names without altering records or bytes',
    () async {
      final database = await create();
      final transaction = database.transaction([
        'files',
        'blocks',
      ], idbModeReadWrite);
      final records = [
        {'name': '/pro_synthetic.db', 'length': 4},
        {'name': '/old_environment_synthetic.db-wal', 'length': 0},
        {'name': '/other_uid.db', 'length': 4.0},
      ];
      for (final record in records) {
        await transaction.objectStore('files').add(record);
      }
      await transaction.objectStore('blocks').put([1, 2, 3, 4], [1, 0]);
      await transaction.completed;
      database.close();
      expect(await readWebAccountDatabaseArtifacts(factory: factory), {
        'pro_synthetic.db',
        'old_environment_synthetic.db-wal',
        'other_uid.db',
      });
      final reopened = await factory.open('sqflite_databases');
      final check = reopened.transaction(['files', 'blocks'], idbModeReadOnly);
      final filesRequest = check.objectStore('files').getAll();
      final bytesRequest = check.objectStore('blocks').getObject([1, 0]);
      expect(await filesRequest, records);
      expect(await bytesRequest, [1, 2, 3, 4]);
      await check.completed;
      reopened.close();
    },
  );

  for (final scenario in [
    'future schema',
    'missing store',
    'malformed file',
    'orphan blocks',
  ]) {
    test('$scenario is unknown rather than empty', () async {
      final database = await create(
        version: scenario == 'future schema' ? 2 : 1,
        complete: scenario != 'missing store',
      );
      if (scenario == 'malformed file' || scenario == 'orphan blocks') {
        final transaction = database.transaction([
          'files',
          'blocks',
        ], idbModeReadWrite);
        if (scenario == 'malformed file') {
          await transaction.objectStore('files').add({'name': 42, 'length': 0});
        } else {
          await transaction.objectStore('blocks').put([1, 2], [1, 0]);
        }
        await transaction.completed;
      }
      await expectLater(
        readWebAccountDatabaseArtifacts(factory: factory),
        throwsStateError,
      );
      database.close();
    });
  }
}
