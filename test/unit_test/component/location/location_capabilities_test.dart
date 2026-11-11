import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/location/location_capabilities.dart';

void main() {
  test('nearby people is available only on native Android and iOS', () {
    for (final platform in TargetPlatform.values) {
      expect(
        LocationCapabilities.supportsNearbyPeopleFor(platform),
        platform == TargetPlatform.android || platform == TargetPlatform.iOS,
        reason: platform.name,
      );
      expect(
        LocationCapabilities.supportsNearbyPeopleFor(platform, isWeb: true),
        isFalse,
        reason: 'web on ${platform.name}',
      );
    }
  });
}
