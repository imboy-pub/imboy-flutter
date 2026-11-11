import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/performance_monitor.dart';

/// 帧耗时统计的契约测试。
///
/// 背景：这个统计曾长期是假的 —— `startFPSMonitor` 空实现、FPS 恒等 60、
/// `fps_achieved` 永远 true。本文件钉死三件事：
///   1. 无采样时"达标"必须是"未知"（null），不能是 true；
///   2. 分位数 / 掉帧率按注入的微秒数如实计算；
///   3. 帧率由渲染帧间隔推得，且空闲空档不计入。
void main() {
  group('FrameTimingSeries', () {
    test('无采样：所有指标为 0，且不伪造成 60fps', () {
      final series = FrameTimingSeries();

      expect(series.sampleCount, 0);
      expect(series.isEmpty, isTrue);
      expect(series.fps, 0);
      expect(series.jankRatio, 0);
      expect(series.p50FrameCostMs, 0);
      expect(series.p95FrameCostMs, 0);
    });

    test('分位数与掉帧率：9 帧 8ms + 1 帧 40ms → p50≈8ms / p95=40ms / 掉帧 10%', () {
      final series = FrameTimingSeries();
      for (var i = 0; i < 9; i++) {
        series.addSample(buildMicros: 5000, rasterMicros: 3000);
      }
      series.addSample(buildMicros: 30000, rasterMicros: 10000);

      expect(series.sampleCount, 10);
      expect(series.p50FrameCostMs, closeTo(8.0, 0.001));
      expect(series.p95FrameCostMs, closeTo(40.0, 0.001));
      expect(series.jankRatio, closeTo(0.1, 0.0001));
      expect(series.avgFrameCostMs, closeTo(11.2, 0.001));
    });

    test('帧率由相邻 rasterFinish 间隔推得：16.667ms → ≈60fps', () {
      final series = FrameTimingSeries();
      const step = 16667;
      for (var i = 0; i <= 10; i++) {
        series.addSample(
          buildMicros: 4000,
          rasterMicros: 4000,
          rasterFinishMicros: i * step,
        );
      }

      expect(series.intervalSampleCount, 10);
      expect(series.fps, closeTo(60.0, 0.1));
    });

    test('空闲空档（>100ms）不计入帧率，避免停手后被判掉帧', () {
      final series = FrameTimingSeries();
      // 三帧连续 16.667ms，随后停手 1 秒再来一帧
      series.addSample(
        buildMicros: 4000,
        rasterMicros: 4000,
        rasterFinishMicros: 0,
      );
      series.addSample(
        buildMicros: 4000,
        rasterMicros: 4000,
        rasterFinishMicros: 16667,
      );
      series.addSample(
        buildMicros: 4000,
        rasterMicros: 4000,
        rasterFinishMicros: 33334,
      );
      series.addSample(
        buildMicros: 4000,
        rasterMicros: 4000,
        rasterFinishMicros: 1033334,
      );

      expect(series.sampleCount, 4);
      // 1 秒空档被剔除，只剩两段 ~16.667ms 间隔
      expect(series.intervalSampleCount, 2);
      expect(series.fps, closeTo(60.0, 0.1));
    });

    test('环形窗口：超出 capacity 的旧采样被丢弃', () {
      final series = FrameTimingSeries(capacity: 5);
      for (var i = 0; i < 8; i++) {
        series.addSample(buildMicros: 1000, rasterMicros: 1000);
      }

      expect(series.sampleCount, 5);
    });

    test('非法采样（负数）被忽略', () {
      final series = FrameTimingSeries();
      series.addSample(buildMicros: -1, rasterMicros: 1000);
      series.addSample(buildMicros: 1000, rasterMicros: -5);

      expect(series.sampleCount, 0);
    });
  });

  group('ChatPerformanceMonitor.getPerformanceReport', () {
    test('无采样时 fps_achieved 为 null（未知 ≠ 达标）', () {
      final monitor = ChatPerformanceMonitor()..frameTimings.clear();
      addTearDown(monitor.frameTimings.clear);

      final report = monitor.getPerformanceReport();

      expect(report['sample_count'], 0);
      expect(report['fps_achieved'], isNull);
      expect(report['jank_ratio'], 0);
    });

    test('有采样且掉帧率达标（≤5%）时为 true，反之为 false', () {
      final monitor = ChatPerformanceMonitor()..frameTimings.clear();
      addTearDown(monitor.frameTimings.clear);

      for (var i = 0; i < 20; i++) {
        monitor.frameTimings.addSample(buildMicros: 4000, rasterMicros: 4000);
      }
      expect(monitor.getPerformanceReport()['fps_achieved'], isTrue);

      for (var i = 0; i < 10; i++) {
        monitor.frameTimings.addSample(buildMicros: 30000, rasterMicros: 20000);
      }
      expect(monitor.getPerformanceReport()['fps_achieved'], isFalse);
    });
  });
}
