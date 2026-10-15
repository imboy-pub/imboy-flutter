import 'dart:convert';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

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

  final _boundDb = SqliteService.to.db;

  Future<bool> insert(AttachmentUploadTask task) async {
    final db = await _boundDb;
    if (db == null) throw StateError('upload journal database unavailable');
    final n = await db.insert(
      tableName,
      task.toMap(),
      conflictAlgorithm: null, // 主键冲突直接抛——幂等键重复由调用方处理
    );
    return n > 0;
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
      where: 'id = ? AND stage = ?${userId == null ? '' : ' AND user_id = ?'}',
      whereArgs: [id, from.value, ?userId],
    );
    return n > 0;
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
            (r) => r['stage'] != AttachmentUploadStage.confirmed.value,
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
      await MessageRepo(tableName: table).insert(message, txn: txn);
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
      if (rows.isEmpty) return true;
      final intents = rows
          .map(
            (r) =>
                jsonDecode(r['business_intent'] as String)
                    as Map<String, dynamic>,
          )
          .toList();
      if (intents.any((i) => i['state'] != 'outbox_ready')) return false;
      for (var index = 0; index < rows.length; index++) {
        await txn.update(
          tableName,
          {
            'business_intent': jsonEncode({
              ...intents[index],
              'state': 'dispatch_intent',
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
      where: 'id = ? AND user_id = ? AND stage NOT IN (?, ?)',
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
