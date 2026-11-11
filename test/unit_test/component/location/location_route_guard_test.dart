import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('desktop blocks nearby people routes', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      for (final path in [
        '/contact/people_nearby',
        '/contact/people_nearby/detail',
      ]) {
        expect(
          RouteFeatureGuard.checkBlocked(
            isLoggedIn: true,
            currentPath: path,
          )?.redirect,
          '/bottom_navigation',
        );
      }
    }
  });
}
