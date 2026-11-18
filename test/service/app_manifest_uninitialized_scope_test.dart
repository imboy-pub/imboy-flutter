@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native manifest without scope returns false before storage initialization',
    () async {
      // This target is a fresh isolate. Do not initialize storage, a feature scope,
      // HttpClient, serviceContainer or a synthetic auth reader for this regression.
      expect(FeatureScope.key, isNull);
      expect(
        () => StorageService.to.getString('synthetic_uninitialized'),
        throwsException,
      );
      expect(await AppManifestService.refresh(), isFalse);
      expect(FeatureScope.key, isNull);
      expect(
        () => StorageService.to.getString('synthetic_uninitialized'),
        throwsException,
      );
    },
  );
}
