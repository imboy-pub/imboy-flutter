import 'dart:convert';

import 'package:dio/dio.dart';
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
import 'sqlite.dart';

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
  if (enable) {
    return _enablePersonalHistory(
      client: client,
      initial: status,
      instance: instance,
      owner: owner,
      requireCurrent: requireCurrent,
      passphrase: passphrase!,
    );
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
  Future<void> confirmDurable() async {
    requireCurrent();
    await durableBrowserAccountDatabase(
      db,
      databaseName: SqliteService.databaseNameForUid(owner.uid),
    );
    requireCurrent();
  }

  final store = PersonalHistoryLocalStore(() async {
    requireCurrent();
    return db;
  });
  final engine = PersonalHistorySyncEngine(
    client: client,
    store: store,
    domain: domain,
    decrypt: (event) async {
      requireCurrent();
      if (!active.ring.hasVersion(event.keyVersion) && passphrase == null) {
        return null;
      }
      return _decryptHistory(
        event,
        loadKey: (version) async {
          if (active.ring.hasVersion(version)) return;
          final package = await client.getKeyPackage(
            keyVersion: version,
            generation: status.generation,
          );
          requireCurrent();
          if (package.generation != status.generation ||
              package.keyVersion != version) {
            throw const FormatException(
              'Personal history package scope changed',
            );
          }
          await requireAuthorization();
          await active.ring.restorePackage(_wirePackage(package), passphrase!);
          await requireAuthorization();
        },
        keyRing: active.ring,
      );
    },
    isCurrent: () => current() && active.current,
    durableConfirm: confirmDurable,
  );
  final upload = await _historyUploadLock.synchronized(() async {
    requireCurrent();
    await confirmDurable();
    return engine.flushUploads(generation: status.generation);
  });
  final outcome = await engine.syncOnce(expectedAuthorization: status);
  if (outcome.kind != PersonalHistorySyncOutcomeKind.synced) return outcome;
  await requireAuthorization();
  final conversationId = _c2cHistoryKey(owner.uid, peerId);
  final restored = conversationId == null
      ? const <String>[]
      : await _readRestoredText(store, client, status, conversationId);
  requireCurrent();
  return PersonalHistorySyncOutcome(
    kind: upload.kind == PersonalHistorySyncOutcomeKind.synced
        ? outcome.kind
        : upload.kind,
    applied: outcome.applied,
    duplicates: outcome.duplicates,
    cursor: outcome.cursor,
    uploaded: upload.uploaded,
    recoveredText: restored,
  );
}

/// Accepts a positively confirmed live C2C text row. Media and expiring
/// messages use different retention and authorization rules.
Future<void> archiveWebAcceptedC2cText({
  required AuthSessionScope session,
  required MessageModel message,
  required int? sequence,
  bool verifyOutbound = false,
}) async {
  final unlocked = _unlocked;
  if (!kIsWeb ||
      unlocked == null ||
      !unlocked.current ||
      unlocked.session != session ||
      message.type != 'C2C' ||
      message.msgType != 'text' ||
      message.id.isEmpty ||
      (!verifyOutbound && (sequence == null || sequence <= 0))) {
    return;
  }
  final payload = message.payloadMap;
  final text = payload['text'];
  if (text is! String ||
      text.isEmpty ||
      message.createdAt <= 0 ||
      ChatBurnService.isBurnPayload(payload) ||
      payload['burn_deleted'] == true) {
    return;
  }
  final from = message.fromId.toString();
  final to = message.toId.toString();
  final participant = verifyOutbound ? from == session.uid : to == session.uid;
  final conversationId = _c2cHistoryKey(from, to);
  if (!participant || conversationId == null) return;
  final cancel = CancelToken();
  try {
    await AccountLocalTaskRegistry.instance.run(
      unlocked.owner,
      onCancel: () => cancel.cancel(),
      operation: (task) => _historyUploadLock.synchronized(() async {
        bool current() => !task.isCancelled && unlocked.current;
        void requireCurrent() {
          if (!current()) throw StateError('Personal history owner changed');
        }

        requireCurrent();
        var acceptedSequence = sequence;
        if (verifyOutbound) {
          acceptedSequence = await MsgApi()
              .acceptedC2cSequence(
                peerId: to,
                messageId: message.id,
                cancelToken: cancel,
                requireCurrent: requireCurrent,
              )
              .timeout(const Duration(seconds: 3));
          requireCurrent();
          if (sequence != null && sequence != acceptedSequence) return;
        }
        if (acceptedSequence == null ||
            acceptedSequence <= 0 ||
            acceptedSequence > PersonalHistoryApiClient.maxSafeInteger) {
          return;
        }
        final client = _historyClient(
          unlocked.instance,
          cancel,
          requireCurrent,
        );
        final live = await client.status();
        requireCurrent();
        if (!live.authorizesSameScope(unlocked.status)) {
          unlocked.close();
          return;
        }
        final db = await SqliteService.to.db;
        requireCurrent();
        if (db == null) return;
        final store = PersonalHistoryLocalStore(() async {
          requireCurrent();
          return db;
        });
        final position = (
          conversationId: conversationId,
          messageId: message.id,
          actionVersion: 0,
          sequence: BigInt.from(acceptedSequence),
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
          sealed = unlocked.ring.encrypt(body, position);
        } finally {
          body.fillRange(0, body.length, 0);
        }
        await store.enqueueUpload(
          domain: unlocked.ring.domain,
          generation: unlocked.ring.generation,
          conversationId: conversationId,
          msgId: message.id,
          actionVersion: 0,
          convSeq: acceptedSequence,
          ciphertext: sealed.ciphertext,
          envelopeMeta: {
            'alg': sealed.algorithm,
            'key_version': sealed.keyVersion,
            'nonce': sealed.nonce,
            'aad': sealed.aad,
          },
          clientTs: DateTime.now().millisecondsSinceEpoch,
        );
        requireCurrent();
        await durableBrowserAccountDatabase(
          db,
          databaseName: SqliteService.databaseNameForUid(unlocked.owner.uid),
        );
        requireCurrent();
        await PersonalHistorySyncEngine(
          client: client,
          store: store,
          domain: unlocked.ring.domain,
          decrypt: (_) async => null,
          isCurrent: current,
        ).flushUploads(generation: unlocked.ring.generation);
      }),
    );
  } on Object catch (error) {
    if (unlocked.current) {
      AppLogger.warning(
        'Personal history upload interrupted (${error.runtimeType})',
      );
    }
  }
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

Future<List<String>> _readRestoredText(
  PersonalHistoryLocalStore store,
  PersonalHistoryApiClient client,
  PersonalHistoryStatus status,
  String conversationId,
) async {
  final page = await client.page(conversationId: conversationId);
  final messages = page['messages'];
  if (page['generation'] != status.generation ||
      page['conversation_id'] != conversationId ||
      messages is! List) {
    throw const FormatException('Invalid personal history snapshot');
  }
  final accepted = <String, PersonalHistoryAcceptedMessage>{};
  for (final value in messages) {
    if (value is! Map || value['deleted'] != false) continue;
    final proof = parsePersonalHistoryAcceptedMessage(
      value['accepted_message'],
    );
    final id = value['msg_id'];
    if (id is String &&
        proof != null &&
        value['conv_seq'] == proof.sequence &&
        value['action_version'] == proof.actionVersion) {
      accepted[id] = proof;
    }
  }
  final rows = await store.readRestoredRows(
    domain: status.domain!,
    generation: status.generation,
    conversationId: conversationId,
  );
  final texts = <String>[];
  for (final row in rows) {
    final proof = accepted[row['msg_id']];
    if (proof == null || row['action_version'] != proof.actionVersion) continue;
    final body = jsonDecode(row['row'] as String);
    if (body is! Map<String, dynamic> ||
        body['chat_type'] != 'c2c' ||
        body['msg_id'] != row['msg_id'] ||
        body['msg_type'] != 'text' ||
        body['from'] != proof.fromId ||
        body['to'] != proof.toId ||
        _c2cHistoryKey('${body['from']}', '${body['to']}') != conversationId) {
      continue;
    }
    final payload = body['payload'];
    if (payload is Map && payload['text'] is String) {
      texts.add(payload['text'] as String);
    }
  }
  return texts;
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

Future<Map<String, dynamic>> _decryptHistory(
  PersonalHistoryEvent event, {
  required Future<void> Function(int version) loadKey,
  required PersonalHistoryKeyService keyRing,
}) async {
  final source = event.acceptedMessage;
  if (source == null ||
      source.sequence != event.convSeq ||
      source.actionVersion != event.actionVersion ||
      _c2cHistoryKey(source.fromId, source.toId) != event.conversationId) {
    throw const FormatException('Missing accepted personal history source');
  }
  await loadKey(event.keyVersion);
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
    return decoded;
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}
