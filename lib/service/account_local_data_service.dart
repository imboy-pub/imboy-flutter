import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/organization/public.dart'
    show CurrentOrganizationStore, OrganizationCache;
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_database_inventory.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/database_snapshot_service.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/e2ee_secret_inventory.dart';
import 'package:imboy/service/e2ee_backup_setup_service.dart'
    show kE2eeBackupPassphraseSecureKey;
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/notification.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/pending_chat_actions.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/sqflite_init.dart' show initSqfliteFactory;
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket_message_queue.dart';

part 'account_local_data_ownership.dart';
part 'account_local_data_inventory.dart';

/// Startup must finish this read before any account data can be published.
class AccountStorageInventoryUnavailableException implements Exception {
  const AccountStorageInventoryUnavailableException();
}

/// Removes a proven account identity from this installation. The caller owns
/// the login/cleanup lock and removes its history record only after success.
/// No remote account, server data, or user-exported file is deleted here.
class AccountLocalDataService {
  /// Capture before startup publishes any account data. Failure stops startup;
  /// the existing initialization error page can retry without creating data.
  static Future<void> captureInitialOwnership({
    AccountLocalDataService? inventoryService,
  }) => _captureInitialAccountStorage(inventoryService);

  /// This is evidence about the immutable startup inventory, never a fresh read
  /// after login has overwritten ownership metadata or created account data.
  static bool wasStorageUnusedAtStartup(LoginAccountIdentity identity) =>
      _initialAccountStorageInventory?.wasUnused(identity) ?? false;

  @visibleForTesting
  static void resetInitialOwnershipForTest() => _resetInitialAccountStorage();

  AccountLocalDataService({
    Future<Directory> Function()? databaseDirectory,
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? cacheDirectory,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? systemTemporaryDirectory,
    Future<void> Function()? waitForDatabaseInitialization,
    Future<void> Function(String uid, String environment)? closeDatabase,
    Future<void> Function(String uid, String environment)? deleteDatabase,
    Future<Map<String, String>> Function()? readSecure,
    Future<void> Function(String key)? deleteSecure,
    void Function()? clearSessionMemory,
    Future<void> Function()? validateNotifications,
    Future<void> Function(AccountLocalTaskOwner owner)? clearNotifications,
    Future<void> Function(AccountLocalTaskOwner owner)? clearMediaCache,
    Future<void> Function(String uid)? clearQueuedMessages,
  }) : _databaseDirectory =
           databaseDirectory ??
           (() async => Directory(await getDatabasesPath())),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _systemTemporaryDirectory =
           systemTemporaryDirectory ?? (() async => Directory.systemTemp),
       _waitForDatabaseInitialization =
           waitForDatabaseInitialization ??
           SqliteService.to.waitForPendingInitialization,
       _closeDatabase =
           closeDatabase ??
           ((uid, environment) => SqliteService.to.closeDatabaseForUid(
             uid,
             environment: environment,
           )),
       _deleteDatabase =
           deleteDatabase ??
           ((uid, environment) => SqliteService.to.deleteDatabaseForUid(
             uid,
             environment: environment,
           )),
       _readSecure = readSecure ?? StorageSecureService.to.readAll,
       _deleteSecure =
           deleteSecure ?? E2eeSecretInventory.production().deleteKey,
       _clearSessionMemory = clearSessionMemory ?? _dropSessionMemory,
       _validateNotifications =
           validateNotifications ??
           NotificationService().validateAccountRemoval,
       _clearNotifications =
           clearNotifications ?? NotificationService().cancelAccount,
       _clearMediaCache = clearMediaCache ?? IMBoyCacheManager().clearAccount,
       _clearQueuedMessages =
           clearQueuedMessages ?? PersistentMessageQueue.removeAccount;

  final Future<Directory> Function() _databaseDirectory;
  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _cacheDirectory;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function() _systemTemporaryDirectory;
  final Future<void> Function() _waitForDatabaseInitialization;
  final Future<void> Function(String uid, String environment) _closeDatabase;
  final Future<void> Function(String uid, String environment) _deleteDatabase;
  final Future<Map<String, String>> Function() _readSecure;
  final Future<void> Function(String key) _deleteSecure;
  final void Function() _clearSessionMemory;
  final Future<void> Function() _validateNotifications;
  final Future<void> Function(AccountLocalTaskOwner owner) _clearNotifications;
  final Future<void> Function(AccountLocalTaskOwner owner) _clearMediaCache;
  final Future<void> Function(String uid) _clearQueuedMessages;

  /// [clearLastSessionData] is only valid when the last saved session belongs
  /// to this identity and no account is signed in. Other historical accounts
  /// never authorize erasing the ownerless legacy session-secret namespace.
  Future<void> clear({
    required String uid,
    required String environment,
    required String endpoint,
    required bool clearLastSessionData,
  }) async {
    _validateIdentity(uid, environment, endpoint);
    final currentUid = StorageService.to.getString(Keys.currentUid);
    if (currentUid.isNotEmpty) {
      throw StateError('Sign out before removing local session data');
    }
    // A previous database open can still be creating its cipher key. Drain it
    // before taking any ownership snapshot, not only when deleting the DB.
    await _waitForDatabaseInitialization().timeout(const Duration(seconds: 30));
    if (StorageService.to.getString(Keys.currentUid).isNotEmpty) {
      throw StateError('Sign out before removing local session data');
    }
    if (clearLastSessionData) {
      final profile = StorageService.getMap(Keys.currentUser);
      final owner = (profile['user_id'] ?? profile['uid'])?.toString() ?? '';
      if (owner.isNotEmpty && owner != uid) {
        throw StateError('The saved session belongs to another account');
      }
    }

    final owner = AccountLocalTaskOwner(
      uid: uid,
      environment: environment,
      endpoint: endpoint,
    );
    final accountDigest = _digest([endpoint, uid]);
    final secure = await _readSecure();
    final backupPassphraseOwner = _backupPassphraseOwner(secure);
    var recordingKeys = <String>{};
    Directory? support, cache, temporary;
    if (!kIsWeb) {
      support = await _supportDirectory();
      if (await _hasSharedAccountStorage(
        await _databaseDirectory(),
        support,
        uid,
        environment,
      )) {
        // Legacy deployments may not be in the login registry. Their UID-only
        // drafts, organization preferences and cipher key cannot be separated.
        // Reject before the first deletion so they stay intact.
        throw const LoginAccountSharedDataException();
      }
      cache = await _cacheDirectory();
      temporary = await _temporaryDirectory();
      await _rejectUnownedWaveformRecordings(cache, randomizedSuffix: true);
      await _rejectUnownedWaveformRecordings(
        await _documentsDirectory(),
        randomizedSuffix: false,
      );
      await _rejectUnownedLegacyTemporaryFiles(temporary);
      final systemTemporary = await _systemTemporaryDirectory();
      if (systemTemporary.path != temporary.path) {
        await _rejectUnownedLegacyTemporaryFiles(systemTemporary);
      }
      recordingKeys = await _recordingSecretsForAccount(
        Directory(p.join(support.path, 'talk_record')),
        accountDigest,
        secure.keys.toSet(),
      );
    } else if (secure.keys.any((key) => key.startsWith('trk_'))) {
      // Browser storage has no native recording directory to prove these
      // legacy key owners. Keep them and report incomplete cleanup.
      throw const AccountLocalDataOwnershipException();
    }
    _rejectUnownedLegacyPreferences();
    await PendingChatActions.instance.validateAccountRemoval(uid);
    await AccountMediaCacheStore(
      cacheDirectory: _cacheDirectory,
      temporaryDirectory: _temporaryDirectory,
    ).assertRemovalCanBeAttributed();
    await _validateNotifications();
    // A failed native close must leave its cipher key and recovery data intact.
    // Authentication stays blocked, so the selected handle cannot reopen here.
    await _closeDatabase(uid, environment);

    final uploadPrefix =
        'utk_${Uri.encodeComponent(environment)}:${Uri.encodeComponent(uid)}:';
    final aiPrefix =
        'talk_record_ai_v1_${_digest([Uri.parse(endpoint).origin, uid])}_';
    bool ownsSecret(String key) {
      if (key == kE2eeBackupPassphraseSecureKey) {
        return backupPassphraseOwner == uid;
      }
      if (recordingKeys.contains(key)) return true;
      if (key == 'db_cipher_key_$uid') return true;
      if (key.startsWith(uploadPrefix) || key.startsWith(aiPrefix)) return true;
      if (!clearLastSessionData) return false;
      return _isLegacySessionSecret(key);
    }

    final keys = secure.keys.where(ownsSecret).toList();
    for (final key in keys) {
      await _deleteSecure(key);
    }
    if ((await _readSecure()).keys.any(ownsSecret)) {
      throw StateError('Some account secrets could not be removed');
    }
    // Key attribution above survives every failure: recording ownership files
    // are retained until the corresponding secure-storage deletions are verified.
    // Recheck the exact account/environment under the same SQLite locks before
    // unlinking files; other accounts' cached handles remain untouched.
    await _deleteDatabase(uid, environment);
    if (!kIsWeb) {
      await _deletePath(
        DatabaseSnapshotService.to.snapshotDir(
          base: support!.path,
          env: environment,
          uid: uid,
        ),
      );
      await _deletePath(p.join(support.path, 'talk_record', accountDigest));
      await _deletePath(
        p.join(
          cache!.path,
          'attachment_uploads',
          sha256.convert(utf8.encode('$environment:$uid')).toString(),
        ),
      );
      await _deletePath(AccountLocalFiles.folderFor(temporary!.path, owner));
    }
    await _clearMediaCache(owner);
    await _clearNotifications(owner);
    await _clearQueuedMessages(uid);
    await PendingChatActions.instance.removeAccount(uid);
    MessageRetry.removeAccount(uid);
    ServerAckReceipts.removeAccount(uid);
    for (final key in StorageService.to.getKeys().toList()) {
      if (_ownsPreference(key, uid, environment, endpoint, accountDigest) ||
          (clearLastSessionData && _isLegacySessionPreference(key))) {
        await StorageService.to.persistPreference(
          () => StorageService.to.remove(key),
        );
      }
    }
    await CurrentOrganizationStore.removeAccount(uid);
    OrganizationCache.disposeAccount(uid);
    if (clearLastSessionData) {
      _clearSessionMemory();
      await StorageService.to.persistPreference(
        () => StorageService.to.remove(Keys.e2eePurgePending),
      );
      // Keep the saved profile until every preceding stage succeeds so a
      // partial failure remains attributable and retryable after restart.
      await StorageService.to.persistPreference(
        () => StorageService.to.remove(Keys.currentUser),
      );
    }
  }

  static void _validateIdentity(
    String uid,
    String environment,
    String endpoint,
  ) {
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(uid) ||
        uid == '.' ||
        uid == '..' ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(environment)) {
      throw ArgumentError('Invalid local account identity');
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !const ['http', 'https'].contains(uri.scheme)) {
      throw ArgumentError('Invalid account endpoint');
    }
  }

  static String _digest(List<String> values) =>
      sha256.convert(utf8.encode(jsonEncode(values))).toString();

  static String _normalizedEndpoint(String endpoint) =>
      Uri.parse(endpoint.trim())
          .normalizePath()
          .replace(fragment: '')
          .toString()
          .replaceFirst(RegExp(r'/+$'), '');

  static bool _ownsPreference(
    String key,
    String uid,
    String environment,
    String endpoint,
    String digest,
  ) {
    if ({
      'org_current_$uid',
      '${Keys.localProductExperience}_$uid',
      'moment_failed_draft_$uid',
      'moment_last_visibility_$uid',
      '${Keys.groupMembershipSelfHealPrefix}_${environment}_$uid',
      '${Keys.offlineCursorC2gPage}_${environment}_$uid',
      'message_search_history_v2_$digest',
      'web_search_history_v2_$digest',
      'quick_replies:$uid',
      ...[
        for (final base in const [
          'chat_search_history',
          'user_collect_pinned_ids',
          'imboy.deleted_message_ids.v1',
        ])
          AccountLocalTaskOwner(
            uid: uid,
            environment: environment,
            endpoint: endpoint,
          ).preferenceKey(base),
      ],
    }.contains(key)) {
      return true;
    }
    final encodedUid = Uri.encodeComponent(uid);
    if ([
      'draft_v2:$encodedUid:',
      'draftCursor_v2:$encodedUid:',
      'group_notice_disabled:$uid:',
      'creation_intent:${endpoint.length}:$endpoint:$uid:',
      'org_group_rename_pending:${endpoint.length}:$endpoint:$uid:',
    ].any(key.startsWith)) {
      return true;
    }
    final repairSuffix = '_repair_v2_${uid}_$endpoint';
    if (key.startsWith(Keys.msgHistorySeqPrefix) &&
        (key.endsWith(repairSuffix) || key.contains('${repairSuffix}_gap_'))) {
      return true;
    }
    // Feature cache scopes contain the manifest hash. Decode the owner so old
    // versions for this identity are removed without matching another account.
    for (final prefix in [
      Keys.appFeatures,
      Keys.appManifest,
      Keys.appManifestEtag,
    ]) {
      final scoped = '${prefix}_scoped_';
      if (!key.startsWith(scoped)) continue;
      try {
        final owner = jsonDecode(
          utf8.decode(base64Url.decode(key.substring(scoped.length))),
        );
        return owner is List &&
            owner.length == 3 &&
            owner[1] == uid &&
            owner[0] == _normalizedEndpoint(endpoint);
      } on FormatException {
        return false;
      }
    }
    return false;
  }

  static bool _isLegacySessionPreference(String key) =>
      (key.startsWith(Keys.msgHistorySeqPrefix) &&
          !key.contains('_repair_v2_')) ||
      const {
        'e2ee_new_device_guide_pending',
        'e2ee_recovery_needed',
        'e2ee_last_restore_marker',
        'e2ee_failed_sync_uids',
        'e2ee_notification_last_since',
        'e2ee_decrypt_fail_metrics',
        'token_decryption_failed',
        'offline_cursor_c2c',
        'offline_cursor_c2g',
        'offline_cursor_s2c',
        'push_registered_device_id',
        'need_set_password',
      }.contains(key);

  static bool _isLegacySessionSecret(String key) {
    // These families have their own account selectors above. The backup
    // passphrase also has an explicit owner even though its key is global.
    if (key == kE2eeBackupPassphraseSecureKey ||
        key.startsWith('db_cipher_key_') ||
        key.startsWith('talk_record_ai_v1_') ||
        (key.startsWith('utk_') && key.contains(':'))) {
      return false;
    }
    return E2eeSecretInventory.matchesSecretKey(key) ||
        const {
          'secure_token',
          'secure_refresh_token',
          'oa_inbound_login_attempt',
        }.contains(key);
  }

  static Future<void> _deletePath(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(path).delete();
      default:
        await File(path).delete();
    }
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('Local account data still exists', path);
    }
  }

  static Future<bool> _hasSharedAccountStorage(
    Directory databases,
    Directory support,
    String uid,
    String selectedEnvironment,
  ) async {
    final accountDatabase = _accountDatabaseArtifactPattern(uid);
    if (await databases.exists()) {
      await for (final entry in databases.list(followLinks: false)) {
        final match = accountDatabase.firstMatch(p.basename(entry.path));
        if (match != null && match.group(1) != selectedEnvironment) return true;
      }
    }
    final snapshots = Directory(
      p.join(support.path, DatabaseSnapshotService.baseDirName),
    );
    if (await snapshots.exists()) {
      await for (final environment in snapshots.list(followLinks: false)) {
        if (p.basename(environment.path) != selectedEnvironment &&
            environment is Directory &&
            await Directory(p.join(environment.path, uid)).exists()) {
          return true;
        }
      }
    }
    return false;
  }

  static void _dropSessionMemory() {
    for (final clear in E2eeSecretInventory.production().clearMemoryCaches) {
      clear();
    }
    OlmSessionService.to.clearMemoryAfterLocalDataRemoval();
    MessageOfflineService.resetLocalCursors();
    AttachmentOpenRegistry.clear();
    AssetUrlResolver.instance.clear();
    SqliteService.to.clearQueryCache();
  }
}
