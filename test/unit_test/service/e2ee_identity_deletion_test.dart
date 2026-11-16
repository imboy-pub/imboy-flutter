import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/e2ee_backup_restore_state.dart';
import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _TemporaryPath extends PathProviderPlatform {
  _TemporaryPath(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final storage = StorageSecureService.to;
  late Map<String, String> entries;
  late Directory temporary;
  late PathProviderPlatform previousPathProvider;
  Future<void> Function(String key)? beforeWrite;
  Future<String?> Function(String key, Map<String, dynamic> args)? readOverride;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'synthetic-key-owner',
    });
    await StorageService.init();
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
    entries = {
      'e2ee_private_key': 'synthetic-current',
      'e2ee_public_key': 'synthetic-public',
      'e2ee_key_id': 'kid-current',
      'e2ee_private_key_history_old': 'synthetic-history',
      'e2ee_shard_s1': 'synthetic-shard',
      'e2ee_backup_passphrase': 'synthetic-passphrase',
      'db_cipher_key_synthetic-key-owner': 'retained-db-key',
      'olm_account_pickle': 'retained-olm',
      'secure_token': 'retained-token',
    };
    beforeWrite = null;
    readOverride = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return readOverride == null
              ? entries[key]
              : readOverride!(key!, args);
        case 'readAll':
          return Map.of(entries);
        case 'write':
          await beforeWrite?.call(key!);
          entries[key!] = args['value'] as String;
          return null;
        case 'delete':
          entries.remove(key);
          return null;
      }
      return null;
    });
    temporary = await Directory.systemTemp.createTemp('imboy-identity-delete-');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPath(temporary.path);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = previousPathProvider;
    await temporary.delete(recursive: true);
    EncrypterService.clearKeyCache();
  });

  test('production delete purges history, shards, passphrase, cache and temporary backups', () async {
    final session = authSessionReader.current;
    final backup = await File('${temporary.path}/imboy_e2ee_backup_fixture.enc')
        .writeAsString('encrypted');
    final unrelated = await File('${temporary.path}/keep.txt')
        .writeAsString('keep');
    EncrypterService.aesEncrypt(
      'fixture',
      '0123456789abcdef',
      'fedcba9876543210',
    );
    expect(EncrypterService.getKeyCacheStats()['cached_keys'], greaterThan(0));

    await storage.deleteAllE2EEKeys();

    expect(entries.keys.where((key) => key.startsWith('e2ee_')), isEmpty);
    expect(entries['db_cipher_key_synthetic-key-owner'], 'retained-db-key');
    expect(entries['olm_account_pickle'], 'retained-olm');
    expect(entries['secure_token'], 'retained-token');
    expect(authSessionReader.current, session);
    expect(EncrypterService.getKeyCacheStats()['cached_keys'], 0);
    expect(await backup.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });

  test(
    'delete waits for an in-flight native identity write before purging',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeWrite = (key) async {
        if (key == 'e2ee_private_key') {
          entered.complete();
          await release.future;
        }
      };
      final write = storage.writeE2eeKeys(
        storage.e2eeKeyGeneration,
        () => storage.savePrivateKey('synthetic-pending'),
      );
      final rejected = expectLater(write, throwsStateError);
      await entered.future;
      var deleted = false;
      final deletion = storage.deleteAllE2EEKeys().then((_) => deleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isFalse);
      release.complete();
      await rejected;
      await deletion;
      expect(entries.keys.where((key) => key.startsWith('e2ee_')), isEmpty);
    },
  );

  test('RSA generation started before deletion cannot recreate keys', () async {
    final generated = E2EEKeyService.generateKeyPair();
    final rejected = expectLater(generated, throwsException);
    await storage.deleteAllE2EEKeys();
    await rejected;
    expect(entries.keys.where((key) => key.startsWith('e2ee_')), isEmpty);
  });

  test(
    'late legacy Keychain read cannot migrate an erased private key back',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final entered = Completer<void>();
      final legacy = Completer<String?>();
      readOverride = (key, args) async {
        if (key != 'e2ee_private_key') return entries[key];
        if ((args['options'] as Map)['accessibility'] != 'unlocked')
          return null;
        entered.complete();
        return legacy.future;
      };
      final read = storage.getPrivateKey();
      await entered.future;
      await storage.deleteAllE2EEKeys();
      legacy.complete('synthetic-erased-legacy-key');
      expect(await read, isNull);
      expect(entries.keys.where((key) => key.startsWith('e2ee_')), isEmpty);
    },
  );

  test('late restore and backup receipt cannot overwrite keys created after deletion', () async {
    final session = authSessionReader.current;
    final oldGeneration = storage.e2eeKeyGeneration;
    await storage.deleteAllE2EEKeys();
    await storage.writeE2eeKeys(storage.e2eeKeyGeneration, () async {
      await storage.savePrivateKey('synthetic-new-private');
      await storage.savePublicKey('synthetic-new-public');
      await storage.setKeyId('synthetic-new-kid');
    });
    final afterDelete = Map.of(entries);
    await expectLater(
      E2eeBackupRestoreState.saveIdentity(
        {
          'private_key': 'old-private',
          'public_key': 'old-public',
          'key_id': 'old-kid',
        },
        session,
        keyGeneration: oldGeneration,
      ),
      throwsStateError,
    );
    await expectLater(
      E2EEBackupSetupService.to.completeSetup(
        passphrase: 'old-passphrase',
        uid: session.uid,
        generation: session.generation,
        keyGeneration: oldGeneration,
      ),
      throwsStateError,
    );
    expect(entries, afterDelete);
    expect(authSessionReader.current, session);
  });
}
