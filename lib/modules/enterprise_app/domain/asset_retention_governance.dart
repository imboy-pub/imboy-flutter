/// 企业附件留存治理的可见状态（FULL-05 / INT-22）。
///
/// 逐条对齐后端（migration 00000140 声明式不变量 + `enterprise_asset_retention_logic`）：
///
/// | 不变量 | 语义 |
/// |---|---|
/// | 留存只可延长 | `retention_until` 只增不减；缩短 → `invalid_request` |
/// | hold 生效中禁止 purge | detail `purge_blocked_by_hold` |
/// | 留存未到期禁止 purge | detail `retention_not_elapsed` |
/// | purged 终态不可回退 | detail `already_purged`；终态上再 hold 亦拒 |
/// | 治理行禁删 | DB 触发器 23514：**任何路径都删不掉治理记录** |
///
/// UI 的职责（本文件的落点）：
/// - 如实展示留存/hold/purge 三态（不得把 held 显示成 none、把 purged 显示成 live）；
/// - **不可删除提示**：[AssetRetentionRecord.isDeletableByClient] 恒 false，
///   UI 据此展示「治理记录不可删除」而不是画一个假的删除按钮；
/// - purge 被挡时给出**原因**（hold / 未到期 / 已清除），不是一个笼统的失败。
///
/// 纯 Dart（零 Flutter / 零 IO）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// hold 状态（后端 `hold_state`）。
enum AssetHoldState {
  none('none', 'holdNone'),
  held('held', 'holdHeld');

  final String wireName;
  final String labelKey;

  const AssetHoldState(this.wireName, this.labelKey);

  static AssetHoldState parse(dynamic raw) {
    final String s = parseModelString(raw);
    return s == held.wireName ? held : none;
  }
}

/// purge 状态（后端 `purge_state`）；purged 是**终态**。
enum AssetPurgeState {
  live('live', 'purgeLive'),
  purged('purged', 'purgePurged');

  final String wireName;
  final String labelKey;

  const AssetPurgeState(this.wireName, this.labelKey);

  static AssetPurgeState parse(dynamic raw) {
    final String s = parseModelString(raw);
    return s == purged.wireName ? purged : live;
  }
}

/// 治理操作（后端 `op` 白名单）。
enum AssetGovernanceOp {
  setRetention('set_retention'),
  hold('hold'),
  releaseHold('release_hold'),
  purge('purge');

  final String wireName;

  const AssetGovernanceOp(this.wireName);

  static AssetGovernanceOp? tryParse(dynamic raw) {
    final String s = parseModelString(raw);
    for (final AssetGovernanceOp op in AssetGovernanceOp.values) {
      if (op.wireName == s) return op;
    }
    return null;
  }
}

/// purge 被挡的原因（后端 detail → UI 可读原因）。
enum PurgeBlockedReason {
  /// 不在被挡状态。
  none(''),

  /// hold 生效中（detail `purge_blocked_by_hold`）。
  holdActive('purge_blocked_by_hold'),

  /// 留存窗口未到期（detail `retention_not_elapsed`）。
  retentionNotElapsed('retention_not_elapsed'),

  /// 已是 purged 终态（detail `already_purged`）。
  alreadyPurged('already_purged');

  /// 后端 detail 字面量（空串 = 非被挡）。
  final String wireDetail;

  const PurgeBlockedReason(this.wireDetail);

  static PurgeBlockedReason parseDetail(dynamic raw) {
    final String s = parseModelString(raw);
    for (final PurgeBlockedReason r in PurgeBlockedReason.values) {
      if (r.wireDetail.isNotEmpty && r.wireDetail == s) return r;
    }
    return PurgeBlockedReason.none;
  }
}

/// 附件治理记录（INT-22 响应 / 附件治理面读取的可见状态）。
class AssetRetentionRecord {
  const AssetRetentionRecord({
    required this.fileId,
    this.objectKey = '',
    this.retentionUntil = '',
    this.holdState = AssetHoldState.none,
    this.holdReason = '',
    this.purgeState = AssetPurgeState.live,
    this.purged = false,
  });

  final EntityId fileId;

  /// 对象键（治理面可见；**不进入 UI 渲染**——后端契约把它作为内部标识返回）。
  final String objectKey;

  /// 留存截止时间（服务端时间字符串，UI 原样展示，不做时区换算）。
  final String retentionUntil;

  final AssetHoldState holdState;

  /// hold 事由（仅 held 时非空；后端 1..200）。
  final String holdReason;

  final AssetPurgeState purgeState;

  /// `purged` 布尔（响应里与 purge_state 同源，保留以对账）。
  final bool purged;

  /// 是否处于冻结。
  bool get isHeld => holdState == AssetHoldState.held;

  /// 是否已清除（终态）。
  bool get isPurged => purgeState == AssetPurgeState.purged || purged;

  /// **恒 false**：治理记录任何路径都不可删除（DB 触发器 23514）。
  ///
  /// UI 据此**不提供**删除入口，只展示「不可删除」提示——不是权限不足，
  /// 是设计上不存在该操作。
  bool get isDeletableByClient => false;

  /// 当前状态下 purge 被挡的原因（none = 允许清除）；基准时间取当前时钟。
  PurgeBlockedReason get purgeBlockedReason =>
      purgeBlockedReasonAt(DateTime.now());

  /// 以 [now] 为基准的 purge 被挡原因（判定序与后端一致：终态 → hold → 未到期）。
  PurgeBlockedReason purgeBlockedReasonAt(DateTime now) {
    if (isPurged) return PurgeBlockedReason.alreadyPurged;
    if (isHeld) return PurgeBlockedReason.holdActive;
    if (!isRetentionElapsedAt(now)) {
      return PurgeBlockedReason.retentionNotElapsed;
    }
    return PurgeBlockedReason.none;
  }

  /// 留存是否已到期（按 [now] 与 [retentionUntil] 的字符串时间比较）。
  ///
  /// 时间解析容错：解析不出时**视为未到期**（fail-closed，不给出可清除的
  /// 错误暗示）。
  bool isRetentionElapsedAt(DateTime now) {
    if (retentionUntil.isEmpty) return false;
    final DateTime? until = DateTime.tryParse(retentionUntil);
    if (until == null) return false;
    return !until.isAfter(now);
  }

  /// 默认取「当前时间」的到期判定（UI 便利入口）。
  bool get isRetentionElapsed => isRetentionElapsedAt(DateTime.now());

  /// 治理面必须保留的事实字段（测试以键集合钉死）。
  Map<String, Object?> get traceableFields => <String, Object?>{
    'file_id': fileId,
    'retention_until': retentionUntil,
    'hold_state': holdState.wireName,
    'hold_reason': holdReason,
    'purge_state': purgeState.wireName,
  };

  factory AssetRetentionRecord.fromJson(Map<String, dynamic> json) {
    return AssetRetentionRecord(
      fileId: entityIdOf(json['file_id']),
      objectKey: parseModelString(json['object_key']),
      retentionUntil: parseModelString(json['retention_until']),
      holdState: AssetHoldState.parse(json['hold_state']),
      holdReason: parseModelString(json['hold_reason']),
      purgeState: AssetPurgeState.parse(json['purge_state']),
      purged: parseModelBool(json['purged']),
    );
  }
}

/// 治理操作结果（INT-22 响应）。
class AssetGovernanceOutcome {
  const AssetGovernanceOutcome({required this.op, required this.record});

  final AssetGovernanceOp op;
  final AssetRetentionRecord record;

  factory AssetGovernanceOutcome.fromJson(Map<String, dynamic> json) {
    return AssetGovernanceOutcome(
      op:
          AssetGovernanceOp.tryParse(json['op']) ??
          AssetGovernanceOp.setRetention,
      record: AssetRetentionRecord.fromJson(json),
    );
  }
}

/// 留存窗口上限（后端 `?MAX_RETENTION_DAYS`，CA 10 年）。
const int kMaxRetentionDays = 3650;

/// hold 事由上限（后端 `?MAX_HOLD_REASON_LEN`）。
const int kMaxHoldReasonLength = 200;

/// `set_retention` 的 days 校验（1..[kMaxRetentionDays]；越界拒绝）。
String? validateRetentionDays(dynamic raw) {
  final int? days = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (days == null) return 'retention_days_not_integer';
  if (days < 1) return 'retention_days_below_min';
  if (days > kMaxRetentionDays) return 'retention_days_over_max';
  return null;
}

/// `hold` 的 reason 校验（1..[kMaxHoldReasonLength]；空理由拒绝）。
String? validateHoldReason(dynamic raw) {
  final String reason = parseModelString(raw);
  if (reason.isEmpty) return 'hold_reason_required';
  if (reason.length > kMaxHoldReasonLength) return 'hold_reason_too_long';
  return null;
}
