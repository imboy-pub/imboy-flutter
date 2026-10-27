import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/schedule/group_schedule_ui.dart';

/// 后端 group_schedule.status 只有 1（有效）/4（取消），
/// 进行中/已结束完全靠客户端按 start/end 推导 —— 这里锁住四态判定，
/// 防止回归成"三天前结束的日程永远显示进行中并催报名"。
void main() {
  final nowSec = 1791517000; // 固定"当前时间"，秒级
  GroupScheduleTimeState resolve({
    required int status,
    required int startAtSec,
    required int endAtSec,
  }) => resolveScheduleTimeState(
    status: status,
    startAtSec: startAtSec,
    endAtSec: endAtSec,
    nowSec: nowSec,
  );

  group('resolveScheduleTimeState', () {
    test('已取消优先于一切时间态', () {
      expect(
        resolve(status: 4, startAtSec: nowSec - 3600, endAtSec: nowSec - 60),
        GroupScheduleTimeState.cancelled,
      );
      expect(
        resolve(status: 4, startAtSec: nowSec + 3600, endAtSec: nowSec + 7200),
        GroupScheduleTimeState.cancelled,
      );
    });

    test('开始前为未开始', () {
      expect(
        resolve(status: 1, startAtSec: nowSec + 60, endAtSec: nowSec + 3660),
        GroupScheduleTimeState.notStarted,
      );
    });

    test('开始后未结束为进行中', () {
      expect(
        resolve(status: 1, startAtSec: nowSec - 60, endAtSec: nowSec + 60),
        GroupScheduleTimeState.inProgress,
      );
      // 缺结束时间（end=0）时不误判为已结束，按进行中处理。
      expect(
        resolve(status: 1, startAtSec: nowSec - 60, endAtSec: 0),
        GroupScheduleTimeState.inProgress,
      );
    });

    test('结束后为已结束，不再可报名', () {
      expect(
        resolve(status: 1, startAtSec: nowSec - 7200, endAtSec: nowSec - 60),
        GroupScheduleTimeState.ended,
      );
    });
  });

  // ─── R13：列表分组按本地日历日边界（DST 安全）─────────────────────────────
  group('resolveScheduleListSection (R13 calendar boundaries)', () {
    // 用本地日历字段构造，断言与运行时区无关；
    // FL-TZ 四时区进程中 America/New_York 的 DST 用例额外钉住日历构造。
    ScheduleListSection sectionOf(DateTime start, DateTime now) =>
        resolveScheduleListSection(start, now);

    test('R13-5 当天最后一刻属今天，次日 00:00 起属本周（无重漏）', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(
        sectionOf(DateTime(2026, 10, 23, 23, 59, 59, 999), now),
        ScheduleListSection.today,
      );
      expect(
        sectionOf(DateTime(2026, 10, 24, 0, 0), now),
        ScheduleListSection.tomorrowToWeek,
      );
    });

    test('本周窗口末日全天属本周，第 7 天 00:00 起属更晚', () {
      // 窗口 = [明天 00:00, 今天+7 日历日 00:00)：now=10-23 → 10-24..10-29。
      final now = DateTime(2026, 10, 23, 12);
      expect(
        sectionOf(DateTime(2026, 10, 29, 23, 59, 59), now),
        ScheduleListSection.tomorrowToWeek,
      );
      expect(
        sectionOf(DateTime(2026, 10, 30, 0, 0), now),
        ScheduleListSection.later,
      );
    });

    test('过去时间保持归入今天组（既有语义不因 R13 改变）', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(
        sectionOf(DateTime(2026, 10, 20, 9), now),
        ScheduleListSection.today,
      );
    });

    test('R13-3 跨年日界按日历日计', () {
      final now = DateTime(2026, 12, 31, 12);
      expect(
        sectionOf(DateTime(2027, 1, 1, 0, 30), now),
        ScheduleListSection.tomorrowToWeek,
      );
      expect(
        sectionOf(DateTime(2027, 1, 8, 0, 0), now),
        ScheduleListSection.later,
      );
    });

    test('R13-3 闰日边界（2024-02-29）按日历日计', () {
      final now = DateTime(2024, 2, 29, 12);
      expect(
        sectionOf(DateTime(2024, 3, 1, 0, 0), now),
        ScheduleListSection.tomorrowToWeek,
      );
      expect(
        sectionOf(DateTime(2024, 3, 8, 0, 0), now),
        ScheduleListSection.later,
      );
    });

    test('R13-4 DST 春季前跳日：次日 00:30 不因 23 小时日误入今天组', () {
      // America/New_York 2026-03-08 春季前跳（当天只有 23 小时）。
      // 旧实现 todayStart.add(24h) 会把次日边界推到 03-09 01:00，
      // 03-09 00:30 的日程被误入"今天"；日历构造在四个 TZ 进程下都正确。
      final now = DateTime(2026, 3, 8, 12);
      expect(
        sectionOf(DateTime(2026, 3, 9, 0, 30), now),
        ScheduleListSection.tomorrowToWeek,
      );
      // 春季前跳日当天本身仍完整归今天。
      expect(
        sectionOf(DateTime(2026, 3, 8, 23, 59), now),
        ScheduleListSection.today,
      );
    });

    test('R13-4 DST 秋季回拨日：第 7 天边界仍为日历日', () {
      // America/New_York 2026-11-01 秋季回拨（25 小时日）。
      final now = DateTime(2026, 10, 31, 12);
      expect(
        sectionOf(DateTime(2026, 11, 7, 0, 0), now),
        ScheduleListSection.later,
      );
      expect(
        sectionOf(DateTime(2026, 11, 6, 23, 59), now),
        ScheduleListSection.tomorrowToWeek,
      );
    });
  });
}
