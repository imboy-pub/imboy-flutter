import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;

/// 带优先级的队列消息
class QueuedMessage {
  final String id;
  final String data; // JSON 字符串
  final int priority; // 0=普通, 1=高优先级(ACK), 2=重试
  final DateTime createdAt;

  QueuedMessage({
    required this.id,
    required this.data,
    this.priority = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
    'id': id,
    'data': data,
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 从 JSON 创建实例
  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    id: json['id'] as String,
    data: json['data'] as String,
    priority: json['priority'] as int? ?? 0,
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
  PersistentMessageQueue._internal();

  static const String _storageKey = 'ws_message_queue';
  static const int _maxQueueSize = 200;

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
    for (final jsonStr in jsonList) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final msg = QueuedMessage.fromJson(json);
        _priorityQueues[msg.priority]!.addLast(msg);
        _deduplicationSet.add(msg.id);
      } catch (e) {
        iPrint('⚠️ [QUEUE] 恢复消息失败: $e');
      }
    }
    return this;
  }

  /// 获取只读消息列表（所有优先级）
  List<QueuedMessage> get messages {
    final result = <QueuedMessage>[];
    for (final queue in _priorityQueues.values) {
      result.addAll(queue.toList());
    }
    return List.unmodifiable(result);
  }

  /// 向下兼容：获取消息字符串列表
  List<String> get messageStrings {
    return messages.map((msg) => msg.data).toList();
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
  void enqueue(
    String id,
    String data, {
    int priority = 0,
  }) {
    // 去重检查
    if (_deduplicationSet.contains(id)) {
      iPrint('⚠️ [QUEUE] 消息已存在: $id');
      return;
    }

    // 队列满时，先尝试移除低优先级消息
    if (_totalSize >= _maxQueueSize) {
      _removeLowestPriorityMessage(priority);
    }

    final msg = QueuedMessage(
      id: id,
      data: data,
      priority: priority,
    );

    _priorityQueues[priority]!.addLast(msg);
    _deduplicationSet.add(id);
    _save();

    iPrint('📥 [QUEUE] 入队: $id, priority=$priority, 总数=$_totalSize');
  }

  /// 向下兼容的旧接口（仅消息内容）
  ///
  /// 使用消息内容的 hash 作为 ID，默认普通优先级
  void enqueueLegacy(String message) {
    final id = message.hashCode.toString();
    enqueue(id, message, priority: 0);
  }

  /// 按优先级出队（优先返回高优先级消息）
  ///
  /// 出队顺序：2(重试) > 1(高优先级) > 0(普通)
  QueuedMessage? dequeueByPriority() {
    // 按优先级顺序检查：2(重试) > 1(高) > 0(普通)
    for (int p = 2; p >= 0; p--) {
      final queue = _priorityQueues[p]!;
      if (queue.isNotEmpty) {
        final msg = queue.removeFirst();
        _deduplicationSet.remove(msg.id);
        _save();
        iPrint('📤 [QUEUE] 出队: ${msg.id}, priority=$p');
        return msg;
      }
    }
    return null;
  }

  /// 向下兼容的旧接口（FIFO 顺序）
  String? dequeue() {
    final msg = dequeueByPriority();
    return msg?.data;
  }

  /// 更新消息优先级
  ///
  /// 用于将失败的消息提升到重试队列
  void updatePriority(String id, int newPriority) {
    for (int p = 0; p < 3; p++) {
      final queue = _priorityQueues[p]!;
      final index = queue.toList().indexWhere((msg) => msg.id == id);
      if (index != -1) {
        // 由于 ListQueue 不支持按索引删除，需要重建
        final tempList = queue.toList();
        tempList.removeAt(index);
        _priorityQueues[p] = ListQueue.from(tempList);

        final msg = tempList[index];
        final updatedMsg = QueuedMessage(
          id: msg.id,
          data: msg.data,
          priority: newPriority,
          createdAt: msg.createdAt,
        );
        _priorityQueues[newPriority]!.addLast(updatedMsg);
        _save();
        iPrint('🔄 [QUEUE] 更新优先级: $id, $p -> $newPriority');
        return;
      }
    }
  }

  bool get isEmpty => _totalSize == 0;

  /// 清空消息队列
  void clear() {
    for (final queue in _priorityQueues.values) {
      queue.clear();
    }
    _deduplicationSet.clear();
    _save();
    iPrint('🧹 [QUEUE] 清空队列');
  }

  /// 获取总队列大小
  int get _totalSize => _priorityQueues.values.fold(0, (sum, queue) => sum + queue.length);

  /// 移除最低优先级的消息（如果其优先级低于新消息优先级）
  void _removeLowestPriorityMessage(int newMessagePriority) {
    // 从最低优先级开始查找可移除的消息
    for (int p = 0; p < newMessagePriority; p++) {
      final queue = _priorityQueues[p]!;
      if (queue.isNotEmpty) {
        queue.removeFirst();
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
