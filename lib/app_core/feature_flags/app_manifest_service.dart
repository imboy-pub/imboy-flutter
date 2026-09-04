import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/storage.dart';
import 'generated_product_features.dart';

class AppManifestMismatchException implements Exception {
  const AppManifestMismatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Manifest data returned by /api/v1/app/manifest.
class AppManifest {
  final String? manifestHash;
  final int? manifestSchemaVersion;
  final List<String> compiledFeatures;
  final Map<String, dynamic> features;
  final Map<String, dynamic> policy;
  final List<String> appEntries;
  final List<String> adminEntries;
  final List<Map<String, dynamic>> plugins;
  final int generatedAt;

  const AppManifest({
    required this.manifestHash,
    required this.manifestSchemaVersion,
    required this.compiledFeatures,
    required this.features,
    required this.policy,
    required this.appEntries,
    required this.adminEntries,
    required this.plugins,
    required this.generatedAt,
  });

  factory AppManifest.fromMap(Map<String, dynamic> raw) {
    final rawCompiledFeatures = raw['compiled_features'];
    final rawSchemaVersion = raw['manifest_schema_version'];
    return AppManifest(
      manifestHash: raw['manifest_hash']?.toString(),
      manifestSchemaVersion: rawSchemaVersion is int ? rawSchemaVersion : null,
      compiledFeatures:
          rawCompiledFeatures is List &&
              rawCompiledFeatures.every((feature) => feature is String)
          ? List<String>.from(rawCompiledFeatures)
          : [],
      features: Map<String, dynamic>.from(raw['features'] as Map? ?? {}),
      policy: Map<String, dynamic>.from(raw['policy'] as Map? ?? {}),
      appEntries:
          (raw['app_entries'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      adminEntries:
          (raw['admin_entries'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      plugins:
          (raw['plugins'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      generatedAt: raw['generated_at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    if (manifestHash != null) 'manifest_hash': manifestHash,
    if (manifestSchemaVersion != null)
      'manifest_schema_version': manifestSchemaVersion,
    'compiled_features': compiledFeatures,
    'features': features,
    'policy': policy,
    'app_entries': appEntries,
    'admin_entries': adminEntries,
    'plugins': plugins,
    'generated_at': generatedAt,
  };

  /// Check if an app entry (e.g. "moment", "channel") is enabled.
  bool hasAppEntry(String entry) => appEntries.contains(entry);

  /// Check if an admin entry is enabled.
  bool hasAdminEntry(String entry) => adminEntries.contains(entry);

  void ensureBuildCompatible() {
    if (manifestHash != productFeatureManifestHash) {
      throw const AppManifestMismatchException('App 与服务端功能清单不一致，请安装匹配版本');
    }
    if (manifestSchemaVersion != productFeatureSchemaVersion) {
      throw const AppManifestMismatchException('App 与服务端功能清单版本不一致，请安装匹配版本');
    }
    if (compiledFeatures.isEmpty ||
        compiledFeatures.any(
          (feature) => !compiledProductFeatures.contains(feature),
        )) {
      throw const AppManifestMismatchException('服务端功能集合超出 App 编译能力，请安装匹配版本');
    }
  }
}

/// Service to fetch and cache the app manifest.
///
/// Fetches from /api/v1/app/manifest on startup and caches locally.
/// Supports Etag/If-None-Match for 304 optimization.
/// Refreshes when receiving a manifest_updated S2C event.
class AppManifestService {
  static AppManifest? _cache;
  static String? _etag;

  static AppManifest? get manifest => _cache;

  /// Load cached manifest from local storage (synchronous).
  static void loadFromCache() {
    final raw = StorageService.getMap(Keys.appManifest);
    if (raw.isNotEmpty) {
      _useIfCompatible(AppManifest.fromMap(raw), source: 'cache');
    }
    _etag = StorageService.to.getString(Keys.appManifestEtag);
  }

  /// Fetch manifest from server and update cache.
  /// Sends If-None-Match header when a cached etag exists.
  /// Returns early on 304 (content unchanged).
  static Future<void> refresh() async {
    try {
      final options = Options(
        validateStatus: (s) => s == 200 || s == 304,
        headers: _etag != null ? {'if-none-match': _etag} : null,
      );
      // 显式拼接完整 URL，不依赖 Dio 实例的 baseUrl：
      // HttpClient._setDefaultConfig 只在走 get/post/... 包装方法时才回填
      // baseUrl，这里直接调 .dio.get 会绕过该逻辑，若这是本 Dio 实例的
      // 首个请求 baseUrl 仍是空串，相对路径会被当成 host 直接失败。
      final response = await HttpClient.client.dio.get<dynamic>(
        '${Env().apiBaseUrl}${API.appManifest}',
        options: options,
      );

      if (response.statusCode == 304) {
        return;
      }

      if (response.statusCode != 200 || response.data is! Map) {
        return;
      }

      final raw = Map<String, dynamic>.from(response.data as Map);
      final manifest = AppManifest.fromMap(raw);
      if (!_useIfCompatible(manifest, source: 'response')) {
        return;
      }
      await StorageService.setMap(Keys.appManifest, raw);

      // Cache the etag from response header
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        _etag = newEtag;
        await StorageService.to.setString(Keys.appManifestEtag, newEtag);
      }
    } catch (error) {
      debugPrint('[app_manifest_service] setString error: $error');
    }
  }

  static bool _useIfCompatible(AppManifest manifest, {required String source}) {
    try {
      manifest.ensureBuildCompatible();
      _cache = manifest;
      return true;
    } on AppManifestMismatchException catch (error) {
      _cache = null;
      debugPrint(
        '[app_manifest_service] ignoring incompatible $source: $error',
      );
      return false;
    }
  }

  /// Replace cache for testing.
  static void replaceForTest(Map<String, dynamic> raw) {
    _cache = AppManifest.fromMap(raw);
  }

  @visibleForTesting
  static bool replaceIfCompatibleForTest(Map<String, dynamic> raw) =>
      _useIfCompatible(AppManifest.fromMap(raw), source: 'test');

  /// Clear cache.
  static Future<void> clear() async {
    _cache = null;
    _etag = null;
    await StorageService.to.remove(Keys.appManifest);
    await StorageService.to.remove(Keys.appManifestEtag);
  }
}
