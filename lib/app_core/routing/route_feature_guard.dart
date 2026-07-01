import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';

/// Describes why a route was blocked.
enum RouteBlockReason { featureFlag, appEntry }

class RouteFeatureGuard {
  static bool _manifestRetryInFlight = false;

  /// manifest 为 null 时的自愈补偿：不能只拦截却不重试，否则离线冷启动后
  /// 若 WebSocket 一直连不上（没有 manifest_updated 事件触发刷新），用户会
  /// 永久卡在被拦截的路由上直到重启 App。这里在每次命中该分支时顺手补一次
  /// 后台刷新尝试；用 _manifestRetryInFlight 避免用户连续导航时重复发起。
  static void _retryManifestFetch() {
    if (_manifestRetryInFlight) return;
    _manifestRetryInFlight = true;
    unawaited(
      AppManifestService.refresh().whenComplete(
        () => _manifestRetryInFlight = false,
      ),
    );
  }

  static String? featureForPath(String path) {
    if (path == AppRoutes.momentFeed ||
        path == AppRoutes.momentCreate ||
        path.startsWith('${AppRoutes.momentRoot}/')) {
      return FeatureKeys.moment;
    }

    if (path == '/contact/people_nearby' ||
        path.startsWith('/contact/people_nearby/')) {
      return FeatureKeys.location;
    }

    if (path == '/channel' || path.startsWith('/channel/')) {
      if (path == '/channel/discover' ||
          path.startsWith('/channel/discover/')) {
        return FeatureKeys.channelDiscover;
      }
      if (path == '/channel/invitations' ||
          path.startsWith('/channel/invitations/')) {
        return FeatureKeys.channelInvitation;
      }
      return FeatureKeys.channel;
    }

    if (RegExp(r'^/group/[^/]+/vote(?:/|$)').hasMatch(path)) {
      return FeatureKeys.groupVote;
    }
    if (RegExp(r'^/group/[^/]+/schedule(?:/|$)').hasMatch(path)) {
      return FeatureKeys.groupSchedule;
    }
    if (RegExp(r'^/group/[^/]+/task(?:/|$)').hasMatch(path)) {
      return FeatureKeys.groupTask;
    }
    return null;
  }

  /// Map a route path to a manifest app entry name.
  /// Returns null if the path is not guarded by manifest entries.
  static String? appEntryForPath(String path) {
    if (path == AppRoutes.momentFeed ||
        path == AppRoutes.momentCreate ||
        path.startsWith('${AppRoutes.momentRoot}/')) {
      return 'moment_tab';
    }
    // NOTE: /channel/discover must be checked before the /channel/ wildcard.
    if (path == '/channel/discover' || path.startsWith('/channel/discover/')) {
      return 'channel_discover_page';
    }
    if (path == '/channel' || path.startsWith('/channel/')) {
      return 'channel_tab';
    }
    if (path == '/contact/people_nearby' ||
        path.startsWith('/contact/people_nearby/')) {
      return 'people_nearby_page';
    }
    if (RegExp(r'^/group/[^/]+/vote(?:/|$)').hasMatch(path)) {
      return 'group_vote_page';
    }
    if (RegExp(r'^/group/[^/]+/schedule(?:/|$)').hasMatch(path)) {
      return 'group_schedule_page';
    }
    if (RegExp(r'^/group/[^/]+/task(?:/|$)').hasMatch(path)) {
      return 'group_task_page';
    }
    return null;
  }

  /// Human-readable name for a feature key or app entry name.
  static String _displayName(String key) => switch (key) {
    FeatureKeys.moment || 'moment' || 'moment_tab' => t.discovery.moment,
    FeatureKeys.channel || 'channel' || 'channel_tab' => t.channel.title,
    FeatureKeys.channelDiscover ||
    'channel_discover_page' => t.channel.discover,
    FeatureKeys.channelInvitation => t.common.channelInvitations,
    FeatureKeys.location ||
    'location' ||
    'people_nearby_page' => t.discovery.findNearbyPeople,
    FeatureKeys.groupVote || 'group_vote_page' => t.groupVote.title,
    FeatureKeys.groupSchedule || 'group_schedule_page' => t.groupSchedule.title,
    FeatureKeys.groupTask || 'group_task_page' => t.groupTask.title,
    _ => '',
  };

  /// Combined check: manifest app_entries first, then feature flags.
  static ({String redirect, RouteBlockReason reason, String name})?
  checkBlocked({required bool isLoggedIn, required String currentPath}) {
    if (!isLoggedIn) return null;

    // Check manifest app_entries first (plugin-level gate)
    final appEntry = appEntryForPath(currentPath);
    if (appEntry != null) {
      final manifest = AppManifestService.manifest;
      // manifest 尚未加载完成时（冷启动竞态、首次安装离线等）保守拒绝，
      // 而非放行：避免短暂时序窗口绕过后端下发的 app_entry 禁用策略。
      // AppInitializer 已 await AppManifestService.refresh()，正常网络下
      // 用户进入任何可路由页面前 manifest 均已就绪，此分支仅在离线/异常
      // 场景触发。
      if (manifest == null || !manifest.hasAppEntry(appEntry)) {
        if (manifest == null) _retryManifestFetch();
        return (
          redirect: '/bottom_navigation',
          reason: RouteBlockReason.appEntry,
          name: _displayName(appEntry),
        );
      }
    }

    // Then check fine-grained feature flags
    final featureKey = featureForPath(currentPath);
    if (featureKey != null && !AppFeatureRegistry.isEnabled(featureKey)) {
      return (
        redirect: '/bottom_navigation',
        reason: RouteBlockReason.featureFlag,
        name: _displayName(featureKey),
      );
    }

    return null;
  }

  static String? redirectPath({
    required bool isLoggedIn,
    required String currentPath,
  }) {
    final result = checkBlocked(
      isLoggedIn: isLoggedIn,
      currentPath: currentPath,
    );
    return result?.redirect;
  }

  static void notifyDisabledFeatureRedirect(BuildContext context) {
    notifyBlocked(context, null);
  }

  static void notifyBlocked(
    BuildContext context,
    ({RouteBlockReason reason, String name})? detail,
  ) {
    Future<dynamic>.delayed(const Duration(milliseconds: 300), () {
      if (!context.mounted) return;
      final message = detail == null || detail.name.isEmpty
          ? t.common.featureNotEnabled
          : t.common.featureDisabledName(name: detail.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    });
  }
}
