import 'dart:collection';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 消息队列持久化服务（Getx 单例）
/// - 限制最大条数
/// - 支持持久化
/// - 提供基本的入队/出队/清空功能
class PersistentMessageQueue extends GetxService {
  static PersistentMessageQueue get to => Get.find();

  static const String _storageKey = 'ws_message_queue';
  static const int _maxQueueSize = 200;

  final ListQueue<String> _queue = ListQueue();
  SharedPreferences? _prefs;

  /// 初始化：从 SharedPreferences 加载历史队列
  Future<PersistentMessageQueue> init() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getStringList(_storageKey) ?? [];
    _queue.addAll(saved);
    return this;
  }

  /// 获取只读消息列表
  List<String> get messages => List.unmodifiable(_queue);

  /// 入队（去重 + 限制长度 + 自动持久化）
  void enqueue(String message) {
    if (_queue.contains(message)) return;
    if (_queue.length >= _maxQueueSize) {
      _queue.removeFirst();
    }
    _queue.addLast(message);
    _save();
  }

  /// 出队：返回队首并移除
  String? dequeue() {
    if (_queue.isEmpty) return null;
    final msg = _queue.removeFirst();
    _save();
    return msg;
  }

  bool get isEmpty => _queue.isEmpty;

  /// 清空消息队列
  void clear() {
    _queue.clear();
    _save();
  }

  /// 内部持久化
  void _save() {
    _prefs?.setStringList(_storageKey, _queue.toList());
  }
}
