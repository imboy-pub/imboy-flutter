part of 'attachment_direct_api.dart';

/// A successful renew can observe a winner without returning a new grant.
Future<DirectUploadResult?> _finishIfConfirmedDirect(
  dynamic payload, {
  required String objectKey,
  CancelToken? cancelToken,
  Future<void> Function(DirectCheckpoint event)? checkpoint,
}) async {
  if (DirectAttachmentApi.str(payload, 'state') !=
      DirectAttachmentApi.stateConfirmed) {
    return null;
  }
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  if (DirectAttachmentApi.str(payload, 'object_key') != objectKey) {
    throw StateError('confirmed upload object identity changed');
  }
  final attemptId =
      int.tryParse(DirectAttachmentApi.str(payload, 'attempt_id')) ?? 0;
  await checkpoint?.call(
    DirectCheckpoint(
      DirectCheckpointStage.confirmed,
      objectKey: objectKey,
      attemptId: attemptId,
    ),
  );
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  return DirectUploadResult(
    objectKey: objectKey,
    state: DirectAttachmentApi.stateConfirmed,
    attemptId: attemptId,
  );
}
