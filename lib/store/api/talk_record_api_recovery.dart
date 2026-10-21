part of 'talk_record_api.dart';

/// 404 deliberately conflates absent, deleted, transferred and revoked.
Future<TalkRecordFetched<TalkRecordModel>?> _lookupRecording(
  TalkRecordApi api, {
  required String clientRecordingId,
  required TalkRecordScope scope,
  EntityId? organizationId,
  EntityId? workspaceId,
}) async {
  final uri = '${API.talkRecords}/by-client-recording-id';
  try {
    final response = await api.get(
      uri,
      queryParameters: {
        'client_recording_id': clientRecordingId,
        'scope': scope.wireName,
        if (organizationId != null && organizationId.isNotEmpty)
          'organization_id': organizationId,
        if (workspaceId != null && workspaceId.isNotEmpty)
          'workspace_id': workspaceId,
      },
    );
    return TalkRecordFetched(
      api._unwrap(response, TalkRecordModel.fromJson),
      etag: api._takeEtag(uri),
    );
  } on TalkRecordApiException catch (error) {
    if (error.kind == TalkRecordErrorKind.noAccess) return null;
    rethrow;
  }
}
