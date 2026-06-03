import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/assets.dart';

/// object_key → presigned GET URL 的网络获取函数（测试可注入替身）。
typedef ViewUrlFetcher = Future<String> Function(String objectKey);

/// 秒级时间源（测试可注入以控制 TTL 过期）。
typedef NowSecondsFn = int Function();

/// 单条 object_key 的短时 presigned GET URL 缓存项。
class _CachedUrl {
  const _CachedUrl(this.url, this.expiresAtSec);

  /// 后端签发的 presigned GET URL。
  final String url;

  /// 本地秒级失效时间戳（已扣除提前量，临近此点即视为过期需刷新）。
  final int expiresAtSec;
}

/// object_key → 短时 presigned GET URL 解析器。
///
/// - 异步：经后端 `GET /v1/attachment/view_url` 换取 600s 短时签发 URL。
/// - TTL 缓存：本地缓存 540s（提前 60s 失效，规避临界过期）。
/// - 并发合并：同一 object_key 的并发请求复用同一次网络往返。
///
/// 设计动机：Garage bucket 未开公开读，下载一律走短时签发；同步渲染层
/// （build/ImageProvider 工厂）无法等待网络，故将解析下沉到 async 下载边界，
/// 详见 [AssetsService.isObjectKey] 与 IMBoyCacheManager 的分流逻辑。
class AssetUrlResolver {
  AssetUrlResolver._();

  /// 创建独立实例（仅供测试，避免污染单例缓存/并发表）。
  @visibleForTesting
  AssetUrlResolver.forTest();

  static final AssetUrlResolver instance = AssetUrlResolver._();

  /// 后端 view_url 签发 600s，提前 60s 失效 → 有效缓存 540s。
  static const int _ttlSeconds = 540;

  final Map<String, _CachedUrl> _cache = <String, _CachedUrl>{};
  final Map<String, Future<String>> _inflight = <String, Future<String>>{};

  /// 测试可注入：替换网络获取（默认 [_fetchFromBackend]）。
  @visibleForTesting
  ViewUrlFetcher? fetcherOverride;

  /// 测试可注入：替换时间源（默认 [DateTimeHelper.second]）。
  @visibleForTesting
  NowSecondsFn nowSeconds = DateTimeHelper.second;

  /// 渲染统一入口：object_key 走 presign view_url；legacy 完整 URL 走旧同步授权。
  ///
  /// 供能 async 的消费点（消息映射、视频播放器等）调用，屏蔽两种来源差异。
  Future<String> resolveForDisplay(String input) async {
    if (!AssetsService.isObjectKey(input)) {
      return AssetsService.viewUrl(input).toString();
    }
    return resolve(input);
  }

  /// 解析 object_key 为短时 presigned GET URL（命中缓存则零网络）。
  Future<String> resolve(String objectKey) {
    final int now = nowSeconds();
    final _CachedUrl? cached = _cache[objectKey];
    if (cached != null && now < cached.expiresAtSec) {
      return Future<String>.value(cached.url);
    }
    final Future<String>? existing = _inflight[objectKey];
    if (existing != null) {
      return existing;
    }
    final Future<String> future = _fetch(objectKey);
    _inflight[objectKey] = future;
    return future;
  }

  Future<String> _fetch(String objectKey) async {
    try {
      final ViewUrlFetcher fetch = fetcherOverride ?? _fetchFromBackend;
      final String url = await fetch(objectKey);
      if (url.isEmpty) {
        throw Exception('attachment view_url 响应缺少 url 字段');
      }
      _cache[objectKey] = _CachedUrl(url, nowSeconds() + _ttlSeconds);
      return url;
    } catch (e) {
      iPrint('AssetUrlResolver._fetch error for $objectKey: $e');
      rethrow;
    } finally {
      _inflight.remove(objectKey);
    }
  }

  /// 默认网络获取：`GET /v1/attachment/view_url?object_key=`（JWT，走 HttpClient）。
  Future<String> _fetchFromBackend(String objectKey) async {
    final resp = await HttpClient.client.get(
      API.attachmentViewUrl,
      queryParameters: <String, dynamic>{'object_key': objectKey},
    );
    if (!resp.ok) {
      throw Exception(
        'attachment view_url 请求失败: code=${resp.code} msg=${resp.msg}',
      );
    }
    final dynamic payload = resp.payload;
    final String? url = (payload is Map ? payload['url'] : null) as String?;
    if (url == null || url.isEmpty) {
      throw Exception('attachment view_url 响应缺少 url 字段');
    }
    return url;
  }

  /// 主动失效某 object_key 缓存（如下载发现签发 URL 已失效时调用）。
  void invalidate(String objectKey) => _cache.remove(objectKey);

  /// 清空全部缓存（登出/切换账号时调用）。
  void clear() {
    _cache.clear();
    _inflight.clear();
  }
}
