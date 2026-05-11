import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

/// Manifest data returned by /v1/app/manifest.
class AppManifest {
  final Map<String, dynamic> features;
  final Map<String, dynamic> policy;
  final List<String> appEntries;
  final List<String> adminEntries;
  final List<Map<String, dynamic>> plugins;
  final int generatedAt;

  const AppManifest({
    required this.features,
    required this.policy,
    required this.appEntries,
    required this.adminEntries,
    required this.plugins,
    required this.generatedAt,
  });

  factory AppManifest.fromMap(Map<String, dynamic> raw) {
    return AppManifest(
      features: Map<String, dynamic>.from(raw['features'] as Map? ?? {}),
      policy: Map<String, dynamic>.from(raw['policy'] as Map? ?? {}),
      appEntries: (raw['app_entries'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      adminEntries: (raw['admin_entries'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      plugins: (raw['plugins'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      generatedAt: raw['generated_at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
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
}

/// Service to fetch and cache the app manifest.
///
/// Fetches from /v1/app/manifest on startup and caches locally.
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
      _cache = AppManifest.fromMap(raw);
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
      final response = await HttpClient.client.dio.get<dynamic>(
        API.appManifest,
        options: options,
      );

      if (response.statusCode == 304) {
        debugPrint('AppManifestService: 304 Not Modified, cache is fresh');
        return;
      }

      if (response.statusCode != 200 || response.data is! Map) {
        debugPrint(
          'AppManifestService: skip refresh, status=${response.statusCode}',
        );
        return;
      }

      final raw = Map<String, dynamic>.from(response.data as Map);
      _cache = AppManifest.fromMap(raw);
      await StorageService.setMap(Keys.appManifest, raw);

      // Cache the etag from response header
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        _etag = newEtag;
        await StorageService.to.setString(Keys.appManifestEtag, newEtag);
      }

      debugPrint(
        'AppManifestService: refreshed, '
        'app_entries=${_cache?.appEntries.length}, '
        'plugins=${_cache?.plugins.length}',
      );
    } catch (error) {
      debugPrint('AppManifestService: refresh failed: $error');
    }
  }

  /// Replace cache for testing.
  static void replaceForTest(Map<String, dynamic> raw) {
    _cache = AppManifest.fromMap(raw);
  }

  /// Clear cache.
  static Future<void> clear() async {
    _cache = null;
    _etag = null;
    await StorageService.to.remove(Keys.appManifest);
    await StorageService.to.remove(Keys.appManifestEtag);
  }
}
