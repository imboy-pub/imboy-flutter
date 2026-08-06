import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/fallback_rotation_policy.dart';

/// E2EE-062：fallback key 周期轮换决策。
///
/// 守护：
/// 1. 【对照组】刚轮换过 → 不再轮换。它红说明判据根本没在看时间；
/// 2. 超过周期 → 必须轮换（本项要消除的"无限期沿用同一把 key"）；
/// 3. **从未记录过 → 轮换**（升级上来的老账号正处于这个状态，
///    "拿不准就不换"会让它们继续无限期沿用同一把 key）；
/// 4. 恰好等于周期 → 轮换（边界取"到点即换"，宁早勿晚）；
/// 5. 时间戳在未来（时钟回拨 / 数据损坏）→ **轮换**，不得因异常值永久卡住。
void main() {
  const day = Duration(days: 1);
  final now = DateTime(2026, 7, 29).millisecondsSinceEpoch;

  test('对照组：刚轮换过 → 不轮换', () {
    expect(
      shouldRotateFallbackKey(lastRotatedAtMs: now, nowMs: now),
      isFalse,
      reason: '对照组红 = 判据没在看时间，后面几条的绿都说明不了什么',
    );
    expect(
      shouldRotateFallbackKey(
        lastRotatedAtMs: now - day.inMilliseconds,
        nowMs: now,
      ),
      isFalse,
    );
  });

  test('超过周期 → 轮换', () {
    expect(
      shouldRotateFallbackKey(
        lastRotatedAtMs: now - (day.inMilliseconds * 8),
        nowMs: now,
      ),
      isTrue,
    );
  });

  test('从未记录过 → 轮换（升级上来的老账号正是这个状态）', () {
    expect(
      shouldRotateFallbackKey(lastRotatedAtMs: null, nowMs: now),
      isTrue,
      reason: '"拿不准就不换"会让老账号继续无限期沿用同一把 key',
    );
  });

  test('恰好等于周期 → 轮换（到点即换，宁早勿晚）', () {
    expect(
      shouldRotateFallbackKey(
        lastRotatedAtMs: now - kFallbackRotationInterval.inMilliseconds,
        nowMs: now,
      ),
      isTrue,
    );
  });

  test('时间戳在未来（时钟回拨/数据损坏）→ 轮换，不得永久卡住', () {
    expect(
      shouldRotateFallbackKey(
        lastRotatedAtMs: now + (day.inMilliseconds * 30),
        nowMs: now,
      ),
      isTrue,
      reason: '异常值若判成"刚轮换过"，该设备将永远不再轮换',
    );
  });
}
