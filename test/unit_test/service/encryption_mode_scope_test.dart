import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'A');
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });
  tearDown(() => EncryptionModeService.debugFetcher = null);

  test(
    'A late policy cannot initialize B or clear B in-flight request',
    () async {
      final a = Completer<Map<String, dynamic>>();
      final b = Completer<Map<String, dynamic>>();
      var calls = 0;
      EncryptionModeService.debugFetcher = () =>
          ++calls == 1 ? a.future : b.future;
      final first = EncryptionModeService.refresh();
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29921',
        uid: 'B',
      );
      expect(EncryptionModeService.isInitialized, isFalse);
      final second = EncryptionModeService.refresh();
      expect(calls, 2);
      a.complete({'storage_mode': 'archived', 'e2ee_mode': 'disabled'});
      await first;
      expect(EncryptionModeService.isInitialized, isFalse);
      final third = EncryptionModeService.refresh();
      expect(
        calls,
        2,
        reason: 'old A finally must not clear the active B future',
      );
      b.complete({'storage_mode': 'secure_e2ee', 'e2ee_mode': 'required'});
      await second;
      await third;
      expect(EncryptionModeService.isInitialized, isTrue);
      expect(EncryptionModeService.current, EncryptionMode.strictE2ee);
    },
  );

  test(
    'endpoint change discards initialization without changing mode rules',
    () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29931',
        uid: 'A',
      );
      expect(EncryptionModeService.isInitialized, isFalse);
      EncryptionModeService.debugFetcher = () async => {
        'storage_mode': 'disabled',
        'e2ee_mode': 'required',
      };
      await EncryptionModeService.refresh();
      expect(EncryptionModeService.isInitialized, isTrue);
      expect(EncryptionModeService.current, EncryptionMode.plaintext);
    },
  );
}
