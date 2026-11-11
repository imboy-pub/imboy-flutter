import 'package:flutter/foundation.dart';

/// 平台能力与第三方插件是否安装分开判断。
class LocationCapabilities {
  static bool supportsNearbyPeopleFor(
    TargetPlatform platform, {
    bool isWeb = false,
  }) =>
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  static bool get supportsNearbyPeople =>
      supportsNearbyPeopleFor(defaultTargetPlatform, isWeb: kIsWeb);
}
