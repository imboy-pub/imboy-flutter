part of 'talk_record_api.dart';

/// Result-domain read endpoint, sharing the API library's strict page parser.
extension TalkRecordTransferCandidatesApi on TalkRecordApi {
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>>
  transferCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final resp = await get(
      API.talkRecordTransferCandidates(id),
      queryParameters: {
        ..._pageQuery(cursor: cursor, limit: limit),
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return _unwrapPage(resp, TalkRecordShareCandidateModel.fromJson);
  }
}

/// POST .../audio-parts/:part_id/confirm 响应（§4：202 verifying 或
/// 200 confirmed；重复同 hash 安全重放）。
class TalkRecordAudioPartConfirmResult {
  /// verifying | confirmed
  final String status;
  final Map<String, dynamic> raw;

  const TalkRecordAudioPartConfirmResult({
    this.status = '',
    this.raw = const {},
  });

  factory TalkRecordAudioPartConfirmResult.fromJson(Map<String, dynamic> json) {
    return TalkRecordAudioPartConfirmResult(
      status: parseModelString(json['status']),
      raw: json,
    );
  }

  bool get isConfirmed => status == 'confirmed';
}

/// POST /:id/complete 响应（§4：202 media assembling + job_id；
/// record_only 不创建模型任务）。
class TalkRecordCompleteResult {
  final EntityId jobId;
  final String mediaStatus;
  final Map<String, dynamic> raw;

  const TalkRecordCompleteResult({
    this.jobId = '',
    this.mediaStatus = '',
    this.raw = const {},
  });

  factory TalkRecordCompleteResult.fromJson(Map<String, dynamic> json) {
    return TalkRecordCompleteResult(
      jobId: entityIdOf(json['job_id']),
      mediaStatus: parseModelString(json['media_status']).isEmpty
          ? parseModelString(json['status'])
          : parseModelString(json['media_status']),
      raw: json,
    );
  }
}

/// POST /:id/share-card 响应（§4：只生成受控 talk_record_card 定位数据，
/// 不额外授权、不发消息）。
class TalkRecordShareCardData {
  final String cardType;
  final EntityId recordId;
  final String title;
  final Map<String, dynamic> raw;

  const TalkRecordShareCardData({
    this.cardType = '',
    this.recordId = '',
    this.title = '',
    this.raw = const {},
  });

  factory TalkRecordShareCardData.fromJson(Map<String, dynamic> json) {
    return TalkRecordShareCardData(
      cardType: parseModelString(json['card_type']),
      recordId: entityIdOf(json['record_id']),
      title: parseModelString(json['title']),
      raw: json,
    );
  }
}

/// POST /:id/playback 响应（§4：短时受控播放会话 URL/expiry；不暴露可
/// 长期直读的 S3 地址）。
class TalkRecordPlaybackSession {
  final String url;
  final DateTime? expiresAt;
  final Map<String, dynamic> raw;

  const TalkRecordPlaybackSession({
    this.url = '',
    this.expiresAt,
    this.raw = const {},
  });

  factory TalkRecordPlaybackSession.fromJson(Map<String, dynamic> json) {
    return TalkRecordPlaybackSession(
      url: parseModelString(json['url']),
      expiresAt:
          parseModelNullableDateTime(json['expiry']) ??
          parseModelNullableDateTime(json['expires_at']),
      raw: json,
    );
  }
}

/// POST /:id/exports 响应（§4：202 export/job）。
class TalkRecordExportResult {
  final EntityId exportId;
  final String state;
  final EntityId jobId;
  final Map<String, dynamic> raw;

  const TalkRecordExportResult({
    this.exportId = '',
    this.state = '',
    this.jobId = '',
    this.raw = const {},
  });

  factory TalkRecordExportResult.fromJson(Map<String, dynamic> json) {
    return TalkRecordExportResult(
      exportId: entityIdOf(json['export_id']),
      state: parseModelString(json['state']),
      jobId: entityIdOf(json['job_id']),
      raw: json,
    );
  }
}

/// DELETE /:id 响应（§4：202 logical_deleted=true、cleanup_status=pending；
/// §10.4 拆分 logical_deleted/cleanup_status）。
class TalkRecordDeleteResult {
  final bool logicalDeleted;
  final TalkRecordCleanupStatus cleanupStatus;
  final Map<String, dynamic> raw;

  const TalkRecordDeleteResult({
    this.logicalDeleted = false,
    this.cleanupStatus = TalkRecordCleanupStatus.none,
    this.raw = const {},
  });

  factory TalkRecordDeleteResult.fromJson(Map<String, dynamic> json) {
    return TalkRecordDeleteResult(
      logicalDeleted: parseModelBool(
        json['logical_deleted'],
        defaultValue: true,
      ),
      cleanupStatus: TalkRecordCleanupStatus.parse(json['cleanup_status']),
      raw: json,
    );
  }
}
