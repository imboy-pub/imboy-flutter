/// 性能监控器 - 追踪测试执行性能
library;

import 'dart:async';

/// 性能指标
class PerformanceMetric {
  /// 操作名称
  final String operation;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  DateTime? endTime;

  /// 持续时间（毫秒）
  int get duration {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMilliseconds;
  }

  /// 是否完成
  bool get isCompleted => endTime != null;

  /// 额外数据
  final Map<String, dynamic> data;

  PerformanceMetric({
    required this.operation,
    required this.startTime,
    this.endTime,
    this.data = const {},
  });

  /// 完成
  void complete() {
    endTime ??= DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration,
      'data': data,
    };
  }
}

/// 性能监控器
class PerformanceMonitor {
  /// 操作指标
  final Map<String, PerformanceMetric> _metrics = {};

  /// 操作堆栈
  final List<String> _operationStack = [];

  /// 开始监控操作
  void startOperation(String operation, {Map<String, dynamic>? data}) {
    final metric = PerformanceMetric(
      operation: operation,
      startTime: DateTime.now(),
      data: data ?? {},
    );
    _metrics[operation] = metric;
    _operationStack.add(operation);
  }

  /// 结束监控操作
  void endOperation(String operation) {
    final metric = _metrics[operation];
    if (metric != null && !metric.isCompleted) {
      metric.complete();
    }
    _operationStack.remove(operation);
  }

  /// 获取操作指标
  PerformanceMetric? getMetric(String operation) {
    return _metrics[operation];
  }

  /// 获取所有指标
  Map<String, PerformanceMetric> get allMetrics =>
      Map.unmodifiable(_metrics);

  /// 获取指标摘要
  Map<String, dynamic> getMetrics() {
    final summary = <String, dynamic>{};

    for (final metric in _metrics.values) {
      if (metric.isCompleted) {
        summary[metric.operation] = {
          'duration': metric.duration,
          'data': metric.data,
        };
      }
    }

    return summary;
  }

  /// 获取总执行时间
  int getTotalDuration() {
    if (_metrics.isEmpty) return 0;

    var total = 0;
    for (final metric in _metrics.values) {
      if (metric.isCompleted) {
        total += metric.duration;
      }
    }

    return total;
  }

  /// 获取平均操作时间
  double getAverageOperationTime() {
    final completed = _metrics.values.where((m) => m.isCompleted).toList();
    if (completed.isEmpty) return 0.0;

    final total = completed.fold<int>(0, (sum, m) => sum + m.duration);
    return total / completed.length;
  }

  /// 获取最慢的操作
  PerformanceMetric? getSlowestOperation() {
    PerformanceMetric? slowest;

    for (final metric in _metrics.values) {
      if (metric.isCompleted) {
        if (slowest == null || metric.duration > slowest.duration) {
          slowest = metric;
        }
      }
    }

    return slowest;
  }

  /// 获取当前操作
  String? get currentOperation {
    return _operationStack.isNotEmpty ? _operationStack.last : null;
  }

  /// 是否正在执行
  bool get isRunning => _operationStack.isNotEmpty;

  /// 清空指标
  void clear() {
    _metrics.clear();
    _operationStack.clear();
  }

  /// 生成性能报告
  Map<String, dynamic> generateReport() {
    final completedMetrics =
        _metrics.values.where((m) => m.isCompleted).toList();

    if (completedMetrics.isEmpty) {
      return {
        'totalOperations': 0,
        'totalDuration': 0,
        'averageDuration': 0.0,
        'slowestOperation': null,
        'operations': <Map<String, dynamic>>[],
      };
    }

    completedMetrics.sort((a, b) => b.duration.compareTo(a.duration));

    return {
      'totalOperations': completedMetrics.length,
      'totalDuration': getTotalDuration(),
      'averageDuration': getAverageOperationTime(),
      'slowestOperation': {
        'operation': getSlowestOperation()?.operation,
        'duration': getSlowestOperation()?.duration,
      },
      'operations': completedMetrics.map((m) => m.toJson()).toList(),
    };
  }

  /// 释放资源
  void dispose() {
    clear();
  }
}
