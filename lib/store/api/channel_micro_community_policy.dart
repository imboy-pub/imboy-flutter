import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';

abstract final class ChannelMicroCommunityPolicy {
  /// Fail closed for stale manifests, delivery profiles and disabled channel flags.
  static bool get enabled {
    final manifest = AppManifestService.manifest;
    final profile = manifest?.policy['profile'];
    return const {
          'community',
          'enterprise',
          'overseas_baseline',
        }.contains(profile) &&
        manifest?.features[FeatureKeys.channel] == true &&
        AppFeatureRegistry.isEnabled(FeatureKeys.channel);
  }
}
