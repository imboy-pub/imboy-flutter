import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

import 'feature_keys.dart';

class AppFeatureRegistry {
  static Map<String, dynamic>? _cache;

  static const Map<String, String> _parentFeatures = {
    FeatureKeys.channelDiscover: FeatureKeys.channel,
    FeatureKeys.channelInvitation: FeatureKeys.channel,
    FeatureKeys.channelOrder: FeatureKeys.channel,
  };

  /// 本地硬关闭集合 — 优先级高于远程 snapshot，后端返回 true 也无效。
  /// 解除：后端 API 就绪后删除对应 key，功能代码无需恢复。
  /// 详见 docs/feature-status.md § 待后端支持（前端隐藏）
  static const Set<String> _localDisabledKeys = {
    FeatureKeys.wallet, // 后端待实现：/v1/wallet/{balance,transactions,topup}
    FeatureKeys.liveRoom, // 后端待实现：WHIP 服务器 + 直播列表 API
  };

  static Map<String, dynamic> get snapshot {
    _cache ??= Map<String, dynamic>.from(
      StorageService.getMap(Keys.appFeatures),
    );
    return _cache!;
  }

  static Future<void> clear() async {
    _cache = {};
    await StorageService.to.remove(Keys.appFeatures);
  }

  static Future<void> refresh() async {
    try {
      final IMBoyHttpResponse response = await HttpClient.client.get(
        API.appFeatures,
      );
      if (!response.ok || response.payload is! Map) {
        return;
      }

      final normalized = normalizeFlags(
        Map<String, dynamic>.from(response.payload as Map),
      );
      _cache = normalized;
      await StorageService.setMap(Keys.appFeatures, normalized);
    } catch (error) {}
  }

  static bool isEnabled(String featureKey) {
    if (featureKey.isEmpty) {
      return true;
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
  }

  static bool _readFlag(Map<String, dynamic> flags, String featureKey) {
    final value = _toBool(flags[featureKey]);
    return value ?? true;
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
