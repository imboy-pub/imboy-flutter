import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

import 'generated_product_features.dart';

import 'feature_keys.dart';
import 'feature_scope.dart';
import 'scoped_preference_writer.dart';

class AppFeatureRegistry {
  static Map<String, dynamic>? _cache;
  static int _latestRequest = 0;
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Accepted partial flags are useful, but cannot stop recovery retries.
  static bool get isComplete =>
      FeatureScope.key != null &&
      compiledProductFeatures.every((key) => snapshot.containsKey(key));

  static void configurationChanged() => revision.value++;

  static void bindScope({required String endpoint, required String uid}) {
    if (!FeatureScope.bind(endpoint: endpoint, uid: uid)) return;
    _cache = normalizeFlags(
      StorageService.getMap(FeatureScope.cacheKey(Keys.appFeatures)),
    );
    revision.value++;
  }

  static const Map<String, String> _parentFeatures = {
    FeatureKeys.channelDiscover: FeatureKeys.channel,
    FeatureKeys.channelInvitation: FeatureKeys.channel,
    FeatureKeys.channelOrder: FeatureKeys.channel,
  };

  /// 本地硬关闭集合 — 优先级高于远程 snapshot，后端返回 true 也无效。
  /// 解除：后端 API 就绪后删除对应 key，功能代码无需恢复。
  /// 详见 docs/reference/feature-status.md § 待后端支持（前端隐藏）
  static const Set<String> _localDisabledKeys = {
    // 钱包已解禁：后端 /api/v1/wallet/{balance,transactions,recharge/*} 已实现并通过测试，
    // 沙箱(mock)模式可走通充值闭环；真实支付 SDK(fluwx/tobias/flutter_stripe)待接入。
    // 2026-09-10 产品决策：直播间暂时不做。保留代码并隐藏入口；
    // 只有用户重新批准该业务域后才能从本集合移除。
    FeatureKeys.liveRoom,
  };

  static Map<String, dynamic> get snapshot {
    _cache ??= Map<String, dynamic>.from(
      FeatureScope.key == null
          ? const <String, dynamic>{}
          : StorageService.getMap(FeatureScope.cacheKey(Keys.appFeatures)),
    );
    return _cache!;
  }

  static Future<void> clear() async {
    FeatureScope.invalidate();
    _cache = {};
    revision.value++;
    if (FeatureScope.key != null) {
      final key = FeatureScope.cacheKey(Keys.appFeatures);
      await ScopedPreferenceWriter.write(
        isCurrent: () => true,
        operation: () async {
          await StorageService.to.remove(key);
        },
      );
    }
  }

  static Future<bool> refresh({
    @visibleForTesting Future<Map<String, dynamic>?> Function()? fetch,
  }) async {
    final scope = FeatureScope.key;
    final epoch = FeatureScope.epoch;
    final request = ++_latestRequest;
    bool current() =>
        FeatureScope.matches(scope, epoch) && request == _latestRequest;
    if (scope == null) return false;
    try {
      final raw = await (fetch ?? _fetchFlags)();
      if (!current() || raw == null) return false;
      final normalized = normalizeFlags(raw);
      if (normalized.isEmpty || normalized.length != raw.length) return false;
      final persisted = await ScopedPreferenceWriter.write(
        isCurrent: current,
        operation: () => StorageService.to.persistPreference(
          () => StorageService.setMap(
            FeatureScope.cacheKey(Keys.appFeatures, scope),
            normalized,
          ),
        ),
      );
      if (!persisted || !current()) return false;
      _cache = normalized;
      revision.value++;
      return true;
    } catch (error) {
      debugPrint('[app_feature_registry] setMap error: $error');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _fetchFlags() async {
    final IMBoyHttpResponse response = await HttpClient.client.get(
      API.appFeatures,
    );
    if (!response.ok || response.payload is! Map) return null;
    return Map<String, dynamic>.from(response.payload as Map);
  }

  static bool isEnabled(String featureKey) {
    if (featureKey.isEmpty) {
      return true;
    }
    if (!compiledProductFeatures.contains(featureKey)) {
      return false;
    }

    // 本地硬关闭优先于远程 snapshot
    if (_localDisabledKeys.contains(featureKey)) {
      return false;
    }

    final selfEnabled = _readFlag(snapshot, featureKey);
    if (!selfEnabled) {
      return false;
    }

    final parentFeature = _parentFeatures[featureKey];
    if (parentFeature == null) {
      return true;
    }
    return isEnabled(parentFeature);
  }

  static Map<String, dynamic> normalizeFlags(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final value = _toBool(entry.value);
      if (value != null) {
        normalized[entry.key] = value;
      }
    }
    return normalized;
  }

  static void replaceSnapshotForTest(Map<String, dynamic> raw) {
    _cache = Map<String, dynamic>.from(raw);
    revision.value++;
  }

  static bool _readFlag(Map<String, dynamic> flags, String featureKey) {
    final value = _toBool(flags[featureKey]);
    return value ?? featureKey == 'core';
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if ({'1', 'true', 'yes', 'on'}.contains(normalized)) {
        return true;
      }
      if ({'0', 'false', 'no', 'off'}.contains(normalized)) {
        return false;
      }
    }
    return null;
  }
}
