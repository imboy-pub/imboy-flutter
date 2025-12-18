import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// 聊天性能监控工具
class ChatPerformanceMonitor {
  static final ChatPerformanceMonitor _instance = ChatPerformanceMonitor._internal();
  
  factory ChatPerformanceMonitor() => _instance;
  
  ChatPerformanceMonitor._internal();
  
  final _messageMemory = <String, Message>{};
  final _imageCache = <String, ImageProvider>{};
  final _visibleMessages = <String>{};
  
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
    }
    
    if (kDebugMode) {
      log('清理了 ${toRemove.length} 条不可见消息，当前内存中消息数: ${_messageMemory.length}');
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
  
  /// 估算内存使用量（字节）
  double _estimateMemoryUsage() {
    double total = 0;
    
    // 估算消息对象内存
    total += _messageMemory.length * 1024; // 每个消息约1KB
    
    // 估算图片缓存内存
    total += _imageCache.length * 2 * 1024 * 1024; // 每张图片约2MB
    
    return total;
  }
  
  /// 监控渲染性能
  static void monitorBuildTime(String widgetName, Duration buildTime) {
    if (buildTime > const Duration(milliseconds: 16)) {
      // 超过16ms（60fps的帧时间）
      log('⚠️ 性能警告: $widgetName 构建耗时 ${buildTime.inMilliseconds}ms');
    }
  }
}

/// 性能监控的Widget包装器
class PerformanceMonitorWidget extends StatelessWidget {
  const PerformanceMonitorWidget({
    super.key,
    required this.child,
    required this.widgetName,
  });
  
  final Widget child;
  final String widgetName;
  
  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();
    
    final result = child;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stopwatch.stop();
      ChatPerformanceMonitor.monitorBuildTime(widgetName, stopwatch.elapsed);
    });
    
    return result;
  }
}
