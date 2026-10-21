/// 面聊记录（talk_record）T09 —— 本地段清单（manifest）。
///
/// 契约源：DESIGN.md §5.1（本地分段、加密临时存储与段清单）、§5.3
/// （App 异常退出→下次恢复已落盘分段，明确实际保留时长）；
/// BACKEND-API.md §11.1（start_ms/end_ms 都是有效音频时间轴，暂停期间
/// 不制造空音频，有效时长以分段累加）。
///
/// 单文件 JSON、原子写（tmp+rename）。每封一段即重写全量——段文件
/// 校验通过的条目才可恢复；末段缺失/校验失败按尾部截断处理（崩溃时
/// 未完成封段的明文临时文件不进清单，天然丢弃）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

/// 清单 schema 版本。
const int kTalkRecordManifestSchemaVersion = 1;

/// 采集会话持久状态（manifest 内）。
enum TalkRecordSessionStatus {
  recording('recording'),
  paused('paused'),
  interrupted('interrupted'),
  ended('ended');

  final String wireName;
  const TalkRecordSessionStatus(this.wireName);

  static TalkRecordSessionStatus parse(dynamic raw) {
    final s = raw is String ? raw : (raw?.toString() ?? '');
    for (final v in values) {
      if (v.wireName == s) return v;
    }
    return TalkRecordSessionStatus.recording;
  }
}

/// 单个已封段条目。
class TalkRecordSegmentEntry {
  final int seq;

  /// 有效音频时间轴起止 ms（§11.1：start_ms/end_ms 均为有效轴）。
  final int startMs;
  final int endMs;

  /// 本段有效毫秒（endMs-startMs）。
  int get durationMs => endMs - startMs;

  final String cipherFileName;
  final int cipherSize;
  final String cipherSha256Hex;
  final int plainSize;
  final String plainSha256Hex;
  final String codec;
  final int sampleRateHz;
  final int numChannels;

  /// 段捕获墙钟（仅溯源，§11.1 captured_wall_time 语义）。
  final String capturedWallTimeIso;

  const TalkRecordSegmentEntry({
    required this.seq,
    required this.startMs,
    required this.endMs,
    required this.cipherFileName,
    required this.cipherSize,
    required this.cipherSha256Hex,
    required this.plainSize,
    required this.plainSha256Hex,
    required this.codec,
    required this.sampleRateHz,
    required this.numChannels,
    required this.capturedWallTimeIso,
  });

  factory TalkRecordSegmentEntry.fromJson(Map<String, dynamic> json) {
    return TalkRecordSegmentEntry(
      seq: _asInt(json['seq']),
      startMs: _asInt(json['start_ms']),
      endMs: _asInt(json['end_ms']),
      cipherFileName: _asStr(json['cipher_file']),
      cipherSize: _asInt(json['cipher_size']),
      cipherSha256Hex: _asStr(json['cipher_sha256']),
      plainSize: _asInt(json['plain_size']),
      plainSha256Hex: _asStr(json['plain_sha256']),
      codec: _asStr(json['codec'], fallback: 'aac_lc'),
      sampleRateHz: _asInt(json['sample_rate_hz']),
      numChannels: _asInt(json['num_channels'], fallback: 1),
      capturedWallTimeIso: _asStr(json['captured_wall_time']),
    );
  }

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'start_ms': startMs,
    'end_ms': endMs,
    'cipher_file': cipherFileName,
    'cipher_size': cipherSize,
    'cipher_sha256': cipherSha256Hex,
    'plain_size': plainSize,
    'plain_sha256': plainSha256Hex,
    'codec': codec,
    'sample_rate_hz': sampleRateHz,
    'num_channels': numChannels,
    'captured_wall_time': capturedWallTimeIso,
  };

  TalkRecordSegmentCipherInfo get cipherInfo => TalkRecordSegmentCipherInfo(
    plainSize: plainSize,
    plainSha256Hex: plainSha256Hex,
    cipherSize: cipherSize,
    cipherSha256Hex: cipherSha256Hex,
  );

  static int _asInt(dynamic v, {int fallback = 0}) =>
      v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? fallback));

  static String _asStr(dynamic v, {String fallback = ''}) =>
      v is String ? v : fallback;
}

/// 本地重点标记（UI-SPEC §2 录音行「重点列表」；离线先本机落盘，
/// 联网幂等补传时再映射 client_mark_id）。
class TalkRecordLocalMark {
  final String localId;
  final int positionMs;
  final String note;
  final String createdAtIso;

  const TalkRecordLocalMark({
    required this.localId,
    required this.positionMs,
    this.note = '',
    required this.createdAtIso,
  });

  factory TalkRecordLocalMark.fromJson(Map<String, dynamic> json) {
    return TalkRecordLocalMark(
      localId: _s(json['local_id']),
      positionMs: _i(json['position_ms']),
      note: _s(json['note']),
      createdAtIso: _s(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'local_id': localId,
    'position_ms': positionMs,
    'note': note,
    'created_at': createdAtIso,
  };

  static String _s(dynamic v) => v is String ? v : '';
  static int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}

/// 中断原因（持久化，恢复后仍可见——DESIGN §5.2）。
class TalkRecordInterruptionRecord {
  final String reason;
  final String occurredAtIso;

  const TalkRecordInterruptionRecord({
    required this.reason,
    required this.occurredAtIso,
  });

  factory TalkRecordInterruptionRecord.fromJson(Map<String, dynamic> json) {
    return TalkRecordInterruptionRecord(
      reason: json['reason'] is String ? json['reason'] as String : '',
      occurredAtIso: json['occurred_at'] is String
          ? json['occurred_at'] as String
          : '',
    );
  }

  Map<String, dynamic> toJson() => {
    'reason': reason,
    'occurred_at': occurredAtIso,
  };
}

/// 会话清单。
class TalkRecordManifest {
  final int schemaVersion;
  final String sessionId;
  final String recordLocalId;

  /// 客户端 UUID 草稿标识（BACKEND-API §3：客户端不得自行生成服务器
  /// TSID；此 ID 用于离线补传幂等对齐）。
  final String clientRecordingId;
  final TalkRecordSessionStatus status;
  final String reportedStartedAtIso;
  final List<TalkRecordSegmentEntry> segments;
  final List<TalkRecordLocalMark> marks;
  final TalkRecordInterruptionRecord? interruption;
  final TalkRecordEncoderSettings encoder;
  final int maxDurationMs;
  final int maxRecordingBytes;
  final String endedReason;
  final String updatedAtIso;

  const TalkRecordManifest({
    this.schemaVersion = kTalkRecordManifestSchemaVersion,
    required this.sessionId,
    required this.recordLocalId,
    required this.clientRecordingId,
    this.status = TalkRecordSessionStatus.recording,
    required this.reportedStartedAtIso,
    this.segments = const [],
    this.marks = const [],
    this.interruption,
    this.encoder = const TalkRecordEncoderSettings(),
    this.maxDurationMs = 0,
    this.maxRecordingBytes = 0,
    this.endedReason = '',
    required this.updatedAtIso,
  });

  /// 有效时长 = 分段累加（暂停/中断不计时，§3）。
  int get effectiveDurationMs =>
      segments.fold<int>(0, (sum, s) => sum + s.durationMs);

  /// 累计密文字节。
  int get totalCipherBytes =>
      segments.fold<int>(0, (sum, s) => sum + s.cipherSize);

  int get lastSeq => segments.isEmpty ? 0 : segments.last.seq;

  TalkRecordManifest copyWith({
    TalkRecordSessionStatus? status,
    List<TalkRecordSegmentEntry>? segments,
    List<TalkRecordLocalMark>? marks,
    TalkRecordInterruptionRecord? interruption,
    bool clearInterruption = false,
    String? endedReason,
    String? updatedAtIso,
  }) => TalkRecordManifest(
    schemaVersion: schemaVersion,
    sessionId: sessionId,
    recordLocalId: recordLocalId,
    clientRecordingId: clientRecordingId,
    status: status ?? this.status,
    reportedStartedAtIso: reportedStartedAtIso,
    segments: segments ?? this.segments,
    marks: marks ?? this.marks,
    interruption: clearInterruption
        ? null
        : (interruption ?? this.interruption),
    encoder: encoder,
    maxDurationMs: maxDurationMs,
    maxRecordingBytes: maxRecordingBytes,
    endedReason: endedReason ?? this.endedReason,
    updatedAtIso: updatedAtIso ?? this.updatedAtIso,
  );

  factory TalkRecordManifest.fromJson(Map<String, dynamic> json) {
    final encJson = json['encoder'];
    final enc = encJson is Map<String, dynamic>
        ? TalkRecordEncoderSettings(
            sampleRateHz: TalkRecordSegmentEntry._asInt(
              encJson['sample_rate'],
              fallback: 16000,
            ),
            numChannels: TalkRecordSegmentEntry._asInt(
              encJson['num_channels'],
              fallback: 1,
            ),
            bitRate: TalkRecordSegmentEntry._asInt(
              encJson['bit_rate'],
              fallback: 24000,
            ),
            codec: TalkRecordSegmentEntry._asStr(
              encJson['codec'],
              fallback: 'aac_lc',
            ),
          )
        : const TalkRecordEncoderSettings();
    final segRaw = json['segments'];
    final markRaw = json['marks'];
    final itrRaw = json['interruption'];
    return TalkRecordManifest(
      schemaVersion: TalkRecordSegmentEntry._asInt(
        json['schema_version'],
        fallback: kTalkRecordManifestSchemaVersion,
      ),
      sessionId: TalkRecordSegmentEntry._asStr(json['session_id']),
      recordLocalId: TalkRecordSegmentEntry._asStr(json['record_local_id']),
      clientRecordingId: TalkRecordSegmentEntry._asStr(
        json['client_recording_id'],
      ),
      status: TalkRecordSessionStatus.parse(json['status']),
      reportedStartedAtIso: TalkRecordSegmentEntry._asStr(
        json['reported_started_at'],
      ),
      segments: segRaw is List
          ? segRaw
                .whereType<Map<String, dynamic>>()
                .map(TalkRecordSegmentEntry.fromJson)
                .toList(growable: false)
          : const <TalkRecordSegmentEntry>[],
      marks: markRaw is List
          ? markRaw
                .whereType<Map<String, dynamic>>()
                .map(TalkRecordLocalMark.fromJson)
                .toList(growable: false)
          : const <TalkRecordLocalMark>[],
      interruption: itrRaw is Map<String, dynamic>
          ? TalkRecordInterruptionRecord.fromJson(itrRaw)
          : null,
      encoder: enc,
      maxDurationMs: TalkRecordSegmentEntry._asInt(json['max_duration_ms']),
      maxRecordingBytes: TalkRecordSegmentEntry._asInt(
        json['max_recording_bytes'],
      ),
      endedReason: TalkRecordSegmentEntry._asStr(json['ended_reason']),
      updatedAtIso: TalkRecordSegmentEntry._asStr(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'session_id': sessionId,
    'record_local_id': recordLocalId,
    'client_recording_id': clientRecordingId,
    'status': status.wireName,
    'reported_started_at': reportedStartedAtIso,
    'segments': segments.map((s) => s.toJson()).toList(),
    'marks': marks.map((m) => m.toJson()).toList(),
    if (interruption != null) 'interruption': interruption!.toJson(),
    'encoder': encoder.toJson(),
    'max_duration_ms': maxDurationMs,
    'max_recording_bytes': maxRecordingBytes,
    'ended_reason': endedReason,
    'updated_at': updatedAtIso,
  };
}

/// 清单 IO 与崩溃恢复。
class TalkRecordManifestStore {
  TalkRecordManifestStore(this.sessionDir);

  /// Discover persisted sessions; a corrupt directory cannot hide other ones.
  static Future<List<TalkRecordManifest>> listSessions(
    Directory baseDirectory,
  ) async {
    if (!baseDirectory.existsSync()) return const [];
    final out = <TalkRecordManifest>[];
    await for (final entity in baseDirectory.list()) {
      if (entity is! Directory) continue;
      try {
        final manifest = await TalkRecordManifestStore(entity).read();
        if (manifest != null) out.add(manifest);
      } catch (_) {
        // read() preserves fail-closed behavior for a corrupt manifest.
      }
    }
    return out;
  }

  final Directory sessionDir;

  File get manifestFile => File('${sessionDir.path}/manifest.json');

  /// 原子写：tmp + rename（同目录保证 rename 原子性）。
  Future<void> write(TalkRecordManifest manifest) async {
    await sessionDir.create(recursive: true);
    final tmp = File('${manifestFile.path}.tmp');
    final sink = tmp.openWrite();
    try {
      sink.write(jsonEncode(manifest.toJson()));
      await sink.flush();
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
    await tmp.rename(manifestFile.path);
  }

  /// 读清单；不存在返回 null，损坏抛异常（fail-closed，不静默重建）。
  Future<TalkRecordManifest?> read() async {
    if (!manifestFile.existsSync()) return null;
    final raw = await manifestFile.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const TalkRecordManifestException('manifest 根结构损坏');
    }
    return TalkRecordManifest.fromJson(decoded);
  }

  /// 崩溃恢复（DESIGN §5.3）：扫描 manifest + 逐段校验密文文件。
  ///
  /// - 密文缺失/大小不符/SHA-256 不符的段：按序截断（从第一个坏段起
  ///   丢弃其后所有段——分段时间轴必须连续有效，不能跳段拼接）；
  /// - 段校验全部通过但状态非 ended：恢复为 interrupted（保留中断
  ///   信息；若此前无中断记录，标记 unknown_interrupt），恢复继续录
  ///   必须用户显式确认；
  /// - 清单状态 ended：直接按已结束恢复。
  Future<TalkRecordRecoveryResult> recover({bool verifyHashes = true}) async {
    final manifest = await read();
    if (manifest == null) {
      return const TalkRecordRecoveryResult.empty();
    }
    final List<TalkRecordSegmentEntry> kept = [];
    var truncated = false;
    for (final seg in manifest.segments) {
      if (truncated) break;
      final cipher = File('${sessionDir.path}/${seg.cipherFileName}');
      if (!cipher.existsSync() || cipher.lengthSync() != seg.cipherSize) {
        truncated = true;
        break;
      }
      if (verifyHashes) {
        final digest = await sha256.bind(cipher.openRead()).first;
        if (digest.toString() != seg.cipherSha256Hex) {
          truncated = true;
          break;
        }
      }
      kept.add(seg);
    }
    if (!truncated && kept.length == manifest.segments.length) {
      if (manifest.status == TalkRecordSessionStatus.ended) {
        return TalkRecordRecoveryResult(
          manifest: manifest,
          truncatedTail: false,
        );
      }
      // 段全部完好但状态非 ended：启动时发现"还在录"的清单 ⇒ 上次异常
      // 退出，归一为 interrupted（unknown_interrupt），续录须用户确认。
      final normalized = manifest.copyWith(
        status: TalkRecordSessionStatus.interrupted,
        interruption:
            manifest.interruption ??
            const TalkRecordInterruptionRecord(
              reason: 'unknown_interrupt',
              occurredAtIso: '',
            ),
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      await write(normalized);
      return TalkRecordRecoveryResult(
        manifest: normalized,
        truncatedTail: false,
      );
    }
    final recovered = manifest.copyWith(
      segments: List.unmodifiable(kept),
      // M3：非 ended 一律归一 interrupted（含首段损坏 kept 空的形态）
      // ——磁盘 manifest 与 listSessions 不得呈现 recording 误导 T10 UI。
      status: manifest.status == TalkRecordSessionStatus.ended
          ? TalkRecordSessionStatus.ended
          : TalkRecordSessionStatus.interrupted,
      interruption:
          manifest.interruption ??
          const TalkRecordInterruptionRecord(
            reason: 'unknown_interrupt',
            occurredAtIso: '',
          ),
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    // 把截断后的清单写回，保证后续续录从一致状态出发。
    if (recovered.segments.length != manifest.segments.length ||
        recovered.status != manifest.status) {
      await write(recovered);
    }
    return TalkRecordRecoveryResult(manifest: recovered, truncatedTail: true);
  }
}

class TalkRecordManifestException implements Exception {
  final String message;
  const TalkRecordManifestException(this.message);
  @override
  String toString() => 'TalkRecordManifestException: $message';
}

/// 恢复结果。
class TalkRecordRecoveryResult {
  final TalkRecordManifest? manifest;
  final bool truncatedTail;

  const TalkRecordRecoveryResult({this.manifest, required this.truncatedTail});

  const TalkRecordRecoveryResult.empty()
    : manifest = null,
      truncatedTail = false;

  /// 恢复出的有效时长 ms（无清单=0）。
  int get effectiveDurationMs => manifest?.effectiveDurationMs ?? 0;
}
