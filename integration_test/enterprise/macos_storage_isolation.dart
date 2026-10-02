import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Existing plugin interface; only the test Keychain service is changed.
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Keep real native storage, isolated from the user's preferences and secrets.
Future<Directory> isolateMacosStorage() async {
  if (!Platform.isMacOS) throw StateError('macOS only');
  final root = await Directory.systemTemp.createTemp(
    'imboy-enterprise-native-',
  );
  final namespace =
      'imboy-enterprise-native-${root.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}';
  SharedPreferences.setPrefix('$namespace.');
  FlutterSecureStoragePlatform.instance = _ScopedKeychain(namespace);
  PathProviderPlatform.instance = _ScopedPaths(root.path);
  // ignore: deprecated_member_use
  await databaseFactory.setDatabasesPath(root.path);
  return root;
}

/// Call after disposing the app and closing its database; keep scope installed.
Future<void> clearMacosStorage(Directory root) async {
  await const FlutterSecureStorage().deleteAll();
  await (await SharedPreferences.getInstance()).clear();
  await root.delete(recursive: true);
}

class _ScopedPaths extends PathProviderPlatform {
  _ScopedPaths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
  @override
  Future<String?> getDownloadsPath() async => path;
}

class _ScopedKeychain extends MethodChannelFlutterSecureStorage {
  _ScopedKeychain(this.service);
  final String service;
  Map<String, String> scoped(Map<String, String> options) => {
    ...options,
    'accountName': service,
  };
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => super.write(key: key, value: value, options: scoped(options));
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => super.read(key: key, options: scoped(options));
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => super.containsKey(key: key, options: scoped(options));
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => super.delete(key: key, options: scoped(options));
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      super.readAll(options: scoped(options));
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      super.deleteAll(options: scoped(options));
}
