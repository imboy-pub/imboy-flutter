part of 'talk_record_api.dart';

/// Result operations use the same authenticated client and envelope handling.
extension TalkRecordResultOperations on TalkRecordApi {
  Future<Map<String, dynamic>> exportStatePayload(
    EntityId id,
    EntityId exportId,
  ) async {
    final response = await get(API.talkRecordExportState(id, exportId));
    return Map<String, dynamic>.unmodifiable(_ensureOk(response));
  }

  Future<Map<String, dynamic>> transferOwnershipPayload(
    EntityId id, {
    required EntityId targetUserId,
    required bool keepAccess,
    required String ifMatch,
    required String idempotencyKey,
  }) async {
    final response = await post(
      API.talkRecordOwnershipTransfers(id),
      data: {'target_user_id': targetUserId, 'keep_access': keepAccess},
      options: _options(ifMatch: ifMatch, idempotencyKey: idempotencyKey),
    );
    return Map<String, dynamic>.unmodifiable(_ensureOk(response));
  }
}
