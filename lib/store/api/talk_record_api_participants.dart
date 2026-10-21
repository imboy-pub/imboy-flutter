part of 'talk_record_api.dart';

extension TalkRecordParticipantApi on TalkRecordApi {
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>>
  participantCandidates({
    required TalkRecordScope scope,
    EntityId? organizationId,
    EntityId? workspaceId,
    String q = '',
    String cursor = '',
  }) async {
    final response = await get(
      '${API.talkRecords}/share-candidates',
      queryParameters: {
        'scope': scope.wireName,
        if (organizationId != null && organizationId.isNotEmpty)
          'organization_id': int.parse(organizationId),
        if (workspaceId != null && workspaceId.isNotEmpty)
          'workspace_id': int.parse(workspaceId),
        ..._pageQuery(cursor: cursor, limit: 100),
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return _unwrapPage(response, TalkRecordShareCandidateModel.fromJson);
  }

  Future<TalkRecordFetched<TalkRecordParticipants>> participants(
    EntityId id,
  ) async {
    final uri = API.talkRecordParticipants(id);
    final response = await get(uri);
    final data = _ensureOk(response);
    final headerEtag = _takeEtag(uri);
    return TalkRecordFetched(
      TalkRecordParticipants.fromJson(data),
      etag: headerEtag.isNotEmpty ? headerEtag : parseModelString(data['etag']),
    );
  }

  Future<TalkRecordFetched<TalkRecordParticipants>> putParticipants(
    EntityId id, {
    required List<TalkRecordParticipantInput> participants,
    required String ifMatch,
  }) async {
    if (ifMatch.isEmpty ||
        participants.length > 100 ||
        participants.map((item) => item.identityKey).toSet().length !=
            participants.length) {
      throw const FormatException('Invalid participants revision or selection');
    }
    final uri = API.talkRecordParticipants(id);
    final response = await put(
      uri,
      data: {
        'participants': participants
            .map((item) => item.toJson())
            .toList(growable: false),
      },
      options: _options(ifMatch: ifMatch),
    );
    final data = _ensureOk(response);
    final headerEtag = _takeEtag(uri);
    return TalkRecordFetched(
      TalkRecordParticipants.fromJson(data),
      etag: headerEtag.isNotEmpty ? headerEtag : parseModelString(data['etag']),
    );
  }
}
