/// R20-A 可注入时钟：把两种时间语义显式分开。
///
/// - **估计服务器 instant**（[AppClock.nowMs]）：墙钟 + NTP/sv_ts 偏移
///   （[NtpHelper] 语义的薄封装）。用于业务时间戳与**持久化 deadline**
///   （epoch 合同：重启后仍可比较）。
/// - **单调经过时长**（[AppClock.mark] / [AppClock.elapsedMs]）：与墙钟
///   完全解耦（Stopwatch 语义），用于冷却、重试间隔、耗时统计等
///   **过程间隔**——墙钟被用户/NTP 回拨或前跳 ±1 小时都不会冻结冷却，
///   也不会造成忙循环。mark 仅进程内有效，**禁止持久化**；跨重启的
///   截止时间一律存 epoch 毫秒（nowMs 通道）。
///
/// 测试通过替换全局 [appClock] 注入 fake（可控墙钟 + 可推进单调轴），
/// 生产默认实现 [SystemAppClock] 走 NtpHelper + Stopwatch。
library;

import 'package:imboy/component/helper/ntp.dart';

/// 单调时刻标记（进程内有效，禁止持久化）。
abstract class AppClockMark {
  const AppClockMark();
}

class _StopwatchMark extends AppClockMark {
  _StopwatchMark() : stopwatch = Stopwatch()..start();
  final Stopwatch stopwatch;
}

abstract class AppClock {
  const AppClock();

  /// 估计的服务器当前时间（epoch 毫秒，墙钟 + 已校准偏移）。
  int nowMs();

  /// [nowMs] 的 DateTime 形态（本地时区表示）。
  DateTime nowDateTime() => DateTime.fromMillisecondsSinceEpoch(nowMs());

  /// 打一个单调时刻标记。
  AppClockMark mark();

  /// 自 [mark] 起经过的单调毫秒数；墙钟调整不影响该值。
  int elapsedMs(AppClockMark mark);
}

/// 生产默认实现：instant 走 NtpHelper（墙钟 + offset），单调走 Stopwatch。
class SystemAppClock extends AppClock {
  const SystemAppClock();

  @override
  int nowMs() => NtpHelper.millisecond();

  @override
  AppClockMark mark() => _StopwatchMark();

  @override
  int elapsedMs(AppClockMark mark) =>
      (mark as _StopwatchMark).stopwatch.elapsedMilliseconds;
}

/// 全局默认时钟。生产代码经它取时间；测试用 fake 整体替换后须还原。
AppClock appClock = const SystemAppClock();

/// R20-A：单调冷却/退避窗口（进程内节流专用）。
///
/// 替代 `DateTime.now().add(cooldown)` 式的墙钟 deadline：墙钟回拨 1 小时
/// 不会把 30s 冷却拉长成 1 小时，墙钟前跳也不会立刻放行。
class MonotonicCooldown {
  MonotonicCooldown([AppClock? clock]) : _clock = clock ?? appClock;

  final AppClock _clock;
  AppClockMark? _startMark;
  Duration _duration = Duration.zero;

  /// 启动一个时长 [duration] 的冷却窗口（覆盖旧窗口）。
  void startFor(Duration duration) {
    _duration = duration;
    _startMark = _clock.mark();
  }

  /// 清除冷却窗口（立即放行）。
  void clear() {
    _startMark = null;
    _duration = Duration.zero;
  }

  /// 剩余毫秒；0 表示不在冷却期。
  int get remainingMs {
    final mark = _startMark;
    if (mark == null) return 0;
    final elapsed = _clock.elapsedMs(mark);
    final remain = _duration.inMilliseconds - elapsed;
    return remain > 0 ? remain : 0;
  }

  bool get active => remainingMs > 0;
}
