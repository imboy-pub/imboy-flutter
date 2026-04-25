import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
  final _frameTimestamps = <DateTime>[];
  Timer? _fpsMonitorTimer;
  double _currentFPS = 60.0;

  /// 启动 FPS 监控
  void startFPSMonitor() {
    _fpsMonitorTimer?.cancel();
    _fpsMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateFPS();
      if (kDebugMode) {
        log('🎯 当前 FPS: $_currentFPS');
      }
    });
  }

  /// 停止 FPS 监控
  void stopFPSMonitor() {
    _fpsMonitorTimer?.cancel();
    _fpsMonitorTimer = null;
  }

  /// 计算当前 FPS
  void _calculateFPS() {
    final now = DateTime.now();
    _frameTimestamps.add(now);

    // 只保留最近 1 秒的时间戳
    _frameTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp).inSeconds > 1,
    );

    if (_frameTimestamps.length >= 2) {
      _currentFPS = _frameTimestamps.length.toDouble();
    }
  }

  /// 获取当前 FPS
  double getCurrentFPS() {
    return _currentFPS;
  }

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
      'fps': _currentFPS,
      'target_fps': 60.0,
      'fps_achieved': _currentFPS >= 58.0, // 允许 2fps 误差
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
    log(
      '🎯 FPS: ${report['fps'].toStringAsFixed(1)} / ${report['target_fps']}',
    );
    log('✅ 达标: ${report['fps_achieved'] ? "是" : "否"}');
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
    _frameTimestamps.clear();
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
    final isGood = fps >= 58.0;

    return Container(
      padding: const EdgeInsets.all(8),
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
                isGood ? Icons.check_circle : Icons.warning,
                color: isGood
                    ? AppColors.getIosGreen(Theme.of(context).brightness)
                    : AppColors.iosOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'FPS: ${fps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '构建: ${report['avg_build_time_ms'].toStringAsFixed(2)}ms',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            '内存: ${report['memory_stats']['memory_usage_mb'].toStringAsFixed(1)}MB',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
