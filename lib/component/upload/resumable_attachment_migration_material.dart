part of 'resumable_attachment_uploader.dart';

// Deterministic encrypted staging and upload material for a legacy migration.
// Keep derivation independent of the uploader's journal and filesystem writes.
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
  final uploadNonce = _migrationKey(oldKey, replacementId, 'upload-nonce', 12);
  final stageKey = _migrationKey(oldKey, replacementId, 'staging-key', 32);
  final stageNonce = _migrationKey(oldKey, replacementId, 'staging-nonce', 12);
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
    chunkCount: AttachmentDescriptor.expectedChunkCount(task.plainSize, chunks),
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
