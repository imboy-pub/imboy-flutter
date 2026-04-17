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

  /// W1.5 稳定化 Sprint 本地硬关闭集合（2026-04-17）：
  /// 优先级高于远程 snapshot — 即使后端 payload 返回 true，此处仍强制关闭。
  /// 目的：稳定化期避免不完善功能暴露给 App Store 审核 + 早期用户。
  /// 解除：删除对应 key 即可恢复（功能代码保留）。
  ///
  /// 注：friendTag（好友分类）+ moment interactions（相册互动）已从本集合移除 —
  /// 用户决定在稳定化期继续完善这两项，而非隐藏。
  static const Set<String> _localDisabledKeys = {
    FeatureKeys.wallet,
    FeatureKeys.liveRoom,
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
        debugPrint(
          'AppFeatureRegistry: skip refresh, code=${response.code}, payload=${response.payload.runtimeType}',
        );
        return;
      }

      final normalized = normalizeFlags(
        Map<String, dynamic>.from(response.payload as Map),
      );
      _cache = normalized;
      await StorageService.setMap(Keys.appFeatures, normalized);
    } catch (error) {
      debugPrint('AppFeatureRegistry: refresh failed: $error');
    }
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
