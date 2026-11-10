import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final history = LoginAccountHistoryService();
  final repo = UserRepoLocal.to;
  const account = 'synthetic-selected';
  const uid = 'synthetic-uid';
  const draft = 'draft_v2:$uid:C2C:peer';
  const channels = [
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
  ];
  late List<String> storageCalls;
  late LoginAccountIdentity identity;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.loginHistoryAccount: [account],
      draft: 'original synthetic draft',
    });
    await StorageService.init();
    repo.clearAuthTransitionFailureForTest();
    identity = await history.rememberLogin(
      account: account,
      profile: {'user_id': uid},
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
      storageWasUnusedAtStartup: true,
    );
    storageCalls = [];
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            storageCalls.add('${channel.name}:${call.method}');
            throw StateError('Cleanup must reject before storage access');
          });
    }
  });
  tearDown(() {
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  for (final scenario in ['new owner', 'old writer', 'new session']) {
    test('cleanup reloads a $scenario written outside its preference cache', () async {
      final cachedRegistry = StorageService.to.getString(
        LoginAccountHistoryService.storageKey,
      );
      final document = jsonDecode(cachedRegistry) as Map<String, dynamic>;
      final accounts = document['accounts'] as List;
      if (scenario == 'new owner') {
        accounts.add({
          'uid': uid,
          'environment': currentEnv,
          'endpoint': 'https://retained.example.test/api',
          'aliases': ['retained'],
        });
      } else if (scenario == 'old writer') {
        (accounts.single as Map).remove('storageOwnershipVerified');
      }
      // Mutate the backing store directly, as a separate cached client would.
      // The active StorageService instance deliberately retains its old cache.
      final backing = SharedPreferencesStorePlatform.instance;
      await backing.setValue(
        'String',
        'flutter.${LoginAccountHistoryService.storageKey}',
        jsonEncode(document),
      );
      await backing.setValue('String', 'flutter.$draft', 'other client draft');
      if (scenario == 'new session') {
        await backing.setValue('String', 'flutter.${Keys.currentUid}', uid);
      }
      final preserved = await backing.getAll();
      expect(
        StorageService.to.getString(LoginAccountHistoryService.storageKey),
        cachedRegistry,
      );
      expect(StorageService.to.getString(draft), 'original synthetic draft');
      expect(
        () => history.requireIndependentStorage(identity),
        returnsNormally,
      );
      expect(repo.isLoggedIn, isFalse);

      await expectLater(
        Future<void>.sync(() => repo.clearHistoricalAccountData(account)),
        throwsA(switch (scenario) {
          'new owner' => isA<LoginAccountSharedDataException>(),
          'old writer' => isA<AccountLocalDataOwnershipException>(),
          _ => isA<LoginAccountCleanupBusyException>(),
        }),
      );
      expect(storageCalls, isEmpty);
      expect(await backing.getAll(), preserved);
      expect(StorageService.to.getString(draft), 'other client draft');
      expect(repo.isAuthTransitioning, isFalse);
    });
  }
}
