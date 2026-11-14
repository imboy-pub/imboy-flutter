import 'dart:convert';
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
  await _installMacosStorage(root);
  return root;
}

Directory? _installedMacosStorageRoot;

Future<void> _installMacosStorage(Directory root) async {
  final namespace =
      'imboy-enterprise-native-${root.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}';
  SharedPreferences.setPrefix('$namespace.');
  FlutterSecureStoragePlatform.instance = _ScopedKeychain(namespace);
  PathProviderPlatform.instance = _ScopedPaths(root.path);
  // ignore: deprecated_member_use
  await databaseFactory.setDatabasesPath(root.path);
  _installedMacosStorageRoot = root;
}

/// File-only preparation permits host checks without touching native storage.
Future<Directory> prepareH2MacosStorageDirectory(
  String runTag,
  String expectedUid, {
  required bool restore,
}) async {
  _validateH2StorageIdentity(runTag, expectedUid);
  final temp = await Directory.systemTemp.resolveSymbolicLinks();
  return _prepareH2StorageDirectory(
    temp,
    runTag,
    expectedUid,
    restore: restore,
  );
}

void _validateH2StorageIdentity(String runTag, String expectedUid) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$').hasMatch(runTag) ||
      !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(expectedUid)) {
    throw ArgumentError('H2 storage requires a safe run tag and numeric UID');
  }
}

/// Resolve persistent Android support storage before installing scoped paths.
/// File-only so host tests can exercise restore without a native plugin.
Future<Directory> prepareH2AndroidStorageDirectory(
  String runTag,
  String expectedUid, {
  required bool restore,
}) async {
  _validateH2StorageIdentity(runTag, expectedUid);
  final paths = PathProviderPlatform.instance;
  if (paths is _ScopedPaths) throw StateError('Native storage already scoped');
  final support = await paths.getApplicationSupportPath();
  if (support == null || support.isEmpty) {
    throw StateError('Native application support path is unavailable');
  }
  final base = await Directory(support).resolveSymbolicLinks();
  final root = await _prepareH2StorageDirectory(
    base,
    runTag,
    expectedUid,
    restore: restore,
  );
  final marker = File('${root.path}/.h2-owner.json');
  if (!restore) {
    final chmod = await Process.run(
      Platform.isAndroid ? '/system/bin/chmod' : '/bin/chmod',
      ['600', marker.path],
    );
    if (chmod.exitCode != 0) {
      throw StateError('Cannot protect Android scope marker');
    }
  }
  if (((await marker.stat()).mode & 0x1ff) != 0x180) {
    throw StateError('Unsafe Android scope marker permissions');
  }
  return root;
}

Future<Directory> _prepareH2StorageDirectory(
  String base,
  String runTag,
  String expectedUid, {
  required bool restore,
}) async {
  final root = Directory('$base/imboy-h2-c2c-$runTag-$expectedUid');
  final marker = File('${root.path}/.h2-owner.json');
  final identity = jsonEncode({
    'owner': 'imboy-h2-c2c-v1',
    'runTag': runTag,
    'expectedUid': expectedUid,
  });
  final type = await FileSystemEntity.type(root.path, followLinks: false);
  if (!restore) {
    if (type != FileSystemEntityType.notFound) {
      throw StateError('H2 storage already exists; use a new run tag');
    }
    final creation = await Process.run(
      Platform.isAndroid ? '/system/bin/mkdir' : '/bin/mkdir',
      ['-m', '700', root.path],
    );
    if (creation.exitCode != 0) {
      throw StateError('Cannot exclusively create private H2 storage');
    }
  }
  if (await FileSystemEntity.type(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      await root.resolveSymbolicLinks() != root.path ||
      ((await root.stat()).mode & 0x3f) != 0) {
    throw StateError('Unsafe H2 storage directory');
  }
  if (!restore) {
    await marker.create(exclusive: true);
    await marker.writeAsString(identity, flush: true);
  }
  if (await FileSystemEntity.type(marker.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await marker.readAsString() != identity) {
    throw StateError('H2 storage ownership mismatch');
  }
  return root;
}

/// B creates this run's scope; its history process must restore the same scope.
Future<Directory> isolateH2MacosStorage(
  String runTag,
  String expectedUid, {
  required bool restore,
}) async {
  if (!Platform.isMacOS) throw StateError('macOS only');
  final root = await prepareH2MacosStorageDirectory(
    runTag,
    expectedUid,
    restore: restore,
  );
  await _installMacosStorage(root);
  return root;
}

/// Persistent owned identity: create once, restore on later process runs.
Future<Directory> isolateH2NativeStorage(
  String runTag,
  String expectedUid, {
  required bool restore,
}) async {
  if (Platform.isMacOS) {
    return isolateH2MacosStorage(runTag, expectedUid, restore: restore);
  }
  if (!Platform.isAndroid) throw StateError('Android or macOS only');
  final root = await prepareH2AndroidStorageDirectory(
    runTag,
    expectedUid,
    restore: restore,
  );
  await _installAndroidStorage(root);
  return root;
}

/// Clean only the scope still installed in this history process, after disposal.
Future<void> clearH2MacosStorage(String runTag, String expectedUid) async {
  final root = await prepareH2MacosStorageDirectory(
    runTag,
    expectedUid,
    restore: true,
  );
  final namespace =
      'imboy-enterprise-native-${root.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}';
  final keychain = FlutterSecureStoragePlatform.instance;
  final paths = PathProviderPlatform.instance;
  if (_installedMacosStorageRoot?.path != root.path ||
      keychain is! _ScopedKeychain ||
      keychain.service != namespace ||
      keychain.androidNamespace ||
      paths is! _ScopedPaths ||
      paths.path != root.path) {
    throw StateError('H2 cleanup requires its installed storage scope');
  }
  await clearMacosStorage(root);
}

/// Isolate Android before app.main without touching the installed user's data.
/// macOS continues to use the original Keychain-service isolation above.
Future<Directory> isolateNativeStorage() async {
  if (Platform.isMacOS) return isolateMacosStorage();
  if (!Platform.isAndroid) throw StateError('Android or macOS only');
  final root = await Directory.systemTemp.createTemp(
    'imboy-enterprise-native-',
  );
  await _installAndroidStorage(root);
  return root;
}

Future<void> _installAndroidStorage(Directory root) async {
  final namespace =
      'imboy-enterprise-native-${root.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}';
  SharedPreferences.setPrefix('$namespace.');
  FlutterSecureStoragePlatform.instance = androidScopedSecureStorage(namespace);
  PathProviderPlatform.instance = _ScopedPaths(root.path);
  // ignore: deprecated_member_use
  await databaseFactory.setDatabasesPath(root.path);
}

/// Uses the plugin's full Android namespace, including KeyStore/config artifacts.
FlutterSecureStoragePlatform androidScopedSecureStorage(String namespace) {
  if (!namespace.startsWith('imboy-enterprise-native-')) {
    throw ArgumentError.value(namespace, 'namespace');
  }
  return _ScopedKeychain(namespace, androidNamespace: true);
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
  _ScopedKeychain(this.service, {this.androidNamespace = false});
  final bool androidNamespace;
  final String service;
  Map<String, String> scoped(Map<String, String> options) => {
    ...options,
    if (androidNamespace) ...{
      'storageNamespace': service,
      'preferencesKeyPrefix': service,
    } else
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
