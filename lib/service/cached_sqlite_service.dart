import 'dart:async';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';

/// 缓存条目
class _CacheEntry {
  final List<Map<String, dynamic>> data;
  final int timestamp;

  _CacheEntry(this.data, this.timestamp);
}

/// 带缓存的数据库查询服务
/// 实现查询结果缓存，减少重复查询的数据库访问
///
/// 遵循原则：
/// - KISS: 简单的 LRU 缓存实现
/// - YAGNI: 只实现必要的缓存功能
/// - 性能优化：减少重复查询，提升响应速度
class CachedSqliteService {
  /// 查询缓存（SQL -> 缓存条目）
  final Map<String, _CacheEntry> _queryCache = {};

  /// 默认缓存过期时间（5分钟）
  static const _defaultTtl = Duration(minutes: 5);

  /// 最大缓存数量（防止内存溢出）
  static const _maxCacheSize = 100;

  /// 缓存命中次数统计
  int _cacheHits = 0;

  /// 缓存未命中次数统计
  int _cacheMisses = 0;

  /// 执行带缓存的查询
  ///
  /// 参数：
  /// - [db]: 数据库实例
  /// - [sql]: SQL 查询语句
  /// - [arguments]: 查询参数
  /// - [ttl]: 缓存过期时间（默认5分钟）
  /// - [useCache]: 是否使用缓存（默认true）
  ///
  /// 返回：查询结果列表
  Future<List<Map<String, dynamic>>> cachedQuery(
    Database db,
    String sql, {
    List<Object?>? arguments,
    Duration ttl = _defaultTtl,
    bool useCache = true,
  }) async {
    // 如果不使用缓存，直接查询
    if (!useCache) {
      return await db.rawQuery(sql, arguments);
    }

    // 生成缓存键（包含 SQL 和参数）
    final cacheKey = _generateCacheKey(sql, arguments);

    // 检查缓存
    final cached = _queryCache[cacheKey];
    final now = DateTimeHelper.millisecond();

    if (cached != null) {
      // 检查是否过期
      if (now - cached.timestamp <= ttl.inMilliseconds) {
        _cacheHits++;
        // iPrint('缓存命中: $sql');
        return cached.data;
      } else {
        // 缓存过期，移除
        _queryCache.remove(cacheKey);
      }
    }

    _cacheMisses++;

    // 执行查询
    final result = await db.rawQuery(sql, arguments);

    // 存入缓存
    _putCache(cacheKey, result);

    return result;
  }

  /// 执行带缓存的标量查询（返回单个值）
  Future<T?> cachedScalarQuery<T>(
    Database db,
    String sql, {
    List<Object?>? arguments,
    Duration ttl = _defaultTtl,
    bool useCache = true,
  }) async {
    final result = await cachedQuery(
      db,
      sql,
      arguments: arguments,
      ttl: ttl,
      useCache: useCache,
    );

    if (result.isEmpty || result.first.isEmpty) {
      return null;
    }

    return result.first.values.first as T?;
  }

  /// 清除特定查询的缓存
  void invalidateCache(String sqlPattern) {
    final keysToRemove = _queryCache.keys
        .where((key) => key.contains(sqlPattern))
        .toList();

    for (final key in keysToRemove) {
      _queryCache.remove(key);
    }

    iPrint('清除缓存: $sqlPattern, 移除了 ${keysToRemove.length} 个缓存条目');
  }

  /// 清除所有缓存
  void clearAllCache() {
    final count = _queryCache.length;
    _queryCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    iPrint('清除所有缓存: 共 $count 个缓存条目');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0
        ? (_cacheHits / totalRequests * 100)
        : 0.0;

    return {
      'cacheSize': _queryCache.length,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': '${hitRate.toStringAsFixed(2)}%',
      'maxCacheSize': _maxCacheSize,
    };
  }

  /// 生成缓存键
  String _generateCacheKey(String sql, List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return sql;
    }
    return '$sql|${arguments.join(',')}';
  }

  /// 存入缓存（带 LRU 淘汰）
  void _putCache(String key, List<Map<String, dynamic>> data) {
    // 如果缓存已满，移除最旧的条目
    if (_queryCache.length >= _maxCacheSize) {
      final oldestKey = _queryCache.entries
          .reduce((a, b) => a.value.timestamp < b.value.timestamp ? a : b)
          .key;
      _queryCache.remove(oldestKey);
    }

    _queryCache[key] = _CacheEntry(data, DateTimeHelper.millisecond());
  }

  /// 清理过期缓存
  void cleanupExpiredCaches() {
    final now = DateTimeHelper.millisecond();
    final expiredKeys = <String>[];

    for (final entry in _queryCache.entries) {
      if (now - entry.value.timestamp > _defaultTtl.inMilliseconds) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _queryCache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      iPrint('清理过期缓存: 移除了 ${expiredKeys.length} 个过期条目');
    }
  }
}
