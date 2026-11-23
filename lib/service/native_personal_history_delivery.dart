part of 'web_personal_history_sync.dart';

typedef _NativeUploadKick = ({
  AuthSessionScope session,
  AccountLocalTaskOwner owner,
  String instance,
});

_NativeUploadKick? _nextNativeUploadKick;
bool _nativeUploadRunning = false;
const _nativeUploadBatchesPerKick = 4;

/// Records an explicitly inspected server grant, including revocation. The
/// database may hold locked references before a key package is available.
Future<void> observeNativePersonalHistoryGrant({
  required AccountLocalTaskOwner owner,
  required PersonalHistoryStatus status,
  required void Function() guard,
}) async {
  await _historyUploadLock.synchronized(() async {
    guard();
    await _observeUploadStatus(status, owner, guard);
    guard();
    final active = _unlocked;
    if (active != null &&
        active.owner == owner &&
        !status.authorizesSameScope(active.status)) {
      active.close();
    }
  });
}

/// The caller transfers ownership of the ring and authorization notifier on
/// success. Neither a recovery passphrase nor a raw history key is saved.
Future<void> retainNativePersonalHistoryUploadKey({
  required AuthSessionScope session,
  required AccountLocalTaskOwner owner,
  required String instance,
  required PersonalHistoryStatus status,
  required PersonalHistoryKeyService ring,
  required ValueNotifier<bool> authorization,
  required void Function() guard,
}) async {
  if (kIsWeb ||
      !isEncryptionSupported ||
      session.uid != owner.uid ||
      !_ownsUploadSession(session, owner, instance)) {
    throw const AccountLocalTaskCancelledException();
  }
  await _historyUploadLock.synchronized(() async {
    guard();
    await _observeUploadStatus(status, owner, guard);
    guard();
    _rememberUnlocked(
      owner: owner,
      instance: instance,
      status: status,
      ring: ring,
      authorization: authorization,
    );
  });
}

/// Coalesce commit and reconnect kicks. A fresh process can retry already
/// sealed rows while waiting for the user to unlock source references.
void scheduleNativePersonalHistoryUploads(
  AuthSessionScope session,
  AccountLocalTaskOwner owner,
) {
  final instance = deviceId;
  if (kIsWeb ||
      !isEncryptionSupported ||
      instance.isEmpty ||
      !_ownsUploadSession(session, owner, instance)) {
    return;
  }
  _nextNativeUploadKick = (session: session, owner: owner, instance: instance);
  if (_nativeUploadRunning) return;
  _nativeUploadRunning = true;
  unawaited(_drainNativeUploadKicks());
}

Future<void> _drainNativeUploadKicks() async {
  try {
    while (_nextNativeUploadKick != null) {
      final kick = _nextNativeUploadKick!;
      _nextNativeUploadKick = null;
      if (!_ownsUploadSession(kick.session, kick.owner, kick.instance)) {
        continue;
      }
      await _runNativeUploadKick(kick);
    }
  } finally {
    _nativeUploadRunning = false;
  }
}

/// Visit at most four distinct batches per kick. Count scanned source refs
/// separately so deferred or removed refs cannot strand the untouched tail.
Future<void> _runNativeUploadKick(_NativeUploadKick kick) async {
  final attempted = <String>{};
  final scannedSources = <String>{};
  for (var batch = 0; batch < _nativeUploadBatchesPerKick; batch++) {
    if (!_ownsUploadSession(kick.session, kick.owner, kick.instance)) return;
    final before = attempted.length + scannedSources.length;
    final active = _unlocked;
    final result =
        active != null &&
            active.current &&
            active.session == kick.session &&
            active.owner == kick.owner
        ? await _attemptUnlockedHistoryUpload(
            active,
            attemptedThisRun: attempted,
            scannedSourcesThisRun: scannedSources,
          )
        : await _retryNativeCiphertext(kick, attempted);
    if (result?.kind != PersonalHistorySyncOutcomeKind.uploadPartial ||
        attempted.length + scannedSources.length == before) {
      return;
    }
  }
}

Future<PersonalHistorySyncOutcome?> _retryNativeCiphertext(
  _NativeUploadKick kick,
  Set<String> attempted,
) async {
  final cancel = CancelToken();
  bool current() => _ownsUploadSession(kick.session, kick.owner, kick.instance);
  try {
    return await AccountLocalTaskRegistry.instance.run(
      kick.owner,
      onCancel: () => cancel.cancel(),
      operation: (task) => _historyUploadLock.synchronized(() async {
        void guard() {
          if (!current() || task.isCancelled) {
            throw const AccountLocalTaskCancelledException();
          }
        }

        guard();
        final db = await SqliteService.to.db;
        guard();
        if (db == null) return null;
        final refs = WebPersonalHistoryUploadRefs(
          db,
          kick.owner.storageDigest,
          guard,
        );
        final grant = await refs.currentGrant();
        if (grant == null) return null;
        final store = PersonalHistoryLocalStore(() async {
          guard();
          return db;
        }, nativeOwnerDigest: kick.owner.storageDigest);
        final pending = await store.pendingUploads(
          grant.domain,
          grant.generation,
          limit: 1,
          excluding: attempted,
        );
        guard();
        if (pending.isEmpty) return null;
        final client = createNativePersonalHistoryClient(
          owner: kick.owner,
          instance: kick.instance,
          cancel: cancel,
          guard: guard,
        );
        final status = await client.status();
        guard();
        await _updateUploadStatus(refs, status);
        guard();
        if (!status.enabled ||
            status.domain != grant.domain ||
            status.generation != grant.generation) {
          return null;
        }
        final engine = PersonalHistorySyncEngine(
          client: client,
          store: store,
          domain: grant.domain,
          decrypt: (_) async => null,
          isCurrent: () => current() && !task.isCancelled,
        );
        return engine.flushUploads(
          generation: grant.generation,
          attemptedThisRun: attempted,
        );
      }),
    );
  } on Object catch (error) {
    if (current()) _logUploadFailure(error);
    return null;
  }
}
