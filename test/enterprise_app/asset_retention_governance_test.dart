/// FULL-05 — 附件留存治理测试（能力项 4 / INT-22）。
///
/// 钉住的语义来自 migration 00000140 的声明式不变量：
/// 留存只可延长、hold 生效中禁止 purge、留存未到期禁止 purge、
/// purged 终态不可回退、**治理记录不可删除**。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_app/public.dart';

DateTime t0 = DateTime.utc(2026, 9, 22);

AssetRetentionRecord record({
  String retentionUntil = '2026-10-01T00:00:00Z',
  AssetHoldState hold = AssetHoldState.none,
  String holdReason = '',
  AssetPurgeState purge = AssetPurgeState.live,
  bool purged = false,
}) => AssetRetentionRecord(
  fileId: '8801',
  objectKey: 'enterprise/objects/8801',
  retentionUntil: retentionUntil,
  holdState: hold,
  holdReason: holdReason,
  purgeState: purge,
  purged: purged,
);

void main() {
  group('三态解析（绝不把 held 显示成 none / purged 显示成 live）', () {
    test('hold_state / purge_state 逐字解析', () {
      final AssetRetentionRecord r = AssetRetentionRecord.fromJson(
        <String, dynamic>{
          'file_id': 8801,
          'object_key': 'k',
          'retention_until': '2026-10-01T00:00:00Z',
          'hold_state': 'held',
          'hold_reason': '诉讼保全',
          'purge_state': 'purged',
          'purged': true,
        },
      );
      expect(r.holdState, AssetHoldState.held);
      expect(r.isHeld, isTrue);
      expect(r.holdReason, '诉讼保全');
      expect(r.purgeState, AssetPurgeState.purged);
      expect(r.isPurged, isTrue);
    });

    test('未知取值 fail-safe 到安全侧（none / live）', () {
      final AssetRetentionStateProbe probe = AssetRetentionStateProbe.of(
        <String, dynamic>{'hold_state': 'weird', 'purge_state': 'weird'},
      );
      expect(probe.hold, AssetHoldState.none);
      expect(probe.purge, AssetPurgeState.live);
    });

    test('不可删除恒真（设计上不存在该操作）', () {
      expect(record().isDeletableByClient, isFalse);
      expect(record(hold: AssetHoldState.held).isDeletableByClient, isFalse);
      expect(
        record(purge: AssetPurgeState.purged).isDeletableByClient,
        isFalse,
      );
    });
  });

  group('purge 被挡原因（判定序：终态 → hold → 未到期）', () {
    test('未到期 → retentionNotElapsed', () {
      final AssetRetentionRecord r = record(
        retentionUntil: '2026-10-01T00:00:00Z',
      );
      expect(
        r.purgeBlockedReasonAt(t0),
        PurgeBlockedReason.retentionNotElapsed,
      );
    });

    test('hold 生效中 → holdActive（即便留存已过期）', () {
      final AssetRetentionRecord r = record(
        retentionUntil: '2026-01-01T00:00:00Z',
        hold: AssetHoldState.held,
        holdReason: '合规调查',
      );
      expect(r.purgeBlockedReasonAt(t0), PurgeBlockedReason.holdActive);
    });

    test('purged 终态优先于一切 → alreadyPurged', () {
      final AssetRetentionRecord r = record(
        retentionUntil: '2026-01-01T00:00:00Z',
        hold: AssetHoldState.held,
        purge: AssetPurgeState.purged,
        purged: true,
      );
      expect(r.purgeBlockedReasonAt(t0), PurgeBlockedReason.alreadyPurged);
    });

    test('hold 释放 + 留存到期 → none（允许清除）', () {
      final AssetRetentionRecord r = record(
        retentionUntil: '2026-01-01T00:00:00Z',
        hold: AssetHoldState.none,
      );
      expect(r.purgeBlockedReasonAt(t0), PurgeBlockedReason.none);
    });

    test('时间解析不出 → 视为未到期（fail-closed）', () {
      expect(
        record(retentionUntil: 'not-a-time').purgeBlockedReasonAt(t0),
        PurgeBlockedReason.retentionNotElapsed,
      );
      expect(
        record(retentionUntil: '').purgeBlockedReasonAt(t0),
        PurgeBlockedReason.retentionNotElapsed,
      );
    });

    test('到期判定边界：等于 now 视为到期', () {
      final AssetRetentionRecord r = record(
        retentionUntil: t0.toIso8601String(),
      );
      expect(r.isRetentionElapsedAt(t0), isTrue);
      expect(r.purgeBlockedReasonAt(t0), PurgeBlockedReason.none);
    });
  });

  group('入参校验（与后端同规则；本地拒可省无效往返）', () {
    test('retention_days 1..3650；0 / 3651 / 非整数拒', () {
      expect(validateRetentionDays(1), isNull);
      expect(validateRetentionDays(3650), isNull);
      expect(validateRetentionDays(0), 'retention_days_below_min');
      expect(validateRetentionDays(3651), 'retention_days_over_max');
      expect(validateRetentionDays('x'), 'retention_days_not_integer');
      expect(kMaxRetentionDays, 3650);
    });

    test('hold reason 必填且 ≤200', () {
      expect(validateHoldReason('诉讼保全'), isNull);
      expect(validateHoldReason(''), 'hold_reason_required');
      expect(validateHoldReason('r' * 201), 'hold_reason_too_long');
      expect(validateHoldReason('r' * 200), isNull);
      expect(kMaxHoldReasonLength, 200);
    });

    test('op 白名单逐字对齐后端', () {
      expect(AssetGovernanceOp.setRetention.wireName, 'set_retention');
      expect(AssetGovernanceOp.hold.wireName, 'hold');
      expect(AssetGovernanceOp.releaseHold.wireName, 'release_hold');
      expect(AssetGovernanceOp.purge.wireName, 'purge');
      expect(AssetGovernanceOp.tryParse('invalid_op'), isNull);
    });

    test('被挡 detail 逐字对齐后端', () {
      expect(
        PurgeBlockedReason.parseDetail('purge_blocked_by_hold'),
        PurgeBlockedReason.holdActive,
      );
      expect(
        PurgeBlockedReason.parseDetail('retention_not_elapsed'),
        PurgeBlockedReason.retentionNotElapsed,
      );
      expect(
        PurgeBlockedReason.parseDetail('already_purged'),
        PurgeBlockedReason.alreadyPurged,
      );
      expect(
        PurgeBlockedReason.parseDetail('something_else'),
        PurgeBlockedReason.none,
      );
    });
  });

  group('治理响应与事实完整性', () {
    test('op + 记录字段解析', () {
      final AssetGovernanceOutcome out = AssetGovernanceOutcome.fromJson(
        <String, dynamic>{
          'op': 'hold',
          'file_id': 8801,
          'object_key': 'k',
          'retention_until': '2026-10-01T00:00:00Z',
          'hold_state': 'held',
          'purge_state': 'live',
          'purged': false,
        },
      );
      expect(out.op, AssetGovernanceOp.hold);
      expect(out.record.isHeld, isTrue);
      expect(out.record.isPurged, isFalse);
    });

    test('traceableFields 逐键齐备（object_key 不进 UI 事实集）', () {
      final Map<String, Object?> fields = record(
        hold: AssetHoldState.held,
        holdReason: '保全',
      ).traceableFields;
      expect(fields.keys.toSet(), <String>{
        'file_id',
        'retention_until',
        'hold_state',
        'hold_reason',
        'purge_state',
      });
      expect(fields['hold_state'], 'held');
      expect(fields['purge_state'], 'live');
    });

    test('未知 op 回落 set_retention（不抛；调用方按记录本身判断）', () {
      final AssetGovernanceOutcome out = AssetGovernanceOutcome.fromJson(
        <String, dynamic>{'op': 'weird', 'file_id': 1},
      );
      expect(out.op, AssetGovernanceOp.setRetention);
    });
  });
}

/// 小工具：直接探 hold/purge 的 fail-safe 解析（避免测试里再造一个 DTO）。
class AssetRetentionStateProbe {
  const AssetRetentionStateProbe({required this.hold, required this.purge});

  final AssetHoldState hold;
  final AssetPurgeState purge;

  static AssetRetentionStateProbe of(Map<String, dynamic> json) =>
      AssetRetentionStateProbe(
        hold: AssetHoldState.parse(json['hold_state']),
        purge: AssetPurgeState.parse(json['purge_state']),
      );
}
