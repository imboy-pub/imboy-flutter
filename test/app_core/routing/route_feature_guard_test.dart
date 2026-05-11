import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';

void main() {
  group('RouteFeatureGuard.appEntryForPath', () {
    test('returns moment for moment routes', () {
      expect(RouteFeatureGuard.appEntryForPath('/moment/feed'), 'moment');
      expect(RouteFeatureGuard.appEntryForPath('/moment/create'), 'moment');
      expect(RouteFeatureGuard.appEntryForPath('/moment/abc123'), 'moment');
    });

    test('returns channel for channel routes', () {
      expect(RouteFeatureGuard.appEntryForPath('/channel'), 'channel');
      expect(RouteFeatureGuard.appEntryForPath('/channel/xyz'), 'channel');
      expect(RouteFeatureGuard.appEntryForPath('/channel/discover'), 'channel');
    });

    test('returns location for people_nearby', () {
      expect(
        RouteFeatureGuard.appEntryForPath('/contact/people_nearby'),
        'location',
      );
    });

    test('returns null for unguarded paths', () {
      expect(RouteFeatureGuard.appEntryForPath('/chat/123'), isNull);
      expect(RouteFeatureGuard.appEntryForPath('/mine'), isNull);
      expect(RouteFeatureGuard.appEntryForPath('/settings'), isNull);
    });
  });

  group('RouteFeatureGuard.checkBlocked', () {
    setUp(() {
      AppFeatureRegistry.replaceSnapshotForTest({
        'moment': true,
        'channel': true,
        'channel_discover': true,
        'channel_invitation': true,
        'location': true,
        'group_vote': true,
        'group_schedule': true,
        'group_task': true,
      });
    });

    test('returns null when all features enabled and manifest has entries', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['moment', 'channel', 'location'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/moment/feed',
      );
      expect(result, isNull);
    });

    test('blocks when manifest lacks app entry', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['channel'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/moment/feed',
      );
      expect(result, isNotNull);
      expect(result!.redirect, '/bottom_navigation');
      expect(result.reason, RouteBlockReason.appEntry);
      expect(result.name, isNotEmpty);
    });

    test('blocks when feature flag disabled', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['moment'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      AppFeatureRegistry.replaceSnapshotForTest({
        'moment': false,
        'channel': true,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/moment/feed',
      );
      expect(result, isNotNull);
      expect(result!.reason, RouteBlockReason.featureFlag);
    });

    test('manifest check takes priority over feature flag', () {
      AppFeatureRegistry.replaceSnapshotForTest({'moment': true});
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/moment/feed',
      );
      expect(result, isNotNull);
      expect(result!.reason, RouteBlockReason.appEntry);
    });

    test('returns null when not logged in', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: false,
        currentPath: '/moment/feed',
      );
      expect(result, isNull);
    });

    test('unguarded path passes regardless of manifest', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/chat/123',
      );
      expect(result, isNull);
    });
  });

  group('RouteFeatureGuard.redirectPath', () {
    test('delegates to checkBlocked and returns redirect', () {
      AppFeatureRegistry.replaceSnapshotForTest({'moment': true});
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });

      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/moment/feed',
        ),
        '/bottom_navigation',
      );
    });
  });
}
