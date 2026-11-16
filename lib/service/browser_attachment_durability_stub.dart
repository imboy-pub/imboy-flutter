import 'package:sqflite_common/sqlite_api.dart';

Future<void> durableBrowserAccountDatabase(
  Database database, {
  required String databaseName,
}) => Future<void>.error(
  UnsupportedError('Browser material durability is Web-only'),
);
