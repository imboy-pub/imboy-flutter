import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'A');
    await AppFeatureRegistry.clear();
  });

  test('unknown optional features are hidden but core remains offline', () {
    expect(AppFeatureRegistry.isEnabled('core'), isTrue);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.e2ee), isFalse);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
  });

  test(
    'successful recovery enables phase1 baseline and honors false',
    () async {
      expect(
        await AppFeatureRegistry.refresh(
          fetch: () async => {
            'core': true,
            FeatureKeys.moment: true,
            FeatureKeys.location: true,
            FeatureKeys.project: false,
            'not_compiled': true,
          },
        ),
        isTrue,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isTrue);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.location), isTrue);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
      expect(AppFeatureRegistry.isEnabled('not_compiled'), isFalse);
    },
  );

  test(
    'same scoped valid cache is usable offline, B cannot inherit A',
    () async {
      await AppFeatureRegistry.refresh(
        fetch: () async => {
          FeatureKeys.moment: true,
          FeatureKeys.project: false,
        },
      );
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29921',
        uid: 'B',
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29921',
        uid: 'A',
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isTrue);
      expect(
        await AppFeatureRegistry.refresh(fetch: () async => null),
        isFalse,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isTrue);
    },
  );

  test('endpoint changes do not inherit cached flags', () async {
    await AppFeatureRegistry.refresh(
      fetch: () async => {FeatureKeys.moment: true},
    );
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29931', uid: 'A');
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
  });

  test('late A response cannot publish to B or persist as B flags', () async {
    final pending = Completer<Map<String, dynamic>?>();
    final request = AppFeatureRegistry.refresh(fetch: () => pending.future);
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'B');
    await AppFeatureRegistry.refresh(
      fetch: () async => {FeatureKeys.moment: false},
    );
    pending.complete({FeatureKeys.moment: true, FeatureKeys.project: true});
    expect(await request, isFalse);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29931', uid: 'B');
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'B');
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
  });

  test('remote false replaces cached true and missing is never true', () async {
    await AppFeatureRegistry.refresh(
      fetch: () async => {FeatureKeys.moment: true},
    );
    await AppFeatureRegistry.refresh(
      fetch: () async => {FeatureKeys.moment: false},
    );
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.location), isFalse);
  });

  test('malformed flags are not published as a successful snapshot', () async {
    expect(
      await AppFeatureRegistry.refresh(
        fetch: () async => {
          FeatureKeys.project: {'enabled': true},
        },
      ),
      isFalse,
    );
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
  });

  test(
    'same scope latest false wins over late older true and persisted cache',
    () async {
      final old = Completer<Map<String, dynamic>?>();
      final first = AppFeatureRegistry.refresh(fetch: () => old.future);
      expect(
        await AppFeatureRegistry.refresh(
          fetch: () async => {FeatureKeys.project: false},
        ),
        isTrue,
      );
      old.complete({FeatureKeys.project: true});
      expect(await first, isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29931',
        uid: 'A',
      );
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29921',
        uid: 'A',
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.project), isFalse);
    },
  );
}
