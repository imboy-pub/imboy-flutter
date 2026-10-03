import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;

/// 带优先级的队列消息
class QueuedMessage {
  final String id;
  final String data; // JSON 字符串
  final int priority; // 0=普通, 1=高优先级(ACK), 2=重试
  final DateTime createdAt;
  final String ownerUid;
  final int? sessionGeneration;
  final bool quarantined;

  QueuedMessage({
    required this.id,
    required this.data,
    this.priority = 0,
    DateTime? createdAt,
    this.ownerUid = '',
    this.sessionGeneration,
    this.quarantined = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get deduplicationKey => jsonEncode([ownerUid, sessionGeneration, id]);

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
    'id': id,
    'data': data,
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'ownerUid': ownerUid,
    'quarantined': quarantined,
  };

  /// 从 JSON 创建实例
  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    id: json['id'] as String,
    data: json['data'] as String,
    priority: json['priority'] as int? ?? 0,
    ownerUid: json['ownerUid'] as String? ?? '',
    quarantined: json['quarantined'] == true,
    sessionGeneration: json['quarantined'] == true
        ? null
        : UserRepoLocal.to.sessionGeneration,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  @override
  String toString() => 'QueuedMessage(id: $id, priority: $priority)';
}

/// 消息队列持久化服务（单例模式，增强版）
///
/// ## 功能特性
/// - 支持三级优先级（0=普通, 1=高优先级/ACK, 2=重试）
/// - 去重机制：相同 ID 的消息只保留一个
/// - 限制最大条数：按优先级淘汰低优先级消息
/// - 持久化支持：应用重启后恢复队列
/// - 按优先级出队：高优先级消息优先发送
/// - 【新增 M1】消息过期清理机制
///
/// ## 使用示例
/// ```dart
/// // 普通消息
/// PersistentMessageQueue.to.enqueue('msg1', '{"type":"chat"}');
///
/// // 高优先级消息（ACK）
/// PersistentMessageQueue.to.enqueue('msg1', '{"type":"ack"}', priority: 1);
///
/// // 出队（按优先级）
/// final msg = PersistentMessageQueue.to.dequeueByPriority();
/// ```
class PersistentMessageQueue {
  // 单例模式
  static PersistentMessageQueue? _instance;
  static PersistentMessageQueue get to =>
      _instance ??= PersistentMessageQueue._internal();
  PersistentMessageQueue._internal() {
    _startPeriodicCleanup();
  }

  static const String _storageKey = 'ws_message_queue';
  static const int _maxQueueSize = 200;

  // 【新增 M1】消息过期时间配置（按优先级）
  static const Map<int, Duration> _messageExpiry = {
    0: Duration(hours: 24), // 普通消息 24 小时
    1: Duration(minutes: 5), // ACK 消息 5 分钟
    2: Duration(hours: 1), // 重试消息 1 小时
  };

  // 【新增 M1】定期清理 Timer（每分钟清理一次）
  Timer? _cleanupTimer;

  // 优先级队列映射
  final Map<int, ListQueue<QueuedMessage>> _priorityQueues = {
    0: ListQueue(), // 普通消息
    1: ListQueue(), // 高优先级（ACK）
    2: ListQueue(), // 重试消息
  };

  // 去重集合
  final Set<String> _deduplicationSet = {};

  SharedPreferences? _prefs;

  /// 初始化：从 SharedPreferences 加载历史队列
  Future<PersistentMessageQueue> init() async {
    _prefs = await SharedPreferences.getInstance();
    final jsonList = _prefs?.getStringList(_storageKey) ?? [];
    final groups = <String, List<QueuedMessage>>{};
    for (final jsonStr in jsonList) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final msg = QueuedMessage.fromJson(json);
        final key = jsonEncode([msg.ownerUid, msg.id]);
        groups.putIfAbsent(key, () => []).add(msg);
      } catch (e) {
        iPrint('⚠️ [QUEUE] 恢复消息失败: $e');
      }
    }
    for (final group in groups.values) {
      _restoreGroup(group);
    }
    final saved = await _prefs?.setStringList(
      _storageKey,
      messages.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    if (saved == false) throw StateError('Queue recovery persistence failed');
    return this;
  }

  void _restoreGroup(List<QueuedMessage> group) {
    final first = group.first;
    final existing = messages
        .where(
          (entry) => entry.ownerUid == first.ownerUid && entry.id == first.id,
        )
        .toList();
    final combined = [...existing, ...group];
    final conflict = combined.map((entry) => entry.data).toSet().length > 1;
    final quarantined = conflict || combined.any((entry) => entry.quarantined);
    if (!quarantined && existing.isNotEmpty) return;
    if (quarantined) {
      for (final queue in _priorityQueues.values) {
        queue.removeWhere(
          (entry) => entry.ownerUid == first.ownerUid && entry.id == first.id,
        );
      }
      _deduplicationSet
        ..clear()
        ..addAll(messages.map((entry) => entry.deduplicationKey));
    }
    final distinct = <String, QueuedMessage>{};
    for (final entry in combined) {
      distinct.putIfAbsent(entry.data, () => entry);
    }
    for (final entry in distinct.values) {
      final restored = quarantined
          ? QueuedMessage(
              id: entry.id,
              data: entry.data,
              priority: entry.priority,
              createdAt: entry.createdAt,
              ownerUid: entry.ownerUid,
              quarantined: true,
            )
          : entry;
      _priorityQueues[restored.priority.clamp(0, 2)]!.addLast(restored);
      _deduplicationSet.add(restored.deduplicationKey);
    }
  }

  /// 获取只读消息列表（所有优先级）
  List<QueuedMessage> get messages {
    final result = <QueuedMessage>[];
    for (final queue in _priorityQueues.values) {
      result.addAll(queue.toList());
    }
    return List.unmodifiable(result);
  }

  /// 获取各优先级队列统计
  Map<int, int> get priorityStats => {
    0: _priorityQueues[0]!.length,
    1: _priorityQueues[1]!.length,
    2: _priorityQueues[2]!.length,
  };

  /// 入队（支持优先级）
  ///
  /// ## 参数
  /// - [id]: 消息唯一标识（用于去重）
  /// - [data]: 消息内容（JSON 字符串）
  /// - [priority]: 优先级（0=普通, 1=高优先级/ACK, 2=重试）
  bool enqueue(
    String id,
    String data, {
    int priority = 0,
    String ownerUid = '',
    int? sessionGeneration,
  }) {
    final msg = QueuedMessage(
      id: id,
      data: data,
      priority: priority.clamp(0, 2),
      ownerUid: ownerUid,
      sessionGeneration: sessionGeneration,
    );
    if (_deduplicationSet.contains(msg.deduplicationKey)) {
      iPrint('⚠️ [QUEUE] 消息已存在: $id');
      return false;
    }
    if (_totalSize >= _maxQueueSize) {
      _removeLowestPriorityMessage(msg.priority);
      if (_totalSize >= _maxQueueSize) return false;
    }

    _priorityQueues[msg.priority]!.addLast(msg);
    _deduplicationSet.add(msg.deduplicationKey);
    _save();

    iPrint('📥 [QUEUE] 入队: $id, priority=$priority, 总数=$_totalSize');
    return true;
  }

  /// 按优先级出队（优先返回高优先级消息）
  ///
  /// 出队顺序：2(重试) > 1(高优先级) > 0(普通)
  QueuedMessage? dequeueByPriority({bool Function(QueuedMessage)? eligible}) {
    // 按优先级顺序检查：2(重试) > 1(高) > 0(普通)
    for (int p = 2; p >= 0; p--) {
      final queue = _priorityQueues[p]!;
      QueuedMessage? candidate;
      for (final entry in queue) {
        if (eligible == null || eligible(entry)) {
          candidate = entry;
          break;
        }
      }
      if (candidate != null) {
        final msg = candidate;
        queue.remove(msg);
        _deduplicationSet.remove(msg.deduplicationKey);
        _save();
        iPrint('📤 [QUEUE] 出队: ${msg.id}, priority=$p');
        return msg;
      }
    }
    return null;
  }

  /// 更新消息优先级
  ///
  /// 用于将失败的消息提升到重试队列
  void updatePriority(
    String id,
    int newPriority, {
    String? ownerUid,
    int? sessionGeneration,
  }) {
    final matches = messages
        .where(
          (entry) =>
              entry.id == id &&
              (ownerUid == null || entry.ownerUid == ownerUid) &&
              (sessionGeneration == null ||
                  entry.sessionGeneration == sessionGeneration),
        )
        .toList();
    if (matches.length != 1) return;
    final target = matches.single;
    for (int p = 0; p < 3; p++) {
      final queue = _priorityQueues[p]!;
      final index = queue.toList().indexWhere((msg) => identical(msg, target));
      if (index != -1) {
        // 由于 ListQueue 不支持按索引删除，需要重建
        final tempList = queue.toList();
        final msg = tempList[index]; // 先读后删，避免索引偏移
        tempList.removeAt(index);
        _priorityQueues[p] = ListQueue.from(tempList);

        final updatedMsg = QueuedMessage(
          id: msg.id,
          data: msg.data,
          priority: newPriority,
          createdAt: msg.createdAt,
          ownerUid: msg.ownerUid,
          sessionGeneration: msg.sessionGeneration,
          quarantined: msg.quarantined,
        );
        _priorityQueues[newPriority.clamp(0, 2)]!.addLast(updatedMsg);
        _save();
        iPrint('🔄 [QUEUE] 更新优先级: $id, $p -> $newPriority');
        return;
      }
    }
  }

  bool get isEmpty => _totalSize == 0;

  /// 清空消息队列（不影响定期清理 Timer 的生命周期）
  void clear() {
    for (final queue in _priorityQueues.values) {
      queue.clear();
    }
    _deduplicationSet.clear();
    _save();
    iPrint('🧹 [QUEUE] 清空队列');
  }

  /// 释放资源（先停 Timer 再清数据，避免 dispose 后 Timer 重启）
  void dispose() {
    _stopPeriodicCleanup();
    clear();
  }

  /// 获取总队列大小
  int get _totalSize =>
      _priorityQueues.values.fold(0, (sum, queue) => sum + queue.length);

  /// 【新增 M1】启动定期清理过期消息
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanupExpiredMessages(),
    );
    iPrint('🧹 [QUEUE] 启动定期清理 Timer');
  }

  /// 【新增 M1】停止定期清理
  void _stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    iPrint('🛑 [QUEUE] 停止定期清理 Timer');
  }

  /// 【新增 M1】清理过期消息
  void _cleanupExpiredMessages() {
    final now = DateTime.now();
    int totalCleaned = 0;

    for (int p = 0; p < 3; p++) {
      final queue = _priorityQueues[p]!;
      final expiry = _messageExpiry[p] ?? const Duration(hours: 24);

      // 由于 ListQueue 不支持迭代时删除，需要重建
      final tempList = <QueuedMessage>[];
      int cleaned = 0;

      while (queue.isNotEmpty) {
        final msg = queue.removeFirst();
        // 检查消息是否过期
        if (now.difference(msg.createdAt) > expiry) {
          _deduplicationSet.remove(msg.deduplicationKey);
          cleaned++;
        } else {
          tempList.add(msg);
        }
      }

      // 重建队列
      _priorityQueues[p] = ListQueue.from(tempList);
      totalCleaned += cleaned;

      if (cleaned > 0) {
        iPrint('🗑️ [QUEUE] 清理优先级 $p 的 $cleaned 条过期消息');
      }
    }

    if (totalCleaned > 0) {
      _save();
      iPrint('🧹 [QUEUE] 总共清理 $totalCleaned 条过期消息');
    }
  }

  /// 【新增 M1】手动清理过期消息（供外部调用）
  void cleanupExpired() {
    _cleanupExpiredMessages();
  }

  /// 【新增 M1】获取队列统计信息
  Map<String, dynamic> getQueueStats() {
    return {
      'total_size': _totalSize,
      'by_priority': priorityStats,
      'max_size': _maxQueueSize,
      'expiry_config': _messageExpiry.map(
        (k, v) => MapEntry(k.toString(), v.inMinutes),
      ),
    };
  }

  /// 移除最低优先级的消息（如果其优先级低于新消息优先级）
  void _removeLowestPriorityMessage(int newMessagePriority) {
    // 从最低优先级开始查找可移除的消息
    for (int p = 0; p < newMessagePriority; p++) {
      final queue = _priorityQueues[p]!;
      if (queue.isNotEmpty) {
        final removed = queue.removeFirst();
        if (!messages.any(
          (entry) => entry.deduplicationKey == removed.deduplicationKey,
        )) {
          _deduplicationSet.remove(removed.deduplicationKey);
        }
        iPrint('🗑️ [QUEUE] 移除低优先级消息: priority=$p');
        return;
      }
    }
  }

  /// 内部持久化
  void _save() {
    final allMessages = <String>[];
    for (final queue in _priorityQueues.values) {
      for (final msg in queue) {
        allMessages.add(jsonEncode(msg.toJson()));
      }
    }
    _prefs?.setStringList(_storageKey, allMessages);
  }
}
