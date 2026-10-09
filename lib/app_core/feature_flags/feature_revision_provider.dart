import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_feature_registry.dart';

/// Existing consumers rebuild when their account's validated flags change.
final featureRevisionProvider = Provider.autoDispose<int>((ref) {
  void changed() => ref.invalidateSelf();
  AppFeatureRegistry.revision.addListener(changed);
  ref.onDispose(() => AppFeatureRegistry.revision.removeListener(changed));
  return AppFeatureRegistry.revision.value;
});
