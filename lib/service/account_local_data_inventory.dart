part of 'account_local_data_service.dart';

_InitialAccountStorageInventory? _initialAccountStorageInventory;
Future<void>? _initialAccountStorageCapture;
int _initialAccountStorageGeneration = 0;

Future<void> _captureInitialAccountStorage(
  AccountLocalDataService? inventoryService,
) {
  final existing = _initialAccountStorageCapture;
  if (existing != null) return existing;
  final generation = _initialAccountStorageGeneration;
  // Schedule after the future is assigned, so even synchronous plugin failures
  // clear the failed attempt and the initialization error page can retry it.
  return _initialAccountStorageCapture = Future<void>.value().then((_) async {
    try {
      // Select the desktop factory without opening or creating any database.
      if (!kIsWeb && inventoryService == null) initSqfliteFactory();
      await StorageService.to.reload();
      final inventory = await _readInitialAccountStorage(
        inventoryService ?? AccountLocalDataService(),
      ).timeout(const Duration(seconds: 10));
      if (generation == _initialAccountStorageGeneration) {
        _initialAccountStorageInventory = inventory;
      }
    } on Object {
      if (generation == _initialAccountStorageGeneration) {
        _initialAccountStorageCapture = null;
      }
      // Do not start writers after an unreadable inventory. Otherwise a fresh
      // login creates data that the next startup cannot distinguish from legacy
      // data and permanently loses its chance to establish ownership.
      throw const AccountStorageInventoryUnavailableException();
    }
  });
}

void _resetInitialAccountStorage() {
  _initialAccountStorageGeneration++;
  _initialAccountStorageCapture = null;
  _initialAccountStorageInventory = null;
}

/// Startup keeps identifiers and key names only; secure values are discarded
/// after extracting the separately owned backup-passphrase UID.
class _InitialAccountStorageInventory {
  _InitialAccountStorageInventory({
    required Set<String> sessionUids,
    required this.hasUnattributedSessionData,
    required Set<String> preferenceKeys,
    required Set<String> queuedUids,
    required Set<String> secureKeyNames,
    required this.backupPassphraseUid,
    required Set<String> databaseArtifacts,
    required Map<String, Set<String>> snapshotOwners,
    required Set<String> uploadScopes,
    required Set<String> recordingScopes,
    required Set<String> temporaryScopes,
    required Set<String> mediaScopes,
  }) : sessionUids = Set.unmodifiable(sessionUids),
       preferenceKeys = Set.unmodifiable(preferenceKeys),
       queuedUids = Set.unmodifiable(queuedUids),
       secureKeyNames = Set.unmodifiable(secureKeyNames),
       databaseArtifacts = Set.unmodifiable(databaseArtifacts),
       snapshotOwners = Map.unmodifiable({
         for (final entry in snapshotOwners.entries)
           entry.key: Set<String>.unmodifiable(entry.value),
       }),
       uploadScopes = Set.unmodifiable(uploadScopes),
       recordingScopes = Set.unmodifiable(recordingScopes),
       temporaryScopes = Set.unmodifiable(temporaryScopes),
       mediaScopes = Set.unmodifiable(mediaScopes);

  final Set<String> sessionUids;
  final bool hasUnattributedSessionData;
  final Set<String> preferenceKeys;
  final Set<String> queuedUids;
  final Set<String> secureKeyNames;
  final String? backupPassphraseUid;
  final Set<String> databaseArtifacts;
  final Map<String, Set<String>> snapshotOwners;
  final Set<String> uploadScopes;
  final Set<String> recordingScopes;
  final Set<String> temporaryScopes;
  final Set<String> mediaScopes;

  bool wasUnused(LoginAccountIdentity identity) {
    try {
      AccountLocalDataService._validateIdentity(
        identity.uid,
        identity.environment,
        identity.endpoint,
      );
      final uid = identity.uid;
      if (hasUnattributedSessionData ||
          sessionUids.contains(uid) ||
          queuedUids.contains(uid) ||
          backupPassphraseUid == uid) {
        return false;
      }
      final digest = AccountLocalDataService._digest([identity.endpoint, uid]);
      if (preferenceKeys.any(
        (key) => AccountLocalDataService._ownsPreference(
          key,
          uid,
          identity.environment,
          identity.endpoint,
          digest,
        ),
      )) {
        return false;
      }
      final uploadPrefix =
          'utk_${Uri.encodeComponent(identity.environment)}:${Uri.encodeComponent(uid)}:';
      final aiPrefix =
          'talk_record_ai_v1_${AccountLocalDataService._digest([Uri.parse(identity.endpoint).origin, uid])}_';
      if (secureKeyNames.contains('db_cipher_key_$uid') ||
          secureKeyNames.any(
            (key) => key.startsWith(uploadPrefix) || key.startsWith(aiPrefix),
          ) ||
          databaseArtifacts.any(
            _accountDatabaseArtifactPattern(uid).hasMatch,
          ) ||
          snapshotOwners.values.any((owners) => owners.contains(uid))) {
        return false;
      }
      final owner = AccountLocalTaskOwner(
        uid: uid,
        environment: identity.environment,
        endpoint: identity.endpoint,
      );
      final uploadScope = sha256
          .convert(utf8.encode('${identity.environment}:$uid'))
          .toString();
      return !uploadScopes.contains(uploadScope) &&
          !recordingScopes.contains(digest) &&
          !temporaryScopes.contains(owner.storageDigest) &&
          !mediaScopes.contains(owner.storageDigest) &&
          !preferenceKeys.contains(AccountMediaCacheStore.indexKey(owner));
    } on Object {
      return false;
    }
  }
}

Future<_InitialAccountStorageInventory> _readInitialAccountStorage(
  AccountLocalDataService service,
) async {
  final preferences = StorageService.to;
  final preferenceKeys = preferences.getKeys().toSet();
  final sessionUids = _initialSessionUids(preferenceKeys);
  final queuedUids = <String>{};
  for (final key in [
    PendingChatActions.readReceiptsKey,
    PendingChatActions.reactionsKey,
  ]) {
    if (!preferenceKeys.contains(key)) continue;
    if (preferences.getString(key).isEmpty) {
      throw const AccountLocalDataOwnershipException();
    }
    for (final item in await PendingChatActions.instance.snapshot(key)) {
      queuedUids.add((item as Map)['from'] as String);
    }
  }
  if (preferenceKeys.contains('ws_message_queue')) {
    final queue = preferences.getStringList('ws_message_queue');
    if (queue == null) throw const AccountLocalDataOwnershipException();
    for (final raw in queue) {
      final item = jsonDecode(raw);
      if (item is! Map ||
          item['ownerUid'] is! String ||
          (item['ownerUid'] as String).trim().isEmpty) {
        throw const AccountLocalDataOwnershipException();
      }
      queuedUids.add(item['ownerUid'] as String);
    }
  }

  final (secureKeyNames, backupPassphraseUid) = await _initialSecureOwnership(
    service,
  );
  final hasSessionData =
      preferenceKeys.any(AccountLocalDataService._isLegacySessionPreference) ||
      secureKeyNames.any(AccountLocalDataService._isLegacySessionSecret);
  if (kIsWeb) {
    if (secureKeyNames.any((key) => key.startsWith('trk_'))) {
      throw const AccountLocalDataOwnershipException();
    }
    return _InitialAccountStorageInventory(
      sessionUids: sessionUids,
      hasUnattributedSessionData: hasSessionData && sessionUids.isEmpty,
      preferenceKeys: preferenceKeys,
      queuedUids: queuedUids,
      secureKeyNames: secureKeyNames,
      backupPassphraseUid: backupPassphraseUid,
      databaseArtifacts: await readWebAccountDatabaseArtifacts(),
      snapshotOwners: const {},
      uploadScopes: const {},
      recordingScopes: const {},
      temporaryScopes: const {},
      mediaScopes: const {},
    );
  }
  final databases = await service._databaseDirectory();
  final support = await service._supportDirectory();
  final cache = await service._cacheDirectory();
  final temporary = await service._temporaryDirectory();
  final databaseArtifacts = await _initialStorageNames(databases);
  final snapshotOwners = <String, Set<String>>{};
  final snapshots = Directory(
    p.join(support.path, DatabaseSnapshotService.baseDirName),
  );
  for (final environment in await _initialStorageNames(snapshots)) {
    snapshotOwners[environment] = await _initialStorageNames(
      Directory(p.join(snapshots.path, environment)),
    );
  }
  final recordingRoot = Directory(p.join(support.path, 'talk_record'));
  final recordingScopes = await _initialStorageNames(recordingRoot);
  // Reuse the existing binding validator, including orphan/conflicting trk_
  // keys. Its return value is deliberately not retained in the snapshot.
  await _recordingSecretsForAccount(recordingRoot, '', secureKeyNames);
  return _InitialAccountStorageInventory(
    sessionUids: sessionUids,
    hasUnattributedSessionData: hasSessionData && sessionUids.isEmpty,
    preferenceKeys: preferenceKeys,
    queuedUids: queuedUids,
    secureKeyNames: secureKeyNames,
    backupPassphraseUid: backupPassphraseUid,
    databaseArtifacts: databaseArtifacts,
    snapshotOwners: snapshotOwners,
    uploadScopes: await _initialStorageNames(
      Directory(p.join(cache.path, 'attachment_uploads')),
    ),
    recordingScopes: recordingScopes,
    temporaryScopes: await _initialStorageNames(
      Directory(p.join(temporary.path, 'account_local_data')),
    ),
    mediaScopes: await _initialStorageNames(
      Directory(
        p.join(temporary.path, AccountMediaCacheStore.temporaryDirectoryName),
      ),
    ),
  );
}

Future<(Set<String>, String?)> _initialSecureOwnership(
  AccountLocalDataService service,
) async {
  final secure = await service._readSecure();
  return (secure.keys.toSet(), _backupPassphraseOwner(secure));
}

Set<String> _initialSessionUids(Set<String> preferenceKeys) {
  final uids = <String>{};
  final currentUid = StorageService.to.getString(Keys.currentUid);
  if (currentUid.isNotEmpty) uids.add(_initialOwnerUid(currentUid));
  if (!preferenceKeys.contains(Keys.currentUser)) return uids;
  // getMap silently turns malformed JSON into {}. Here that would falsely
  // certify a UID whose last owner was unreadable, so parse the original value.
  final profile = jsonDecode(StorageService.to.getString(Keys.currentUser));
  if (profile is! Map<String, dynamic>) {
    throw const AccountLocalDataOwnershipException();
  }
  if (profile.isEmpty) return uids;
  final profileUid = _initialOwnerUid(profile['user_id'] ?? profile['uid']);
  if (currentUid.isNotEmpty && currentUid != profileUid) {
    throw const AccountLocalDataOwnershipException();
  }
  uids.add(profileUid);
  if (profile.containsKey(LoginAccountHistoryService.localProfileKey)) {
    final marker = LoginAccountIdentity.fromJson(
      profile[LoginAccountHistoryService.localProfileKey],
    );
    if (marker == null || marker.uid != profileUid) {
      throw const AccountLocalDataOwnershipException();
    }
    uids.add(marker.uid);
  }
  return uids;
}

String _initialOwnerUid(Object? value) {
  if (value is! String && value is! int) {
    throw const AccountLocalDataOwnershipException();
  }
  final uid = value.toString();
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(uid) ||
      uid == '.' ||
      uid == '..') {
    throw const AccountLocalDataOwnershipException();
  }
  return uid;
}

Future<Set<String>> _initialStorageNames(Directory directory) async {
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return {};
  if (type != FileSystemEntityType.directory) {
    throw const AccountLocalDataOwnershipException();
  }
  final names = <String>{};
  await for (final entry in directory.list(followLinks: false)) {
    names.add(p.basename(entry.path));
  }
  return names;
}

RegExp _accountDatabaseArtifactPattern(String uid) => RegExp(
  '^([A-Za-z0-9_-]+)_${RegExp.escape(uid)}\\.db'
  r'(?:(?:\.(?:pre_restore\.bak|restoring\.tmp))?(?:-wal|-shm|-journal)?'
  r'|\.restore\..+)$',
);
