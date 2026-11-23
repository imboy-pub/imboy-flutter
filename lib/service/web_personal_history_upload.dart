part of 'web_personal_history_sync.dart';

/// References an accepted C2C row in the source transaction. While locked it
/// writes no additional copy of the ordinary message body or the history key.
Future<bool> recordAcceptedPersonalHistoryC2cText({
  required DatabaseExecutor transaction,
  required AuthSessionScope session,
  required AccountLocalTaskOwner owner,
  required MessageModel message,
  required int? sequence,
  bool outbound = false,
}) async {
  if ((!kIsWeb && !isEncryptionSupported) ||
      deviceId.isEmpty ||
      session.uid.isEmpty ||
      !_isVersionZeroText(message, session.uid, outbound) ||
      _sourcePlaintext(message) == null ||
      (!outbound && !_validSequence(sequence))) {
    return false;
  }
  final instance = deviceId;
  void requireCurrent() {
    if (!_ownsUploadSession(session, owner, instance)) {
      throw StateError('Personal history owner changed');
    }
  }

  requireCurrent();
  return WebPersonalHistoryUploadRefs.enqueue(
    transaction,
    owner.storageDigest,
    (messageId: message.id, sequence: sequence, outbound: outbound),
    requireCurrent,
  );
}

bool _ownsUploadSession(
  AuthSessionScope session,
  AccountLocalTaskOwner owner,
  String instance,
) =>
    authSessionReader.isCurrent(session) &&
    !authSessionReader.transitionFailed &&
    owner == AccountLocalTaskOwner.capture(uid: session.uid) &&
    instance == deviceId;

/// Called only after the source transaction commits. Browser writes also
/// confirm the IndexedDB boundary; native writes already committed in SQLite.
Future<void> confirmAcceptedPersonalHistoryC2cText(
  AuthSessionScope session,
  AccountLocalTaskOwner owner,
) async {
  if (!kIsWeb) {
    scheduleNativePersonalHistoryUploads(session, owner);
    return;
  }
  final instance = deviceId;
  bool current() => _ownsUploadSession(session, owner, instance);
  if (!current()) return;
  try {
    await AccountLocalTaskRegistry.instance.run(
      owner,
      operation: (task) async {
        void requireCurrent() {
          if (task.isCancelled || !current()) {
            throw StateError('Personal history owner changed');
          }
        }

        final db = await SqliteService.to.db;
        requireCurrent();
        if (db == null) {
          throw StateError('Personal history database unavailable');
        }
        await _confirmUploadDurable(db, owner, requireCurrent);
      },
    );
    final active = _unlocked;
    if (current() &&
        active != null &&
        active.current &&
        active.session == session) {
      unawaited(_tryFlushWebHistory(active));
    }
  } on Object catch (error) {
    if (current()) _logUploadFailure(error);
  }
}

Future<void> _observeUploadStatus(
  PersonalHistoryStatus status,
  AccountLocalTaskOwner owner,
  void Function() requireCurrent,
) async {
  final db = await SqliteService.to.db;
  requireCurrent();
  if (db == null) throw StateError('Personal history database unavailable');
  final refs = WebPersonalHistoryUploadRefs(
    db,
    owner.storageDigest,
    requireCurrent,
  );
  if (await _updateUploadStatus(refs, status)) {
    await _confirmUploadDurable(db, owner, requireCurrent);
  }
}

Future<bool> _updateUploadStatus(
  WebPersonalHistoryUploadRefs refs,
  PersonalHistoryStatus status,
) {
  if (!const {
        'ON',
        'OFF',
        'OFF_PURGE_PENDING',
        'OFF_PURGED',
      }.contains(status.state) ||
      (status.enabled &&
          ((status.domain?.isEmpty ?? true) || status.generation == 0))) {
    throw const FormatException('Invalid personal history upload scope');
  }
  return refs.observe(
    enabled: status.enabled,
    domain: status.domain,
    generation: status.generation,
  );
}

Future<void> _confirmUploadDurable(
  Database db,
  AccountLocalTaskOwner owner,
  void Function() requireCurrent,
) async {
  requireCurrent();
  if (kIsWeb) {
    await durableBrowserAccountDatabase(
      db,
      databaseName: SqliteService.databaseNameForUid(owner.uid),
    );
  }
  requireCurrent();
}

Future<void> _tryFlushWebHistory(_UnlockedWebHistory active) async {
  await _attemptUnlockedHistoryUpload(active);
}

Future<PersonalHistorySyncOutcome?> _attemptUnlockedHistoryUpload(
  _UnlockedWebHistory active, {
  Set<String>? attemptedThisRun,
  Set<String>? scannedSourcesThisRun,
}) async {
  if (!active.current) return null;
  final cancel = CancelToken();
  try {
    return await AccountLocalTaskRegistry.instance.run(
      active.owner,
      onCancel: () => cancel.cancel(),
      operation: (task) => _historyUploadLock.synchronized(() async {
        bool current() => !task.isCancelled && active.current;
        if (!current()) return null;
        void requireCurrent() {
          if (!current()) throw StateError('Personal history owner changed');
        }

        final db = await SqliteService.to.db;
        requireCurrent();
        if (db == null) return null;
        final client = kIsWeb
            ? _historyClient(active.instance, cancel, requireCurrent)
            : createNativePersonalHistoryClient(
                owner: active.owner,
                instance: active.instance,
                cancel: cancel,
                guard: requireCurrent,
              );
        final store = PersonalHistoryLocalStore(() async {
          requireCurrent();
          return db;
        }, nativeOwnerDigest: kIsWeb ? null : active.owner.storageDigest);
        return _flushWebHistory(
          active: active,
          client: client,
          cancel: cancel,
          refs: WebPersonalHistoryUploadRefs(
            db,
            active.owner.storageDigest,
            requireCurrent,
          ),
          store: store,
          engine: PersonalHistorySyncEngine(
            client: client,
            store: store,
            domain: active.ring.domain,
            decrypt: (_) async => null,
            isCurrent: current,
          ),
          requireCurrent: requireCurrent,
          confirmDurable: () =>
              _confirmUploadDurable(db, active.owner, requireCurrent),
          attemptedThisRun: attemptedThisRun,
          scannedSourcesThisRun: scannedSourcesThisRun,
        );
      }),
    );
  } on Object catch (error) {
    if (active.current) _logUploadFailure(error);
    return null;
  }
}

Future<PersonalHistorySyncOutcome> _flushWebHistory({
  required _UnlockedWebHistory active,
  required PersonalHistoryApiClient client,
  required CancelToken cancel,
  required WebPersonalHistoryUploadRefs refs,
  required PersonalHistoryLocalStore store,
  required PersonalHistorySyncEngine engine,
  required void Function() requireCurrent,
  required Future<void> Function() confirmDurable,
  Set<String>? attemptedThisRun,
  Set<String>? scannedSourcesThisRun,
}) async {
  final live = await client.status();
  requireCurrent();
  if (await _updateUploadStatus(refs, live)) await confirmDurable();
  if (!live.authorizesSameScope(active.status)) {
    active.close();
    return _aborted;
  }
  final domain = active.ring.domain;
  final generation = active.ring.generation;
  final pending = await refs.pending(
    domain,
    generation,
    excluding: scannedSourcesThisRun ?? const {},
  );
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  for (final ref in pending) {
    scannedSourcesThisRun?.add(ref.messageId);
    final message = await repo.find(
      ref.messageId,
      includeConversationSequence: !ref.outbound,
    );
    requireCurrent();
    if (message == null) {
      await refs.defer(domain, generation, ref.messageId);
      continue;
    }
    if (_isVersionZeroText(message, active.owner.uid, ref.outbound)) {
      final text = _sourcePlaintext(message);
      final sequence = text == null
          ? null
          : await _acceptedSequence(
              ref,
              message,
              cancel: cancel,
              requireCurrent: requireCurrent,
            );
      if (text == null || sequence == null) {
        await refs.defer(domain, generation, ref.messageId);
        continue;
      }
      _requireActive(active, requireCurrent);
      await _sealUpload(store, active.ring, message, text, sequence);
      // A tab can terminate after writing either table. Keep the reference
      // until its replacement ciphertext survives that boundary.
      await confirmDurable();
    }
    await refs.remove(domain, generation, ref.messageId);
  }
  _requireActive(active, requireCurrent);
  await confirmDurable();
  final upload = await engine.flushUploads(
    generation: generation,
    attemptedThisRun: attemptedThisRun,
  );
  if (upload.kind == PersonalHistorySyncOutcomeKind.synced &&
      (await refs.pending(domain, generation)).isNotEmpty) {
    return PersonalHistorySyncOutcome(
      kind: PersonalHistorySyncOutcomeKind.uploadPartial,
      uploaded: upload.uploaded,
    );
  }
  return upload;
}

void _requireActive(
  _UnlockedWebHistory active,
  void Function() requireCurrent,
) {
  requireCurrent();
  if (!active.current) throw StateError('Personal history key changed');
}

bool _isVersionZeroText(MessageModel message, String uid, bool outbound) {
  if (message.type != 'C2C' ||
      message.msgType != 'text' ||
      message.id.isEmpty ||
      message.createdAt <= 0 ||
      IMBoyMessageStatus.isRevokedStatus(message.status)) {
    return false;
  }
  final from = message.fromId.toString();
  final to = message.toId.toString();
  if ((outbound ? from : to) != uid || _c2cHistoryKey(from, to) == null) {
    return false;
  }
  final payload = message.payloadMap;
  // A delayed version-zero upload must never wrap the text of a later edit.
  return payload['is_edited'] != true &&
      !payload.containsKey('edited_at') &&
      payload['burn_deleted'] != true &&
      !ChatBurnService.isBurnPayload(payload);
}

String? _sourcePlaintext(MessageModel message) {
  final payload = message.payloadMap;
  final text = payload['text'];
  return text is String && text.isNotEmpty && payload['_e2ee_failed'] != true
      ? text
      : null;
}

bool _validSequence(int? value) =>
    value != null &&
    value > 0 &&
    value <= PersonalHistoryApiClient.maxSafeInteger;

Future<int?> _acceptedSequence(
  WebPersonalHistoryUploadRef ref,
  MessageModel message, {
  required CancelToken cancel,
  required void Function() requireCurrent,
}) async {
  if (!ref.outbound) {
    return ref.sequence == message.convSeq ? ref.sequence : null;
  }
  int? sequence;
  try {
    sequence = await MsgApi()
        .acceptedC2cSequence(
          peerId: message.toId.toString(),
          messageId: message.id,
          cancelToken: cancel,
          requireCurrent: requireCurrent,
        )
        .timeout(const Duration(seconds: 3));
  } on Object catch (error) {
    requireCurrent();
    _logUploadFailure(error);
  }
  requireCurrent();
  if (!_validSequence(sequence) ||
      (ref.sequence != null && ref.sequence != sequence)) {
    return null;
  }
  return sequence;
}

Future<void> _sealUpload(
  PersonalHistoryLocalStore store,
  PersonalHistoryKeyService ring,
  MessageModel message,
  String text,
  int sequence,
) async {
  final from = message.fromId.toString();
  final to = message.toId.toString();
  final conversationId = _c2cHistoryKey(from, to)!;
  final position = (
    conversationId: conversationId,
    messageId: message.id,
    actionVersion: 0,
    sequence: BigInt.from(sequence),
  );
  final body = utf8.encode(
    jsonEncode({
      'chat_type': 'c2c',
      'msg_id': message.id,
      'from': from,
      'to': to,
      'msg_type': 'text',
      'created_at': message.createdAt,
      'payload': {'text': text},
    }),
  );
  final PersonalHistoryCiphertext sealed;
  try {
    sealed = ring.encrypt(body, position);
  } finally {
    body.fillRange(0, body.length, 0);
  }
  await store.enqueueUpload(
    domain: ring.domain,
    generation: ring.generation,
    conversationId: conversationId,
    msgId: message.id,
    actionVersion: 0,
    convSeq: sequence,
    ciphertext: sealed.ciphertext,
    envelopeMeta: {
      'alg': sealed.algorithm,
      'key_version': sealed.keyVersion,
      'nonce': sealed.nonce,
      'aad': sealed.aad,
    },
    clientTs: DateTime.now().millisecondsSinceEpoch,
  );
}

void _logUploadFailure(Object error) => AppLogger.warning(
  'Personal history upload interrupted (${error.runtimeType})',
);
