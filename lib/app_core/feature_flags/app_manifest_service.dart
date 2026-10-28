import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/storage.dart';

import 'generated_product_features.dart';
import 'feature_scope.dart';
import 'app_feature_registry.dart';
import 'scoped_preference_writer.dart';

// W04.d：合同能力门判定（create_receipt_contract_enabled）。
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';
import 'package:imboy/store/api/list_cursor_client.dart'
    show listCursorContractEnabled;

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

  /// W04.d（channel-group-ux-v2.2 §6.4 C1）：顶层合同对象增量。
  /// 仅群/频道两对象进本版解析；会话偏好等对象随对应工作包扩展。
  /// 缺失折叠为空 map（= 能力未启用），绝不激进解释未知键。
  final Map<String, dynamic> groupContracts;
  final Map<String, dynamic> channelContracts;

  /// W07.c（C2 清单 cursor 协议）合同。缺失折叠空 map（未启用）。
  final Map<String, dynamic> listContracts;

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
    this.groupContracts = const {},
    this.channelContracts = const {},
    this.listContracts = const {},
  });

  /// 群创建受理合同（`group_contracts.create_request_id`）：恰为整数 1
  /// 才启用；缺失/true/"1"/2 均不启用（J27.d/e 精度）。
  bool get groupCreateReceiptEnabled =>
      createReceiptContractEnabled(groupContracts);

  /// W07.c（C2 清单 cursor 协议）：`list_contracts` 能力门
  /// （恰为整数 1 才启用，未声明 → legacy 路径零变化）。
  bool get listCursorGateEnabled => listCursorContractEnabled(listContracts);

  /// 频道创建受理合同（`channel_contracts.create_request_id`）。
  bool get channelCreateReceiptEnabled =>
      createReceiptContractEnabled(channelContracts);

  /// W08（C4/D3 查看更新边界）：`channel_contracts.view_watermark`
  /// 恰为整数 1 才启用（与 J27.b 同款精度，绝不激进解释）；
  /// 未声明 → 全部 legacy 已读路径零变化，未知能力不发送新边界。
  bool get viewWatermarkEnabled =>
      channelContracts['view_watermark'] is int &&
      channelContracts['view_watermark'] == 1;

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
      groupContracts: raw['group_contracts'] is Map
          ? Map<String, dynamic>.from(raw['group_contracts'] as Map)
          : const {},
      listContracts: raw['list_contracts'] is Map
          ? Map<String, dynamic>.from(raw['list_contracts'] as Map)
          : const {},
      channelContracts: raw['channel_contracts'] is Map
          ? Map<String, dynamic>.from(raw['channel_contracts'] as Map)
          : const {},
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
    'group_contracts': groupContracts,
    'list_contracts': listContracts,
    'channel_contracts': channelContracts,
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
    if (compiledFeatures.length != compiledProductFeatures.length ||
        compiledFeatures.toSet().length != compiledProductFeatures.length ||
        compiledFeatures.any(
          (feature) => !compiledProductFeatures.contains(feature),
        )) {
      throw const AppManifestMismatchException('服务端功能集合与 App 编译能力不一致，请安装匹配版本');
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
  static String? _scope;
  static int _epoch = -1;
  static int _latestRequest = 0;

  static AppManifest? get manifest {
    _checkScope();
    return _cache;
  }

  static void _checkScope() {
    if (_scope == FeatureScope.key && _epoch == FeatureScope.epoch) return;
    _scope = FeatureScope.key;
    _epoch = FeatureScope.epoch;
    _cache = null;
    _etag = null;
  }

  /// Load cached manifest from local storage (synchronous).
  static void loadFromCache() {
    _checkScope();
    _cache = null;
    _etag = null;
    if (_scope == null) return;
    final envelope = StorageService.getMap(
      FeatureScope.cacheKey(Keys.appManifest),
    );
    final body = envelope['body'];
    if (body is! Map) return;
    final raw = Map<String, dynamic>.from(body);
    if (raw.isNotEmpty &&
        _useIfCompatible(AppManifest.fromMap(raw), source: 'cache')) {
      _etag = envelope['etag'] is String ? envelope['etag'] as String : null;
    }
  }

  /// Fetch manifest from server and update cache.
  /// Sends If-None-Match header when a cached etag exists.
  /// Returns early on 304 (content unchanged).
  static Future<bool> refresh() async {
    _checkScope();
    final scope = _scope;
    final epoch = _epoch;
    final request = ++_latestRequest;
    bool current() =>
        FeatureScope.matches(scope, epoch) && request == _latestRequest;
    if (scope == null) return false;
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

      if (!current()) return false;

      if (response.statusCode == 304) {
        return _cache != null;
      }

      if (response.statusCode != 200 || response.data is! Map) {
        return false;
      }

      final raw = Map<String, dynamic>.from(response.data as Map);
      final manifest = AppManifest.fromMap(raw);
      manifest.ensureBuildCompatible();
      final etag = response.headers.value('etag');
      final persisted = await _persistCache(raw, etag, scope, current);
      if (!persisted) return false;
      _etag = etag;
      if (!current()) return false;
      _cache = manifest;
      AppFeatureRegistry.configurationChanged();
      return true;
    } catch (error) {
      debugPrint('[app_manifest_service] setString error: $error');
      return false;
    }
  }

  static Future<bool> _persistCache(
    Map<String, dynamic> raw,
    String? etag,
    String scope,
    bool Function() current,
  ) => ScopedPreferenceWriter.write(
    isCurrent: current,
    operation: () => StorageService.to.persistPreference(
      () => StorageService.setMap(
        FeatureScope.cacheKey(Keys.appManifest, scope),
        {'body': raw, 'etag': etag},
      ),
    ),
  );

  static bool _useIfCompatible(AppManifest manifest, {required String source}) {
    try {
      manifest.ensureBuildCompatible();
      _cache = manifest;
      AppFeatureRegistry.configurationChanged();
      return true;
    } on AppManifestMismatchException catch (error) {
      _cache = null;
      _etag = null;
      debugPrint(
        '[app_manifest_service] ignoring incompatible $source: $error',
      );
      return false;
    }
  }

  /// Replace cache for testing.
  static void replaceForTest(Map<String, dynamic> raw) {
    _checkScope();
    _cache = AppManifest.fromMap(raw);
  }

  @visibleForTesting
  static bool replaceIfCompatibleForTest(Map<String, dynamic> raw) =>
      _replaceCompatible(raw);

  static bool _replaceCompatible(Map<String, dynamic> raw) {
    _checkScope();
    return _useIfCompatible(AppManifest.fromMap(raw), source: 'test');
  }

  /// Clear cache.
  static Future<void> clear() async {
    _checkScope();
    _cache = null;
    _etag = null;
    if (_scope == null) return;
    final key = FeatureScope.cacheKey(Keys.appManifest);
    await ScopedPreferenceWriter.write(
      isCurrent: () => true,
      operation: () async {
        await StorageService.to.remove(key);
      },
    );
  }
}
