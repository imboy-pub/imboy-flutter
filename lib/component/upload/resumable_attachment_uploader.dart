import 'package:imboy/service/server_ack_receipts.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:crypto/crypto.dart';
import 'package:imboy/config/init.dart' show currentEnv, navigatorKey;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/message_retry.dart';

import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/component/upload/attachment_template_restore.dart';

Uint8List _hexDecode(String hex) => Uint8List.fromList(
  List<int>.generate(
    hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  ),
);

/// W5-01 密钥材料安全存储抽象。
///
/// 生产默认 [SecureUploadKeyStore]（flutter_secure_storage，经
/// [StorageSecureService]）；测试注入内存实现。contentKey/baseNonce
/// 绝不进 SQLite——任务行只保存 [ref] 引用。
abstract class UploadKeyStore {
  Future<void> write(String ref, Map<String, String> material);
  Future<Map<String, String>?> read(String ref);
}

/// 生产实现：安全存储（键前缀 utk_，值 JSON {content_key, base_nonce}，
/// 均为 base64）。
class SecureUploadKeyStore implements UploadKeyStore {
  SecureUploadKeyStore()
    : _uid = UserRepoLocal.to.currentUid,
      _generation = UserRepoLocal.to.sessionGeneration,
      _environment = currentEnv;

  final String _uid;
  final int _generation;
  final String _environment;

  String _storageKey(String ref) =>
      '$_prefix${Uri.encodeComponent(_environment)}:${Uri.encodeComponent(_uid)}:${Uri.encodeComponent(ref)}';

  static const String _prefix = 'utk_';

  @override
  Future<void> write(String ref, Map<String, String> material) async {
    await UserRepoLocal.to.writeSessionSecret(
      uid: _uid,
      generation: _generation,
      write: () async {
        _requireScope();
        await StorageSecureService.to.write(
          key: _storageKey(ref),
          value: jsonEncode(material),
        );
        _requireScope();
      },
      discard: () => StorageSecureService.to.delete(key: _storageKey(ref)),
    );
  }

  void _requireScope() {
    final actor = UserRepoLocal.to;
    if (_uid.isEmpty ||
        actor.currentUid != _uid ||
        !actor.isCurrentSession(_generation) ||
        actor.isAuthTransitioning ||
        currentEnv != _environment) {
      throw StateError('upload secret scope changed');
    }
  }

  @override
  Future<Map<String, String>?> read(String ref) async {
    _requireScope();
    final String? raw = await StorageSecureService.to.read(
      key: _storageKey(ref),
    );
    _requireScope();
    if (raw == null || raw.isEmpty) return null;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded.cast<String, String>();
  }
}

class LostCipherMaterialError implements Exception {
  final String taskId;
  LostCipherMaterialError(this.taskId);
  @override
  String toString() => 'LostCipherMaterialError($taskId)';
}

class ResumableAttachmentUploader {
  ResumableAttachmentUploader({
    AttachmentUploadTaskRepo? repo,
    UploadKeyStore? keyStore,
    bool Function(String userId)? sessionGuard,
    AttachmentSealRequest? sealRequest,
    this.encrypt = true,
    this.process = true,
    this.cacheDirectory,
    this.cacheWriter,
    this.directSessionFn,
    this.directPutFn,
    this.legacyMigrationBarrier,
    this.legacyMigrationCommittedBarrier,
  }) : _repo = repo ?? AttachmentUploadTaskRepo(),
       _keys = keyStore ?? SecureUploadKeyStore(),
       _sessionGuard = sessionGuard ?? _currentSessionGuard(),
       _externalSeal = sealRequest,
       _generation = UserRepoLocal.to.sessionGeneration;

  final AttachmentUploadTaskRepo _repo;
  final UploadKeyStore _keys;
  final AttachmentSealRequest? _externalSeal;
  final bool encrypt;
  final bool process;
  final Directory? cacheDirectory;
  final DirectSessionFn? directSessionFn;
  final DirectFilePutFn? directPutFn;
  final Future<void> Function(String replacementId)? legacyMigrationBarrier;
  final Future<void> Function(String replacementId)?
  legacyMigrationCommittedBarrier;
  final Future<void> Function(Future<void> Function(), Future<void> Function())?
  cacheWriter;
  final int _generation;
  final bool Function(String userId) _sessionGuard;

  static bool Function(String userId) _currentSessionGuard() {
    final actor = UserRepoLocal.to;
    final generation = actor.sessionGeneration;
    final environment = currentEnv;
    return (userId) =>
        actor.currentUid == userId &&
        actor.isCurrentSession(generation) &&
        !actor.isAuthTransitioning &&
        currentEnv == environment;
  }

  void _requireSession(String userId) {
    if (userId.isEmpty || !_sessionGuard(userId)) {
      throw StateError('upload session changed');
    }
  }

  Future<String> uploadProduction({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String mime,
    required String scope,
    String? scopeRef,
    String? anchorMsgId,
    String? clientUploadId,
    Map<String, dynamic>? messageIntent,
    bool prepareOnly = false,
  }) async {
    _requireSession(userId);
    final binding =
        _externalSeal?.bindingHash
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join() ??
        '';
    final digest = sha256.convert(bytes).toString();
    final rows = await _repo.listResumable(userId);
    final matches = rows
        .where(
          (r) =>
              r.scope == scope &&
              r.scopeRef == scopeRef &&
              r.anchorMsgId == anchorMsgId &&
              r.fileName == fileName &&
              r.mime == mime &&
              r.plainSha256 == digest &&
              r.bindingHash == binding,
        )
        .toList();
    if (clientUploadId == null && matches.length > 1) {
      throw StateError('ambiguous resumable upload; select a client_upload_id');
    }
    final id =
        clientUploadId ?? (matches.isNotEmpty ? matches.single.id : _newUuid());
    return upload(
      idempotencyKey: id,
      userId: userId,
      bytes: bytes,
      fileName: fileName,
      mime: mime,
      bindingHashHex: binding,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      prepareOnly: prepareOnly,
    );
  }

  static String _newUuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<File> _cacheFile(AttachmentUploadTask task) async {
    final root = cacheDirectory ?? await getApplicationCacheDirectory();
    final scope = sha256
        .convert(utf8.encode('$currentEnv:${task.userId}'))
        .toString();
    final name = sha256.convert(utf8.encode(task.id)).toString();
    final directory = Directory('${root.path}/attachment_uploads/$scope');
    await directory.create(recursive: true);
    return File('${directory.path}/$name.bin');
  }

  Future<File> _migrationFile(
    AttachmentUploadTask task,
    String replacementId,
  ) async {
    final parent = (await _cacheFile(task)).parent;
    final name = sha256.convert(utf8.encode(replacementId)).toString();
    return File('${parent.path}/$name.migration');
  }

  Future<void> _cleanupMigrationParts(File target) async {
    final prefix = '${target.path}.part-';
    await for (final entry in target.parent.list()) {
      if (entry is File && entry.path.startsWith(prefix)) {
        try {
          await entry.delete();
        } on FileSystemException {
          // An active concurrent writer may still own this encrypted part.
        }
      }
    }
  }

  Uint8List _migrationKey(
    Uint8List original,
    String id,
    String purpose,
    int length,
  ) {
    final digest = Hmac(
      sha256,
      original,
    ).convert(utf8.encode('imboy-legacy-migration-v1:$id:$purpose'));
    return Uint8List.fromList(digest.bytes.sublist(0, length));
  }

  Map<String, String> _derivedMigrationMaterial(
    AttachmentUploadTask task,
    String replacementId,
    Map<String, String> original, {
    String? finalObjectKey,
  }) {
    final oldKey = Uint8List.fromList(base64Decode(original['content_key']!));
    if (oldKey.length != 32) throw LostCipherMaterialError(task.id);
    final uploadKey = _migrationKey(oldKey, replacementId, 'upload-key', 32);
    final uploadNonce = _migrationKey(
      oldKey,
      replacementId,
      'upload-nonce',
      12,
    );
    final stageKey = _migrationKey(oldKey, replacementId, 'staging-key', 32);
    final stageNonce = _migrationKey(
      oldKey,
      replacementId,
      'staging-nonce',
      12,
    );
    final chunkSize = int.parse(
      original['chunk_size'] ?? '${AttachmentEncryptor.defaultChunkSize}',
    );
    AttachmentDescriptor descriptor(
      String id,
      String key,
      Uint8List contentKey,
      Uint8List nonce,
      int chunks, {
      AttachmentDescriptor? thumb,
    }) => AttachmentDescriptor(
      attachmentId: id,
      objectKey: key,
      contentKey: contentKey,
      cipher: AttachmentDescriptor.supportedCipher,
      chunkSize: chunks,
      chunkCount: AttachmentDescriptor.expectedChunkCount(
        task.plainSize,
        chunks,
      ),
      baseNonce: nonce,
      plainSize: task.plainSize,
      plainSha256: _hexDecode(task.plainSha256),
      mime: task.mime,
      name: task.fileName,
      thumb: thumb,
    );
    final temp = descriptor(
      'migration-$replacementId',
      'migration/$replacementId',
      stageKey,
      stageNonce,
      AttachmentEncryptor.defaultChunkSize,
    );
    final thumb = original['thumb'] == null
        ? null
        : AttachmentDescriptor.fromMap(
            jsonDecode(original['thumb']!) as Map<String, dynamic>,
          );
    return {
      'content_key': base64Encode(uploadKey),
      'base_nonce': base64Encode(uploadNonce),
      'attachment_id': replacementId,
      'chunk_size': '$chunkSize',
      'migration_descriptor': jsonEncode(temp.toMap()),
      if (original['thumb'] != null) 'thumb': original['thumb']!,
      if (finalObjectKey != null && finalObjectKey.isNotEmpty)
        'descriptor': jsonEncode(
          descriptor(
            replacementId,
            finalObjectKey,
            uploadKey,
            uploadNonce,
            chunkSize,
            thumb: thumb,
          ).toMap(),
        ),
    };
  }

  // Retain legacy plaintext until durable source ownership and absence of
  // references can both be proven atomically. A digest alone is not proof.
  Future<void> _cleanupLegacyPlainSource(AttachmentUploadTask task) async {}

  /// Keeps the old journal row until encrypted staging and key material are durable.
  Future<String> _migrateLegacy(
    AttachmentUploadTask task, {
    bool allowConfirmedVideoThumb = false,
  }) async {
    _requireSession(task.userId);
    if (task.cipher == null) {
      throw LostCipherMaterialError(task.id);
    }
    final oldMaterial = await _loadMaterials(task);
    if (oldMaterial == null ||
        task.uploadPath == null ||
        oldMaterial['content_key'] == null ||
        oldMaterial['base_nonce'] == null) {
      throw LostCipherMaterialError(task.id);
    }
    final cached = await File(task.uploadPath!).readAsBytes();
    _requireSession(task.userId);
    final originalKey = Uint8List.fromList(
      base64Decode(oldMaterial['content_key']!),
    );
    if (originalKey.length != 32) throw LostCipherMaterialError(task.id);
    final oldCache = (await _cacheFile(task)).path;
    final Uint8List plaintext;
    if (task.uploadPath == '$oldCache.source') {
      plaintext = cached;
    } else if (task.uploadPath == '$oldCache.source.enc') {
      plaintext = await _readEncryptedSource(
        task,
        oldMaterial,
        File(task.uploadPath!),
      );
    } else if ((task.uploadPath == oldCache ||
            task.uploadPath!.startsWith('$oldCache.material-')) &&
        oldMaterial['descriptor'] != null &&
        sha256.convert(cached).toString() == task.ciphertextSha256) {
      final descriptor = AttachmentDescriptor.fromMap(
        jsonDecode(oldMaterial['descriptor']!) as Map<String, dynamic>,
      );
      if (descriptor.objectKey != task.objectKey ||
          base64Encode(descriptor.contentKey) != oldMaterial['content_key'] ||
          base64Encode(descriptor.baseNonce) != oldMaterial['base_nonce']) {
        throw LostCipherMaterialError(task.id);
      }
      plaintext = AttachmentEncryptor.open(
        ciphertext: cached,
        descriptor: descriptor,
        bindingHash: _hexDecode(task.bindingHash!),
      );
    } else {
      throw LostCipherMaterialError(task.id);
    }
    if (plaintext.length != task.plainSize ||
        sha256.convert(plaintext).toString() != task.plainSha256) {
      throw LostCipherMaterialError(task.id);
    }
    _requireSession(task.userId);
    final replacementId = await _repo.reserveLegacyMigration(
      task,
      _newUuid(),
      isCurrent: () => _sessionGuard(task.userId),
      allowConfirmedVideoThumb: allowConfirmedVideoThumb,
    );
    await legacyMigrationBarrier?.call(replacementId);
    _requireSession(task.userId);
    final tempKey = _migrationKey(
      originalKey,
      replacementId,
      'staging-key',
      32,
    );
    final tempNonce = _migrationKey(
      originalKey,
      replacementId,
      'staging-nonce',
      12,
    );
    final stage = AttachmentEncryptor.seal(
      plaintext: plaintext,
      bindingHash: _hexDecode(task.bindingHash!),
      attachmentId: 'migration-$replacementId',
      objectKey: 'migration/$replacementId',
      mime: task.mime,
      name: task.fileName,
      contentKey: tempKey,
      baseNonce: tempNonce,
    );
    final target = await _migrationFile(task, replacementId);
    final temporary = File('${target.path}.part-${_newUuid()}');
    await temporary.writeAsBytes(stage.ciphertext, flush: true);
    _requireSession(task.userId);
    await temporary.rename(target.path);
    _requireSession(task.userId);
    if (!await _repo.commitLegacyMigration(
      task,
      replacementId,
      target.path,
      isCurrent: () => _sessionGuard(task.userId),
    )) {
      // Another recovery may already have committed the same deterministic replacement.
      final replacement = await _repo.find(replacementId);
      if (replacement == null ||
          replacement.userId != task.userId ||
          replacement.lastError !=
              AttachmentUploadTaskRepo.legacyMigrationMarker(task)) {
        throw StateError('legacy migration commit failed');
      }
      // A late writer must not recreate staging after the replacement advanced.
      if (replacement.uploadPath != target.path && await target.exists()) {
        await target.delete();
      }
    }
    await _cleanupMigrationParts(target);
    await legacyMigrationCommittedBarrier?.call(replacementId);
    _requireSession(task.userId);
    final replacement = await _repo.find(replacementId);
    if (replacement == null) throw StateError('legacy replacement missing');
    await _cleanupLegacyPlainSource(replacement);
    return replacementId;
  }

  AttachmentDescriptor _sourceDescriptor(
    AttachmentUploadTask task,
    Map<String, String> material,
  ) {
    final key = Uint8List.fromList(base64Decode(material['content_key']!));
    if (key.length != 32) throw LostCipherMaterialError(task.id);
    final chunkSize = AttachmentEncryptor.defaultChunkSize;
    return AttachmentDescriptor(
      attachmentId: 'source-${task.id}',
      objectKey: 'source/${task.id}',
      contentKey: _migrationKey(key, task.id, 'source-cache-key', 32),
      cipher: AttachmentDescriptor.supportedCipher,
      chunkSize: chunkSize,
      chunkCount: AttachmentDescriptor.expectedChunkCount(
        task.plainSize,
        chunkSize,
      ),
      baseNonce: _migrationKey(key, task.id, 'source-cache-nonce', 12),
      plainSize: task.plainSize,
      plainSha256: _hexDecode(task.plainSha256),
      mime: task.mime,
      name: task.fileName,
    );
  }

  Future<Uint8List> _readEncryptedSource(
    AttachmentUploadTask task,
    Map<String, String> material,
    File file,
  ) async {
    final bytes = await file.readAsBytes();
    _requireSession(task.userId);
    return AttachmentEncryptor.open(
      ciphertext: bytes,
      descriptor: _sourceDescriptor(task, material),
      bindingHash: _hexDecode(task.bindingHash!),
    );
  }

  Future<AttachmentUploadTask?> _recoverEncryptedSource(
    AttachmentUploadTask task,
    Map<String, String> material,
  ) async {
    final target = File('${(await _cacheFile(task)).path}.source.enc');
    final candidates = <File>[];
    if (await target.exists()) candidates.add(target);
    await for (final entry in target.parent.list()) {
      if (entry is File && entry.path.startsWith('${target.path}.part-')) {
        candidates.add(entry);
      }
    }
    for (final candidate in candidates) {
      try {
        final source = await _readEncryptedSource(task, material, candidate);
        if (source.length != task.plainSize ||
            sha256.convert(source).toString() != task.plainSha256) {
          continue;
        }
        _requireSession(task.userId);
        if (candidate.path != target.path) await candidate.rename(target.path);
        _requireSession(task.userId);
        if (!await _repo.advanceStage(
          task.id,
          task.stage,
          task.stage,
          userId: task.userId,
          uploadPath: target.path,
        )) {
          throw StateError('source recovery checkpoint failed');
        }
        await _cleanupMigrationParts(target);
        return task.copyWith(uploadPath: target.path);
      } on AttachmentSealException {
        // A crash may leave an incomplete encrypted part; never trust it.
      } on FileSystemException {
        // A concurrent recovery can move an encrypted part; try the next one.
      }
    }
    return null;
  }

  Future<void> _cacheSource(AttachmentUploadTask task, Uint8List bytes) async {
    final encrypted = task.cipher != null;
    final base = (await _cacheFile(task)).path;
    final file = File('$base.source${encrypted ? '.enc' : ''}');
    final temporary = File('${file.path}.part-${_newUuid()}');
    Uint8List output = bytes;
    if (encrypted) {
      final material = await _loadMaterials(task);
      if (material == null || material['content_key'] == null) {
        throw LostCipherMaterialError(task.id);
      }
      final descriptor = _sourceDescriptor(task, material);
      output = AttachmentEncryptor.seal(
        plaintext: bytes,
        bindingHash: _hexDecode(task.bindingHash!),
        attachmentId: descriptor.attachmentId,
        objectKey: descriptor.objectKey,
        mime: descriptor.mime,
        name: descriptor.name,
        contentKey: descriptor.contentKey,
        baseNonce: descriptor.baseNonce,
        chunkSize: descriptor.chunkSize,
      ).ciphertext;
    }
    Future<void> write() async {
      _requireSession(task.userId);
      await temporary.writeAsBytes(output, flush: true);
      _requireSession(task.userId);
      await temporary.rename(file.path);
      if (!await _repo.advanceStage(
        task.id,
        AttachmentUploadStage.pending,
        AttachmentUploadStage.pending,
        userId: task.userId,
        uploadPath: file.path,
      )) {
        throw StateError('source checkpoint failed');
      }
      await _cleanupMigrationParts(file);
    }

    Future<void> discard() async {
      if (await temporary.exists()) await temporary.delete();
    }

    if (cacheWriter != null) {
      await cacheWriter!(write, discard);
    } else {
      await UserRepoLocal.to.writeSessionSecret(
        uid: task.userId,
        generation: _generation,
        write: write,
        discard: discard,
      );
    }
  }

  Future<void> _cacheUpload(
    AttachmentUploadTask task,
    UploadCheckpoint event, {
    String? expectedKeyRef,
  }) async {
    if (event.uploadBytes == null) {
      throw StateError('upload checkpoint missing bytes');
    }
    final base = await _cacheFile(task);
    final file = File('${base.path}.material-${_newUuid()}');
    final temporary = File('${file.path}.tmp');
    Future<void> write() async {
      _requireSession(task.userId);
      await temporary.writeAsBytes(event.uploadBytes!, flush: true);
      _requireSession(task.userId);
      await temporary.rename(file.path);
      if (!await _repo.advanceStage(
        task.id,
        AttachmentUploadStage.presigned,
        AttachmentUploadStage.presigned,
        userId: task.userId,
        uploadPath: file.path,
        ciphertextSha256: event.ciphertextSha256,
        expectedKeyRef: expectedKeyRef,
      )) {
        throw StateError('upload cache checkpoint failed');
      }
      _requireSession(task.userId);
      final source = File('${base.path}.source');
      if (await source.exists()) await source.delete();
      final encryptedSource = File('${base.path}.source.enc');
      if (await encryptedSource.exists()) await encryptedSource.delete();
      await _cleanupMigrationParts(encryptedSource);
      if (task.lastError?.startsWith('legacy_migrated:') ?? false) {
        final migration = await _migrationFile(task, task.id);
        if (await migration.exists()) await migration.delete();
        await _cleanupMigrationParts(migration);
      }
    }

    Future<void> discard() async {
      if (await temporary.exists()) await temporary.delete();
    }

    if (cacheWriter != null) {
      await cacheWriter!(write, discard);
    } else {
      await UserRepoLocal.to.writeSessionSecret(
        uid: task.userId,
        generation: _generation,
        write: write,
        discard: discard,
      );
    }
  }

  static Future<void>? _recovering;
  static String? _recoveringScope;
  static Future<void> recoverCurrentSession() {
    final actor = UserRepoLocal.to;
    if (!actor.isLoggedIn || actor.isAuthTransitioning) return Future.value();
    final uid = actor.currentUid;
    final scope = '$currentEnv:$uid:${actor.sessionGeneration}';
    if (_recovering != null) {
      return _recoveringScope == scope
          ? _recovering!
          : _recovering!.then((_) => recoverCurrentSession());
    }
    _recoveringScope = scope;
    _recovering = () async {
      try {
        final uploader = ResumableAttachmentUploader();
        // 单阶段故障不阻挡已经确认的业务 outbox；账号切换仍停止整轮。
        for (final recover in <Future<void> Function()>[
          () => ServerAckReceipts.restoreDurable(uid, uploader._generation),
          () async {
            await uploader.resumeAll(uid);
          },
          () => uploader.reconcileMessages(uid),
          () => uploader.recoverBusinessOutbox(uid),
        ]) {
          uploader._requireSession(uid);
          try {
            await recover();
          } on Object {
            uploader._requireSession(uid);
            debugPrint(
              '[attachment_upload] recovery phase blocked; checkpoints retained',
            );
          }
        }
        uploader._requireSession(uid);
        if (await uploader.repo.hasUnrecoverableNonChat(uid)) {
          uploader._requireSession(uid);
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            AppLoading.showError(t.common.legacyUploadReturnToOriginalPage);
          }
        }
      } on Object {
        debugPrint(
          '[attachment_upload] recovery blocked; checkpoints retained',
        );
      } finally {
        _recovering = null;
      }
    }();
    return _recovering!;
  }

  Future<void> reconcileMessages(String uid, {MsgApi? api}) async {
    for (final row in await _repo.listBusinessPending(uid)) {
      _requireSession(uid);
      if (row.stage != AttachmentUploadStage.confirmed) continue;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      if (intent['author_id'] != uid || intent['state'] == 'committed') {
        continue;
      }
      if (intent['state'] == 'outbox_ready' ||
          intent['state'] == 'dispatch_reserved_v2') {
        continue;
      }
      if (intent['state'] == 'uploading' &&
          intent['message_template'] != null) {
        continue;
      }
      if (intent['message'] == null && intent['message_template'] == null) {
        await _repo.saveBusinessIntent(
          row.anchorMsgId!,
          uid,
          jsonEncode({...intent, 'state': 'unknown_business_intent'}),
        );
        continue;
      }
      final type = intent['chat_type'].toString();
      if (type != 'c2c' && type != 'c2g') {
        continue;
      }
      final committed = await (api ?? MsgApi()).isCommitted(
        chatType: type,
        peerId: intent['peer_id'].toString(),
        messageId: row.anchorMsgId!,
      );
      _requireSession(uid);
      if ({'dispatch_intent', 'commit_unknown'}.contains(intent['state'])) {
        final changed = committed
            ? await _repo.reconcileOutboxCommitted(
                row.anchorMsgId!,
                uid,
                isCurrent: () => _sessionGuard(uid),
              )
            : await _repo.markOutboxUnknown(
                row.anchorMsgId!,
                uid,
                type,
                isCurrent: () => _sessionGuard(uid),
              );
        if (changed && committed) {
          final messages = MessageRepo(
            tableName: MessageRepo.getTableName(type.toUpperCase()),
          );
          final message = await messages.find(row.anchorMsgId!);
          if (message != null && _sessionGuard(uid)) {
            ServerAckReceipts.announceVerified(
              message: message,
              ownerUid: uid,
              generation: _generation,
              isCurrent: () => _sessionGuard(uid),
            );
          }
        }
        continue;
      }
      if (committed) {
        final repo = MessageRepo(
          tableName: MessageRepo.getTableName(type.toUpperCase()),
        );
        if (await repo.find(row.anchorMsgId!) != null) {
          await repo.update({
            'id': row.anchorMsgId,
            'status': IMBoyMessageStatus.sent,
          });
        }
      }
      await _repo.saveBusinessIntent(
        row.anchorMsgId!,
        uid,
        jsonEncode({
          ...intent,
          'state': committed ? 'committed' : 'commit_unknown',
        }),
      );
    }
  }

  Future<void> recoverBusinessOutbox(
    String uid, {
    Future<MessageModel> Function(Map<String, dynamic>, Message)?
    prepareMessage,
    void Function(String, String)? notifyRetry,
  }) async {
    final seen = <String>{};
    for (final row in await _repo.listBusinessPending(uid)) {
      _requireSession(uid);
      if (row.anchorMsgId == null || !seen.add(row.anchorMsgId!)) continue;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      if (intent['author_id'] != uid ||
          !{
            'uploading',
            'outbox_ready',
            'dispatch_reserved_v2',
          }.contains(intent['state'])) {
        continue;
      }
      try {
        if (intent['state'] == 'uploading') {
          final message = messageFromPendingTemplate(
            await restoreMessageTemplate(row),
          );
          final model =
              await (prepareMessage?.call(intent, message) ??
                  const ChatNetworkService().prepareAttachmentOutboxMessage(
                    type: intent['chat_type'].toString().toUpperCase(),
                    conversationUk3: intent['conversation_uk3'].toString(),
                    message: message,
                  ));
          _requireSession(uid);
          if (!await _repo.enqueueBusinessOutbox(
            model,
            userId: uid,
            isCurrent: () => _sessionGuard(uid),
          )) {
            continue;
          }
        }
        _requireSession(uid);
        (notifyRetry ?? MessageRetry.instance.addToRetryQueue)(
          row.anchorMsgId!,
          intent['chat_type'].toString(),
        );
      } on Object {
        debugPrint(
          '[attachment_upload] business outbox blocked; original template retained',
        );
      }
    }
  }

  static Message messageFromPendingTemplate(Map<String, dynamic> json) {
    final message = Message.fromJson(json);
    if (message is AudioMessage) {
      final duration = message.metadata?['duration_ms'] as int?;
      if (duration != null) {
        return message.copyWith(duration: Duration(milliseconds: duration));
      }
    }
    return message;
  }

  /// 从模板 + journal 重建消息（实现见 attachment_template_restore.dart；
  /// 多图 imageMulti 在同一路径回填 images[]）。
  Future<Map<String, dynamic>> restoreMessageTemplate(
    AttachmentUploadTask row,
  ) async {
    _requireSession(row.userId);
    final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
    final rows = await _repo.findByAnchor(row.anchorMsgId!, row.userId);
    return restoreAttachmentGroupTemplate(
      intent: intent,
      rows: rows,
      userId: row.userId,
      loadMaterials: _loadMaterials,
      requireSession: _requireSession,
    );
  }

  AttachmentUploadTaskRepo get repo => _repo;

  Future<String> upload({
    required String idempotencyKey,
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String mime,

    required String bindingHashHex,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    bool prepareOnly = false,
    String? attachmentId,
    int chunkSize = AttachmentEncryptor.defaultChunkSize,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,

    Future<void> Function(UploadCheckpoint event)? checkpoint,
  }) async {
    _requireSession(userId);
    final digest = sha256.convert(bytes).toString();
    final existing = await _repo.find(idempotencyKey);
    _requireSession(userId);
    if (existing != null) {
      if (existing.userId != userId) {
        // 账号切换后的旧幂等键：不写入新账号，按新任务处理。
        throw StateError('upload idempotency key belongs to another account');
      }
      if (existing.stage == AttachmentUploadStage.abandoned) {
        throw StateError('abandoned upload requires a new client_upload_id');
      }
      if (existing.scope != scope ||
          existing.scopeRef != scopeRef ||
          existing.fileName != fileName ||
          existing.mime != mime ||
          existing.anchorMsgId != anchorMsgId ||
          existing.bindingHash != bindingHashHex ||
          existing.plainSize != bytes.length ||
          existing.plainSha256 != digest) {
        throw StateError('upload declaration changed');
      }
      if (prepareOnly) {
        if (existing.stage == AttachmentUploadStage.pending &&
            existing.objectKey == null) {
          await _cacheSource(existing, bytes);
        }
        return existing.id;
      }
      if (existing.stage == AttachmentUploadStage.confirmed) {
        if (encrypt && _externalSeal != null) {
          final material = await _loadMaterials(existing);
          _requireSession(userId);
          if (material == null) throw LostCipherMaterialError(existing.id);
          final result = AttachmentEncryptor.seal(
            plaintext: bytes,
            bindingHash: _hexDecode(existing.bindingHash!),
            attachmentId: material['attachment_id'] ?? existing.id,
            objectKey: existing.objectKey!,
            mime: existing.mime,
            name: existing.fileName,
            contentKey: base64Decode(material['content_key']!),
            baseNonce: base64Decode(material['base_nonce']!),
            chunkSize: int.parse(
              material['chunk_size'] ??
                  '${AttachmentEncryptor.defaultChunkSize}',
            ),
            thumb: material['thumb'] == null
                ? null
                : AttachmentDescriptor.fromMap(
                    jsonDecode(material['thumb']!) as Map<String, dynamic>,
                  ),
          );
          if (result.ciphertextSha256Hex != existing.ciphertextSha256) {
            throw StateError('confirmed upload ciphertext changed');
          }
          _externalSeal.descriptor = result.descriptor;
          _externalSeal.uploadedFileHash256 = result.ciphertextSha256Hex;
        }
        return existing.objectKey!;
      }
      return resume(
        existing,
        bytes,
        fileName: fileName,
        mime: mime,
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        presignFn: presignFn,
        putFn: putFn,
        confirmFn: confirmFn,
        checkpoint: checkpoint,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = AttachmentUploadTask(
      id: idempotencyKey,
      userId: userId,
      scope: scope,
      scopeRef: scopeRef,
      fileName: fileName,
      mime: mime,
      plainSize: bytes.length,
      plainSha256: digest,
      objectKey: null,
      stage: AttachmentUploadStage.pending,
      cipher: encrypt ? AttachmentDescriptor.supportedCipher : null,
      bindingHash: bindingHashHex,
      keyRef: idempotencyKey,
      ciphertextSha256: null,
      anchorMsgId: anchorMsgId,
      businessIntent: messageIntent == null ? null : jsonEncode(messageIntent),
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );
    if (!await _repo.insert(task)) {
      throw StateError('upload journal write failed');
    }
    if (encrypt) {
      await _keys.write(task.keyRef!, {
        'content_key': base64Encode(AttachmentEncryptor.randomContentKey()),
        'base_nonce': base64Encode(AttachmentEncryptor.randomBaseNonce()),
        'attachment_id': _externalSeal?.attachmentId ?? task.id,
        'chunk_size': (_externalSeal?.chunkSize ?? chunkSize).toString(),
      });
    }
    _requireSession(userId);
    await _cacheSource(task, bytes);
    if (prepareOnly) return task.id;
    return _run(
      task,
      bytes,
      fileName: fileName,
      mime: mime,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
      checkpoint: checkpoint,
    );
  }

  Future<String> resume(
    AttachmentUploadTask task,
    Uint8List bytes, {
    required String fileName,
    required String mime,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
    Future<void> Function(UploadCheckpoint event)? checkpoint,
  }) async {
    return _run(
      task,
      bytes,
      fileName: fileName,
      mime: mime,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
      checkpoint: checkpoint,
    );
  }

  Future<List<String>> resumeAll(
    String userId, {
    Future<Uint8List?> Function(AttachmentUploadTask task)? bytesProvider,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
    UploadSessionFn? sessionFn,
  }) async {
    _requireSession(userId);
    final rows = await _repo.listResumable(userId);
    final scheduled = rows.map((row) => row.id).toSet();
    final ok = <String>[];
    Future<void> scheduleReplacement(String id) async {
      _requireSession(userId);
      if (scheduled.contains(id)) return;
      final replacement = await _repo.find(id);
      _requireSession(userId);
      if (replacement != null &&
          replacement.userId == userId &&
          !replacement.stage.isTerminal) {
        scheduled.add(id);
        rows.add(replacement);
      }
    }

    Future<void> scheduleVideoDependent(AttachmentUploadTask thumb) async {
      if (!thumb.mime.startsWith('image/') ||
          thumb.anchorMsgId == null ||
          !(thumb.lastError?.startsWith('legacy_migrated:') ?? false)) {
        return;
      }
      final group = await _repo.findByAnchor(thumb.anchorMsgId!, userId);
      for (final row in group) {
        if (row.mime.startsWith('video/') &&
            !row.stage.isTerminal &&
            (row.lastError == 'legacy_reselect' ||
                (row.lastError?.startsWith('legacy_migrating:') ?? false))) {
          await scheduleReplacement(row.id);
        }
      }
    }

    for (var index = 0; index < rows.length; index++) {
      var row = rows[index];
      scheduled.remove(row.id);
      _requireSession(userId);
      if (row.lastError == 'legacy_outbox_check' ||
          row.lastError == 'legacy_return_page') {
        continue;
      }
      if (row.mime.startsWith('video/') &&
          row.cipher != null &&
          row.stage == AttachmentUploadStage.pending &&
          row.objectKey == null &&
          row.anchorMsgId != null &&
          row.lastError != 'legacy_reselect' &&
          !(row.lastError?.startsWith('legacy_migrating:') ?? false) &&
          !(row.lastError?.startsWith('legacy_migrated:') ?? false)) {
        try {
          if (await _repo.legacyOutboxMayExist(row)) {
            await _repo.setRecoveryReason(row, 'legacy_outbox_check');
            continue;
          }
          final group = await _repo.findByAnchor(row.anchorMsgId!, userId);
          final thumbs = group
              .where((r) => r.id != row.id && r.mime.startsWith('image/'))
              .toList();
          if (group.length != 2 ||
              thumbs.length != 1 ||
              thumbs.single.stage != AttachmentUploadStage.confirmed ||
              thumbs.single.objectKey == null) {
            continue;
          }
          final thumb = thumbs.single;
          final state = await DirectAttachmentApi.strictStatus(
            objectKey: thumb.objectKey!,
            sessionFn: directSessionFn,
          );
          _requireSession(userId);
          if (state == null) {
            if (await _repo.setRecoveryReason(row, 'legacy_reselect')) {
              final current = await _repo.find(row.id);
              if (current != null) {
                final replacementId = await _prepareLegacyMigration(current);
                if (replacementId != null) {
                  await scheduleReplacement(replacementId);
                }
              }
            }
            continue;
          }
          if (state != 'CONFIRMED') continue;
        } on Object {
          _requireSession(userId);
          continue;
        }
      }
      if (row.lastError == 'legacy_reselect' ||
          (row.lastError?.startsWith('legacy_migrating:') ?? false)) {
        try {
          final replacementId = await _prepareLegacyMigration(row);
          if (replacementId != null) await scheduleReplacement(replacementId);
        } on LegacyOutboxConflict {
          _requireSession(userId);
          final current = await _repo.find(row.id);
          if (current != null &&
              !current.stage.isTerminal &&
              !(current.lastError?.startsWith('legacy_migrating:') ?? false)) {
            await _repo.setRecoveryReason(current, 'legacy_outbox_check');
          }
        } on Object {
          _requireSession(userId);
        }
        continue;
      }
      try {
        await _cleanupLegacyPlainSource(row);
        final materials = await _loadMaterials(row);
        if (bytesProvider != null) {
          final bytes = await bytesProvider(row);
          if (bytes == null) continue;
          ok.add(
            await _runWithMaterials(
              row,
              materials,
              bytes: bytes,
              presignFn: presignFn,
              putFn: putFn,
              confirmFn: confirmFn,
              sessionFn: sessionFn,
            ),
          );
          await scheduleVideoDependent(row);
          continue;
        }
        if ((row.uploadPath == null || !await File(row.uploadPath!).exists()) &&
            row.cipher != null &&
            materials != null &&
            (row.stage == AttachmentUploadStage.pending ||
                row.stage == AttachmentUploadStage.presigned)) {
          final recovered = await _recoverEncryptedSource(row, materials);
          if (recovered != null) row = recovered;
        }
        if (row.uploadPath == null || !await File(row.uploadPath!).exists()) {
          // Migrated keys still need their marker to reconstruct from the old key.
          if (!(row.lastError?.startsWith('legacy_migrated:') ?? false)) {
            await _repo.abandon(
              row.id,
              userId,
              'upload cache lost; new task and key required',
            );
          }
          continue;
        }
        final cachePath = (await _cacheFile(row)).path;
        final migrationPath = (await _migrationFile(row, row.id)).path;
        if (row.uploadPath == migrationPath &&
            (row.lastError?.startsWith('legacy_migrated:') ?? false)) {
          if (materials?['migration_descriptor'] == null) {
            throw LostCipherMaterialError(row.id);
          }
          final descriptor = AttachmentDescriptor.fromMap(
            jsonDecode(materials!['migration_descriptor']!)
                as Map<String, dynamic>,
          );
          final sealed = await File(migrationPath).readAsBytes();
          final source = AttachmentEncryptor.open(
            ciphertext: sealed,
            descriptor: descriptor,
            bindingHash: _hexDecode(row.bindingHash!),
          );
          if (source.length != row.plainSize ||
              sha256.convert(source).toString() != row.plainSha256) {
            throw LostCipherMaterialError(row.id);
          }
          ok.add(
            await _runWithMaterials(
              row,
              materials,
              bytes: source,
              presignFn: presignFn,
              putFn: putFn,
              confirmFn: confirmFn,
              sessionFn: sessionFn,
            ),
          );
          await scheduleVideoDependent(row);
          continue;
        }
        if (row.uploadPath == '$cachePath.source' ||
            row.uploadPath == '$cachePath.source.enc') {
          if (row.stage != AttachmentUploadStage.pending &&
              row.stage != AttachmentUploadStage.presigned) {
            throw LostCipherMaterialError(row.id);
          }
          final source = row.uploadPath == '$cachePath.source.enc'
              ? await _readEncryptedSource(
                  row,
                  materials!,
                  File(row.uploadPath!),
                )
              : await File(row.uploadPath!).readAsBytes();
          if (sha256.convert(source).toString() != row.plainSha256) {
            throw LostCipherMaterialError(row.id);
          }
          var sourceMaterial = materials;
          if (row.mime.startsWith('video/') && row.cipher != null) {
            final group = await _repo.findByAnchor(row.anchorMsgId!, userId);
            final thumb = group.singleWhere((r) => r.mime.startsWith('image/'));
            if (thumb.stage != AttachmentUploadStage.confirmed) continue;
            final thumbMaterial = await _loadMaterials(thumb);
            if (sourceMaterial == null ||
                thumbMaterial?['descriptor'] == null) {
              throw LostCipherMaterialError(row.id);
            }
            sourceMaterial = {
              ...sourceMaterial,
              'thumb': thumbMaterial!['descriptor']!,
            };
          }
          ok.add(
            await _runWithMaterials(
              row,
              sourceMaterial,
              bytes: source,
              presignFn: presignFn,
              putFn: putFn,
              confirmFn: confirmFn,
              sessionFn: sessionFn,
            ),
          );
          await scheduleVideoDependent(row);
          continue;
        }
        if (row.uploadPath != cachePath &&
            !(row.uploadPath?.startsWith('$cachePath.material-') ?? false)) {
          throw LostCipherMaterialError(row.id);
        }
        final cached = await File(row.uploadPath!).readAsBytes();
        _requireSession(userId);
        if (sha256.convert(cached).toString() != row.ciphertextSha256) {
          throw LostCipherMaterialError(row.id);
        }
        final encrypted = row.cipher != null;
        final descriptor = encrypted && materials?['descriptor'] != null
            ? AttachmentDescriptor.fromMap(
                jsonDecode(materials!['descriptor']!) as Map<String, dynamic>,
              )
            : null;
        if (encrypted &&
            (descriptor == null ||
                descriptor.objectKey != row.objectKey ||
                descriptor.plainSize != row.plainSize ||
                descriptor.name != row.fileName ||
                descriptor.mime != row.mime ||
                descriptor.plainSha256
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join() !=
                    row.plainSha256)) {
          throw LostCipherMaterialError(row.id);
        }
        ok.add(
          await _runWithMaterials(
            row,
            materials,
            bytes: cached,
            cachedSealed: descriptor == null
                ? null
                : SealedAttachment(cached, descriptor),
            presignFn: presignFn,
            putFn: putFn,
            confirmFn: confirmFn,
            sessionFn: sessionFn,
          ),
        );
        await scheduleVideoDependent(row);
      } on LegacyUploadConflict {
        _requireSession(userId);
        final current = await _repo.find(row.id);
        if (current != null &&
            !current.stage.isTerminal &&
            !(current.lastError?.startsWith('legacy_migrated:') ?? false)) {
          final reason = current.businessIntent == null
              ? 'legacy_return_page'
              : await _repo.legacyOutboxMayExist(current)
              ? 'legacy_outbox_check'
              : 'legacy_reselect';
          _requireSession(userId);
          await _repo.setRecoveryReason(current, reason);
          if (reason == 'legacy_reselect') {
            try {
              final latest = await _repo.find(current.id);
              if (latest != null &&
                  (latest.lastError == 'legacy_reselect' ||
                      (latest.lastError?.startsWith('legacy_migrating:') ??
                          false))) {
                final replacementId = await _prepareLegacyMigration(latest);
                if (replacementId != null) {
                  await scheduleReplacement(replacementId);
                }
              }
            } on Object {
              _requireSession(userId);
            }
          }
        }
      } on LostCipherMaterialError {
        _requireSession(userId);
        if (!(row.lastError?.startsWith('legacy_migrated:') ?? false)) {
          await _repo.abandon(
            row.id,
            userId,
            'cipher material lost; new task and key required',
          );
        }
      } on UploadSessionRejected {
        _requireSession(userId);
        if (!(row.lastError?.startsWith('legacy_migrated:') ?? false)) {
          await _repo.abandon(
            row.id,
            userId,
            'upload session rejected; new task required',
          );
        }
      } on Object {
        _requireSession(userId);
        // 保留原身份、密文和实际已落盘阶段；下一轮重试，不阻塞其它任务。
        final current = await _repo.find(row.id);
        _requireSession(userId);
        if (current != null &&
            current.userId == userId &&
            !current.stage.isTerminal) {
          await _repo.setRecoveryReason(
            current,
            'upload recovery failed; original checkpoint retained',
          );
        }
      }
    }
    return ok;
  }

  Future<String> _videoThumbDescriptor(AttachmentUploadTask task) async {
    if (task.anchorMsgId == null) throw LostCipherMaterialError(task.id);
    final group = await _repo.findByAnchor(task.anchorMsgId!, task.userId);
    final thumbs = group
        .where((row) => row.id != task.id && row.mime.startsWith('image/'))
        .toList();
    if (group.length != 2 || thumbs.length != 1) {
      throw LostCipherMaterialError(task.id);
    }
    final thumb = thumbs.single;
    if (thumb.stage != AttachmentUploadStage.confirmed ||
        !(thumb.lastError?.startsWith('legacy_migrated:') ?? false) ||
        thumb.objectKey == null ||
        thumb.ciphertextSha256 == null) {
      throw LostCipherMaterialError(task.id);
    }
    final material = await _loadMaterials(thumb);
    _requireSession(task.userId);
    final raw = material?['descriptor'];
    if (raw == null) throw LostCipherMaterialError(task.id);
    final descriptor = AttachmentDescriptor.fromMap(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (descriptor.objectKey != thumb.objectKey ||
        descriptor.plainSize != thumb.plainSize ||
        descriptor.mime != thumb.mime ||
        descriptor.name != thumb.fileName ||
        base64Encode(descriptor.plainSha256) !=
            base64Encode(_hexDecode(thumb.plainSha256))) {
      throw LostCipherMaterialError(task.id);
    }
    return raw;
  }

  Future<String?> _prepareLegacyMigration(AttachmentUploadTask task) async {
    if (!task.mime.startsWith('video/')) return _migrateLegacy(task);
    if (task.anchorMsgId == null) throw LostCipherMaterialError(task.id);
    final group = await _repo.findByAnchor(task.anchorMsgId!, task.userId);
    final thumbs = group
        .where((row) => row.id != task.id && row.mime.startsWith('image/'))
        .toList();
    if (group.length != 2 || thumbs.length != 1) {
      throw LostCipherMaterialError(task.id);
    }
    final thumb = thumbs.single;
    if (thumb.stage != AttachmentUploadStage.confirmed) return null;
    if (!(thumb.lastError?.startsWith('legacy_migrated:') ?? false)) {
      return _migrateLegacy(thumb, allowConfirmedVideoThumb: true);
    }
    await _videoThumbDescriptor(task);
    return _migrateLegacy(task);
  }

  Future<Map<String, String>?> _loadMaterials(AttachmentUploadTask task) async {
    if (task.cipher == null) return null;
    final material = await _keys.read(task.keyRef ?? task.id);
    if (material != null) return material;
    final marker = task.lastError;
    if (marker == null || !marker.startsWith('legacy_migrated:')) return null;
    try {
      final encoded = marker.substring('legacy_migrated:'.length);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (decoded is! Map ||
          decoded['key_ref'] is! String ||
          decoded['id'] is! String) {
        return null;
      }
      final old = await _keys.read(decoded['key_ref'] as String);
      if (old == null || old['content_key'] == null) return null;
      final effective = task.mime.startsWith('video/')
          ? {...old, 'thumb': await _videoThumbDescriptor(task)}
          : old;
      return _derivedMigrationMaterial(
        task,
        task.id,
        effective,
        finalObjectKey: task.objectKey,
      );
    } on Object {
      return null;
    }
  }

  Future<String> _run(
    AttachmentUploadTask task,
    Uint8List bytes, {
    required String fileName,
    required String mime,
    required String scope,
    String? scopeRef,
    String? anchorMsgId,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
    Future<void> Function(UploadCheckpoint event)? checkpoint,
  }) async {
    final materials = await _loadMaterials(task);
    return _runWithMaterials(
      task,
      materials,
      bytes: bytes,
      fileName: fileName,
      mime: mime,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
      checkpoint: checkpoint,
    );
  }

  Future<String> _runWithMaterials(
    AttachmentUploadTask task,
    Map<String, String>? materials, {
    Uint8List? bytes,
    SealedAttachment? cachedSealed,
    UploadSessionFn? sessionFn,
    String? fileName,
    String? mime,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
    Future<void> Function(UploadCheckpoint event)? checkpoint,
  }) async {
    _requireSession(task.userId);
    final encrypted = task.cipher != null;
    if (encrypted &&
        task.mime.startsWith('video/') &&
        task.stage == AttachmentUploadStage.pending &&
        task.objectKey == null &&
        task.anchorMsgId != null &&
        task.businessIntent != null) {
      if (await _repo.legacyOutboxMayExist(task)) {
        await _repo.setRecoveryReason(task, 'legacy_outbox_check');
        throw StateError('video outbox state is uncertain');
      }
      final group = await _repo.findByAnchor(task.anchorMsgId!, task.userId);
      final thumbs = group
          .where((r) => r.id != task.id && r.mime.startsWith('image/'))
          .toList();
      if (group.length != 2 ||
          thumbs.length != 1 ||
          thumbs.single.stage != AttachmentUploadStage.confirmed ||
          thumbs.single.objectKey == null) {
        throw StateError('video thumbnail is not confirmed');
      }
      final thumb = thumbs.single;
      final state = await DirectAttachmentApi.strictStatus(
        objectKey: thumb.objectKey!,
        sessionFn: directSessionFn,
      );
      _requireSession(task.userId);
      if (state == null) {
        await _repo.setRecoveryReason(task, 'legacy_reselect');
        throw StateError('legacy thumbnail requires migration');
      }
      if (state != 'CONFIRMED') {
        throw StateError('thumbnail status not confirmed');
      }
      final proposedThumb = _externalSeal?.thumbDescriptor;
      final rawThumb =
          materials?['thumb'] ??
          (proposedThumb == null ? null : jsonEncode(proposedThumb.toMap()));
      final thumbMaterials = await _loadMaterials(thumb);
      _requireSession(task.userId);
      final actualThumb = thumbMaterials?['descriptor'];
      if (rawThumb == null || actualThumb == null) {
        throw StateError('video thumbnail descriptor unavailable');
      }
      final savedDescriptor = AttachmentDescriptor.fromMap(
        jsonDecode(rawThumb) as Map<String, dynamic>,
      );
      final confirmedDescriptor = AttachmentDescriptor.fromMap(
        jsonDecode(actualThumb) as Map<String, dynamic>,
      );
      if (savedDescriptor.objectKey != thumb.objectKey ||
          jsonEncode(savedDescriptor.toMap()) !=
              jsonEncode(confirmedDescriptor.toMap())) {
        throw StateError('video thumbnail descriptor changed');
      }
      if (materials != null && materials['thumb'] == null) {
        materials = {...materials, 'thumb': rawThumb};
      }
    }
    if (task.stage.isTerminal) {
      throw StateError('terminal upload cannot resume');
    }
    if (bytes == null ||
        (cachedSealed == null &&
            (bytes.length != task.plainSize ||
                sha256.convert(bytes).toString() != task.plainSha256)) ||
        (fileName != null && fileName != task.fileName) ||
        (mime != null && mime != task.mime)) {
      throw StateError('upload source or declaration changed');
    }
    if (materials != null &&
        _externalSeal != null &&
        ((materials['attachment_id'] != null &&
                materials['attachment_id'] != _externalSeal.attachmentId) ||
            (materials['chunk_size'] != null &&
                materials['chunk_size'] !=
                    _externalSeal.chunkSize.toString()) ||
            materials['thumb'] !=
                (_externalSeal.thumbDescriptor == null
                    ? null
                    : jsonEncode(_externalSeal.thumbDescriptor!.toMap())))) {
      throw StateError('upload encryption declaration changed');
    }
    final stage = task.stage;
    final hasMaterial =
        materials != null &&
        materials.containsKey('content_key') &&
        materials.containsKey('base_nonce');
    if (encrypted && stage != AttachmentUploadStage.pending && !hasMaterial) {
      // 非 pending 行必须有可取回材料：同 key 同密文恢复的前提。
      throw LostCipherMaterialError(task.id);
    }
    Uint8List? contentKey;
    Uint8List? baseNonce;
    if (hasMaterial) {
      contentKey = Uint8List.fromList(base64Decode(materials['content_key']!));
      baseNonce = Uint8List.fromList(base64Decode(materials['base_nonce']!));
    }
    final resumeState = stage == AttachmentUploadStage.pending && !hasMaterial
        ? null
        : ResumableUploadState(
            objectKey: task.objectKey ?? '',
            contentKey: contentKey,
            baseNonce: baseNonce,
            skipPut: stage == AttachmentUploadStage.putDone,
            ciphertextSha256: task.ciphertextSha256,
            sealedAttachment: cachedSealed,
          );

    // 管道：编排持久化先行（kill 注入点之前行必须已到达该阶段），
    // 随后外部观察/注入闭包——它抛错即中止后续阶段。
    Future<void> pipeline(UploadCheckpoint event) async {
      _requireSession(task.userId);
      await _persistCheckpoint(task, stage, event);
      _requireSession(task.userId);
      await checkpoint?.call(event);
    }

    return AttachmentApi.uploadViaPresign(
      bytes,
      fileName ?? task.fileName,
      mime ?? task.mime,
      process: process,
      scope: task.scope,
      scopeRef: task.scopeRef,
      anchorMsgId: task.anchorMsgId,
      clientUploadId: task.id,
      sessionFn: sessionFn,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
      seal: !encrypted
          ? null
          : (_externalSeal ??
                  AttachmentSealRequest(
                    bindingHash: _hexDecode(task.bindingHash!),
                    attachmentId: materials?['attachment_id'] ?? task.id,
                    chunkSize: int.parse(
                      materials?['chunk_size'] ??
                          '${AttachmentEncryptor.defaultChunkSize}',
                    ),
                  )
              ..thumbDescriptor = materials?['thumb'] == null
                  ? _externalSeal?.thumbDescriptor
                  : AttachmentDescriptor.fromMap(
                      jsonDecode(materials!['thumb']!) as Map<String, dynamic>,
                    )),
      resume: resumeState,
      checkpoint: pipeline,
      requireSession: () => _requireSession(task.userId),
      directSessionFn: directSessionFn,
      directPutFn: directPutFn,
      persistTask: false,
    );
  }

  Future<void> _persistCheckpoint(
    AttachmentUploadTask task,
    AttachmentUploadStage stage,
    UploadCheckpoint event,
  ) async {
    switch (event.stage) {
      case UploadCheckpointStage.presigned:
        final ok = await _repo.advanceStage(
          task.id,
          stage,
          AttachmentUploadStage.presigned,
          objectKey: event.objectKey,
          userId: task.userId,
        );
        if (!ok) {
          throw StateError('checkpoint CAS failed at presigned for ${task.id}');
        }
      case UploadCheckpointStage.sealed:
        if (stage == AttachmentUploadStage.putDone) return;
        String? materialRef;
        if (event.contentKey != null &&
            event.contentKey!.isNotEmpty &&
            event.baseNonce != null &&
            event.baseNonce!.isNotEmpty) {
          // 材料落安全存储必须先于密文上网络（fail-closed）。
          final ref = task.keyRef ?? task.id;
          final stored = await _keys.read(ref);
          final descriptor = event.descriptor == null
              ? null
              : jsonEncode(event.descriptor!.toMap());
          if (stored?['descriptor'] != null) {
            if (stored!['descriptor'] != descriptor ||
                stored['content_key'] != base64Encode(event.contentKey!) ||
                stored['base_nonce'] != base64Encode(event.baseNonce!)) {
              throw StateError('sealed material changed for ${task.id}');
            }
            materialRef = ref;
          } else {
            final nextRef = '${task.id}:material:${_newUuid()}';
            materialRef = nextRef;
            await _keys.write(nextRef, {
              ...?await _loadMaterials(task),
              'content_key': base64Encode(event.contentKey!),
              'base_nonce': base64Encode(event.baseNonce!),
              'descriptor': ?descriptor,
              if (event.descriptor?.thumb != null)
                'thumb': jsonEncode(event.descriptor!.thumb!.toMap()),
            });
            if (!await _repo.publishMaterialReference(task, nextRef)) {
              throw StateError('material reference CAS failed for ${task.id}');
            }
          }
        }
        await _cacheUpload(task, event, expectedKeyRef: materialRef);
      case UploadCheckpointStage.putDone:
        // 事件顺序保证 presigned 检查点已把行推进到 presigned
        // （恢复 put_done 行走 skipPut 不触发本分支）。
        final ok = await _repo.advanceStage(
          task.id,
          AttachmentUploadStage.presigned,
          AttachmentUploadStage.putDone,
          ciphertextSha256: event.ciphertextSha256,
          userId: task.userId,
        );
        if (!ok) {
          throw StateError('checkpoint CAS failed at put_done for ${task.id}');
        }
      case UploadCheckpointStage.confirmed:
        final ok = await _repo.advanceStage(
          task.id,
          AttachmentUploadStage.putDone,
          AttachmentUploadStage.confirmed,
          userId: task.userId,
        );
        if (!ok) {
          throw StateError('checkpoint CAS failed at confirmed for ${task.id}');
        }
    }
  }
}
