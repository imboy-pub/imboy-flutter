import 'package:flutter/material.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';

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

  static String? redirectPath({
    required bool isLoggedIn,
    required String currentPath,
  }) {
    if (!isLoggedIn) {
      return null;
    }

    final featureKey = featureForPath(currentPath);
    if (featureKey != null && !AppFeatureRegistry.isEnabled(featureKey)) {
      return '/bottom_navigation';
    }
    return null;
  }

  static void notifyDisabledFeatureRedirect(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(t.featureNotEnabled),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
}
