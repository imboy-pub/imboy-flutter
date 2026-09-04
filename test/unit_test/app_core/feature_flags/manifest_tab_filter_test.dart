import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';

void main() {
  group('AppManifest.hasAppEntry', () {
    tearDown(() => AppManifestService.replaceForTest(<String, dynamic>{}));

    test('returns true when entry exists in app_entries', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['channel_tab', 'moment_tab'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      final manifest = AppManifestService.manifest!;
      expect(manifest.hasAppEntry('channel_tab'), isTrue);
      expect(manifest.hasAppEntry('moment_tab'), isTrue);
    });

    test('returns false when entry absent from app_entries', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['moment_tab'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      final manifest = AppManifestService.manifest!;
      expect(manifest.hasAppEntry('channel_tab'), isFalse);
    });

    test('empty app_entries returns false for any entry', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      final manifest = AppManifestService.manifest!;
      expect(manifest.hasAppEntry('channel_tab'), isFalse);
      expect(manifest.hasAppEntry('moment_tab'), isFalse);
    });

    test('replaceForTest({}) creates empty manifest, not null', () {
      AppManifestService.replaceForTest({});
      final manifest = AppManifestService.manifest;
      expect(manifest, isNotNull);
      expect(manifest!.appEntries, isEmpty);
      expect(manifest.hasAppEntry('channel_tab'), isFalse);
    });
  });

  group('AppManifest parsing edge cases', () {
    test('matching generated build metadata is accepted', () {
      final manifest = AppManifest.fromMap(<String, dynamic>{
        'manifest_hash': productFeatureManifestHash,
        'manifest_schema_version': productFeatureSchemaVersion,
        'compiled_features': compiledProductFeatures,
      });
      expect(manifest.ensureBuildCompatible, returnsNormally);
    });

    test('missing, malformed and mismatched contract fields fail closed', () {
      for (final raw in <Map<String, dynamic>>[
        {},
        {'manifest_hash': 'sha256:mismatch'},
        {'manifest_schema_version': 999},
        {'manifest_schema_version': 'not-an-int'},
        {'compiled_features': 'not-an-array'},
        {'compiled_features': <dynamic>[]},
        {
          'compiled_features': [123],
        },
        {
          'compiled_features': ['not_compiled'],
        },
      ]) {
        expect(
          AppManifest.fromMap(raw).ensureBuildCompatible,
          throwsA(isA<AppManifestMismatchException>()),
        );
      }
    });

    test('incompatible manifest is ignored without throwing', () {
      final accepted = AppManifestService.replaceIfCompatibleForTest(
        <String, dynamic>{'manifest_hash': 'sha256:stale'},
      );

      expect(accepted, isFalse);
      expect(AppManifestService.manifest, isNull);
    });

    test('missing app_entries key defaults to empty list', () {
      final manifest = AppManifest.fromMap(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
      });
      expect(manifest.appEntries, isEmpty);
      expect(manifest.hasAppEntry('channel_tab'), isFalse);
    });

    test('app_entries with mixed types coerced to strings', () {
      final manifest = AppManifest.fromMap(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': ['channel_tab', 123, true],
      });
      expect(manifest.appEntries, ['channel_tab', '123', 'true']);
    });

    test('toMap roundtrip preserves app_entries', () {
      final raw = <String, dynamic>{
        'features': <String, dynamic>{'channel': true},
        'policy': <String, dynamic>{},
        'app_entries': ['channel_tab'],
        'admin_entries': ['channels_page'],
        'plugins': <dynamic>[],
        'generated_at': 1234567890,
      };
      final manifest = AppManifest.fromMap(raw);
      expect(manifest.toMap()['app_entries'], ['channel_tab']);
      expect(manifest.toMap()['features'], {'channel': true});
    });
  });

  group('Tab visibility logic simulation', () {
    tearDown(() => AppManifestService.replaceForTest(<String, dynamic>{}));

    test('all enabled -> 4 tabs (conversation, contact, channel, mine)', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{'channel': true, 'moment': true},
        'policy': <String, dynamic>{},
        'app_entries': ['channel_tab', 'moment_tab'],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      final manifest = AppManifestService.manifest!;
      final tabCount = 3 + (manifest.hasAppEntry('channel_tab') ? 1 : 0);
      expect(tabCount, 4);
    });

    test('channel disabled -> 3 tabs (conversation, contact, mine)', () {
      AppManifestService.replaceForTest(<String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': <dynamic>[],
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      });
      final manifest = AppManifestService.manifest!;
      final tabCount = 3 + (manifest.hasAppEntry('channel_tab') ? 1 : 0);
      expect(tabCount, 3);
    });

    test('normalizeIndex clamps to dynamic tab count', () {
      int normalizeIndex(int value, int count) => value.clamp(0, count - 1);
      expect(normalizeIndex(0, 3), 0);
      expect(normalizeIndex(2, 3), 2);
      expect(normalizeIndex(3, 3), 2);
      expect(normalizeIndex(5, 3), 2);
      expect(normalizeIndex(-1, 3), 0);

      expect(normalizeIndex(3, 4), 3);
      expect(normalizeIndex(4, 4), 3);
    });
  });
}
