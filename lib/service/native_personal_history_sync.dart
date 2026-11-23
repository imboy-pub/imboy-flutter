import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/personal_history_key_service.dart';
import 'package:imboy/service/personal_history_native_transport.dart';
import 'package:imboy/service/web_personal_history_sync.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/sqflite_init.dart' show isEncryptionSupported;
import 'package:imboy/store/repository/message_repo_sqlite.dart';

enum NativeHistoryRestoreKind {
  restored,
  rescanRequired,
  enabled,
  wrongPassphrase,
  cloudOff,
  purgePending,
  missingPackage,
  cancelled,
  failed,
}

typedef NativeHistoryPageCursor = ({
  String owner,
  String domain,
  int generation,
  ({int mergedAt, String messageId, String conversationId}) after,
});

class NativeHistoryRestoreResult {
  const NativeHistoryRestoreResult(
    this.kind, {
    this.texts = const [],
    this.nextPage,
    this.moreToSync = false,
  });

  final NativeHistoryRestoreKind kind;
  final List<String> texts;
  final NativeHistoryPageCursor? nextPage;
  final bool moreToSync;
}

NativeHistoryRestoreResult _result(NativeHistoryRestoreKind kind) =>
    NativeHistoryRestoreResult(kind);

/// Restores the account's authorized personal history on native clients.
Future<NativeHistoryRestoreResult> restoreNativePersonalHistory({
  required AuthSessionScope session,
  required AccountLocalTaskOwner owner,
  String? passphrase,
  NativeHistoryPageCursor? page,
  bool enable = false,
  required bool Function() viewIsCurrent,
}) async {
  final instance = deviceId;
  bool current() =>
      viewIsCurrent() &&
      authSessionReader.isCurrent(session) &&
      !authSessionReader.transitionFailed &&
      AccountLocalTaskOwner.capture(uid: session.uid) == owner &&
      deviceId == instance;
  if (kIsWeb ||
      !isEncryptionSupported ||
      instance.isEmpty ||
      (page == null && (passphrase?.trim().isEmpty ?? true)) ||
      (page != null &&
          (enable ||
              passphrase != null ||
              page.owner != owner.storageDigest)) ||
      session.uid != owner.uid ||
      !current()) {
    return _result(NativeHistoryRestoreKind.cancelled);
  }

  final cancel = CancelToken();
  try {
    return await AccountLocalTaskRegistry.instance.run(
      owner,
      onCancel: () => cancel.cancel(),
      operation: (task) => _restore(
        uid: session.uid,
        owner: owner,
        page: page,
        session: session,
        instance: instance,
        enable: enable,
        client: createNativePersonalHistoryClient(
          owner: owner,
          instance: instance,
          cancel: cancel,
          guard: () {
            if (!current() || task.isCancelled) {
              throw const AccountLocalTaskCancelledException();
            }
          },
        ),
        passphrase: passphrase,
        isCurrent: () => current() && !task.isCancelled,
      ),
    );
  } on AccountLocalTaskCancelledException {
    return _result(NativeHistoryRestoreKind.cancelled);
  } on Object {
    return _result(
      current()
          ? NativeHistoryRestoreKind.failed
          : NativeHistoryRestoreKind.cancelled,
    );
  }
}

Future<NativeHistoryRestoreResult> _restore({
  required String uid,
  required AccountLocalTaskOwner owner,
  required NativeHistoryPageCursor? page,
  required AuthSessionScope session,
  required String instance,
  required bool enable,
  required PersonalHistoryApiClient client,
  required String? passphrase,
  required bool Function() isCurrent,
}) async {
  void guard() {
    if (!isCurrent()) throw const AccountLocalTaskCancelledException();
  }

  final initial = await client.status();
  guard();
  var status = initial;
  if (enable && (initial.state == 'OFF' || initial.state == 'OFF_PURGED')) {
    final domain = initial.domain;
    if (domain == null || domain.isEmpty) {
      return _result(NativeHistoryRestoreKind.failed);
    }
    final grant = await client.optIn(instance);
    guard();
    status = await client.status();
    guard();
    if (status.domain != domain ||
        status.generation != grant.generation ||
        !status.enabled) {
      return _result(NativeHistoryRestoreKind.cancelled);
    }
  }
  await observeNativePersonalHistoryGrant(
    owner: owner,
    status: status,
    guard: guard,
  );
  switch (status.state) {
    case 'OFF':
    case 'OFF_PURGED':
      return _result(NativeHistoryRestoreKind.cloudOff);
    case 'OFF_PURGE_PENDING':
      return _result(NativeHistoryRestoreKind.purgePending);
    case 'ON':
      break;
    default:
      return _result(NativeHistoryRestoreKind.failed);
  }
  final domain = status.domain;
  if (domain == null || domain.isEmpty || status.generation <= 0) {
    return _result(NativeHistoryRestoreKind.failed);
  }

  if (page != null) {
    if (page.domain != domain || page.generation != status.generation) {
      return _result(NativeHistoryRestoreKind.cancelled);
    }
    return _readVerifiedPage(
      await _accountStore(owner, guard),
      client,
      status,
      owner,
      page.after,
      guard,
    );
  }

  final authorization = ValueNotifier(true);
  PersonalHistoryKeyService? keys;
  var retained = false;
  try {
    final ring = keys = PersonalHistoryKeyService(
      domain: domain,
      generation: status.generation,
      authorization: authorization,
    );
    return await _restoreAuthorized(
      uid: uid,
      owner: owner,
      client: client,
      ring: ring,
      passphrase: passphrase!,
      status: status,
      enable: enable,
      onUnlocked: () async {
        await retainNativePersonalHistoryUploadKey(
          session: session,
          owner: owner,
          instance: instance,
          status: status,
          ring: ring,
          authorization: authorization,
          guard: guard,
        );
        retained = true;
        scheduleNativePersonalHistoryUploads(session, owner);
      },
      isCurrent: isCurrent,
      guard: guard,
    );
  } finally {
    if (!retained) {
      keys?.close();
      authorization.dispose();
    }
  }
}

Future<NativeHistoryRestoreResult> _restoreAuthorized({
  required String uid,
  required AccountLocalTaskOwner owner,
  required PersonalHistoryApiClient client,
  required PersonalHistoryKeyService ring,
  required String passphrase,
  required PersonalHistoryStatus status,
  required bool enable,
  required Future<void> Function() onUnlocked,
  required bool Function() isCurrent,
  required void Function() guard,
}) async {
  Future<void> confirmGrant() async {
    final latest = await client.status();
    guard();
    if (!latest.authorizesSameScope(status)) {
      throw const AccountLocalTaskCancelledException();
    }
  }

  Future<void> loadKey(int version) async {
    if (ring.hasVersion(version)) return;
    final package = await client.getKeyPackage(
      keyVersion: version,
      generation: status.generation,
    );
    guard();
    if (package.generation != status.generation ||
        package.keyVersion != version) {
      throw const FormatException('Personal history package scope changed');
    }
    await confirmGrant();
    await ring.restorePackage({
      'key_version': package.keyVersion,
      'wrapped_key': package.wrappedKey,
      'kdf_meta': package.kdfMeta,
      'integrity_hash': package.integrityHash,
    }, passphrase);
    await confirmGrant();
  }

  try {
    await loadKey(1);
  } on PersonalHistoryKeyException catch (error) {
    guard();
    if (error.reason == PersonalHistoryKeyFailure.authenticationFailed) {
      return _result(NativeHistoryRestoreKind.wrongPassphrase);
    }
    rethrow;
  } on PersonalHistoryApiException catch (error) {
    guard();
    if (error.code != PersonalHistoryErrorCode.keyPackageMissing) rethrow;
    if (!enable) return _result(NativeHistoryRestoreKind.missingPackage);
    final existing = await client.changes(cursor: 0, limit: 1);
    guard();
    if (existing.generation != status.generation ||
        existing.resetHint ||
        existing.events.isNotEmpty) {
      return _result(NativeHistoryRestoreKind.missingPackage);
    }
    await confirmGrant();
    ring.rotate(1);
    final wrapped = await ring.sealPackage(1, passphrase);
    await confirmGrant();
    await client.putKeyPackage(wrapped, generation: status.generation);
    await confirmGrant();
  }
  await onUnlocked();
  if (enable) return _result(NativeHistoryRestoreKind.enabled);

  final store = await _accountStore(owner, guard);
  final engine = PersonalHistorySyncEngine(
    client: client,
    store: store,
    domain: ring.domain,
    isCurrent: isCurrent,
    decrypt: (event) async {
      await loadKey(event.keyVersion);
      guard();
      return _decryptEvent(event, ring, uid);
    },
  );
  final outcome = await engine.syncOnce(expectedAuthorization: status);
  guard();
  if (outcome.kind == PersonalHistorySyncOutcomeKind.aborted) {
    return _result(NativeHistoryRestoreKind.cancelled);
  }
  if (outcome.kind == PersonalHistorySyncOutcomeKind.rescanRequired) {
    return _readVerifiedPage(
      store,
      client,
      status,
      owner,
      null,
      guard,
      kind: NativeHistoryRestoreKind.rescanRequired,
    );
  }
  if (outcome.kind != PersonalHistorySyncOutcomeKind.synced) {
    return _result(NativeHistoryRestoreKind.failed);
  }
  // A full batch at the engine limit does not prove the cloud scan is done.
  // Probe one row after the committed cursor, without applying or ACKing it.
  final pending = await client.changes(cursor: outcome.cursor, limit: 1);
  guard();
  if (pending.generation != status.generation) {
    return _result(NativeHistoryRestoreKind.cancelled);
  }
  return _readVerifiedPage(
    store,
    client,
    status,
    owner,
    null,
    guard,
    kind: pending.resetHint
        ? NativeHistoryRestoreKind.rescanRequired
        : NativeHistoryRestoreKind.restored,
    moreToSync: !pending.resetHint && pending.events.isNotEmpty,
  );
}

Future<PersonalHistoryLocalStore> _accountStore(
  AccountLocalTaskOwner owner,
  void Function() guard,
) async {
  final db = await SqliteService.to.db;
  guard();
  if (db == null) throw StateError('Personal history database unavailable');
  return PersonalHistoryLocalStore(() async {
    guard();
    return db;
  }, nativeOwnerDigest: owner.storageDigest);
}

String? _conversationKey(PersonalHistoryAcceptedMessage source, String uid) {
  final from = BigInt.tryParse(source.fromId);
  final to = BigInt.tryParse(source.toId);
  if (from == null ||
      to == null ||
      from <= BigInt.zero ||
      to <= BigInt.zero ||
      from == to ||
      (source.fromId != uid && source.toId != uid)) {
    return null;
  }
  return from < to ? 'c2c:$from:$to' : 'c2c:$to:$from';
}

Map<String, dynamic> _decryptEvent(
  PersonalHistoryEvent event,
  PersonalHistoryKeyService ring,
  String uid,
) {
  final source = event.acceptedMessage;
  if (source == null ||
      source.sequence != event.convSeq ||
      source.actionVersion != event.actionVersion ||
      _conversationKey(source, uid) != event.conversationId) {
    throw const FormatException('Unverified personal history source');
  }
  final m = event.envelopeMeta;
  final bytes = ring.decrypt(
    (
      keyVersion: event.keyVersion,
      algorithm: m['alg'] as String,
      nonce: m['nonce'] as String,
      aad: m['aad'] as String,
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
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> ||
        _text(data, event.msgId, source) == null) {
      throw const FormatException('Invalid personal history body');
    }
    // Persist only the verified server position. It allows exact older proof
    // lookups without scanning the recent snapshot on every recovery page.
    return {...data, '_history_server_sequence': event.convSeq};
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}

String? _text(
  Map<String, dynamic> row,
  Object? msgId,
  PersonalHistoryAcceptedMessage source,
) {
  if (row['msg_id'] != msgId ||
      row['chat_type'] != 'c2c' ||
      row['msg_type'] != 'text' ||
      row['from'] != source.fromId ||
      row['to'] != source.toId) {
    return null;
  }
  final payload = row['payload'];
  final text = payload is Map ? payload['text'] : null;
  return text is String ? text : null;
}

/// Page the committed projection by its stable key, including filtered-out rows.
Future<NativeHistoryRestoreResult> _readVerifiedPage(
  PersonalHistoryLocalStore store,
  PersonalHistoryApiClient client,
  PersonalHistoryStatus status,
  AccountLocalTaskOwner owner,
  ({int mergedAt, String messageId, String conversationId})? after,
  void Function() guard, {
  bool moreToSync = false,
  NativeHistoryRestoreKind kind = NativeHistoryRestoreKind.restored,
}) async {
  final rows = await store.readRestoredRows(
    domain: status.domain!,
    generation: status.generation,
    after: after,
    limit: 21,
  );
  guard();
  final texts = <String>[];
  NativeHistoryPageCursor? nextPage;
  for (final row in rows.take(20)) {
    final conversation = row['conversation_id'] as String;
    final messageId = row['msg_id'] as String;
    nextPage = (
      owner: owner.storageDigest,
      domain: status.domain!,
      generation: status.generation,
      after: (
        mergedAt: row['merged_at'] as int,
        messageId: messageId,
        conversationId: conversation,
      ),
    );
    final data = jsonDecode(row['row'] as String);
    if (data is! Map<String, dynamic>) continue;
    final version = row['action_version'] as int;
    final fact = await _readVisibleFact(
      client,
      status,
      owner.uid,
      conversation,
      messageId,
      version,
      data['_history_server_sequence'],
      guard,
    );
    if (fact == null) continue;
    final text = _text(data, messageId, fact);
    if (text != null) texts.add(text);
  }
  final latest = await client.status();
  guard();
  if (!latest.authorizesSameScope(status)) {
    return _result(NativeHistoryRestoreKind.cancelled);
  }
  return NativeHistoryRestoreResult(
    kind,
    texts: texts,
    nextPage: rows.length > 20 ? nextPage : null,
    moreToSync: moreToSync,
  );
}

Future<PersonalHistoryAcceptedMessage?> _readVisibleFact(
  PersonalHistoryApiClient client,
  PersonalHistoryStatus status,
  String uid,
  String conversation,
  String messageId,
  int version,
  Object? rawSequence,
  void Function() guard,
) async {
  final sequence =
      rawSequence is int &&
          rawSequence > 0 &&
          rawSequence <= PersonalHistoryApiClient.maxSafeInteger
      ? rawSequence
      : null;
  final seenTokens = <String>{};
  String? token;
  var before = sequence == null ? 0 : sequence + 1;
  int? observedAnchor;
  for (;;) {
    final Map<String, dynamic> page;
    try {
      page = await client.page(
        conversationId: conversation,
        before: before,
        pageToken: token,
      );
    } on PersonalHistoryApiException catch (error) {
      guard();
      if (token == null ||
          observedAnchor == null ||
          (error.code != PersonalHistoryErrorCode.pageTokenExpired &&
              error.code != PersonalHistoryErrorCode.rescanBoundExceeded)) {
        rethrow;
      }
      // Re-anchor only this snapshot to the last actual row we examined.
      // It does not change the account change-log checkpoint or acknowledge it.
      before = observedAnchor;
      token = null;
      continue;
    }
    guard();
    final rows = page['messages'];
    final hasMore = page['has_more'];
    if (page['generation'] != status.generation ||
        page['conversation_id'] != conversation ||
        rows is! List ||
        hasMore is! bool) {
      throw const FormatException('Invalid personal history page');
    }
    for (final row in rows) {
      if (row is! Map || row['msg_id'] != messageId) continue;
      final fact = parsePersonalHistoryAcceptedMessage(row['accepted_message']);
      if (fact != null &&
          row['deleted'] == false &&
          row['conv_seq'] == fact.sequence &&
          (sequence == null || sequence == fact.sequence) &&
          row['action_version'] == version &&
          fact.actionVersion == version &&
          _conversationKey(fact, uid) == conversation) {
        return fact;
      }
      return null;
    }
    // New rows can address their exact position. Older projections without a
    // position follow the signed snapshot tokens until the target is reached.
    if (sequence != null || !hasMore) return null;
    final next = page['page_token'];
    final last = rows.lastOrNull;
    final lastSequence = last is Map ? last['conv_seq'] : null;
    if (next is! String ||
        next.isEmpty ||
        !seenTokens.add(next) ||
        lastSequence is! int ||
        lastSequence <= 0 ||
        (observedAnchor != null && lastSequence >= observedAnchor)) {
      throw const FormatException('Invalid personal history continuation');
    }
    observedAnchor = lastSequence;
    token = next;
  }
}
