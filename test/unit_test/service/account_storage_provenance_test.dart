import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_data_service.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/pending_chat_actions.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const selected = LoginAccountIdentity(
    uid: 'legacy-uid',
    environment: 'pro',
    endpoint: 'https://selected.example.test/api',
    aliases: {'selected'},
  );
  const fresh = LoginAccountIdentity(
    uid: 'new-uid',
    environment: 'pro',
    endpoint: 'https://selected.example.test/api',
    aliases: {'new'},
  );
  final history = LoginAccountHistoryService();
  late Directory root;
  late Map<String, String> secure;
  late int destructiveCalls;

  String digest(List<String> values) =>
      sha256.convert(utf8.encode(jsonEncode(values))).toString();
  Future<File> file(String relative) async {
    final result = File(p.join(root.path, relative));
    await result.parent.create(recursive: true);
    await result.writeAsString('synthetic preserved bytes');
    return result;
  }

  AccountLocalDataService service({bool failRead = false}) =>
      AccountLocalDataService(
        databaseDirectory: () async => Directory(p.join(root.path, 'db')),
        supportDirectory: () async => Directory(p.join(root.path, 'support')),
        cacheDirectory: () async => Directory(p.join(root.path, 'cache')),
        documentsDirectory: () async =>
            Directory(p.join(root.path, 'documents')),
        temporaryDirectory: () async =>
            Directory(p.join(root.path, 'temporary')),
        systemTemporaryDirectory: () async =>
            Directory(p.join(root.path, 'temporary')),
        waitForDatabaseInitialization: () async {},
        readSecure: () async {
          if (failRead) throw StateError('synthetic unavailable secure store');
          return Map.of(secure);
        },
        deleteSecure: (_) async {
          destructiveCalls++;
        },
        closeDatabase: (_, _) async {
          destructiveCalls++;
        },
        deleteDatabase: (_, _) async {
          destructiveCalls++;
        },
      );
  Future<void> capture({bool failRead = false}) =>
      AccountLocalDataService.captureInitialOwnership(
        inventoryService: service(failRead: failRead),
      );
  bool unused(LoginAccountIdentity identity) =>
      AccountLocalDataService.wasStorageUnusedAtStartup(identity);
  Future<LoginAccountIdentity> remember(LoginAccountIdentity identity) =>
      history.rememberLogin(
        account: identity.aliases.single,
        profile: {'user_id': identity.uid},
        environment: identity.environment,
        endpoint: identity.endpoint,
        storageWasUnusedAtStartup: unused(identity),
      );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('imboy-provenance-');
    secure = {};
    destructiveCalls = 0;
    AccountLocalDataService.resetInitialOwnershipForTest();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  tearDown(() async {
    expect(destructiveCalls, 0);
    AccountLocalDataService.resetInitialOwnershipForTest();
    await root.delete(recursive: true);
  });

  test('fresh UID on an old installation gets durable account-scoped proof', () async {
    await file('db/pro_${selected.uid}.db');
    secure['db_cipher_key_${selected.uid}'] = 'synthetic old key';
    await StorageService.to.setString(
      'draft_v2:${selected.uid}:peer',
      'old draft',
    );
    await StorageService.to.setString('theme', 'dark');
    await StorageService.setMap(Keys.currentUser, {
      'user_id': selected.uid,
      LoginAccountHistoryService.localProfileKey: selected.toJson(),
    });
    secure['secure_token'] = 'synthetic old token';
    await capture();
    expect(unused(selected), isFalse);
    expect(unused(fresh), isTrue);
    final account = await remember(fresh);
    await file('db/pro_${fresh.uid}.db');
    secure['db_cipher_key_${fresh.uid}'] = 'synthetic new key';
    expect(() => history.requireIndependentStorage(account), returnsNormally);
    // A later startup sees data; it must preserve rather than re-create proof.
    AccountLocalDataService.resetInitialOwnershipForTest();
    await capture();
    expect(unused(fresh), isFalse);
    final again = await remember(fresh);
    expect(again.storageOwnershipVerified, isTrue);
    expect(() => history.requireIndependentStorage(again), returnsNormally);
    expect(
      await File(p.join(root.path, 'db/pro_${selected.uid}.db')).readAsString(),
      'synthetic preserved bytes',
    );
    expect(StorageService.to.getString('theme'), 'dark');
  });
  for (final suffix in [
    '',
    '-wal',
    '-shm',
    '-journal',
    '.pre_restore.bak',
    '.restoring.tmp-wal',
    '.restore.interrupted/original.db',
  ]) {
    test(
      'standalone legacy DB artifact $suffix blocks certification',
      () async {
        final original = await file('db/pro_${selected.uid}.db$suffix');
        await capture();
        expect(unused(selected), isFalse);
        expect(unused(fresh), isTrue);
        final identity = await remember(selected);
        expect(
          () => history.requireIndependentStorage(identity),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        expect(await original.readAsString(), 'synthetic preserved bytes');
      },
    );
  }
  test(
    'another historical environment with the same UID is not fresh storage',
    () async {
      await file('db/retired_environment_${selected.uid}.db-journal');
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
    },
  );
  test('an orphan snapshot blocks certification without a database or key', () async {
    await file(
      'support/imboy_db_snapshots/retired_environment/${selected.uid}/snapshot.db',
    );
    await capture();
    expect(unused(selected), isFalse);
  });
  test(
    'an orphan UID upload cache blocks certification without a key',
    () async {
      final scope = sha256
          .convert(utf8.encode('pro:${selected.uid}'))
          .toString();
      await file('cache/attachment_uploads/$scope/upload.bin');
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
    },
  );
  test('endpoint and UID recording data is not independent of the environment', () async {
    await file(
      'support/talk_record/${digest([selected.endpoint, selected.uid])}/audio/session/file.enc',
    );
    await capture();
    expect(unused(selected), isFalse);
    expect(unused(fresh), isTrue);
  });
  for (final key in [
    'db_cipher_key_${selected.uid}',
    'utk_pro:${selected.uid}:synthetic',
    'talk_record_ai_v1_${digest([Uri.parse(selected.endpoint).origin, selected.uid])}_checkpoint',
  ]) {
    test('standalone secure entry $key blocks certification', () async {
      secure[key] = 'synthetic secret';
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
      expect(secure, {key: 'synthetic secret'});
    });
  }
  for (final key in [
    'draft_v2:${selected.uid}:C2C:peer',
    'draftCursor_v2:${selected.uid}:C2C:peer',
    'org_current_${selected.uid}',
    'quick_replies:${selected.uid}',
  ]) {
    test('standalone legacy preference $key blocks certification', () async {
      await StorageService.to.setString(key, 'synthetic data');
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
      expect(StorageService.to.getString(key), 'synthetic data');
    });
  }
  for (final key in [
    PendingChatActions.readReceiptsKey,
    PendingChatActions.reactionsKey,
    'ws_message_queue',
  ]) {
    test('persisted sender ownership in $key blocks certification', () async {
      final entry = jsonEncode({
        key == 'ws_message_queue' ? 'ownerUid' : 'from': selected.uid,
      });
      if (key == 'ws_message_queue') {
        await StorageService.to.setList(key, [entry]);
      } else {
        await StorageService.to.setString(key, '[$entry]');
      }
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
    });
  }
  test('failed startup inventory can retry before login and preserve later cleanup', () async {
    expect(unused(fresh), isFalse);
    await expectLater(
      capture(failRead: true),
      throwsA(isA<AccountStorageInventoryUnavailableException>()),
    );
    expect(unused(fresh), isFalse);
    expect(StorageService.to.getKeys(), isEmpty);
    expect(secure, isEmpty);
    await capture();
    expect(unused(fresh), isTrue);
    final identity = await remember(fresh);
    await StorageService.setMap(Keys.currentUser, {
      'user_id': fresh.uid,
      LoginAccountHistoryService.localProfileKey: identity.toJson(),
    });
    await file('db/pro_${fresh.uid}.db');
    secure['db_cipher_key_${fresh.uid}'] = 'synthetic new key';
    AccountLocalDataService.resetInitialOwnershipForTest();
    await capture();
    expect(unused(fresh), isFalse);
    final restored = await remember(fresh);
    expect(restored.storageOwnershipVerified, isTrue);
    expect(() => history.requireIndependentStorage(restored), returnsNormally);
  });
  test(
    'later deletion of old evidence cannot rewrite the startup snapshot',
    () async {
      final original = await file('db/pro_${selected.uid}.db');
      await capture();
      await original.delete();
      await capture();
      expect(unused(selected), isFalse);
      expect(unused(fresh), isTrue);
    },
  );
  test(
    'every post-startup endpoint remains an owner even after alias transfer',
    () async {
      final remote = LoginAccountIdentity(
        uid: selected.uid,
        environment: 'pro',
        endpoint: 'https://remote.example.test/api',
        aliases: {'remote'},
      );
      await capture();
      final first = await remember(selected);
      final second = await remember(remote);
      await history.rememberLogin(
        account: 'remote',
        profile: {'user_id': 'replacement'},
        environment: remote.environment,
        endpoint: remote.endpoint,
      );
      for (final identity in [first, second]) {
        expect(
          () => history.requireIndependentStorage(identity),
          throwsA(isA<LoginAccountSharedDataException>()),
        );
      }
    },
  );
}
