/// Capture states and physical-stop fencing, shared by service and UI.
library;

import 'talk_record_manifest.dart';

/// 采集阶段（UI 状态机输入）。
enum TalkRecordRecorderPhase {
  /// 未开始/已清理。
  idle,

  /// 录制中（计时累计）。
  recording,

  /// 用户暂停（不计时）。
  paused,

  /// 系统中断（来电/抢占；恢复必须用户点击）。
  interrupted,

  /// 已结束（含限额到限结束）。
  ended,

  /// 不可恢复失败（引擎打开失败等）。
  failed,
}

extension TalkRecordRecorderPhaseX on TalkRecordRecorderPhase {
  bool get isActive =>
      this == TalkRecordRecorderPhase.recording ||
      this == TalkRecordRecorderPhase.paused ||
      this == TalkRecordRecorderPhase.interrupted;
}

/// 结束原因。
enum TalkRecordEndReason {
  user('user'),
  durationLimit('duration_limit'),
  bytesLimit('bytes_limit'),
  diskFull('disk_full'),
  writeFailure('write_failure'),
  engineFailure('engine_failure');

  final String wireName;
  const TalkRecordEndReason(this.wireName);
}

/// 接近限额提示。
enum TalkRecordLimitWarn { none, duration, bytes }

/// 采集会话快照（widget 单一数据源）。
class TalkRecordRecorderSnapshot {
  final TalkRecordRecorderPhase phase;
  final String sessionId;
  final int effectiveDurationMs;
  final int segmentCount;
  final int sealedCipherBytes;

  /// 当前段实时电平（平台不支持时 null）。
  final double? decibels;
  final int markCount;
  final String? interruptReason;
  final TalkRecordLimitWarn limitWarn;
  final TalkRecordEndReason? endReason;

  /// 结束时是否干净落盘（写入失败中止 → false，UI 不得显示保存成功）。
  final bool savedCleanly;

  /// Platform close did not confirm physical microphone release.
  final bool stopUnconfirmed;

  const TalkRecordRecorderSnapshot({
    this.phase = TalkRecordRecorderPhase.idle,
    this.sessionId = '',
    this.effectiveDurationMs = 0,
    this.segmentCount = 0,
    this.sealedCipherBytes = 0,
    this.decibels,
    this.markCount = 0,
    this.interruptReason,
    this.limitWarn = TalkRecordLimitWarn.none,
    this.endReason,
    this.savedCleanly = true,
    this.stopUnconfirmed = false,
  });

  bool get isActive =>
      phase == TalkRecordRecorderPhase.recording ||
      phase == TalkRecordRecorderPhase.paused ||
      phase == TalkRecordRecorderPhase.interrupted;
}

/// 结束产物。
class TalkRecordSessionResult {
  final String sessionId;
  final String recordLocalId;
  final String clientRecordingId;
  final TalkRecordEndReason endReason;
  final bool savedCleanly;

  /// Platform close did not confirm physical microphone release.
  final bool stopUnconfirmed;
  final int effectiveDurationMs;
  final int segmentCount;
  final int totalCipherBytes;
  final TalkRecordManifest manifest;

  const TalkRecordSessionResult({
    required this.sessionId,
    required this.recordLocalId,
    required this.clientRecordingId,
    required this.endReason,
    required this.savedCleanly,
    this.stopUnconfirmed = false,
    required this.effectiveDurationMs,
    required this.segmentCount,
    required this.totalCipherBytes,
    required this.manifest,
  });
}

/// A safe-to-display code; it contains no prior account or recording content.
class TalkRecordStopUnconfirmedException implements Exception {
  const TalkRecordStopUnconfirmedException();
  @override
  String toString() => 'microphone_stop_unconfirmed';
}

/// 单 capture 规则冲突（重复 start）。
class TalkRecordCaptureBusyException implements Exception {
  final String activeRecordLocalId;
  TalkRecordCaptureBusyException(this.activeRecordLocalId);
  @override
  String toString() =>
      'TalkRecordCaptureBusyException(active=$activeRecordLocalId)';
}

/// 启动被拒（磁盘不足等）。
class TalkRecordStartException implements Exception {
  final String reason;
  final Object? cause;
  TalkRecordStartException(this.reason, {this.cause});
  @override
  String toString() => 'TalkRecordStartException: $reason';
}

/// 进程级单 capture 租约：同一时刻至多一条活跃本机采集
/// （§3 单写入者 + §7 并发 1；同记录与跨记录重复 start 均拒绝）。
class TalkRecordCaptureLease {
  static String? _activeRecordLocalId;

  static bool get isBusy => _activeRecordLocalId != null;
  static String? get activeRecordLocalId => _activeRecordLocalId;

  static void take(String recordLocalId) {
    if (isBusy) {
      throw TalkRecordCaptureBusyException(_activeRecordLocalId!);
    }
    _activeRecordLocalId = recordLocalId;
  }

  static void release(String recordLocalId) {
    if (_activeRecordLocalId == recordLocalId) {
      _activeRecordLocalId = null;
    }
  }

  /// 测试隔离用。
  static void resetForTest() => _activeRecordLocalId = null;
}
