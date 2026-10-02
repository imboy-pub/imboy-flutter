import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'macos_storage_isolation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('macOS native storage stays in a fresh test namespace', (
    tester,
  ) async {
    expect(Platform.isMacOS, isTrue);
    await tester.runAsync(() async {
      expect((await PackageInfo.fromPlatform()).packageName, 'pub.imboy.app');
      final root = await isolateMacosStorage();
      Database? db;
      addTearDown(() async {
        await db?.close();
        await clearMacosStorage(root);
      });
      expect((await getApplicationSupportDirectory()).path, root.path);
      expect((await getTemporaryDirectory()).path, root.path);
      expect(await getDatabasesPath(), root.path);
      db = await openDatabase(
        '${root.path}/native-storage-check.db',
        password: 'synthetic-only',
      );
      await db.execute('CREATE TABLE native_check (value TEXT NOT NULL)');
      await db.insert('native_check', {'value': 'synthetic-only'});
      expect(await db.query('native_check'), [
        {'value': 'synthetic-only'},
      ]);
      await db.close();
      db = null;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(await prefs.setString('sentinel', 'synthetic-only'), isTrue);
      await prefs.reload();
      expect(prefs.getString('sentinel'), 'synthetic-only');
      expect(await prefs.clear(), isTrue);
      const secure = FlutterSecureStorage();
      expect(await secure.readAll(), isEmpty);
      await secure.write(key: 'sentinel', value: 'synthetic-only');
      expect(await secure.read(key: 'sentinel'), 'synthetic-only');
      expect(await secure.containsKey(key: 'sentinel'), isTrue);
      await secure.delete(key: 'sentinel');
      expect(await secure.containsKey(key: 'sentinel'), isFalse);
      await secure.write(key: 'sentinel', value: 'synthetic-only');
      await secure.deleteAll();
      expect(await secure.readAll(), isEmpty);
    });
  });
}
