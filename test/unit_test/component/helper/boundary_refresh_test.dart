/// R20-B：页面边界刷新（下一有效边界 / resume / zone 变化 / dispose）。
///
/// - R20-4：静置跨开始/结束边界自动翻转显示；后台越界返回（resume）即正确；
/// - R20-5：zone 指纹变化在 resume 时被检测并告知刷新回调；
/// - R20-6：dispose 取消 timer / 移除 observer，无泄漏、无 unmounted setState。
///
/// 全部 fake 计时（fake_async 驱动 widget 测试的 Timer + FakeAppClock 推进
/// 墙钟），不真实 sleep。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:imboy/component/helper/app_clock.dart';
import 'package:imboy/component/helper/boundary_refresh.dart';
import 'package:imboy/page/group/schedule/group_schedule_ui.dart';

/// 可控 fake 墙钟（复用 W2 app_clock_test 的形状）。
class _FakeAppClock extends AppClock {
  _FakeAppClock(int nowMs) : _nowMs = nowMs;

  int _nowMs;

  void setWallMs(int v) => _nowMs = v;

  @override
  int nowMs() => _nowMs;

  @override
  AppClockMark mark() => throw UnimplementedError();

  @override
  int elapsedMs(AppClockMark mark) => throw UnimplementedError();
}

/// R20-B 宿主：按 appClock 即时推导日程状态（与详情页同语义），
/// 并调度 start/end/午夜边界。
class _ScheduleHost extends StatefulWidget {
  const _ScheduleHost({
    required this.startSec,
    required this.endSec,
    this.zoneKeys = const ['Z0', 'Z0'],
  });

  final int startSec;
  final int endSec;
  final List<String> zoneKeys;

  @override
  State<_ScheduleHost> createState() => _ScheduleHostState();
}

class _ScheduleHostState extends State<_ScheduleHost>
    with BoundaryRefreshLifecycle<_ScheduleHost> {
  int zoneKeyIndex = 0;
  int refreshCount = 0;
  bool zoneChangedSeen = false;

  @override
  String boundaryZoneKey() =>
      widget.zoneKeys[zoneKeyIndex.clamp(0, widget.zoneKeys.length - 1)];

  @override
  void onBoundaryRefresh({bool zoneChanged = false}) {
    if (!mounted) return;
    refreshCount++;
    if (zoneChanged) zoneChangedSeen = true;
    setState(() {});
  }

  void _schedule() {
    final now = DateTime.now();
    scheduleBoundaryAt(
      nextBoundary([
        if (widget.startSec > 0)
          DateTime.fromMillisecondsSinceEpoch(widget.startSec * 1000),
        if (widget.endSec > widget.startSec)
          DateTime.fromMillisecondsSinceEpoch(widget.endSec * 1000),
        nextLocalMidnight(now),
      ], now),
    );
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    final state = resolveScheduleTimeState(
      status: 1,
      startAtSec: widget.startSec,
      endAtSec: widget.endSec,
      nowSec: appClock.nowMs() ~/ 1000,
    );
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('state:${state.name}', key: const Key('host_state')),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('纯函数', () {
    test('nextLocalMidnight 日历构造（DST 日也是真实次日 00:00）', () {
      final m = nextLocalMidnight(DateTime(2026, 3, 8, 15, 30));
      expect((m.year, m.month, m.day), (2026, 3, 9));
      expect((m.hour, m.minute), (0, 0));
    });

    test('nextBoundary 取最近未来；过去/null 忽略', () {
      final now = DateTime(2026, 10, 26, 12, 0);
      final a = DateTime(2026, 10, 26, 18, 0);
      final b = DateTime(2026, 10, 27, 0, 0);
      final past = DateTime(2026, 10, 25, 0, 0);
      expect(nextBoundary([b, a, past, null], now), a);
      expect(nextBoundary([past, null], now), isNull);
      expect(nextBoundary([], now), isNull);
    });
  });

  group('BoundaryScheduler（fake_async）', () {
    test('调度未来边界 → 到点触发一次；hasPendingTimer 正确翻转', () {
      fakeAsync((async) {
        var fired = 0;
        final s = BoundaryScheduler()..onFire = () => fired++;
        final now = DateTime(2026, 10, 26, 12, 0);
        s.scheduleAt(DateTime(2026, 10, 26, 12, 0, 30), now: now);
        expect(s.hasPendingTimer, isTrue);
        async.elapse(const Duration(seconds: 29));
        expect(fired, 0);
        async.elapse(const Duration(seconds: 1));
        expect(fired, 1);
        expect(s.hasPendingTimer, isFalse);
      });
    });

    test('R20-6 dispose 取消待决 timer，到点不再触发', () {
      fakeAsync((async) {
        var fired = 0;
        final s = BoundaryScheduler()..onFire = () => fired++;
        final now = DateTime(2026, 10, 26, 12, 0);
        s.scheduleAt(DateTime(2026, 10, 26, 12, 0, 30), now: now);
        expect(s.hasPendingTimer, isTrue);
        s.dispose();
        expect(s.hasPendingTimer, isFalse);
        async.elapse(const Duration(hours: 1));
        expect(fired, 0, reason: 'dispose 后 timer 不得再触发');
      });
    });

    test('过去/空边界不调度（防忙循环）', () {
      fakeAsync((async) {
        var fired = 0;
        final s = BoundaryScheduler()..onFire = () => fired++;
        final now = DateTime(2026, 10, 26, 12, 0);
        s.scheduleAt(DateTime(2026, 10, 26, 11, 59, 59), now: now);
        expect(s.hasPendingTimer, isFalse);
        s.scheduleAt(null, now: now);
        expect(s.hasPendingTimer, isFalse);
        async.elapse(const Duration(hours: 1));
        expect(fired, 0);
      });
    });

    test('R20-5 zone 指纹变化在 resume 被检测（首次 resume 不误报）', () {
      fakeAsync((async) {
        final keys = ['+08:00|CST', '+08:00|CST', '-05:00|EST'];
        var i = 0;
        final s = BoundaryScheduler(zoneKey: () => keys[i.clamp(0, 2)]);
        s.noteZone();
        i = 1;
        expect(s.zoneChangedOnResume(), isFalse, reason: 'zone 未变');
        i = 2;
        expect(s.zoneChangedOnResume(), isTrue, reason: '旅行跨区被检测');
        // 指纹已更新为基线，再次 resume 不再报变化。
        expect(s.zoneChangedOnResume(), isFalse);
      });
    });
  });

  group('R20-4 页面宿主（widget + fake timer）', () {
    testWidgets('静置跨结束边界：进行中 → 已结束自动翻转', (tester) async {
      final clock = _FakeAppClock(
        DateTime(2026, 10, 26, 12, 0).millisecondsSinceEpoch,
      );
      final original = appClock;
      appClock = clock;
      addTearDown(() => appClock = original);

      // widget 测试的 fake clock 与 Timer 时轴独立：start/end 用相对真实
      // DateTime.now() 的未来 2s/4s，让 tester.pump 能推进 Timer。
      final nowWall = DateTime.now();
      final startSec =
          nowWall.add(const Duration(seconds: 2)).millisecondsSinceEpoch ~/
          1000;
      final endSec =
          nowWall.add(const Duration(seconds: 4)).millisecondsSinceEpoch ~/
          1000;
      clock.setWallMs(startSec * 1000 + 500); // 已开始未结束

      await tester.pumpWidget(
        _ScheduleHost(startSec: startSec, endSec: endSec),
      );
      expect(find.text('state:inProgress'), findsOneWidget);

      // 静置跨过结束边界：墙钟跨 end（Timer 时轴同步推进），边界 timer
      // 触发 → 重算 → ended（R20-4）。
      clock.setWallMs(endSec * 1000 + 1000);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('state:ended'), findsOneWidget);
    });

    testWidgets('后台越界返回：paused → resumed 立即翻转，不等 timer', (tester) async {
      final clock = _FakeAppClock(
        DateTime(2026, 10, 26, 12, 0).millisecondsSinceEpoch,
      );
      final original = appClock;
      appClock = clock;
      addTearDown(() => appClock = original);

      final nowWall = DateTime.now();
      final startSec =
          nowWall.add(const Duration(seconds: 2)).millisecondsSinceEpoch ~/
          1000;
      final endSec =
          nowWall.add(const Duration(seconds: 4)).millisecondsSinceEpoch ~/
          1000;
      clock.setWallMs(startSec * 1000 + 500);

      await tester.pumpWidget(
        _ScheduleHost(startSec: startSec, endSec: endSec),
      );
      expect(find.text('state:inProgress'), findsOneWidget);

      // 模拟后台静置：墙钟跨过结束（Timer 未触发），resume 立即重算。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.setWallMs(endSec * 1000 + 1000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('state:ended'), findsOneWidget);
    });

    testWidgets('R20-5 zone 变化：resume 时回调收到 zoneChanged=true', (tester) async {
      final clock = _FakeAppClock(
        DateTime(2026, 10, 26, 12, 0).millisecondsSinceEpoch,
      );
      final original = appClock;
      appClock = clock;
      addTearDown(() => appClock = original);

      await tester.pumpWidget(
        const _ScheduleHost(startSec: 0, endSec: 0, zoneKeys: ['A', 'B']),
      );
      final state = tester.state<_ScheduleHostState>(
        find.byType(_ScheduleHost),
      );
      expect(state.zoneChangedSeen, isFalse);

      state.zoneKeyIndex = 1; // 模拟旅行跨区
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.zoneChangedSeen, isTrue);
    });

    testWidgets('R20-6 dispose：边界 timer 取消，长时间推进无泄漏无异常', (tester) async {
      final clock = _FakeAppClock(
        DateTime(2026, 10, 26, 12, 0).millisecondsSinceEpoch,
      );
      final original = appClock;
      appClock = clock;
      addTearDown(() => appClock = original);

      final nowWall = DateTime.now();
      final startSec =
          nowWall.add(const Duration(seconds: 2)).millisecondsSinceEpoch ~/
          1000;
      await tester.pumpWidget(_ScheduleHost(startSec: startSec, endSec: 0));
      final state = tester.state<_ScheduleHostState>(
        find.byType(_ScheduleHost),
      );
      expect(state.boundaryScheduler.hasPendingTimer, isTrue);

      await tester.pumpWidget(const SizedBox()); // 移除宿主 → dispose
      expect(
        state.boundaryScheduler.hasPendingTimer,
        isFalse,
        reason: 'dispose 必须取消待决边界 timer',
      );

      // 推进远超边界时长：无 fire、无 unmounted setState 异常。
      await tester.pump(const Duration(hours: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
