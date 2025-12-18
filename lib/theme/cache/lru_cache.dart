import 'dart:collection';

/// LRU (Least Recently Used) 缓存实现
/// 用于优化主题相关数据的缓存管理
class LRUCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// 缓存命中次数
  int _hits = 0;

  /// 缓存未命中次数
  int _misses = 0;

  /// 缓存清理次数
  int _evictions = 0;

  LRUCache(this._maxSize) : assert(_maxSize > 0);

  /// 获取缓存值
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // 移到最后（最近使用）
      _hits++;
      return value;
    }
    _misses++;
    return null;
  }

  /// 设置缓存值
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxSize) {
      // 移除最久未使用的项
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictions++;
    }
    _cache[key] = value;
  }

  /// 移除指定键的缓存
  V? remove(K key) {
    return _cache.remove(key);
  }

  /// 检查是否包含指定键
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// 获取当前缓存大小
  int get length => _cache.length;

  /// 获取最大缓存大小
  int get maxSize => _maxSize;

  /// 检查缓存是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 检查缓存是否已满
  bool get isFull => _cache.length >= _maxSize;

  /// 获取缓存命中率
  double get hitRate {
    final total = _hits + _misses;
    return total > 0 ? _hits / total : 0.0;
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxSize,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hitRate': hitRate,
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  /// 估算内存使用量（字节）
  int _estimateMemoryUsage() {
    // 简单估算，实际使用量可能不同
    return _cache.length * 100; // 假设每个条目平均100字节
  }

  /// 获取所有键
  Iterable<K> get keys => _cache.keys;

  /// 获取所有值
  Iterable<V> get values => _cache.values;

  /// 重置统计信息
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// 获取缓存使用率
  double get usageRate => _cache.length / _maxSize;

  /// 预热缓存（批量添加数据）
  void warmUp(Map<K, V> data) {
    for (final entry in data.entries) {
      put(entry.key, entry.value);
    }
  }

  /// 获取最近使用的N个键
  List<K> getMostRecentKeys(int count) {
    final keys = _cache.keys.toList();
    final startIndex = (keys.length - count).clamp(0, keys.length);
    return keys.sublist(startIndex);
  }

  /// 获取最久未使用的N个键
  List<K> getLeastRecentKeys(int count) {
    final keys = _cache.keys.toList();
    final endIndex = count.clamp(0, keys.length);
    return keys.sublist(0, endIndex);
  }

  /// 批量移除最久未使用的项
  void evictLeastRecent(int count) {
    final keysToRemove = getLeastRecentKeys(count);
    for (final key in keysToRemove) {
      _cache.remove(key);
      _evictions++;
    }
  }

  /// 根据条件移除缓存项
  void removeWhere(bool Function(K key, V value) test) {
    final keysToRemove = <K>[];
    for (final entry in _cache.entries) {
      if (test(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  @override
  String toString() {
    return 'LRUCache(size: ${_cache.length}/$_maxSize, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}

/// 带过期时间的 LRU 缓存
class TTLLRUCache<K, V> extends LRUCache<K, V> {
  final Map<K, DateTime> _expireTimes = {};
  final Duration _defaultTTL;

  TTLLRUCache(super.maxSize, this._defaultTTL);

  @override
  V? get(K key) {
    // 检查是否过期
    final expireTime = _expireTimes[key];
    if (expireTime != null && DateTime.now().isAfter(expireTime)) {
      remove(key);
      return null;
    }
    return super.get(key);
  }

  /// 设置缓存值（带过期时间）
  void putWithTTL(K key, V value, Duration? ttl) {
    put(key, value);
    _expireTimes[key] = DateTime.now().add(ttl ?? _defaultTTL);
  }

  @override
  void put(K key, V value) {
    super.put(key, value);
    _expireTimes[key] = DateTime.now().add(_defaultTTL);
  }

  @override
  V? remove(K key) {
    _expireTimes.remove(key);
    return super.remove(key);
  }

  @override
  void clear() {
    super.clear();
    _expireTimes.clear();
  }

  /// 清理过期的缓存项
  void cleanupExpired() {
    final now = DateTime.now();
    final expiredKeys = <K>[];

    for (final entry in _expireTimes.entries) {
      if (now.isAfter(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove(key);
    }
  }

  /// 获取剩余生存时间
  Duration? getRemainingTTL(K key) {
    final expireTime = _expireTimes[key];
    if (expireTime == null) return null;

    final remaining = expireTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 延长缓存项的生存时间
  void extendTTL(K key, Duration extension) {
    final currentExpireTime = _expireTimes[key];
    if (currentExpireTime != null) {
      _expireTimes[key] = currentExpireTime.add(extension);
    }
  }

  @override
  Map<String, dynamic> getStats() {
    final baseStats = super.getStats();
    baseStats['expiredItems'] = _expireTimes.length;
    baseStats['defaultTTL'] = _defaultTTL.inMilliseconds;
    return baseStats;
  }
}
