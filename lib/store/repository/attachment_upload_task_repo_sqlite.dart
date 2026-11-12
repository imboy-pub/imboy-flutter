import 'package:imboy/service/server_ack_receipts.dart';

import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart'
    show Database, DatabaseExecutor, ConflictAlgorithm;

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

class LegacyOutboxConflict implements Exception {
  const LegacyOutboxConflict();
}

/// 附件上传任务的持久化阶段（W5-01 / AC08）。
///
/// 只进不退：presigned → put_done → confirmed；任何非终态可转
/// abandoned（密钥材料丢失/授权撤销等，显式新建任务而非复用）。
enum AttachmentUploadStage {
  pending('pending'),
  presigned('presigned'),
  putDone('put_done'),
  confirmed('confirmed'),
  abandoned('abandoned');

  final String value;
  const AttachmentUploadStage(this.value);

  static AttachmentUploadStage fromValue(String v) => values.firstWhere(
    (s) => s.value == v,
    orElse: () => throw ArgumentError(v),
  );

  bool get isTerminal => this == confirmed || this == abandoned;
}

/// 附件上传任务行（immutable）。
///
/// 边界：不持久化 URL；contentKey/baseNonce 等敏感材料只存安全存储，
/// 本行仅持 [keyRef] 引用；服务端只收密文 hash（[ciphertextSha256]）。
class AttachmentUploadTask {
  final String id;
  final String userId;
  final String scope;
  final String? scopeRef;
  final String fileName;
  final String mime;
  final int plainSize;
  final String plainSha256;
  final String? objectKey;
  final String? uploadPath;
  final String? businessIntent;
  final AttachmentUploadStage stage;
  final String? cipher;
  final String? bindingHash;
  final String? keyRef;
  final String? ciphertextSha256;
  final String? anchorMsgId;
  final String? lastError;
  final int createdAt;
  final int updatedAt;

  const AttachmentUploadTask({
    required this.id,
    required this.userId,
    required this.scope,
    required this.scopeRef,
    required this.fileName,
    required this.mime,
    required this.plainSize,
    required this.plainSha256,
    required this.objectKey,
    this.uploadPath,
    this.businessIntent,
    required this.stage,
    required this.cipher,
    required this.bindingHash,
    required this.keyRef,
    required this.ciphertextSha256,
    required this.anchorMsgId,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  AttachmentUploadTask copyWith({
    String? objectKey,
    String? uploadPath,
    AttachmentUploadStage? stage,
    String? cipher,
    String? bindingHash,
    String? keyRef,
    String? ciphertextSha256,
    String? lastError,
    int? updatedAt,
  }) => AttachmentUploadTask(
    id: id,
    userId: userId,
    scope: scope,
    scopeRef: scopeRef,
    fileName: fileName,
    mime: mime,
    plainSize: plainSize,
    plainSha256: plainSha256,
    objectKey: objectKey ?? this.objectKey,
    uploadPath: uploadPath ?? this.uploadPath,
    businessIntent: businessIntent,
    stage: stage ?? this.stage,
    cipher: cipher ?? this.cipher,
    bindingHash: bindingHash ?? this.bindingHash,
    keyRef: keyRef ?? this.keyRef,
    ciphertextSha256: ciphertextSha256 ?? this.ciphertextSha256,
    anchorMsgId: anchorMsgId,
    lastError: lastError,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'scope': scope,
    'scope_ref': scopeRef,
    'file_name': fileName,
    'mime': mime,
    'plain_size': plainSize,
    'plain_sha256': plainSha256,
    'object_key': objectKey,
    'upload_path': uploadPath,
    'business_intent': businessIntent,
    'stage': stage.value,
    'cipher': cipher,
    'binding_hash': bindingHash,
    'key_ref': keyRef,
    'ciphertext_sha256': ciphertextSha256,
    'anchor_msg_id': anchorMsgId,
    'last_error': lastError,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static AttachmentUploadTask fromMap(Map<String, dynamic> m) =>
      AttachmentUploadTask(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        scope: m['scope'] as String,
        scopeRef: m['scope_ref'] as String?,
        fileName: m['file_name'] as String,
        mime: m['mime'] as String,
        plainSize: m['plain_size'] as int,
        plainSha256: m['plain_sha256'] as String,
        objectKey: m['object_key'] as String?,
        uploadPath: m['upload_path'] as String?,
        businessIntent: m['business_intent'] as String?,
        stage: AttachmentUploadStage.fromValue(m['stage'] as String),
        cipher: m['cipher'] as String?,
        bindingHash: m['binding_hash'] as String?,
        keyRef: m['key_ref'] as String?,
        ciphertextSha256: m['ciphertext_sha256'] as String?,
        anchorMsgId: m['anchor_msg_id'] as String?,
        lastError: m['last_error'] as String?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}

/// 附件上传任务持久化仓库（W5-01）。
///
/// 表由迁移 v33 建立；此处只做行读写。阶段推进是 CAS：
/// [advanceStage] 只在行当前 stage 等于 from 时更新，0 行受影响即返回
/// false；账号切换另由上传编排的认证 generation 检查拒绝。
class AttachmentUploadTaskRepo {
  static const String tableName = 'attachment_upload_task';

  /// 惰性绑定：构造期取 `SqliteService.to.db` 会立即启动数据库打开，且
  /// 构造后未 await 的实例（如 sendMessage 无门控路径）会把打开失败的
  /// future 泄漏成未处理异步错误，污染整个测试进程。改为使用期解析，
  /// SqliteService 内部有锁与句柄缓存，重复取值行为等价。
  Future<Database?> get _boundDb => SqliteService.to.db;

  Future<bool> insert(AttachmentUploadTask task) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    return db.transaction((tx) async {
      await _ensureSendGate(tx);
      if (task.anchorMsgId != null && task.anchorMsgId!.isNotEmpty) {
        final sent = await tx.query(
          'attachment_send_gate',
          columns: ['anchor'],
          where: 'user_id = ? AND anchor = ?',
          whereArgs: [task.userId, task.anchorMsgId],
          limit: 1,
        );
        if (sent.isNotEmpty) {
          throw StateError('outbound anchor already dispatched');
        }
      }
      final n = await tx.insert(
        tableName,
        task.toMap(),
        conflictAlgorithm: null,
      );
      return n > 0;
    });
  }

  static Future<void> _ensureSendGate(DatabaseExecutor tx) => tx.execute(
    'CREATE TABLE IF NOT EXISTS attachment_send_gate '
    '(user_id TEXT NOT NULL, anchor TEXT NOT NULL, PRIMARY KEY (user_id, anchor))',
  );

  Future<bool> publishMaterialReference(
    AttachmentUploadTask task,
    String next,
  ) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final count = await db.update(
      tableName,
      {'key_ref': next, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where:
          "id = ? AND user_id = ? AND key_ref = ? AND stage IN (?, ?) "
          "AND (last_error IS NULL OR last_error NOT LIKE 'legacy_migrating:%')",
      whereArgs: [
        task.id,
        task.userId,
        task.keyRef ?? task.id,
        AttachmentUploadStage.pending.value,
        AttachmentUploadStage.presigned.value,
      ],
    );
    return count == 1;
  }

  /// CAS 阶段推进。成功返回 true；行不存在/阶段不匹配/已终态返回 false。
  Future<bool> advanceStage(
    String id,
    AttachmentUploadStage from,
    AttachmentUploadStage to, {
    String? objectKey,
    String? ciphertextSha256,
    String? uploadPath,
    String? lastError,
    String? userId,
    String? expectedKeyRef,
  }) async {
    final allowed =
        !from.isTerminal &&
        (from == to ||
            (from == AttachmentUploadStage.pending &&
                to == AttachmentUploadStage.presigned) ||
            (from == AttachmentUploadStage.presigned &&
                to == AttachmentUploadStage.putDone) ||
            (from == AttachmentUploadStage.putDone &&
                to == AttachmentUploadStage.confirmed));
    if (!allowed) return false;
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final n = await db.update(
      tableName,
      {
        'stage': to.value,
        'object_key': ?objectKey,
        'ciphertext_sha256': ?ciphertextSha256,
        'upload_path': ?uploadPath,
        'last_error': ?lastError,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where:
          'id = ? AND stage = ?${userId == null ? '' : ' AND user_id = ?'}'
          '${lastError == null ? '' : " AND (last_error IS NULL OR (last_error NOT LIKE 'legacy_migrating:%' AND last_error NOT LIKE 'legacy_migrated:%'))"}'
          '${expectedKeyRef == null ? '' : ' AND key_ref = ?'}',
      whereArgs: [id, from.value, ?userId, ?expectedKeyRef],
    );
    return n > 0;
  }

  /// Updates a recovery reason only if no competing writer changed the row.
  Future<bool> setRecoveryReason(
    AttachmentUploadTask observed,
    String reason,
  ) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    if (observed.lastError?.startsWith('legacy_migrating:') == true ||
        observed.lastError?.startsWith('legacy_migrated:') == true) {
      return false;
    }
    final n = await db.update(
      tableName,
      {
        'last_error': reason,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where:
          'id = ? AND user_id = ? AND stage = ? AND '
          '${observed.lastError == null ? 'last_error IS NULL' : 'last_error = ?'}',
      whereArgs: [
        observed.id,
        observed.userId,
        observed.stage.value,
        ?observed.lastError,
      ],
    );
    return n == 1;
  }

  /// 未能证明未提交时按可能已发送处理，避免自动重复发送。
  Future<bool> legacyOutboxMayExist(AttachmentUploadTask task) async {
    try {
      if (task.anchorMsgId == null ||
          task.anchorMsgId!.isEmpty ||
          task.businessIntent == null) {
        return true;
      }
      final intent = jsonDecode(task.businessIntent!);
      if (intent is! Map ||
          intent['state'] != 'uploading' ||
          intent['author_id']?.toString() != task.userId ||
          !{'c2c', 'c2g'}.contains(intent['chat_type'])) {
        return true;
      }
      final db = await _boundDb;
      if (db == null) return true;
      final table = MessageRepo.getTableName(
        intent['chat_type'].toString().toUpperCase(),
      );
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [task.anchorMsgId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } on Object {
      return true;
    }
  }

  /// Reserves a replacement identity before any migration material is created.
  /// The old row remains authoritative until [commitLegacyMigration] succeeds.
  Future<String> reserveLegacyMigration(
    AttachmentUploadTask task,
    String proposedId, {
    required bool Function() isCurrent,
    bool allowConfirmedVideoThumb = false,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('upload account changed');
      final rows = await tx.query(
        tableName,
        where: 'id = ? AND user_id = ?',
        whereArgs: [task.id, task.userId],
        limit: 1,
      );
      if (rows.length != 1) throw StateError('legacy upload no longer exists');
      final current = AttachmentUploadTask.fromMap(rows.single);
      if ((current.stage.isTerminal &&
              !(allowConfirmedVideoThumb &&
                  current.stage == AttachmentUploadStage.confirmed)) ||
          current.stage != task.stage ||
          current.objectKey != task.objectKey ||
          current.keyRef != task.keyRef ||
          current.uploadPath != task.uploadPath ||
          current.ciphertextSha256 != task.ciphertextSha256 ||
          current.businessIntent != task.businessIntent) {
        throw StateError('legacy upload changed');
      }
      await _requireLegacyOutboxEmpty(tx, current);
      if (current.stage == AttachmentUploadStage.confirmed) {
        await _requireConfirmedVideoThumb(tx, current);
      }
      final existing = current.lastError;
      if (existing != null && existing.startsWith('legacy_migrating:')) {
        final id = existing.substring('legacy_migrating:'.length);
        if (!_validMigrationId(id)) {
          throw StateError('legacy migration identity invalid');
        }
        return id;
      }
      if (!_validMigrationId(proposedId)) {
        throw StateError('legacy migration identity invalid');
      }
      final updated = await tx.update(
        tableName,
        {
          'last_error': 'legacy_migrating:$proposedId',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ? AND stage = ?',
        whereArgs: [task.id, task.userId, task.stage.value],
      );
      if (updated != 1 || !isCurrent()) {
        throw StateError('legacy migration reservation failed');
      }
      return proposedId;
    });
  }

  /// Swaps the single authoritative row while preserving its intent and anchor.
  Future<bool> commitLegacyMigration(
    AttachmentUploadTask original,
    String replacementId,
    String encryptedPath, {
    required bool Function() isCurrent,
  }) async {
    if (!_validMigrationId(replacementId)) {
      throw StateError('legacy migration identity invalid');
    }
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('upload account changed');
      final rows = await tx.query(
        tableName,
        where: 'id = ? AND user_id = ?',
        whereArgs: [original.id, original.userId],
        limit: 1,
      );
      if (rows.length != 1) return false;
      final current = AttachmentUploadTask.fromMap(rows.single);
      if (current.stage != original.stage ||
          current.objectKey != original.objectKey ||
          current.keyRef != original.keyRef ||
          current.uploadPath != original.uploadPath ||
          current.ciphertextSha256 != original.ciphertextSha256 ||
          current.businessIntent != original.businessIntent ||
          current.lastError != 'legacy_migrating:$replacementId') {
        return false;
      }
      await _requireLegacyOutboxEmpty(tx, current);
      if (current.stage == AttachmentUploadStage.confirmed) {
        await _requireConfirmedVideoThumb(tx, current);
      }
      final n = await tx.update(
        tableName,
        {
          'id': replacementId,
          'key_ref': replacementId,
          'object_key': null,
          'stage': AttachmentUploadStage.pending.value,
          'upload_path': encryptedPath,
          'ciphertext_sha256': null,
          'last_error': legacyMigrationMarker(original),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ? AND stage = ? AND last_error = ?',
        whereArgs: [
          original.id,
          original.userId,
          original.stage.value,
          'legacy_migrating:$replacementId',
        ],
      );
      if (!isCurrent()) throw StateError('upload account changed');
      return n == 1;
    });
  }

  static String legacyMigrationMarker(AttachmentUploadTask original) =>
      'legacy_migrated:${base64UrlEncode(utf8.encode(jsonEncode({'id': original.id, 'key_ref': original.keyRef ?? original.id})))}';

  static bool _validMigrationId(String id) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(id);

  Future<void> _requireConfirmedVideoThumb(
    DatabaseExecutor tx,
    AttachmentUploadTask thumb,
  ) async {
    final raw = thumb.businessIntent == null
        ? null
        : jsonDecode(thumb.businessIntent!);
    if (!thumb.mime.startsWith('image/') ||
        raw is! Map ||
        raw['attachment_kind'] != 'video' ||
        raw['expected_objects'] != 2) {
      throw const LegacyOutboxConflict();
    }
    final rows = await tx.query(
      tableName,
      where: 'user_id = ? AND anchor_msg_id = ?',
      whereArgs: [thumb.userId, thumb.anchorMsgId],
    );
    if (rows.length != 2) throw const LegacyOutboxConflict();
    final other = rows
        .map(AttachmentUploadTask.fromMap)
        .where((row) => row.id != thumb.id)
        .toList();
    if (other.length != 1 ||
        !other.single.mime.startsWith('video/') ||
        other.single.stage.isTerminal ||
        other.single.businessIntent != thumb.businessIntent) {
      throw const LegacyOutboxConflict();
    }
  }

  Future<void> _requireLegacyOutboxEmpty(
    DatabaseExecutor tx,
    AttachmentUploadTask task,
  ) async {
    final intent = task.businessIntent == null
        ? null
        : jsonDecode(task.businessIntent!);
    if (task.anchorMsgId == null ||
        task.anchorMsgId!.isEmpty ||
        intent is! Map ||
        intent['state'] != 'uploading' ||
        intent['author_id']?.toString() != task.userId ||
        !{'c2c', 'c2g'}.contains(intent['chat_type'])) {
      throw const LegacyOutboxConflict();
    }
    final table = MessageRepo.getTableName(
      intent['chat_type'].toString().toUpperCase(),
    );
    final rows = await tx.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [task.anchorMsgId],
      limit: 1,
    );
    if (rows.isNotEmpty) throw const LegacyOutboxConflict();
  }

  Future<AttachmentUploadTask?> find(String id) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final rows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttachmentUploadTask.fromMap(rows.first);
  }

  Future<List<AttachmentUploadTask>> findByAnchor(
    String anchor,
    String userId,
  ) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final rows = await db.query(
      tableName,
      where: 'anchor_msg_id = ? AND user_id = ?',
      whereArgs: [anchor, userId],
    );
    return rows.map(AttachmentUploadTask.fromMap).toList();
  }

  Future<List<AttachmentUploadTask>> listBusinessPending(String userId) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND business_intent IS NOT NULL',
      whereArgs: [userId],
    );
    return rows.map(AttachmentUploadTask.fromMap).toList();
  }

  Future<bool> enqueueBusinessOutbox(
    MessageModel message, {
    required String userId,
    required bool Function() isCurrent,
  }) async {
    final encrypted = message.e2ee != null && message.e2ee!.isNotEmpty;
    if (message.fromId.toString() != userId ||
        (encrypted ? message.payload != '' : message.payload is! Map) ||
        AttachmentSealPolicy.carriesContentKey(message.payload)) {
      throw ArgumentError('outbox identity or safe payload invalid');
    }
    final db = await _boundDb;
    if (db == null || !isCurrent()) {
      throw StateError('outbox account unavailable');
    }
    final table = MessageRepo.getTableName(message.type ?? '');
    return db.transaction((txn) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await txn.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [message.id, userId],
      );
      if (rows.isEmpty) throw StateError('outbox upload group missing');
      final intents = rows
          .map(
            (r) =>
                jsonDecode(r['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      final existing = await txn.query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [message.id],
      );
      if (intents.every((i) => i['state'] == 'outbox_ready')) {
        if (existing.length != 1) throw StateError('outbox message missing');
        return true;
      }
      if (rows.any(
            (r) =>
                r['stage'] != AttachmentUploadStage.confirmed.value ||
                (r['last_error'] as String?)?.startsWith('legacy_migrating:') ==
                    true,
          ) ||
          intents.any((i) => i['state'] != 'uploading')) {
        return false;
      }
      if (existing.isNotEmpty) {
        throw StateError('outbox message result unknown');
      }
      if (rows.length != intents.first['expected_objects'] ||
          intents.any(
            (i) =>
                i['author_id'] != userId ||
                i['peer_id'].toString() != message.toId.toString() ||
                i['chat_type'].toString().toUpperCase() != message.type,
          )) {
        throw StateError('outbox upload group identity mismatch');
      }
      await MessageRepo(tableName: table)
          .insert(message, txn: txn, outbound: true, attachmentCommit: true);
      for (var index = 0; index < rows.length; index++) {
        await txn.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intents[index],
              'state': 'outbox_ready',
              'message': intents[index]['message_template'],
            }),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [rows[index]['id'], userId],
        );
      }
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  /// Legacy action ACKs may clear a non-attachment retry, but never race a
  /// protected attachment being created under the same identity.
  Future<bool> allowUnprotectedActionAck(
    String anchor,
    String userId, {
    required bool Function() isCurrent,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await tx.query(
        tableName,
        columns: ['id'],
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
        limit: 1,
      );
      if (rows.isNotEmpty) return false;
      await _ensureSendGate(tx);
      await tx.insert('attachment_send_gate', {
        'user_id': userId,
        'anchor': anchor,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  /// V5 日志行里 `business_intent` 为 NULL 的行是「纯上传 journal」
  /// （ResumableAttachmentUploader 在 messageIntent 缺省时写入——转发
  /// 明文附件重上传正是这一形态），不属于 outbox 派发协议：认领/派发/
  /// 复原判定一律忽略它们，等价于「该锚点无 outbox 任务」。
  static bool _isOutboxManaged(Map<String, Object?> row) =>
      row['business_intent'] != null;

  Future<bool> claimOutboxDispatch(
    String anchor,
    String userId, {
    required bool Function() isCurrent,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((txn) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await txn.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      final managed = rows.where(_isOutboxManaged).toList();
      if (managed.isEmpty) {
        await _ensureSendGate(txn);
        await txn.insert('attachment_send_gate', {
          'user_id': userId,
          'anchor': anchor,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (!isCurrent()) throw StateError('outbox account changed');
        return true;
      }
      final intents = managed
          .map(
            (r) =>
                jsonDecode(r['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      if (intents.every((i) => i['state'] == 'dispatch_reserved_v2') &&
          managed.every(
            (r) =>
                r['stage'] == AttachmentUploadStage.confirmed.value &&
                (r['last_error'] as String?)?.startsWith('legacy_migrating:') !=
                    true,
          )) {
        return true;
      }
      if (intents.any((i) => i['state'] != 'outbox_ready') ||
          managed.any(
            (r) =>
                r['stage'] != AttachmentUploadStage.confirmed.value ||
                (r['last_error'] as String?)?.startsWith('legacy_migrating:') ==
                    true,
          )) {
        return false;
      }
      for (var index = 0; index < managed.length; index++) {
        await txn.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intents[index],
              'state': 'dispatch_reserved_v2',
            }),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [managed[index]['id'], userId],
        );
      }
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  /// Move a reserved dispatch to an unknown outcome immediately before I/O.
  /// A crash at or after this transition is reconciled, never blindly resent.
  Future<bool> beginOutboxSend(
    String anchor,
    String userId, {
    required bool Function() isCurrent,
    String? attemptToken,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await tx.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      await tx.execute(
        'CREATE TABLE IF NOT EXISTS message_send_attempt '
        '(user_id TEXT NOT NULL, anchor TEXT NOT NULL, token TEXT NOT NULL, '
        'PRIMARY KEY (user_id, anchor, token))',
      );
      final managed = rows.where(_isOutboxManaged).toList();
      if (managed.isEmpty) {
        if (attemptToken != null) {
          await tx.insert('message_send_attempt', {
            'user_id': userId,
            'anchor': anchor,
            'token': attemptToken,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (!isCurrent()) throw StateError('outbox account changed');
        return true;
      }
      final intents = managed
          .map(
            (row) =>
                jsonDecode(row['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      if (managed.any(
            (row) =>
                row['stage'] != AttachmentUploadStage.confirmed.value ||
                (row['last_error'] as String?)?.startsWith(
                      'legacy_migrating:',
                    ) ==
                    true,
          ) ||
          intents.any((intent) => intent['state'] != 'dispatch_reserved_v2')) {
        return false;
      }
      for (var i = 0; i < managed.length; i++) {
        await tx.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intents[i],
              'state': 'commit_unknown',
              'dispatch_attempt': ?attemptToken,
            }),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [managed[i]['id'], userId],
        );
      }
      if (attemptToken != null) {
        await tx.insert('message_send_attempt', {
          'user_id': userId,
          'anchor': anchor,
          'token': attemptToken,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  /// Revert only our own attempt when the sink was never invoked.
  Future<bool> cancelUnsentOutboxAttempt(
    String anchor,
    String userId,
    String token, {
    required bool Function() isCurrent,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await tx.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      final managed = rows.where(_isOutboxManaged).toList();
      if (managed.isEmpty) {
        await tx.delete(
          'message_send_attempt',
          where: 'user_id = ? AND anchor = ? AND token = ?',
          whereArgs: [userId, anchor, token],
        );
        return true;
      }
      final intents = managed
          .map(
            (row) =>
                jsonDecode(row['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      if (intents.any(
        (intent) =>
            intent['state'] != 'commit_unknown' ||
            intent['dispatch_attempt'] != token,
      )) {
        return false;
      }
      for (var i = 0; i < managed.length; i++) {
        final next = {...intents[i], 'state': 'dispatch_reserved_v2'}
          ..remove('dispatch_attempt');
        await tx.update(
          tableName,
          {'business_intent': jsonEncode(next)},
          where: 'id = ? AND user_id = ?',
          whereArgs: [managed[i]['id'], userId],
        );
      }
      await tx.delete(
        'message_send_attempt',
        where: 'user_id = ? AND anchor = ? AND token = ?',
        whereArgs: [userId, anchor, token],
      );
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  Future<bool> reconcileOutboxCommitted(
    String anchor,
    String userId, {
    required bool Function() isCurrent,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await tx.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      if (rows.isEmpty) return false;
      final managed = rows.where(_isOutboxManaged).toList();
      if (managed.isEmpty) return false;
      String? chatType;
      for (final row in managed) {
        final intent = jsonDecode(
          row['business_intent'] as String,
        ) as Map<String, dynamic>;
        final type = intent['chat_type']?.toString().toUpperCase();
        if (row['stage'] != 'confirmed' ||
            intent['author_id']?.toString() != userId ||
            !{'C2C', 'C2G'}.contains(type) ||
            (chatType != null && chatType != type) ||
            !{
              'dispatch_intent',
              'commit_unknown',
              'committed',
            }.contains(intent['state'])) {
          return false;
        }
        chatType = type;
      }
      final messageTable = MessageRepo.getTableName(chatType!);
      final messages = await tx.query(
        messageTable,
        columns: [
          'id',
          'type',
          'from_id',
          'is_author',
          'status',
          'conversation_uk3',
        ],
        where: 'id = ?',
        whereArgs: [anchor],
        limit: 1,
      );
      if (messages.length != 1) return false;
      final message = messages.single;
      if (message['type'] != chatType ||
          message['from_id'].toString() != userId ||
          message['is_author'] != 1 ||
          (message['conversation_uk3']?.toString().isEmpty ?? true) ||
          !{
            IMBoyMessageStatus.sending,
            IMBoyMessageStatus.pendingRetry,
            IMBoyMessageStatus.error,
            IMBoyMessageStatus.sent,
          }.contains(message['status'])) {
        return false;
      }
      for (final row in managed) {
        final intent = jsonDecode(
          row['business_intent'] as String,
        ) as Map<String, dynamic>;
        await tx.update(
          tableName,
          {
            'business_intent': jsonEncode({...intent, 'state': 'committed'}),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['id'], userId],
        );
      }
      await tx.update(
        messageTable,
        {'status': IMBoyMessageStatus.sent},
        where: 'id = ? AND from_id = ?',
        whereArgs: [anchor, userId],
      );
      final tables = await tx.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['crypto_outbox'],
      );
      if (tables.isNotEmpty) {
        await tx.rawUpdate(
          "UPDATE crypto_outbox SET status = 'sent', sent_at = ? WHERE id = ? AND status = 'pending'",
          [DateTime.now().millisecondsSinceEpoch, anchor],
        );
      }
      await ServerAckReceipts.persistReceipt(
        tx,
        userId,
        anchor,
        chatType,
        message['conversation_uk3'] as String,
      );
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  /// An inconclusive result must not roll a concurrent positive result back.
  Future<bool> markOutboxUnknown(
    String anchor,
    String userId,
    String chatType, {
    required bool Function() isCurrent,
  }) async {
    final db = await _boundDb;
    if (db == null) throw StateError('outbox database unavailable');
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('outbox account changed');
      final rows = await tx.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      if (rows.isEmpty) return false;
      final managed = rows.where(_isOutboxManaged).toList();
      if (managed.isEmpty) return false;
      final intents = managed
          .map(
            (row) =>
                jsonDecode(row['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      if (intents.any(
        (intent) =>
            !{'dispatch_intent', 'commit_unknown'}.contains(intent['state']),
      )) {
        return false;
      }
      final table = MessageRepo.getTableName(chatType.toUpperCase());
      final messages = await tx.query(
        table,
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [anchor],
        limit: 1,
      );
      if (messages.isNotEmpty &&
          messages.single['status'] == IMBoyMessageStatus.sent) {
        return false;
      }
      for (var i = 0; i < managed.length; i++) {
        await tx.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intents[i],
              'state': 'commit_unknown',
            }),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [managed[i]['id'], userId],
        );
      }
      await tx.update(
        table,
        {'status': IMBoyMessageStatus.error},
        where: 'id = ? AND status != ?',
        whereArgs: [anchor, IMBoyMessageStatus.sent],
      );
      if (!isCurrent()) throw StateError('outbox account changed');
      return true;
    });
  }

  Future<bool> claimBusinessDispatch(
    String anchor,
    String userId,
    Map<String, dynamic> message,
  ) async {
    if ((message['metadata'] as Map?)?.containsKey('attachment_descriptor') ==
        true) {
      throw ArgumentError('upload secrets must not enter the business journal');
    }
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    return db.transaction((txn) async {
      final rows = await txn.query(
        tableName,
        where: 'anchor_msg_id = ? AND user_id = ?',
        whereArgs: [anchor, userId],
      );
      if (rows.isEmpty) return true;
      for (final row in rows) {
        final intent = jsonDecode(
          row['business_intent'] as String,
        ) as Map<String, dynamic>;
        if (row['stage'] != AttachmentUploadStage.confirmed.value ||
            (row['last_error'] as String?)?.startsWith('legacy_migrating:') ==
                true ||
            intent['state'] != 'uploading') {
          return false;
        }
      }
      for (final row in rows) {
        final intent = jsonDecode(
          row['business_intent'] as String,
        ) as Map<String, dynamic>;
        await txn.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intent,
              'state': 'dispatch_intent',
              'message': message,
            }),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['id'], userId],
        );
      }
      return true;
    });
  }

  Future<int> saveBusinessIntent(
    String anchor,
    String userId,
    String intent,
  ) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    return db.update(
      tableName,
      {'business_intent': intent},
      where: 'anchor_msg_id = ? AND user_id = ?',
      whereArgs: [anchor, userId],
    );
  }

  /// 待恢复任务：本账号所有非终态行，按创建序。
  Future<List<AttachmentUploadTask>> listResumable(String userId) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND stage IN (?, ?, ?)',
      whereArgs: [
        userId,
        AttachmentUploadStage.pending.value,
        AttachmentUploadStage.presigned.value,
        AttachmentUploadStage.putDone.value,
      ],
      orderBy: 'created_at ASC, rowid ASC',
    );
    return rows.map(AttachmentUploadTask.fromMap).toList();
  }

  Future<bool> hasUnrecoverableNonChat(String userId) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final rows = await db.query(
      tableName,
      columns: ['id'],
      limit: 1,
      where:
          'user_id = ? AND business_intent IS NULL AND last_error IN (?, ?, ?)',
      whereArgs: [
        userId,
        'legacy_return_page',
        'upload cache lost; new task and key required',
        'cipher material lost; new task and key required',
      ],
    );
    return rows.isNotEmpty;
  }

  /// 显式放弃（密钥材料丢失/授权撤销）：任何非终态 → abandoned。
  Future<bool> abandon(String id, String userId, String reason) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final n = await db.update(
      tableName,
      {
        'stage': AttachmentUploadStage.abandoned.value,
        'last_error': reason,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where:
          'id = ? AND user_id = ? AND stage NOT IN (?, ?)'
          " AND (last_error IS NULL OR (last_error NOT LIKE 'legacy_migrating:%' AND last_error NOT LIKE 'legacy_migrated:%'))",
      whereArgs: [
        id,
        userId,
        AttachmentUploadStage.confirmed.value,
        AttachmentUploadStage.abandoned.value,
      ],
    );
    return n > 0;
  }
}
