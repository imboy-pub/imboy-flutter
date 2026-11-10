import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import 'account_local_task_registry.dart';
import 'account_media_cache_web_stub.dart'
    if (dart.library.js_interop) 'account_media_cache_web.dart';
import 'login_account_history_service.dart';
import 'storage.dart';

/// Ownership is persisted before either CrossCache or the materialized file is
/// written. Keeping the index until removal succeeds makes partial failures
/// attributable on the next attempt, including after a process restart.
class AccountMediaCacheStore {
  AccountMediaCacheStore({
    Future<Directory> Function()? cacheDirectory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const indexPrefix = 'account_media_cache_v1_';
  static const temporaryDirectoryName = 'account_media_cache';
  static final _indexLock = Lock();
  final Future<Directory> Function() _cacheDirectory;
  final Future<Directory> Function() _temporaryDirectory;

  static String digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static String scopeId(AccountLocalTaskOwner owner) =>
      owner.uid.isEmpty ? 'device-public' : owner.storageDigest;

  static String cacheKey(AccountLocalTaskOwner owner, String resource) =>
      'account-media-v1:${scopeId(owner)}:${digest(resource)}';

  static String indexKey(AccountLocalTaskOwner owner) =>
      '$indexPrefix${scopeId(owner)}';

  Future<String> reserve(AccountLocalTaskOwner owner, String resource) =>
      _indexLock.synchronized(() async {
        final key = cacheKey(owner, resource);
        final keys = _readIndex(indexKey(owner));
        if (!keys.contains(key)) {
          await StorageService.to.persistPreference(
            () => StorageService.to.setList(indexKey(owner), [...keys, key]),
          );
        }
        return key;
      });

  Future<Directory> materializedDirectory(AccountLocalTaskOwner owner) async =>
      Directory(
        p.join(
          (await _temporaryDirectory()).path,
          temporaryDirectoryName,
          scopeId(owner),
        ),
      );

  static List<String> _readIndex(String preference) {
    final scope = preference.substring(indexPrefix.length);
    if (scope != 'device-public' &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(scope)) {
      throw const AccountLocalDataOwnershipException();
    }
    List<String> keys;
    try {
      keys = StorageService.to.getStringList(preference) ?? const [];
    } on Object {
      throw const AccountLocalDataOwnershipException();
    }
    final keyPattern = RegExp(
      '^account-media-v1:${RegExp.escape(scope)}:[a-f0-9]{64}\$',
    );
    if (keys.any((key) => !keyPattern.hasMatch(key))) {
      throw const AccountLocalDataOwnershipException();
    }
    return keys;
  }

  /// Old flat caches contain no account identity. A last-login profile cannot
  /// prove ownership of those bytes, so refuse before deleting any account data.
  Future<void> assertRemovalCanBeAttributed() => _indexLock.synchronized(
    () async {
      final preferences = StorageService.to.getKeys().where(
        (key) => key.startsWith(indexPrefix),
      );
      final keys = <String>{};
      final scopes = <String>{};
      for (final preference in preferences) {
        scopes.add(preference.substring(indexPrefix.length));
        keys.addAll(_readIndex(preference));
      }
      if (kIsWeb) {
        await assertWebMediaOwnership(keys);
        return;
      }
      final cache = Directory(
        p.join((await _cacheDirectory()).path, 'cross_cache'),
      );
      final knownFiles = keys.map(digest).toSet();
      if (await cache.exists()) {
        await for (final entry in cache.list(followLinks: false)) {
          if (entry is! File || !knownFiles.contains(p.basename(entry.path))) {
            throw const AccountLocalDataOwnershipException();
          }
        }
      }
      final temporary = await _temporaryDirectory();
      final legacy = Directory(p.join(temporary.path, 'imboy_cache'));
      if (await legacy.exists() &&
          !await legacy.list(followLinks: false).isEmpty) {
        throw const AccountLocalDataOwnershipException();
      }
      final root = Directory(p.join(temporary.path, temporaryDirectoryName));
      if (await root.exists()) {
        await for (final entry in root.list(followLinks: false)) {
          if (entry is! Directory || !scopes.contains(p.basename(entry.path))) {
            throw const AccountLocalDataOwnershipException();
          }
        }
      }
    },
  );

  Future<void> removeAccount(
    AccountLocalTaskOwner owner, {
    required Future<void> Function(String) deleteKey,
    required Future<bool> Function(String) containsKey,
  }) => _indexLock.synchronized(() async {
    final preference = indexKey(owner);
    for (final key in _readIndex(preference)) {
      await deleteKey(key);
      if (await containsKey(key)) {
        throw StateError('An account media cache entry could not be removed');
      }
    }
    if (!kIsWeb) {
      final directory = await materializedDirectory(owner);
      await _deletePath(directory.path);
    }
    await StorageService.to.persistPreference(
      () => StorageService.to.remove(preference),
    );
  });

  /// A corrupt image retry removes only this resource. Its registration remains
  /// while another request might still be writing the same account's resource.
  Future<void> removeResourceFiles(
    AccountLocalTaskOwner owner,
    String key,
  ) async {
    if (kIsWeb) return;
    final directory = await materializedDirectory(owner);
    if (!await directory.exists()) return;
    final prefix = '${digest(key)}.';
    await for (final entry in directory.list(followLinks: false)) {
      if (p.basename(entry.path).startsWith(prefix)) {
        await _deletePath(entry.path);
      }
    }
  }

  static Future<void> _deletePath(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else {
      await File(path).delete();
    }
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('Account media files still exist', path);
    }
  }
}
