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
}
