/// R20-A：AppClock 双通道语义与 MonotonicCooldown 单调性测试。
///
/// 全部用 fake 时钟推进，不真实 sleep：
/// - R20-1：墙钟 ±1 小时回拨/前跳不冻结冷却也不放行/忙循环；
/// - R20-6（核心）：单调通道 elapsed 不受墙钟调整影响；
/// - SystemAppClock 冒烟：真实 Stopwatch 单调不减。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/app_clock.dart';

/// 可控 fake：墙钟 nowMs 独立设置；单调轴由 advance() 推进。
class FakeAppClock extends AppClock {
  FakeAppClock({int nowMs = 1000000})
    : _nowMs = nowMs; // ignore: prefer_initializing_formals

  int _nowMs;
  int _monotonicMs = 0;

  void setWallMs(int v) => _nowMs = v;
  void advance(Duration d) => _monotonicMs += d.inMilliseconds;

  @override
  int nowMs() => _nowMs;

  @override
  AppClockMark mark() => _FakeMark(_monotonicMs);

  @override
  int elapsedMs(AppClockMark mark) => _monotonicMs - (mark as _FakeMark).atMs;
}

class _FakeMark extends AppClockMark {
  const _FakeMark(this.atMs);
  final int atMs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppClock 双通道解耦', () {
    test('R20-6 墙钟回拨/前跳不改变单调 elapsed', () {
      final clock = FakeAppClock();
      final mark = clock.mark();
      clock.advance(const Duration(seconds: 10));
      clock.setWallMs(clock.nowMs() - 3600 * 1000); // 回拨 1h
      expect(clock.elapsedMs(mark), 10000);
      clock.setWallMs(clock.nowMs() + 2 * 3600 * 1000); // 前跳 2h
      expect(clock.elapsedMs(mark), 10000);
      clock.advance(const Duration(seconds: 5));
      expect(clock.elapsedMs(mark), 15000);
    });

    test('不同 mark 互不干扰（Stopwatch 工厂语义）', () {
      final clock = FakeAppClock();
      final a = clock.mark();
      clock.advance(const Duration(seconds: 3));
      final b = clock.mark();
      clock.advance(const Duration(seconds: 4));
      expect(clock.elapsedMs(a), 7000);
      expect(clock.elapsedMs(b), 4000);
    });
  });

  group('MonotonicCooldown', () {
    test('R20-1 墙钟回拨 1 小时不延长 30s 冷却', () {
      final clock = FakeAppClock();
      final cooldown = MonotonicCooldown(clock);
      cooldown.startFor(const Duration(seconds: 30));
      expect(cooldown.active, isTrue);

      clock.setWallMs(clock.nowMs() - 3600 * 1000);
      expect(cooldown.remainingMs, 30000);
      expect(cooldown.active, isTrue);
    });

    test('R20-1 墙钟前跳 1 小时不立刻放行（不产生忙循环）', () {
      final clock = FakeAppClock();
      final cooldown = MonotonicCooldown(clock);
      cooldown.startFor(const Duration(seconds: 30));

      clock.setWallMs(clock.nowMs() + 3600 * 1000);
      expect(cooldown.active, isTrue);
      expect(cooldown.remainingMs, 30000);
    });

    test('单调推进到期后正常放行（不冻结）', () {
      final clock = FakeAppClock();
      final cooldown = MonotonicCooldown(clock);
      cooldown.startFor(const Duration(seconds: 30));

      clock.advance(const Duration(seconds: 29));
      expect(cooldown.active, isTrue);
      expect(cooldown.remainingMs, 1000);
      clock.advance(const Duration(seconds: 2));
      expect(cooldown.active, isFalse);
      expect(cooldown.remainingMs, 0);
    });

    test('remainingMs 单调递减直至 0（不反弹、不忙等）', () {
      final clock = FakeAppClock();
      final cooldown = MonotonicCooldown(clock);
      cooldown.startFor(const Duration(seconds: 10));
      var prev = cooldown.remainingMs;
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(seconds: 1));
        final now = cooldown.remainingMs;
        expect(now, lessThanOrEqualTo(prev));
        prev = now;
      }
      expect(prev, 0);
    });

    test('clear 立即放行；新窗口覆盖旧窗口', () {
      final clock = FakeAppClock();
      final cooldown = MonotonicCooldown(clock);
      cooldown.startFor(const Duration(seconds: 30));
      cooldown.clear();
      expect(cooldown.active, isFalse);

      cooldown.startFor(const Duration(seconds: 5));
      clock.advance(const Duration(seconds: 6));
      expect(cooldown.active, isFalse);

      cooldown.startFor(const Duration(seconds: 60));
      expect(cooldown.remainingMs, 60000);
    });
  });

  group('SystemAppClock', () {
    test('单调通道真实单调不减', () {
      const clock = SystemAppClock();
      final mark = clock.mark();
      var prev = clock.elapsedMs(mark);
      for (var i = 0; i < 100; i++) {
        final now = clock.elapsedMs(mark);
        expect(now, greaterThanOrEqualTo(prev));
        prev = now;
      }
    });

    test('nowMs 与设备墙钟一致（未校准时 offset=0）', () {
      const clock = SystemAppClock();
      final wall = DateTime.now().millisecondsSinceEpoch;
      expect((clock.nowMs() - wall).abs(), lessThan(60000));
    });
  });
}
