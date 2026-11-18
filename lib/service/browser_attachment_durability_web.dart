import 'package:sqflite_common/sqlite_api.dart';

import 'browser_sqlite_storage_bridge_web.dart';

Future<void> durableBrowserAccountDatabase(
  Database database, {
  required String databaseName,
}) => browserSqliteStorageBridge.durableAccountBarrier(
  database,
  databaseName: databaseName,
);
