import 'package:flutter/material.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';

/// Describes why a route was blocked.
enum RouteBlockReason { featureFlag, appEntry }

class RouteFeatureGuard {
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
      if (manifest != null && !manifest.hasAppEntry(appEntry)) {
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
