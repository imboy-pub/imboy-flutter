/// 快捷回复持久化服务（S2）
///
/// 用户自定义的常用短语，持久化到键值存储，在 chat_input 快捷回复
/// 面板显示。支持 add/remove/update/reset，多账号隔离。
///
/// Domain 层纯类，依赖抽象 [QuickReplyStore]，便于单元测试。
/// 生产适配由 SharedPreferences (StorageService) 承接。
library;

import 'dart:convert';

/// 抽象键值存储接口（便于注入内存 Fake 做测试）。
abstract interface class QuickReplyStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// 快捷回复短语服务。
class QuickReplyService {
  /// 单条短语最大字符数，防止超长文本污染存储。
  static const int maxTextLength = 200;

  /// 总条数上限，防止列表无限增长。
  static const int maxEntries = 50;

  static const String _keyPrefix = 'quick_replies:';

  final QuickReplyStore _store;
  final List<String> _defaults;

  QuickReplyService(this._store, {required List<String> defaults})
      : _defaults = List.unmodifiable(defaults);

  String _key(String uid) => '$_keyPrefix$uid';

  /// 加载当前用户的短语列表。
  ///
  /// 行为：
  ///   - key 不存在 → 返回默认列表
  ///   - JSON 损坏 / 非 List → 默认列表
  ///   - 列表为空 → 默认列表（避免用户看到空面板）
  ///   - 混合类型数组 → 仅保留字符串项
  Future<List<String>> load(String uid) async {
    final raw = await _store.getString(_key(uid));
    if (raw == null) return List.of(_defaults);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List.of(_defaults);
      final strings = decoded.whereType<String>().toList(growable: false);
      if (strings.isEmpty) return List.of(_defaults);
      return strings;
    } on FormatException {
      return List.of(_defaults);
    }
  }

  /// 整体保存列表（覆盖式）。
  Future<void> save(String uid, List<String> replies) async {
    await _store.setString(_key(uid), jsonEncode(replies));
  }

  /// 清空持久化条目，下次 load 返回默认列表。
  Future<void> reset(String uid) async {
    await _store.remove(_key(uid));
  }

  /// 追加一条。
  /// - 去除前后空白；空白串被忽略
  /// - 重复（已存在相同文本）被忽略
  /// - 超长截断
  /// - 已达上限被拒绝
  Future<void> add(String uid, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = await load(uid);
    if (current.length >= maxEntries) return;
    if (current.contains(trimmed)) return;
    final normalized = trimmed.length > maxTextLength
        ? trimmed.substring(0, maxTextLength)
        : trimmed;
    await save(uid, [...current, normalized]);
  }

  /// 按索引删除；越界无操作。
  Future<void> removeAt(String uid, int index) async {
    final current = await load(uid);
    if (index < 0 || index >= current.length) return;
    final next = [...current]..removeAt(index);
    await save(uid, next);
  }

  /// 按索引更新；越界/空串无操作；超长截断。
  Future<void> updateAt(String uid, int index, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = await load(uid);
    if (index < 0 || index >= current.length) return;
    final normalized = trimmed.length > maxTextLength
        ? trimmed.substring(0, maxTextLength)
        : trimmed;
    final next = [...current];
    next[index] = normalized;
    await save(uid, next);
  }
}
