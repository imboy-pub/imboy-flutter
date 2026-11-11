import 'dart:async';
import 'dart:developer';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 一帧的耗时采样集合（纯计算，不依赖 binding，因此可单测）。
///
/// 术语约定（避免自欺）：
/// - **帧耗时** = build + raster 两个阶段的合计；60Hz 预算 16.667ms。
/// - **掉帧率** = 帧耗时超过预算的采样占比。它衡量"这一帧来不及"，比
///   "FPS"更贴近用户体感，也不受空闲期不产帧的干扰。
/// - **fps** 由相邻渲染帧的间隔推得，并剔除间隔 > 100ms 的空闲空档
///   （用户停手时不产帧，不算掉帧）。
class FrameTimingSeries {
  FrameTimingSeries({this.capacity = 300});

  /// 保留的最近采样数（环形窗口，避免长期运行无限增长）
  final int capacity;

  /// 60Hz 下单帧预算（微秒）
  static const int budgetMicros = 16667;

  /// 间隔超过该值视为空闲空档，不计入 fps（微秒）
  static const int idleGapMicros = 100000;

  final List<int> _frameCostMicros = <int>[];
  final List<int> _intervalsMicros = <int>[];
  int? _lastRasterFinishMicros;

  int get sampleCount => _frameCostMicros.length;

  int get intervalSampleCount => _intervalsMicros.length;

  bool get isEmpty => _frameCostMicros.isEmpty;

  void addTiming(FrameTiming timing) {
    addSample(
      buildMicros: timing.buildDuration.inMicroseconds,
      rasterMicros: timing.rasterDuration.inMicroseconds,
      rasterFinishMicros: timing.timestampInMicroseconds(
        FramePhase.rasterFinish,
      ),
    );
  }

  /// 直接注入一次采样（测试用；生产走 [addTiming]）。
  void addSample({
    required int buildMicros,
    required int rasterMicros,
    int? rasterFinishMicros,
  }) {
    if (buildMicros < 0 || rasterMicros < 0) return;
    _frameCostMicros.add(buildMicros + rasterMicros);
    if (_frameCostMicros.length > capacity) {
      _frameCostMicros.removeRange(0, _frameCostMicros.length - capacity);
    }

    if (rasterFinishMicros != null) {
      final previous = _lastRasterFinishMicros;
      _lastRasterFinishMicros = rasterFinishMicros;
      if (previous != null) {
        final interval = rasterFinishMicros - previous;
        if (interval > 0 && interval <= idleGapMicros) {
          _intervalsMicros.add(interval);
          if (_intervalsMicros.length > capacity) {
            _intervalsMicros.removeRange(0, _intervalsMicros.length - capacity);
          }
        }
      }
    }
  }

  void clear() {
    _frameCostMicros.clear();
    _intervalsMicros.clear();
    _lastRasterFinishMicros = null;
  }

  double get avgFrameCostMs => isEmpty ? 0 : _mean(_frameCostMicros) / 1000;

  double get p50FrameCostMs =>
      isEmpty ? 0 : _percentile(_frameCostMicros, 0.50) / 1000;

  double get p95FrameCostMs =>
      isEmpty ? 0 : _percentile(_frameCostMicros, 0.95) / 1000;

  /// 帧耗时超出 16.667ms 预算的采样占比（0~1）
  double get jankRatio {
    if (isEmpty) return 0;
    final janky = _frameCostMicros.where((v) => v > budgetMicros).length;
    return janky / _frameCostMicros.length;
  }

  /// 由渲染帧间隔推得的帧率；无间隔采样时返回 0（不伪造 60）
  double get fps {
    if (_intervalsMicros.isEmpty) return 0;
    final meanInterval = _mean(_intervalsMicros);
    if (meanInterval <= 0) return 0;
    return 1000000 / meanInterval;
  }

  Map<String, dynamic> toJson() => {
    'sample_count': sampleCount,
    'jank_ratio': jankRatio,
    'fps': fps,
    'avg_frame_cost_ms': avgFrameCostMs,
    'p50_frame_cost_ms': p50FrameCostMs,
    'p95_frame_cost_ms': p95FrameCostMs,
  };

  static double _mean(List<int> values) {
    if (values.isEmpty) return 0;
    var sum = 0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  static int _percentile(List<int> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.of(values)..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

/// 聊天性能监控工具（增强版）
/// 用于监控聊天界面的渲染性能和内存使用
class ChatPerformanceMonitor {
  static final ChatPerformanceMonitor _instance =
      ChatPerformanceMonitor._internal();

  factory ChatPerformanceMonitor() => _instance;

  ChatPerformanceMonitor._internal();

  // 内存管理
  final _messageMemory = <String, Message>{};
  final _imageCache = <String, ImageProvider>{};
  final _visibleMessages = <String>{};

  // 性能统计
  final _buildTimes = <String, int>{};

  /// 真实帧耗时采样（来自 SchedulerBinding.addTimingsCallback）。
  ///
  /// 历史上这里的 FPS 是假的：`startFPSMonitor` 是空实现，
  /// `_currentFPS` 恒为硬编码 60.0，于是 `getPerformanceReport()` 里
  /// `fps_achieved` 永远为 true —— 这类"不等于坏值"的断言等于没有断言。
  /// 现在改为采集引擎上报的 [FrameTiming]，用分位数与掉帧率说话。
  final FrameTimingSeries frameTimings = FrameTimingSeries();

  bool _timingsSubscribed = false;

  /// 启动帧耗时采集。
  ///
  /// 只在显式调用时订阅（由调试入口或 `IMBOY_PERF=1` 触发），
  /// 默认不影响生产路径。
  void startFPSMonitor() {
    if (_timingsSubscribed) return;
    _timingsSubscribed = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  /// 停止帧耗时采集
  void stopFPSMonitor() {
    if (!_timingsSubscribed) return;
    _timingsSubscribed = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      frameTimings.addTiming(timing);
    }
  }

  /// 是否已挂上帧耗时采集
  bool get isSampling => _timingsSubscribed;

  /// 实时帧率（由渲染帧间隔推得；无采样时返回 0，不再伪造 60）。
  double getCurrentFPS() => frameTimings.fps;

  /// 记录消息构建时间（微秒）
  void recordBuildTime(String messageId, int microseconds) {
    _buildTimes[messageId] = microseconds;

    // 超过 16ms（60fps 阈值）时发出警告
    if (microseconds > 16000) {
      if (kDebugMode) {
        log('⚠️ 性能警告: 消息 $messageId 构建耗时 ${microseconds / 1000}ms');
      }
    }
  }

  /// 获取平均构建时间（毫秒）
  double getAverageBuildTime() {
    if (_buildTimes.isEmpty) return 0;
    final total = _buildTimes.values.reduce((a, b) => a + b);
    return total / _buildTimes.length / 1000;
  }

  /// 获取慢消息列表（超过阈值的消息）
  List<String> getSlowMessages({int thresholdMs = 16}) {
    return _buildTimes.entries
        .where((e) => e.value > thresholdMs * 1000)
        .map((e) => 'Message ${e.key}: ${e.value / 1000}ms')
        .toList();
  }

  /// 清除构建时间记录
  void clearBuildTimes() {
    _buildTimes.clear();
  }

  /// 添加消息到内存管理
  void addMessage(Message message) {
    if (_messageMemory.length > 500) {
      // 清理最旧的消息
      final oldestKey = _messageMemory.keys.first;
      _messageMemory.remove(oldestKey);
    }
    _messageMemory[message.id] = message;
  }

  /// 从内存中移除消息
  void removeMessage(String messageId) {
    _messageMemory.remove(messageId);
    _imageCache.remove(messageId);
    _visibleMessages.remove(messageId);
    _buildTimes.remove(messageId);
  }

  /// 清理不可见的消息
  void cleanupInvisibleMessages() {
    final toRemove = <String>[];

    for (final messageId in _messageMemory.keys) {
      if (!_visibleMessages.contains(messageId)) {
        toRemove.add(messageId);
      }
    }

    for (final id in toRemove) {
      _messageMemory.remove(id);
      _imageCache.remove(id);
      _buildTimes.remove(id);
    }

    if (kDebugMode && toRemove.isNotEmpty) {
      log(
        '🧹 清理了 ${toRemove.length} 条不可见消息，当前内存中消息数: ${_messageMemory.length}',
      );
    }
  }

  /// 标记消息可见
  void markMessageVisible(String messageId) {
    _visibleMessages.add(messageId);
  }

  /// 标记消息不可见
  void markMessageInvisible(String messageId) {
    _visibleMessages.remove(messageId);
  }

  /// 查询消息当前是否可见
  bool isMessageVisible(String messageId) {
    return _visibleMessages.contains(messageId);
  }

  /// 获取内存使用统计
  Map<String, dynamic> getMemoryStats() {
    return {
      'total_messages': _messageMemory.length,
      'visible_messages': _visibleMessages.length,
      'cached_images': _imageCache.length,
      'memory_usage_mb': _estimateMemoryUsage() / 1024 / 1024,
    };
  }

  /// 获取完整的性能报告
  Map<String, dynamic> getPerformanceReport() {
    return {
      'fps': frameTimings.fps,
      'target_fps': 60.0,
      'sample_count': frameTimings.sampleCount,
      // 没有采样时不能判断"达标"：null 表示未知，不是 false。
      'fps_achieved': frameTimings.sampleCount == 0
          ? null
          : frameTimings.jankRatio <= 0.05,
      'jank_ratio': frameTimings.jankRatio,
      'avg_frame_cost_ms': frameTimings.avgFrameCostMs,
      'p50_frame_cost_ms': frameTimings.p50FrameCostMs,
      'p95_frame_cost_ms': frameTimings.p95FrameCostMs,
      'avg_build_time_ms': getAverageBuildTime(),
      'slow_messages_count': getSlowMessages().length,
      'memory_stats': getMemoryStats(),
    };
  }

  /// 估算内存使用量（字节）
  double _estimateMemoryUsage() {
    double total = 0;

    // 估算消息对象内存
    total += _messageMemory.length * 1024; // 每个消息约1KB

    // 估算图片缓存内存
    total += _imageCache.length * 2 * 1024 * 1024; // 每张图片约2MB

    return total;
  }

  /// 监控渲染性能（静态方法，保持兼容）
  static void monitorBuildTime(String widgetName, Duration buildTime) {
    if (buildTime > const Duration(milliseconds: 16)) {
      // 超过16ms（60fps的帧时间）
      log('⚠️ 性能警告: $widgetName 构建耗时 ${buildTime.inMilliseconds}ms');
    }
  }

  /// 打印性能摘要
  void printPerformanceSummary() {
    if (!kDebugMode) return;

    final report = getPerformanceReport();
    log('═══════════════════════════════════');
    log('📊 性能监控摘要');
    log('───────────────────────────────────');
    log('🎯 FPS: ${(report['fps'] as double).toStringAsFixed(1)} / 60.0');
    final achieved = report['fps_achieved'];
    log('✅ 达标: ${achieved == null ? "无采样" : (achieved == true ? "是" : "否")}');
    log('🖼️ 采样帧数: ${report['sample_count']}');
    log(
      '📉 掉帧率: ${((report['jank_ratio'] as double) * 100).toStringAsFixed(1)}%',
    );
    log(
      '⏱️ 帧耗时 p50/p95: '
      '${(report['p50_frame_cost_ms'] as double).toStringAsFixed(2)}ms / '
      '${(report['p95_frame_cost_ms'] as double).toStringAsFixed(2)}ms',
    );
    log('⏱️ 平均构建时间: ${report['avg_build_time_ms'].toStringAsFixed(2)}ms');
    log('🐌 慢消息数量: ${report['slow_messages_count']}');
    log(
      '💾 内存使用: ${report['memory_stats']['memory_usage_mb'].toStringAsFixed(2)} MB',
    );
    log('───────────────────────────────────');
    log('📨 总消息数: ${report['memory_stats']['total_messages']}');
    log('👁️ 可见消息: ${report['memory_stats']['visible_messages']}');
    log('🖼️ 缓存图片: ${report['memory_stats']['cached_images']}');
    log('═══════════════════════════════════');
  }

  /// 释放资源
  void dispose() {
    stopFPSMonitor();
    _messageMemory.clear();
    _imageCache.clear();
    _visibleMessages.clear();
    _buildTimes.clear();
    frameTimings.clear();
  }
}

/// 性能监控的 Widget 包装器
class PerformanceMonitorWidget extends StatefulWidget {
  const PerformanceMonitorWidget({
    super.key,
    required this.child,
    required this.widgetName,
    this.monitor,
  });

  final Widget child;
  final String widgetName;
  final ChatPerformanceMonitor? monitor;

  @override
  State<PerformanceMonitorWidget> createState() =>
      _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget> {
  late final ChatPerformanceMonitor _monitor;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _monitor = widget.monitor ?? ChatPerformanceMonitor();
    _monitor.startFPSMonitor();
  }

  @override
  void dispose() {
    if (widget.monitor == null) {
      _monitor.stopFPSMonitor();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _stopwatch
      ..reset()
      ..start();

    final result = widget.child;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stopwatch.stop();
      _monitor.recordBuildTime(
        widget.widgetName,
        _stopwatch.elapsedMicroseconds,
      );
    });

    return result;
  }
}

/// 性能监控显示面板（调试用）
class PerformanceMonitorPanel extends StatefulWidget {
  const PerformanceMonitorPanel({super.key});

  @override
  State<PerformanceMonitorPanel> createState() =>
      _PerformanceMonitorPanelState();
}

class _PerformanceMonitorPanelState extends State<PerformanceMonitorPanel> {
  final ChatPerformanceMonitor _monitor = ChatPerformanceMonitor();
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _monitor.startFPSMonitor();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _monitor.stopFPSMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final report = _monitor.getPerformanceReport();
    final fps = report['fps'] as double;
    final samples = report['sample_count'] as int;
    final jankRatio = report['jank_ratio'] as double;
    final p95 = report['p95_frame_cost_ms'] as double;
    // 无采样时不给绿灯：未知 ≠ 达标
    final isGood = samples > 0 && jankRatio <= 0.05;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGood
                    ? CupertinoIcons.checkmark_circle
                    : CupertinoIcons.exclamationmark_triangle,
                color: isGood
                    ? AppColors.getIosGreen(Theme.of(context).brightness)
                    : AppColors.iosOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                samples == 0 ? '采样中…' : 'FPS: ${fps.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: FontSizeType.small.size,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '掉帧: ${(jankRatio * 100).toStringAsFixed(1)}%  '
            'p95: ${p95.toStringAsFixed(1)}ms',
            style: TextStyle(
              color: AppColors.overlayWhite70,
              fontSize: FontSizeType.tiny.size,
            ),
          ),
          Text(
            '帧数: $samples',
            style: TextStyle(
              color: AppColors.overlayWhite70,
              fontSize: FontSizeType.tiny.size,
            ),
          ),
        ],
      ),
    );
  }
}
