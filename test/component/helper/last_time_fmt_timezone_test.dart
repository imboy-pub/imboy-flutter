import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:imboy/component/helper/datetime.dart';

/// BUG#84：`lastTimeFmt` 曾用 `millisecondToDateTime(ms, isUtc: true)` 构造
/// DateTime，而 `DateFormat.format` 是按 DateTime 自身的 isUtc 输出字段值的 ——
/// 于是 UTC 时间被当成本地时间摆给用户看。
///
/// 真机实证（东八区）：同一条设备记录，
/// 列表页 `lastTimeFmt` 显示 `08-01 16:13`，详情页本地构造显示
/// `2026-08-02 00:13:36`，**差恰好 8 小时**。
///
/// 影响 13 处调用点（会话列表、消息搜索、反馈、收藏、设备管理…），
/// 凡是退化成绝对时间格式的地方全部偏一个时区。
void main() {
  group('DateTimeHelper.lastTimeFmt 时区', () {
    // 取足够久远的时刻，确保走绝对格式分支而非「N小时前」。
    const ms = 1600000000000; // 2020-09-13T12:26:40Z

    test('绝对时间按本地时区渲染，与 DateTime.fromMillisecondsSinceEpoch 一致', () {
      final expected = DateFormat(
        'y-MM-dd HH:mm',
      ).format(DateTime.fromMillisecondsSinceEpoch(ms));

      expect(DateTimeHelper.lastTimeFmt(ms), expected);
    });

    test('非 UTC 时区下不得等于 UTC 字段值（这正是 BUG#84 的表现）', () {
      final utcRendered = DateFormat(
        'y-MM-dd HH:mm',
      ).format(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
      final localRendered = DateTimeHelper.lastTimeFmt(ms);

      // CI 若跑在 UTC 机器上两者本就相同，此时该断言无意义，跳过。
      if (DateTime.now().timeZoneOffset == Duration.zero) {
        return;
      }
      expect(
        localRendered,
        isNot(utcRendered),
        reason: '本地时区非 UTC 时，渲染结果不应等于 UTC 字段值',
      );
    });

    test('millisFmtOrEmpty 走同一条路径，一并守住', () {
      expect(
        DateTimeHelper.millisFmtOrEmpty(ms),
        DateTimeHelper.lastTimeFmt(ms),
      );
    });
  });
}
