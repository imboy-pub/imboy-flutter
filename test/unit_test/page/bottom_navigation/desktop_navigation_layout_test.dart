import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';

void main() {
  group('shouldUseCollapsibleDesktopNavigation', () {
    test('600–900pt 在 macOS / Windows / Linux 与 Web 启用', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          shouldUseCollapsibleDesktopNavigation(
            width: 688,
            platform: platform,
            isWeb: false,
          ),
          isTrue,
        );
      }
      expect(
        shouldUseCollapsibleDesktopNavigation(
          width: 688,
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        isTrue,
      );
    });

    test('iOS / Android 平板保留既有 Material NavigationRail', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          shouldUseCollapsibleDesktopNavigation(
            width: 688,
            platform: platform,
            isWeb: false,
          ),
          isFalse,
        );
      }
    });

    test('小于 600pt 与大于等于 900pt 不由个人壳紧凑导航接管', () {
      for (final width in [599.99, 900.0, 1200.0]) {
        expect(
          shouldUseCollapsibleDesktopNavigation(
            width: width,
            platform: TargetPlatform.macOS,
            isWeb: false,
          ),
          isFalse,
        );
      }
    });
  });
}
