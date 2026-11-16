part of 'attachment_upload_task_repo_sqlite.dart';

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
