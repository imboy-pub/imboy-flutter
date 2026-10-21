/// 面聊记录（talk_record）领域枚举（T08 数据层）。
///
/// 契约源：imboy docs/design/2026-10-20-face-to-face-notes/BACKEND-API.md
/// §2 逻辑表 + §3 状态机 + §8 scope 差异 + §11 补充合同。
///
/// 解析策略（对齐 WorkspaceMemberRole 宽容先例）：未知/缺失 wire 值一律
/// 降级 `unknown` 变体（不猜业务状态，UI/调用方自行决定展示），服务端
/// 未来新增枚举值不炸客户端。
library;

T _parseWire<T extends Enum>(
  List<T> values,
  String Function(T) wireOf,
  dynamic raw,
  T unknown,
) {
  final s = raw is String ? raw : (raw?.toString() ?? '');
  if (s.isEmpty) return unknown;
  for (final v in values) {
    if (wireOf(v) == s) return v;
  }
  return unknown;
}

/// 记录归属（§1/§8）：personal 不带 org/workspace；organization 必填 org。
enum TalkRecordScope {
  personal('personal'),
  organization('organization'),
  unknown('unknown');

  final String wireName;
  const TalkRecordScope(this.wireName);
  static TalkRecordScope parse(dynamic raw) => _parseWire(
    TalkRecordScope.values,
    (v) => v.wireName,
    raw,
    TalkRecordScope.unknown,
  );
}

/// 记录来源（§8）：V1 仅开放 live_recording；其余为未来扩展方向，
/// capabilities 不得宣布已支持，提交含未来值返回 422。
enum TalkRecordSourceType {
  liveRecording('live_recording'),
  importedAudio('imported_audio'),
  remoteCall('remote_call'),
  unknown('unknown');

  final String wireName;
  const TalkRecordSourceType(this.wireName);
  static TalkRecordSourceType parse(dynamic raw) => _parseWire(
    TalkRecordSourceType.values,
    (v) => v.wireName,
    raw,
    TalkRecordSourceType.unknown,
  );

  /// V1 唯一可提交值（§8 冻结）。
  static TalkRecordSourceType get v1Default =>
      TalkRecordSourceType.liveRecording;
}

/// 介质状态机（§3）：local_only → uploading → verifying → available；
/// 失败 → retryable_failed；丢段不能标 available。
enum TalkRecordMediaStatus {
  localOnly('local_only'),
  uploading('uploading'),
  verifying('verifying'),
  assembling('assembling'),
  available('available'),
  retryableFailed('retryable_failed'),
  unknown('unknown');

  final String wireName;
  const TalkRecordMediaStatus(this.wireName);
  static TalkRecordMediaStatus parse(dynamic raw) => _parseWire(
    TalkRecordMediaStatus.values,
    (v) => v.wireName,
    raw,
    TalkRecordMediaStatus.unknown,
  );
}

/// 转写/摘要处理状态（§3）：not_requested/unavailable/queued/running/
/// ready/failed；转写另有 no_speech（§11.2），摘要复用本枚举宽松解析。
enum TalkRecordProcessingStatus {
  notRequested('not_requested'),
  unavailable('unavailable'),
  queued('queued'),
  running('running'),
  ready('ready'),
  failed('failed'),
  noSpeech('no_speech'),
  unknown('unknown');

  final String wireName;
  const TalkRecordProcessingStatus(this.wireName);
  static TalkRecordProcessingStatus parse(dynamic raw) => _parseWire(
    TalkRecordProcessingStatus.values,
    (v) => v.wireName,
    raw,
    TalkRecordProcessingStatus.unknown,
  );
}

/// 处理模式（§2）：record_only 不排队模型任务；会后升级走 processing-requests。
enum TalkRecordProcessingMode {
  recordOnly('record_only'),
  transcribe('transcribe'),
  summarize('summarize'),
  unknown('unknown');

  final String wireName;
  const TalkRecordProcessingMode(this.wireName);
  static TalkRecordProcessingMode parse(dynamic raw) => _parseWire(
    TalkRecordProcessingMode.values,
    (v) => v.wireName,
    raw,
    TalkRecordProcessingMode.unknown,
  );
}

/// 采集状态机（§3）：draft → recording ↔ paused → ended；中断 →
/// interrupted → paused（用户确认恢复）或 → ended。
enum TalkRecordCaptureStatus {
  draft('draft'),
  recording('recording'),
  paused('paused'),
  interrupted('interrupted'),
  ended('ended'),
  unknown('unknown');

  final String wireName;
  const TalkRecordCaptureStatus(this.wireName);
  static TalkRecordCaptureStatus parse(dynamic raw) => _parseWire(
    TalkRecordCaptureStatus.values,
    (v) => v.wireName,
    raw,
    TalkRecordCaptureStatus.unknown,
  );
}

/// 清理状态（§2/§10.4）：删除后 pending；blocked_* 表示留存/hold 阻止；
/// retained_by_other_reference 表示资产仍被合法引用；failed 不得伪报 complete。
enum TalkRecordCleanupStatus {
  none('none'),
  pending('pending'),
  blockedRetention('blocked_retention'),
  blockedHold('blocked_hold'),
  retainedByOtherReference('retained_by_other_reference'),
  failed('failed'),
  complete('complete'),
  unknown('unknown');

  final String wireName;
  const TalkRecordCleanupStatus(this.wireName);
  static TalkRecordCleanupStatus parse(dynamic raw) => _parseWire(
    TalkRecordCleanupStatus.values,
    (v) => v.wireName,
    raw,
    TalkRecordCleanupStatus.unknown,
  );
}

/// 授权角色（§1）：viewer 读/回听；editor 另可校对；owner 在主表不在 grant。
enum TalkRecordGrantRole {
  viewer('viewer'),
  editor('editor'),
  unknown('unknown');

  final String wireName;
  const TalkRecordGrantRole(this.wireName);
  static TalkRecordGrantRole parse(dynamic raw) => _parseWire(
    TalkRecordGrantRole.values,
    (v) => v.wireName,
    raw,
    TalkRecordGrantRole.unknown,
  );

  String toWire() => this == TalkRecordGrantRole.unknown
      ? TalkRecordGrantRole.viewer.wireName
      : wireName;
}

/// 任务类型（§2 talk_record_job.kind）。
enum TalkRecordJobKind {
  assemble('assemble'),
  transcribe('transcribe'),
  summarize('summarize'),
  export('export'),
  purge('purge'),
  unknown('unknown');

  final String wireName;
  const TalkRecordJobKind(this.wireName);
  static TalkRecordJobKind parse(dynamic raw) => _parseWire(
    TalkRecordJobKind.values,
    (v) => v.wireName,
    raw,
    TalkRecordJobKind.unknown,
  );
}

/// 任务状态（§2）：retry_wait 表示可退避重试；cancelled 不可重试。
enum TalkRecordJobState {
  queued('queued'),
  running('running'),
  retryWait('retry_wait'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  unknown('unknown');

  final String wireName;
  const TalkRecordJobState(this.wireName);
  static TalkRecordJobState parse(dynamic raw) => _parseWire(
    TalkRecordJobState.values,
    (v) => v.wireName,
    raw,
    TalkRecordJobState.unknown,
  );

  /// 仅 failed（含退避后）可触发 retry；succeeded 重放由幂等键返回首果。
  bool get retryable => this == TalkRecordJobState.failed;
}

/// 原文片段来源（§2 segment.origin）：model 原始转写 / human 人工修订。
enum TalkRecordSegmentOrigin {
  model('model'),
  human('human'),
  unknown('unknown');

  final String wireName;
  const TalkRecordSegmentOrigin(this.wireName);
  static TalkRecordSegmentOrigin parse(dynamic raw) => _parseWire(
    TalkRecordSegmentOrigin.values,
    (v) => v.wireName,
    raw,
    TalkRecordSegmentOrigin.unknown,
  );
}

/// 摘要状态（§2）：正文校对后旧摘要标 stale；confirm 由人显式确认。
enum TalkRecordSummaryStatus {
  draft('draft'),
  confirmed('confirmed'),
  stale('stale'),
  unknown('unknown');

  final String wireName;
  const TalkRecordSummaryStatus(this.wireName);
  static TalkRecordSummaryStatus parse(dynamic raw) => _parseWire(
    TalkRecordSummaryStatus.values,
    (v) => v.wireName,
    raw,
    TalkRecordSummaryStatus.unknown,
  );
}

/// 说话人身份来源（§2）：voice_suggestion 为后续可选能力，自动建议
/// 不得直接变本人确认（§1）。
enum TalkRecordSpeakerIdentitySource {
  anonymous('anonymous'),
  selfClaim('self_claim'),
  manual('manual'),
  voiceSuggestion('voice_suggestion'),
  unknown('unknown');

  final String wireName;
  const TalkRecordSpeakerIdentitySource(this.wireName);
  static TalkRecordSpeakerIdentitySource parse(dynamic raw) => _parseWire(
    TalkRecordSpeakerIdentitySource.values,
    (v) => v.wireName,
    raw,
    TalkRecordSpeakerIdentitySource.unknown,
  );
}

/// 采集事件（§4 events 端点 event 字段）。
enum TalkRecordCaptureEventKind {
  start('start'),
  pause('pause'),
  resume('resume'),
  interrupt('interrupt'),
  end('end'),
  unknown('unknown');

  final String wireName;
  const TalkRecordCaptureEventKind(this.wireName);
  static TalkRecordCaptureEventKind parse(dynamic raw) => _parseWire(
    TalkRecordCaptureEventKind.values,
    (v) => v.wireName,
    raw,
    TalkRecordCaptureEventKind.unknown,
  );
}

/// 导出格式（§2 talk_record_export.format）：V1 冻结 txt/md。
enum TalkRecordExportFormat {
  txt('txt'),
  md('md'),
  unknown('unknown');

  final String wireName;
  const TalkRecordExportFormat(this.wireName);
  static TalkRecordExportFormat parse(dynamic raw) => _parseWire(
    TalkRecordExportFormat.values,
    (v) => v.wireName,
    raw,
    TalkRecordExportFormat.unknown,
  );
}

/// 列表过滤（§4 GET /）：all/owned/shared；cursor 绑定筛选与调用者。
enum TalkRecordListFilter {
  all('all'),
  owned('owned'),
  shared('shared'),
  unknown('unknown');

  final String wireName;
  const TalkRecordListFilter(this.wireName);
  static TalkRecordListFilter parse(dynamic raw) => _parseWire(
    TalkRecordListFilter.values,
    (v) => v.wireName,
    raw,
    TalkRecordListFilter.unknown,
  );

  String toWire() => this == TalkRecordListFilter.unknown
      ? TalkRecordListFilter.all.wireName
      : wireName;
}
