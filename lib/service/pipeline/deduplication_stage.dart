/// 消息去重阶段 — 纯 Dart，不依赖 Flutter / sqflite / 任何平台组件。
///
/// 去重策略（优先级从高到低）：
///   1. receiving_ttl：[markReceiving] 后 TTL 内同 msgId → Duplicate
///   2. content_hash：相同内容哈希 → Duplicate
///   3. db_exists：dbLookup 返回 true → Duplicate
///   4. 其余 → Pass
///
/// receiving_ttl 按**全局 msgId**去重，不区分 msgType。
/// 服务端生成的 msgId 全局唯一，以单键去重更保守，防止同一消息以不同
/// msgType 二次入库。
library;

// ─────────────────────────────────────────────────────────────────────────── //
// Sealed result types
// ─────────────────────────────────────────────────────────────────────────── //

sealed class DeduplicationResult {
  const DeduplicationResult();
}

/// 消息未重复，允许继续处理。
final class DeduplicationPass extends DeduplicationResult {
  const DeduplicationPass();
}

/// 消息已重复，应丢弃。
final class DeduplicationDuplicate extends DeduplicationResult {
  const DeduplicationDuplicate(this.reason);

  /// 去重原因：'receiving_ttl' | 'content_hash' | 'db_exists'
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────── //
// MessageDeduplicator
// ─────────────────────────────────────────────────────────────────────────── //

/// 消息去重器。
///
/// [clock] 可注入时钟函数（返回 ms 时间戳），便于单元测试控制 TTL。
class MessageDeduplicator {
  MessageDeduplicator({int Function()? clock})
      : _clock = clock ?? _defaultClock;

  final int Function() _clock;

  /// receiving_ttl 窗口时长（毫秒）。
  static const int _ttlMs = 5000;

  /// msgId → 首次接收时间戳（全局，不区分 msgType）。
  final Map<String, int> _receivingWindow = {};

  /// 已见内容哈希集合，用于 content_hash 去重。
  final Set<String> _seenHashes = {};

  // ── Public API ──────────────────────────────────────────────────────────── //

  /// 标记某 msgId 正在接收，打开 TTL 窗口。
  ///
  /// 幂等：同一 msgId 多次调用不报错（刷新时间戳）。
  void markReceiving(String msgId, String msgType) {
    if (msgId.isEmpty) return;
    _receivingWindow[msgId] = _clock();
  }

  /// 检查消息是否重复。
  ///
  /// [dbLookup] 接收 msgId，返回该消息是否已存在于本地数据库。
  /// 若 dbLookup 抛出异常，视为 Pass（不阻断主流程）。
  Future<DeduplicationResult> check({
    required String msgId,
    required String msgType,
    String? contentHash,
    required Future<bool> Function(String msgId) dbLookup,
  }) async {
    // 1. receiving_ttl（全局 msgId 键）
    if (msgId.isNotEmpty && _receivingWindow.containsKey(msgId)) {
      final ts = _receivingWindow[msgId]!;
      if (_clock() - ts < _ttlMs) {
        return const DeduplicationDuplicate('receiving_ttl');
      }
    }

    // 2. content_hash
    if (contentHash != null && contentHash.isNotEmpty) {
      if (_seenHashes.contains(contentHash)) {
        return const DeduplicationDuplicate('content_hash');
      }
      _seenHashes.add(contentHash);
    } else if (msgId.isEmpty) {
      // msgId 为空且无 contentHash：无法安全去重，直接放行。
      return const DeduplicationPass();
    }

    // 3. db_exists
    if (msgId.isNotEmpty) {
      try {
        final exists = await dbLookup(msgId);
        if (exists) return const DeduplicationDuplicate('db_exists');
      } catch (_) {
        // DB 查询异常不阻断主流程。
        return const DeduplicationPass();
      }
    }

    return const DeduplicationPass();
  }

  /// 清理 receiving_ttl 窗口中已过期的条目。
  ///
  /// 建议在每条消息处理完成后或定时调用，防止内存泄漏。
  void cleanExpired() {
    final now = _clock();
    _receivingWindow.removeWhere((_, ts) => now - ts >= _ttlMs);
  }
}

int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
