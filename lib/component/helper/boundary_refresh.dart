/// R20-B 页面边界刷新：按「下一有效边界」调度刷新 + resume / zone 变化刷新
/// + dispose 取消 timer。
///
/// 设计要点（R20-B 合同）：
/// - **一次性 timer**：每页至多一个待决 timer，指向下一个会让可见内容变化的
///   时刻（日程开始/结束、本地午夜、相对分钟边界）；触发后由页面重算并调度
///   下一个边界——不逐消息常驻秒级 timer（R20-6）。
/// - **判定即重取**：timer 只是「显示刷新」的优化；deadline/状态的权威判定
///   一律在动作发生时用 `appClock.nowMs()` 即时重取（R20-4），timer 触发
///   偏差不影响正确性。
/// - **resume 刷新**：后台静置跨过边界后回到前台立即重算；同时核对本地时区
///   指纹（offset+名称），变化时回调方可知（R20-5 zone 变化标签同步，
///   配合 R13 日历标签重算）。
/// - **dispose 清理**：cancel timer、移除 observer，无泄漏（R20-6）。
///
/// 计时通道说明：timer 时长 = 边界墙钟时刻 − 当前墙钟（`DateTime.now()`）。
/// 墙钟被用户调整会让 timer 提前/推迟触发，但触发后的重算以即时
/// `appClock.nowMs()` 为准，最坏情况是一次多余的重建或一次被 resume 兜底的
/// 延迟刷新，不会产生忙循环或错误状态。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// 下一个本地日历午夜（日历构造，DST 日也是真实 00:00）。
DateTime nextLocalMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

/// 候选边界中最近的**未来**时刻；无未来候选返回 null。
DateTime? nextBoundary(List<DateTime?> candidates, DateTime now) {
  DateTime? best;
  for (final c in candidates) {
    if (c == null || !c.isAfter(now)) continue;
    if (best == null || c.isBefore(best)) best = c;
  }
  return best;
}

/// 可独立测试的边界调度器（页面经 [BoundaryRefreshLifecycle] 组合使用）。
class BoundaryScheduler {
  BoundaryScheduler({String Function()? zoneKey}) : _customZoneKey = zoneKey;

  static String _defaultZoneKey() {
    final now = DateTime.now();
    return '${now.timeZoneOffset}|${now.timeZoneName}';
  }

  /// 边界到达回调（由装配方注入；可为 null，仅测试计时行为时留空）。
  void Function()? onFire;

  final String Function()? _customZoneKey;
  Timer? _timer;
  String? _lastZoneKey;

  String Function() get _zoneKey => _customZoneKey ?? _defaultZoneKey;

  /// 是否有待决边界 timer（测试断言 dispose 清理用）。
  bool get hasPendingTimer => _timer?.isActive ?? false;

  /// 调度到 [boundary] 的一次性刷新（覆盖旧 timer）。
  ///
  /// 过去/空边界不调度（显示已按最新值重算，无需再触发；也避免忙循环）。
  void scheduleAt(DateTime? boundary, {required DateTime now}) {
    _timer?.cancel();
    _timer = null;
    if (boundary == null || !boundary.isAfter(now)) return;
    _timer = Timer(boundary.difference(now), () {
      _timer = null;
      onFire?.call();
    });
  }

  /// 记录当前 zone 指纹（调度边界时调用，作为后续 resume 比对基线）。
  void noteZone() {
    _lastZoneKey = _zoneKey();
  }

  /// 页面 resume：返回 zone 指纹是否变化（恒重算由调用方负责，见 mixin）。
  bool zoneChangedOnResume() {
    final key = _zoneKey();
    final changed = _lastZoneKey != null && _lastZoneKey != key;
    _lastZoneKey = key;
    return changed;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 转发 resume 的私有 observer（WidgetsBindingObserver 是 abstract mixin
/// class，mixin 声明无法直接 implements，故组合）。
class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver({required this.onResume});

  final void Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// R20-B 页面生命周期 mixin：边界 timer + resume/zone 变化刷新 + dispose 清理。
///
/// 宿主在数据就绪/build 后调用 [scheduleBoundaryAt] 指定下一有效边界；
/// 覆写 [onBoundaryRefresh] 定制刷新（默认重建当前页）；
/// 覆写 [boundaryZoneKey] 可注入测试用 zone 指纹。
mixin BoundaryRefreshLifecycle<T extends StatefulWidget> on State<T> {
  BoundaryScheduler? _boundaryScheduler;
  _ResumeObserver? _resumeObserver;

  BoundaryScheduler get boundaryScheduler =>
      _boundaryScheduler ??= BoundaryScheduler(zoneKey: boundaryZoneKey)
        ..onFire = _fireRefresh;

  void _fireRefresh() => onBoundaryRefresh();

  @override
  void initState() {
    super.initState();
    boundaryScheduler.noteZone();
    _resumeObserver = _ResumeObserver(onResume: _handleAppResume);
    WidgetsBinding.instance.addObserver(_resumeObserver!);
  }

  @override
  void dispose() {
    final observer = _resumeObserver;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    _boundaryScheduler?.dispose();
    super.dispose();
  }

  void _handleAppResume() {
    // R20-4 后台越界返回即正确：resume 恒重算；
    // R20-5 zone 指纹变化一并告知回调方（如需重算日历标签）。
    final zoneChanged = boundaryScheduler.zoneChangedOnResume();
    onBoundaryRefresh(zoneChanged: zoneChanged);
  }

  /// R20-5 测试注入点：默认设备本地 zone 指纹（offset|名称）。
  @protected
  String boundaryZoneKey() {
    final now = DateTime.now();
    return '${now.timeZoneOffset}|${now.timeZoneName}';
  }

  /// 边界到达 / resume 时的刷新钩子（默认重建当前页）。
  @protected
  void onBoundaryRefresh({bool zoneChanged = false}) {
    if (mounted) setState(() {});
  }

  /// 调度下一有效边界（null/过去不调度）；每次调用重记 zone 基线。
  @protected
  void scheduleBoundaryAt(DateTime? boundary) {
    boundaryScheduler
      ..noteZone()
      ..scheduleAt(boundary, now: DateTime.now());
  }
}
