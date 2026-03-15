import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/routes.dart';

void main() {
  test('normalizes supported feature flag payload values', () {
    final normalized = AppFeatureRegistry.normalizeFlags({
      FeatureKeys.channel: true,
      FeatureKeys.channelDiscover: 1,
      FeatureKeys.channelInvitation: 'off',
      FeatureKeys.channelOrder: 'YES',
      'ignored': {'enabled': true},
    });

    expect(
      normalized,
      {
        FeatureKeys.channel: true,
        FeatureKeys.channelDiscover: true,
        FeatureKeys.channelInvitation: false,
        FeatureKeys.channelOrder: true,
      },
    );
  });

  test('inherits parent feature state for child features', () {
    AppFeatureRegistry.replaceSnapshotForTest({
      FeatureKeys.channel: false,
      FeatureKeys.channelDiscover: true,
    });

    expect(AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover), isFalse);
  });

  test('maps route paths to feature keys', () {
    expect(
      RouteFeatureGuard.featureForPath('/channel/discover'),
      FeatureKeys.channelDiscover,
    );
    expect(
      RouteFeatureGuard.featureForPath('${AppRoutes.momentRoot}/m1'),
      FeatureKeys.moment,
    );
    expect(
      RouteFeatureGuard.featureForPath('/group/g1/task/detail'),
      FeatureKeys.groupTask,
    );
    expect(RouteFeatureGuard.featureForPath('/chat/u1'), isNull);
  });

  test('returns bottom navigation redirect for disabled feature routes', () {
    AppFeatureRegistry.replaceSnapshotForTest({
      FeatureKeys.moment: false,
    });

    expect(
      RouteFeatureGuard.redirectPath(
        isLoggedIn: true,
        currentPath: AppRoutes.momentFeed,
      ),
      '/bottom_navigation',
    );
  });
}
