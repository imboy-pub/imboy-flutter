import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:crypto/crypto.dart';
import 'package:imboy/config/init.dart' show currentEnv;
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
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';

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
  final Future<void> Function(Future<void> Function(), Future<void> Function())?
  cacheWriter;
  final int _generation;
  final bool Function(String userId) _sessionGuard;

  static bool Function(String userId) _currentSessionGuard() {
    final actor = UserRepoLocal.to;
    final generation = actor.sessionGeneration;
    return (userId) =>
        actor.currentUid == userId &&
        actor.isCurrentSession(generation) &&
        !actor.isAuthTransitioning;
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

  Future<void> _cacheSource(AttachmentUploadTask task, Uint8List bytes) async {
    final file = File('${(await _cacheFile(task)).path}.source');
    final temporary = File('${file.path}.tmp');
    Future<void> write() async {
      _requireSession(task.userId);
      await temporary.writeAsBytes(bytes, flush: true);
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
    }

    Future<void> discard() async {
      if (await temporary.exists()) await temporary.delete();
      if (await file.exists()) await file.delete();
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
    UploadCheckpoint event,
  ) async {
    if (event.uploadBytes == null) {
      throw StateError('upload checkpoint missing bytes');
    }
    final file = await _cacheFile(task);
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
      )) {
        throw StateError('upload cache checkpoint failed');
      }
      _requireSession(task.userId);
      final source = File('${file.path}.source');
      if (await source.exists()) await source.delete();
    }

    Future<void> discard() async {
      if (await temporary.exists()) await temporary.delete();
      if (await file.exists()) await file.delete();
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
        await uploader.resumeAll(uid);
        await uploader.reconcileMessages(uid);
        await uploader.recoverBusinessOutbox(uid);
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
      if (intent['state'] == 'outbox_ready') continue;
      if (intent['state'] == 'uploading' &&
          intent['message_template'] != null) {
        continue;
      }
      if (intent['message'] == null) {
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
          !{'uploading', 'outbox_ready'}.contains(intent['state'])) {
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

  Future<Map<String, dynamic>> restoreMessageTemplate(
    AttachmentUploadTask row,
  ) async {
    _requireSession(row.userId);
    final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
    final rows = await _repo.findByAnchor(row.anchorMsgId!, row.userId);
    final count = intent['expected_objects'] as int;
    if (rows.length != count ||
        rows.any((r) => r.stage != AttachmentUploadStage.confirmed)) {
      throw StateError('attachment group incomplete');
    }
    final kind = intent['attachment_kind'];
    final main = kind == 'video'
        ? rows.singleWhere((r) => r.mime.startsWith('video/'))
        : rows.single;
    if (main.objectKey == null || main.objectKey!.isEmpty) {
      throw StateError('confirmed attachment identity missing');
    }
    final template = Map<String, dynamic>.from(
      intent['message_template'] as Map,
    );
    final metadata = Map<String, dynamic>.from(
      template['metadata'] as Map? ?? {},
    );
    if (main.cipher != null) {
      final materials = await _loadMaterials(main);
      _requireSession(row.userId);
      final descriptor = materials?['descriptor'];
      if (descriptor == null) throw LostCipherMaterialError(main.id);
      metadata['attachment_descriptor'] = jsonDecode(descriptor);
    }
    metadata['file_hash256'] = main.ciphertextSha256 ?? main.plainSha256;
    if (kind == 'location') {
      metadata['thumb'] = main.objectKey;
      metadata['size'] = main.plainSize;
    } else {
      template['source'] = main.objectKey;
      template['size'] = main.plainSize;
    }
    if (kind == 'video') {
      final thumb = rows.singleWhere((r) => r.id != main.id);
      metadata['thumb'] = {'uri': thumb.objectKey};
    }
    template['metadata'] = metadata;
    return template;
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
      if (existing.stage == AttachmentUploadStage.pending &&
          existing.objectKey == null &&
          _externalSeal?.thumbDescriptor != null) {
        final material = await _loadMaterials(existing);
        if (material == null) throw LostCipherMaterialError(existing.id);
        await _keys.write(existing.keyRef ?? existing.id, {
          ...material,
          'thumb': jsonEncode(_externalSeal!.thumbDescriptor!.toMap()),
        });
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
        if (_externalSeal?.thumbDescriptor != null)
          'thumb': jsonEncode(_externalSeal!.thumbDescriptor!.toMap()),
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
    final ok = <String>[];
    for (final row in rows) {
      _requireSession(userId);
      try {
        final materials = await _loadMaterials(row);
        if (bytesProvider != null) {
          final bytes = await bytesProvider(row);
          if (bytes == null) continue;
          ok.add(await _runWithMaterials(row, materials, bytes: bytes));
          continue;
        }
        if (row.uploadPath == null || !await File(row.uploadPath!).exists()) {
          // 无恢复字节时不能新建能力或复用旧 key；用户必须显式新任务。
          await _repo.abandon(
            row.id,
            userId,
            'upload cache lost; new task and key required',
          );
          continue;
        }
        final cachePath = (await _cacheFile(row)).path;
        if (row.uploadPath == '$cachePath.source') {
          if (row.stage != AttachmentUploadStage.pending &&
              row.stage != AttachmentUploadStage.presigned) {
            throw LostCipherMaterialError(row.id);
          }
          final source = await File(row.uploadPath!).readAsBytes();
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
            await _keys.write(row.keyRef ?? row.id, sourceMaterial);
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
          continue;
        }
        if (row.uploadPath != cachePath) {
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
      } on LostCipherMaterialError {
        _requireSession(userId);
        await _repo.abandon(
          row.id,
          userId,
          'cipher material lost; new task and key required',
        );
      }
    }
    return ok;
  }

  Future<Map<String, String>?> _loadMaterials(AttachmentUploadTask task) =>
      task.cipher != null
      ? _keys.read(task.keyRef ?? task.id)
      : Future.value(null);

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
  }) {
    _requireSession(task.userId);
    final encrypted = task.cipher != null;
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
        if (event.contentKey != null &&
            event.contentKey!.isNotEmpty &&
            event.baseNonce != null &&
            event.baseNonce!.isNotEmpty) {
          // 材料落安全存储必须先于密文上网络（fail-closed）。
          await _keys.write(task.keyRef ?? task.id, {
            ...?await _loadMaterials(task),
            'content_key': base64Encode(event.contentKey!),
            'base_nonce': base64Encode(event.baseNonce!),
            if (event.descriptor != null)
              'descriptor': jsonEncode(event.descriptor!.toMap()),
            if (event.descriptor?.thumb != null)
              'thumb': jsonEncode(event.descriptor!.thumb!.toMap()),
          });
        }
        await _cacheUpload(task, event);
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
