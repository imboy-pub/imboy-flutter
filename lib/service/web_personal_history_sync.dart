import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, DatabaseExecutor;
import 'package:synchronized/synchronized.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'account_local_task_registry.dart';
import 'auth_session_scope.dart';
import 'browser_attachment_durability.dart';
import 'personal_history_key_service.dart';
import 'personal_history_native_transport.dart';
import 'sqlite.dart';
import 'sqflite_init.dart' show isEncryptionSupported;
import 'web_personal_history_upload_refs.dart';

part 'web_personal_history_snapshot.dart';
part 'web_personal_history_upload.dart';
part 'native_personal_history_delivery.dart';

const _aborted = PersonalHistorySyncOutcome(
  kind: PersonalHistorySyncOutcomeKind.aborted,
);

final _historyUploadLock = Lock();
_UnlockedWebHistory? _unlocked;

class _UnlockedWebHistory {
  _UnlockedWebHistory({
    required this.owner,
    required this.instance,
    required this.status,
    required this.ring,
    required this.authorization,
  }) : session = authSessionReader.current {
    authSessionReader.addListener(_onSessionChanged);
  }

  final AccountLocalTaskOwner owner;
  final String instance;
  final PersonalHistoryStatus status;
  final PersonalHistoryKeyService ring;
  final ValueNotifier<bool> authorization;
  final AuthSessionScope session;
  final snapshotPositions = <String, _SnapshotPosition>{};
  bool _closed = false;

  bool get current =>
      !_closed &&
      identical(_unlocked, this) &&
      authSessionReader.isCurrent(session) &&
      !authSessionReader.transitionFailed &&
      deviceId == instance &&
      AccountLocalTaskOwner.capture(uid: session.uid) == owner;

  void _onSessionChanged() {
    if (!current) close();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    snapshotPositions.clear();
    if (identical(_unlocked, this)) _unlocked = null;
    authSessionReader.removeListener(_onSessionChanged);
    ring.close();
    authorization.dispose();
  }
}

void _rememberUnlocked({
  required AccountLocalTaskOwner owner,
  required String instance,
  required PersonalHistoryStatus status,
  required PersonalHistoryKeyService ring,
  required ValueNotifier<bool> authorization,
}) {
  _unlocked?.close();
  _unlocked = _UnlockedWebHistory(
    owner: owner,
    instance: instance,
    status: status,
    ring: ring,
    authorization: authorization,
  );
}

/// Runs a user-requested Web recovery or enrollment without saving its passphrase.
Future<PersonalHistorySyncOutcome> syncWebPersonalHistory({
  required AuthSessionScope session,
  required AccountLocalTaskOwner owner,
  required bool Function() viewIsCurrent,
  required String peerId,
  String? passphrase,
  bool enable = false,
}) async {
  if (enable && (passphrase == null || passphrase.isEmpty)) return _aborted;
  final instance = deviceId;
  bool stillOwned() =>
      viewIsCurrent() &&
      authSessionReader.isCurrent(session) &&
      !authSessionReader.transitionFailed &&
      AccountLocalTaskOwner.capture(uid: session.uid) == owner &&
      deviceId == instance;

  if (!kIsWeb ||
      instance.isEmpty ||
      session.uid != owner.uid ||
      !stillOwned()) {
    return _aborted;
  }
  final cancel = CancelToken();
  try {
    final outcome = await AccountLocalTaskRegistry.instance.run(
      owner,
      onCancel: () => cancel.cancel(),
      operation: (task) {
        bool current() => !task.isCancelled && stillOwned();
        return _recover(
          instance: instance,
          cancel: cancel,
          owner: owner,
          current: current,
          peerId: peerId,
          passphrase: passphrase,
          enable: enable,
        );
      },
    );
    return stillOwned() ? outcome : _aborted;
  } on Object catch (error) {
    return stillOwned()
        ? PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.failed,
            error: error,
          )
        : _aborted;
  }
}

Future<PersonalHistorySyncOutcome> _recover({
  required String instance,
  required CancelToken cancel,
  required AccountLocalTaskOwner owner,
  required bool Function() current,
  required String peerId,
  required String? passphrase,
  required bool enable,
}) async {
  void requireCurrent() {
    if (!current()) throw StateError('Personal history owner changed');
  }

  final client = _historyClient(instance, cancel, requireCurrent);
  final status = await client.status();
  requireCurrent();
  final previous = _unlocked;
  if (previous != null &&
      (!previous.current || !status.authorizesSameScope(previous.status))) {
    previous.close();
  }
  await _historyUploadLock.synchronized(
    () => _observeUploadStatus(status, owner, requireCurrent),
  );
  if (enable) {
    final outcome = await _enablePersonalHistory(
      client: client,
      initial: status,
      instance: instance,
      owner: owner,
      requireCurrent: requireCurrent,
      passphrase: passphrase!,
    );
    final enabled = _unlocked;
    if (outcome.kind == PersonalHistorySyncOutcomeKind.cloudEnabled &&
        enabled != null &&
        enabled.current) {
      unawaited(_tryFlushWebHistory(enabled));
    }
    return outcome;
  }
  Future<void> requireAuthorization() async {
    final live = await client.status();
    requireCurrent();
    if (!live.authorizesSameScope(status)) {
      throw StateError('Personal history authorization changed');
    }
  }

  if (!status.enabled) {
    return PersonalHistorySyncOutcome(
      kind: status.state == 'OFF_PURGE_PENDING'
          ? PersonalHistorySyncOutcomeKind.purgePending
          : PersonalHistorySyncOutcomeKind.cloudOff,
    );
  }
  final domain = status.domain;
  if (domain == null || domain.isEmpty || status.generation == 0) {
    throw const FormatException('Invalid personal history scope');
  }
  var unlocked = _unlocked;
  if (unlocked == null) {
    final initial = await _readInitialPackage(client, status.generation);
    await requireAuthorization();
    if (initial == null) {
      return const PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.setupRequired,
      );
    }
    if (passphrase == null || passphrase.isEmpty) {
      return const PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.waitingKey,
      );
    }
    final authorization = ValueNotifier<bool>(true);
    PersonalHistoryKeyService? keys;
    try {
      final ring = keys = PersonalHistoryKeyService(
        domain: domain,
        generation: status.generation,
        authorization: authorization,
        owner: owner,
      );
      await ring.restorePackage(_wirePackage(initial), passphrase);
      await requireAuthorization();
      _rememberUnlocked(
        owner: owner,
        instance: instance,
        status: status,
        ring: ring,
        authorization: authorization,
      );
      unlocked = _unlocked;
    } finally {
      if (unlocked == null) {
        keys?.close();
        authorization.dispose();
      }
    }
  }

  final active = unlocked;
  if (active == null || !active.current) return _aborted;
  final db = await SqliteService.to.db;
  requireCurrent();
  if (db == null) throw StateError('Personal history database unavailable');
  Future<void> confirmDurable() =>
      _confirmUploadDurable(db, owner, requireCurrent);

  final store = PersonalHistoryLocalStore(() async {
    requireCurrent();
    return db;
  });
  Future<Map<String, dynamic>?> decryptCopy(_HistoryCopyEnvelope copy) async {
    _requireActive(active, requireCurrent);
    if (!active.ring.hasVersion(copy.keyVersion)) {
      if (passphrase == null) return null;
      final package = await client.getKeyPackage(
        keyVersion: copy.keyVersion,
        generation: status.generation,
      );
      _requireActive(active, requireCurrent);
      if (package.generation != status.generation ||
          package.keyVersion != copy.keyVersion) {
        throw const FormatException('Personal history package scope changed');
      }
      await requireAuthorization();
      await active.ring.restorePackage(_wirePackage(package), passphrase);
      await requireAuthorization();
    }
    _requireActive(active, requireCurrent);
    return _decryptHistory(copy, active.ring);
  }

  final engine = PersonalHistorySyncEngine(
    client: client,
    store: store,
    domain: domain,
    decrypt: (event) => decryptCopy((
      conversationId: event.conversationId,
      msgId: event.msgId,
      actionVersion: event.actionVersion,
      convSeq: event.convSeq,
      keyVersion: event.keyVersion,
      ciphertext: event.ciphertext,
      envelopeMeta: event.envelopeMeta,
      acceptedMessage: event.acceptedMessage,
    )),
    isCurrent: () => current() && active.current,
    durableConfirm: confirmDurable,
  );
  final upload = await _historyUploadLock.synchronized(() async {
    requireCurrent();
    return _flushWebHistory(
      active: active,
      client: client,
      cancel: cancel,
      refs: WebPersonalHistoryUploadRefs(
        db,
        owner.storageDigest,
        requireCurrent,
      ),
      store: store,
      engine: engine,
      requireCurrent: requireCurrent,
      confirmDurable: confirmDurable,
    );
  });
  final outcome = await engine.syncOnce(expectedAuthorization: status);
  if (outcome.kind != PersonalHistorySyncOutcomeKind.synced) {
    final error = outcome.error;
    if ((error is PersonalHistoryApiException &&
            error.code == PersonalHistoryErrorCode.generationExpired) ||
        (outcome.kind == PersonalHistorySyncOutcomeKind.aborted &&
            current() &&
            active.current)) {
      active.close();
    }
    return outcome;
  }
  final conversationId = _c2cHistoryKey(owner.uid, peerId);
  _SnapshotResult restored = (texts: const [], partial: false, position: null);
  if (conversationId != null) {
    try {
      restored = await _readRestoredText(
        store: store,
        client: client,
        status: status,
        conversationId: conversationId,
        start: active.snapshotPositions[conversationId],
        requireCurrent: () => _requireActive(active, requireCurrent),
        confirmDurable: confirmDurable,
        decryptCopy: decryptCopy,
      );
      final live = await client.status();
      _requireActive(active, requireCurrent);
      if (!live.authorizesSameScope(status)) {
        active.close();
        return _aborted;
      }
      final position = restored.position;
      if (position == null) {
        active.snapshotPositions.remove(conversationId);
      } else {
        active.snapshotPositions[conversationId] = position;
      }
    } on PersonalHistoryApiException catch (error) {
      if (error.code != PersonalHistoryErrorCode.generationExpired) rethrow;
      active.close();
      return _aborted;
    }
  }
  requireCurrent();
  final kind = upload.kind == PersonalHistorySyncOutcomeKind.synced
      ? outcome.kind
      : upload.kind;
  return PersonalHistorySyncOutcome(
    kind: restored.partial
        ? PersonalHistorySyncOutcomeKind.rescanRequired
        : kind,
    applied: outcome.applied,
    duplicates: outcome.duplicates,
    cursor: outcome.cursor,
    uploaded: upload.uploaded,
    recoveredText: restored.texts,
    canContinueSnapshot: restored.position != null,
  );
}

String? _c2cHistoryKey(String from, String to) {
  final fromId = BigInt.tryParse(from);
  final toId = BigInt.tryParse(to);
  if (fromId == null ||
      toId == null ||
      fromId <= BigInt.zero ||
      toId <= BigInt.zero ||
      fromId == toId) {
    return null;
  }
  return fromId < toId ? 'c2c:$fromId:$toId' : 'c2c:$toId:$fromId';
}

const _initialKeyVersion = 1;

Future<PersonalHistoryKeyPackageRead?> _readInitialPackage(
  PersonalHistoryApiClient client,
  int generation,
) async {
  try {
    final package = await client.getKeyPackage(
      keyVersion: _initialKeyVersion,
      generation: generation,
    );
    if (package.generation != generation ||
        package.keyVersion != _initialKeyVersion) {
      throw const FormatException('Personal history package scope changed');
    }
    return package;
  } on PersonalHistoryApiException catch (error) {
    if (error.code == PersonalHistoryErrorCode.keyPackageMissing) return null;
    rethrow;
  }
}

Future<PersonalHistorySyncOutcome> _enablePersonalHistory({
  required PersonalHistoryApiClient client,
  required PersonalHistoryStatus initial,
  required String instance,
  required AccountLocalTaskOwner owner,
  required void Function() requireCurrent,
  required String passphrase,
}) async {
  final domain = initial.domain;
  if (domain == null || domain.isEmpty) {
    throw const FormatException('Invalid personal history scope');
  }
  if (!initial.enabled &&
      initial.state != 'OFF' &&
      initial.state != 'OFF_PURGED') {
    return _aborted;
  }

  final expected = initial.enabled ? initial : await client.optIn(instance);
  requireCurrent();
  final status = await client.status();
  requireCurrent();
  if (!status.enabled ||
      status.generation != expected.generation ||
      status.domain != domain) {
    return _aborted;
  }
  await _historyUploadLock.synchronized(
    () => _observeUploadStatus(status, owner, requireCurrent),
  );
  Future<void> requireAuthorization() async {
    final live = await client.status();
    requireCurrent();
    if (!live.authorizesSameScope(status)) {
      throw StateError('Personal history authorization changed');
    }
  }

  final authorization = ValueNotifier<bool>(true);
  PersonalHistoryKeyService? keys;
  var retained = false;
  try {
    final ring = keys = PersonalHistoryKeyService(
      domain: domain,
      generation: status.generation,
      authorization: authorization,
      owner: owner,
    );
    final existing = await _readInitialPackage(client, status.generation);
    await requireAuthorization();
    if (existing == null) {
      ring.rotate(_initialKeyVersion);
      final package = await ring.sealPackage(_initialKeyVersion, passphrase);
      await requireAuthorization();
      await client.putKeyPackage(package, generation: status.generation);
    } else {
      await ring.restorePackage(_wirePackage(existing), passphrase);
    }
    await requireAuthorization();
    _rememberUnlocked(
      owner: owner,
      instance: instance,
      status: status,
      ring: ring,
      authorization: authorization,
    );
    retained = true;
    return const PersonalHistorySyncOutcome(
      kind: PersonalHistorySyncOutcomeKind.cloudEnabled,
    );
  } finally {
    if (!retained) {
      keys?.close();
      authorization.dispose();
    }
  }
}

Map<String, Object?> _wirePackage(PersonalHistoryKeyPackageRead package) => {
  'key_version': package.keyVersion,
  'wrapped_key': package.wrappedKey,
  'kdf_meta': package.kdfMeta,
  'integrity_hash': package.integrityHash,
};

PersonalHistoryApiClient _historyClient(
  String instance,
  CancelToken cancel,
  void Function() requireCurrent,
) => PersonalHistoryApiClient(
  webFace: true,
  clientInstance: instance,
  transport: (method, path, {queryParameters, data}) async {
    requireCurrent();
    final result = await HttpClient.client.dio.request<dynamic>(
      path,
      queryParameters: queryParameters,
      data: data,
      cancelToken: cancel,
      options: Options(
        method: method,
        extra: {httpRequestGuard: requireCurrent, httpNoAutoRetry: true},
      ),
    );
    requireCurrent();
    final envelope = result.data;
    return PersonalHistoryTransportResult(
      httpStatus: result.statusCode ?? 0,
      body: envelope is Map<String, dynamic> ? envelope : null,
    );
  },
);

Map<String, dynamic> _decryptHistory(
  _HistoryCopyEnvelope event,
  PersonalHistoryKeyService keyRing,
) {
  final source = event.acceptedMessage;
  if (source == null ||
      source.sequence != event.convSeq ||
      source.actionVersion != event.actionVersion ||
      _c2cHistoryKey(source.fromId, source.toId) != event.conversationId) {
    throw const FormatException('Missing accepted personal history source');
  }
  final meta = event.envelopeMeta;
  final bytes = keyRing.decrypt(
    (
      keyVersion: event.keyVersion,
      algorithm: meta['alg'] as String,
      nonce: meta['nonce'] as String,
      aad: meta['aad'] as String,
      ciphertext: event.ciphertext,
    ),
    (
      conversationId: event.conversationId,
      messageId: event.msgId,
      actionVersion: event.actionVersion,
      sequence: BigInt.from(event.convSeq),
    ),
  );
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['msg_id'] != event.msgId ||
        decoded['from'] != source.fromId ||
        decoded['to'] != source.toId) {
      throw const FormatException('Invalid personal history message');
    }
    // Locally stamp only the sequence verified by the accepted proof and AEAD.
    return {...decoded, _restoredConvSeq: event.convSeq};
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}
