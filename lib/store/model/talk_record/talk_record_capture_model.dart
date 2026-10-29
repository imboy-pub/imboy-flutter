/// 面聊记录（talk_record）采集模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_capture / talk_record_capture_event
/// + §8 采集 API + §11.1 失联恢复（last_seen_at/lease_epoch/lease_until、
/// recover/abandon）。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

/// Epoch zero is a valid initial lease; absent/malformed values are unknown.
/// General model integer parsing coerces bool/fractions to zero, so do not use
/// it for this ownership fence.
int parseTalkRecordLeaseEpoch(dynamic value) {
  if (value is int) return value >= 0 ? value : -1;
  if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) {
    return int.tryParse(value) ?? -1;
  }
  return -1;
}

/// talk_record_capture 行（§2/§8）。
class TalkRecordCaptureModel {
  final EntityId id;
  final EntityId recordId;
  final String deviceSessionId;
  final String deviceId;
  final String completionManifestHash;
  final EntityId startedBy;
  final TalkRecordSourceType sourceType;
  final TalkRecordCaptureStatus status;

  /// 设备上报开始时间（仅供显示，§3）。
  final DateTime? reportedStartedAt;

  /// 服务器时间（用于审计，§3）。
  final DateTime? serverStartedAt;
  final DateTime? endedAt;
  final int durationMs;
  final int revision;
  final DateTime? lastSeenAt;
  final int leaseEpoch;
  final DateTime? leaseUntil;
  final String etag;
  final int lastEventSeq;
  final bool recovered;
  final bool abandoned;
  final Map<String, dynamic> parts;
  final List<Map<String, dynamic>> confirmedParts;

  const TalkRecordCaptureModel({
    required this.id,
    this.recordId = '',
    this.deviceSessionId = '',
    this.deviceId = '',
    this.completionManifestHash = '',
    this.startedBy = '',
    this.sourceType = TalkRecordSourceType.unknown,
    this.status = TalkRecordCaptureStatus.unknown,
    this.reportedStartedAt,
    this.serverStartedAt,
    this.endedAt,
    this.durationMs = 0,
    this.revision = 1,
    this.lastSeenAt,
    this.leaseEpoch = -1,
    this.leaseUntil,
    this.etag = '',
    this.lastEventSeq = -2,
    this.recovered = false,
    this.abandoned = false,
    this.parts = const {},
    this.confirmedParts = const [],
  });

  factory TalkRecordCaptureModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordCaptureModel(
      id: entityIdOf(json['capture_id'] ?? json['id']),
      recordId: entityIdOf(json['record_id']),
      deviceSessionId: parseModelString(json['device_session_id']),
      deviceId: parseModelString(json['device_id']),
      completionManifestHash: parseModelString(
        json['completion_manifest_hash'],
      ),
      startedBy: entityIdOf(json['started_by']),
      sourceType: TalkRecordSourceType.parse(json['source_type']),
      status: TalkRecordCaptureStatus.parse(json['status']),
      reportedStartedAt: parseModelNullableDateTime(
        json['reported_started_at'],
      ),
      serverStartedAt: parseModelNullableDateTime(
        json['started_at'] ?? json['server_started_at'],
      ),
      endedAt: parseModelNullableDateTime(json['ended_at']),
      durationMs: parseModelInt(json['duration_ms']),
      revision: parseModelInt(json['revision'], defaultValue: 1),
      lastSeenAt: parseModelNullableDateTime(json['last_seen_at']),
      leaseEpoch: parseTalkRecordLeaseEpoch(json['lease_epoch']),
      leaseUntil: parseModelNullableDateTime(json['lease_until']),
      etag: parseModelString(json['etag']),
      lastEventSeq:
          json['last_event_seq'] is int && (json['last_event_seq'] as int) >= -1
          ? json['last_event_seq'] as int
          : -2,
      recovered: parseModelBool(json['recovered']),
      abandoned: parseModelBool(json['abandoned']),
      parts: Map<String, dynamic>.unmodifiable(
        json['parts'] is Map
            ? Map<String, dynamic>.from(json['parts'] as Map)
            : <String, dynamic>{},
      ),
      confirmedParts: List<Map<String, dynamic>>.unmodifiable(
        (json['confirmed_parts'] is List
                ? json['confirmed_parts'] as List<dynamic>
                : <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (part) => Map<String, dynamic>.unmodifiable(
                Map<String, dynamic>.from(part),
              ),
            ),
      ),
    );
  }

  bool get isActive =>
      status == TalkRecordCaptureStatus.recording ||
      status == TalkRecordCaptureStatus.paused;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'device_session_id': deviceSessionId,
    'device_id': deviceId,
    'started_by': startedBy,
    'source_type': sourceType.wireName,
    'status': status.wireName,
    if (reportedStartedAt != null)
      'reported_started_at': reportedStartedAt!.toIso8601String(),
    if (serverStartedAt != null)
      'server_started_at': serverStartedAt!.toIso8601String(),
    if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
    if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
    'duration_ms': durationMs,
    'revision': revision,
    'lease_epoch': leaseEpoch,
    if (leaseUntil != null) 'lease_until': leaseUntil!.toIso8601String(),
    'etag': etag,
    'last_event_seq': lastEventSeq,
    'recovered': recovered,
    'abandoned': abandoned,
    'parts': parts,
    'confirmed_parts': confirmedParts,
  };
}

/// POST /:id/captures/:capture_id/events 请求体（§4/§8）。
///
/// client_event_id + (capture_id, seq) 双唯一键离线去重（§2）；
/// 服务端凭此更新 capture 状态并返回 revision，不宣称设备仍持有麦克风。
class TalkRecordCaptureEventInput {
  final String clientEventId;
  final String deviceSessionId;
  final int seq;
  final TalkRecordCaptureEventKind event;
  final int positionMs;
  final DateTime? reportedAt;

  const TalkRecordCaptureEventInput({
    required this.clientEventId,
    required this.deviceSessionId,
    required this.seq,
    required this.event,
    this.positionMs = 0,
    this.reportedAt,
  });

  Map<String, dynamic> toJson() => {
    'client_event_id': clientEventId,
    'device_session_id': deviceSessionId,
    'seq': seq,
    'event': event.wireName,
    'position_ms': positionMs,
    if (reportedAt != null) 'reported_at': reportedAt!.toIso8601String(),
  };
}

/// POST /:id/captures/:capture_id/audio-parts 请求体（§4/§8）。
///
/// start_ms/end_ms 均为有效音频时间轴；capture_offset_ms 为有效音频
/// 位置（§11.1）。
class TalkRecordAudioPartInput {
  final int seq;
  final int startMs;
  final int endMs;
  final String sha256;
  final int byteSize;
  final String codec;
  final int? sampleRate;
  final int? channels;
  final int captureOffsetMs;
  final DateTime? capturedWallTime;

  const TalkRecordAudioPartInput({
    required this.seq,
    required this.startMs,
    required this.endMs,
    required this.sha256,
    required this.byteSize,
    this.codec = 'aac_lc',
    this.sampleRate,
    this.channels,
    this.captureOffsetMs = 0,
    this.capturedWallTime,
  });

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'start_ms': startMs,
    'end_ms': endMs,
    'sha256': sha256,
    'size': byteSize,
    'codec': codec,
    if (sampleRate != null) 'sample_rate': sampleRate,
    if (channels != null) 'channels': channels,
    'capture_offset_ms': captureOffsetMs,
    if (capturedWallTime != null)
      'captured_wall_time': capturedWallTime!.toIso8601String(),
  };
}

/// POST /:id/complete 请求体 captures 元素（§8：清单为
/// {capture_id, last_seq, manifest_hash}）。
class TalkRecordCompleteCaptureInput {
  final EntityId captureId;
  final int lastSeq;
  final String manifestHash;

  const TalkRecordCompleteCaptureInput({
    required this.captureId,
    required this.lastSeq,
    required this.manifestHash,
  });

  Map<String, dynamic> toJson() {
    final exactId = BigInt.tryParse(captureId);
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(captureId) ||
        exactId == null ||
        exactId > BigInt.parse('9223372036854775807') ||
        (kIsWeb && exactId > BigInt.from(9007199254740991))) {
      throw const FormatException('Invalid completion capture ID');
    }
    return {
      'capture_id': exactId.toInt(),
      'last_seq': lastSeq,
      'manifest_hash': manifestHash,
    };
  }
}
