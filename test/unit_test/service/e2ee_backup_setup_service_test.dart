import 'dart:async';
import 'dart:convert';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 路径3 编排服务：首启判定 / 完成回执 / 换号防呆 / 无口令跳过自动重传。
///
/// 安全存储用可持久化的 mock（helper 的 sqflite_test_helper 固定返 null，
/// 读不回写不进，无法覆盖「缓存口令→再读出」链）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String?>{};
  final deletedKeys = <String>[];
  Future<String?> Function(String key, String? value)? interceptRead;

  setUp(() async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: true});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    secureStore.clear();
    deletedKeys.clear();
    interceptRead = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            switch (call.method) {
              case 'write':
                final args = call.arguments as Map<Object?, Object?>;
                secureStore[args['key'] as String] = args['value'] as String?;
                return null;
              case 'read':
                final args = call.arguments as Map<Object?, Object?>;
                final key = args['key'] as String;
                final value = secureStore[key];
                return interceptRead == null
                    ? value
                    : await interceptRead!(key, value);
              case 'delete':
                final args = call.arguments as Map<Object?, Object?>;
                deletedKeys.add(args['key'] as String);
                secureStore.remove(args['key'] as String);
                return null;
              case 'containsKey':
                final args = call.arguments as Map<Object?, Object?>;
                return secureStore.containsKey(args['key'] as String);
              default:
                return null;
            }
          },
        );
    E2EEBackupSetupService.to.resetPromptGuardForTest();
    await StorageService.to.setBool(kE2eeBackupSetupDoneKey, false);
  });

  tearDown(() async {
    AppFeatureRegistry.replaceSnapshotForTest({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  /// 预置本机已有 E2EE 密钥（私钥/公钥写进安全存储）
  Future<void> seedKeys() async {
    await StorageSecureService.to.savePrivateKey('-----BEGIN PRIVATE KEY');
    await StorageSecureService.to.savePublicKey('-----BEGIN PUBLIC KEY');
  }

  group('needsSetup', () {
    test('无密钥 → false', () async {
      expect(await E2EEBackupSetupService.to.needsSetup(), isFalse);
    });

    test('有密钥且未完成设置 → true', () async {
      await seedKeys();
      expect(await E2EEBackupSetupService.to.needsSetup(), isTrue);
    });

    test('已完成设置 → 恒 false', () async {
      await seedKeys();
      await StorageService.to.setString(
        Keys.currentUid,
        'synthetic-backup-owner',
      );
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'x');
      expect(await E2EEBackupSetupService.to.needsSetup(), isFalse);
    });
  });

  group('shouldPromptNow', () {
    test('关闭时不请求备份也不标记完成，恢复开启后仍可提示', () async {
      await seedKeys();
      final api = _FakeBackupApi();
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: false});
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(api: api),
        isFalse,
      );
      expect(api.infoCalls, 0);
      expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: true});
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(api: api),
        compiledProductFeatures.contains(FeatureKeys.e2ee),
      );
      expect(
        api.infoCalls,
        compiledProductFeatures.contains(FeatureKeys.e2ee) ? 1 : 0,
      );
      expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);
    });

    test('备份查询期间关闭时不弹出，也不改写完成标记', () async {
      await seedKeys();
      final pending = Completer<E2EEBackupInfo>();
      final api = _FakeBackupApi(pendingInfo: pending.future);
      final result = E2EEBackupSetupService.to.shouldPromptNow(api: api);
      if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
        expect(await result, isFalse);
        expect(api.infoCalls, 0);
        expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);
        return;
      }
      await api.infoStarted.future;
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: false});
      pending.complete(const E2EEBackupInfo(hasBackup: true, backupVersion: 1));
      expect(await result, isFalse);
      expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);
    });
    test('服务端已有备份 → 静默补完成标记并返回 false', () async {
      await seedKeys();
      final api = _FakeBackupApi(hasBackup: true);
      final prompt = await E2EEBackupSetupService.to.shouldPromptNow(api: api);
      expect(prompt, isFalse);
      expect(
        StorageService.to.getBool(kE2eeBackupSetupDoneKey),
        compiledProductFeatures.contains(FeatureKeys.e2ee),
      );
      expect(
        api.infoCalls,
        compiledProductFeatures.contains(FeatureKeys.e2ee) ? 1 : 0,
      );
    });

    test('服务端无备份 → true；推过一次后本次会话不再推', () async {
      await seedKeys();
      final api = _FakeBackupApi(hasBackup: false);
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(api: api),
        compiledProductFeatures.contains(FeatureKeys.e2ee),
      );
      expect(
        api.infoCalls,
        compiledProductFeatures.contains(FeatureKeys.e2ee) ? 1 : 0,
      );
      E2EEBackupSetupService.to.markPrompted();
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(
          api: _FakeBackupApi(hasBackup: false),
        ),
        isFalse,
      );
    });

    test('info() 网络失败 → false（本次不打扰）', () async {
      await seedKeys();
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(
          api: _FakeBackupApi(throws: true),
        ),
        isFalse,
      );
    });
  });

  group('completeSetup / cachedPassphrase', () {
    test('回执后口令可读回（同账号）', () async {
      await StorageService.to.setString(Keys.currentUid, '1000000056');
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'secret-1');
      expect(await E2EEBackupSetupService.to.cachedPassphrase(), 'secret-1');
      expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isTrue);
    });

    test('空会话（uid 未落库）：读不到但不误删缓存', () async {
      // 测试环境 currentUid 为空串 ≠ 'user-A'——视为会话未知，
      // 只拒绝返回，不清除（口令是用户唯一的恢复凭据副本）
      await StorageService.to.setString(Keys.currentUid, 'user-A');
      await E2EEBackupSetupService.to.completeSetup(
        passphrase: 'old-user-pwd',
        uid: 'user-A',
      );
      await StorageService.to.remove(Keys.currentUid);
      expect(await E2EEBackupSetupService.to.cachedPassphrase(), isNull);
      expect(secureStore.containsKey(kE2eeBackupPassphraseSecureKey), isTrue);
    });

    test('换号防呆：已登录账号与缓存归属不同 → 读不到并清除', () async {
      await StorageService.to.setString(Keys.currentUid, 'user-A');
      await E2EEBackupSetupService.to.completeSetup(
        passphrase: 'old-user-pwd',
        uid: 'user-A',
      );
      await StorageService.to.setString(Keys.currentUid, 'user-B');
      expect(await E2EEBackupSetupService.to.cachedPassphrase(), isNull);
      expect(secureStore.containsKey(kE2eeBackupPassphraseSecureKey), isFalse);
    });

    test('A 的迟到口令读取不能返回或删除 B 的新口令', () async {
      await StorageService.to.setString(Keys.currentUid, 'user-A');
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'A-passphrase');
      final reading = Completer<void>(), release = Completer<void>();
      interceptRead = (key, value) async {
        if (key == kE2eeBackupPassphraseSecureKey && !reading.isCompleted) {
          reading.complete();
          await release.future;
        }
        return value;
      };
      final pending = E2EEBackupSetupService.to.cachedPassphrase();
      await reading.future;
      await StorageService.to.setString(Keys.currentUid, 'user-B');
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'B-passphrase');
      release.complete();
      expect(await pending, isNull);
      expect(deletedKeys, isEmpty);
      expect(
        await E2EEBackupSetupService.to.cachedPassphrase(),
        'B-passphrase',
      );
    });

    test('删除旧口令前在会话写入队列内复核原始值', () async {
      await StorageService.to.setString(Keys.currentUid, 'user-B');
      secureStore[kE2eeBackupPassphraseSecureKey] = jsonEncode({
        'uid': 'user-A',
        'passphrase': 'A-passphrase',
      });
      final session = authSessionReader.current;
      final entered = Completer<void>(), release = Completer<void>();
      final firstRead = Completer<void>();
      interceptRead = (key, value) async {
        if (key == kE2eeBackupPassphraseSecureKey && !firstRead.isCompleted) {
          firstRead.complete();
        }
        return value;
      };
      final writer = UserRepoLocal.to.writeSessionSecret(
        uid: session.uid,
        generation: session.generation,
        write: () async {
          entered.complete();
          await release.future;
          secureStore[kE2eeBackupPassphraseSecureKey] = jsonEncode({
            'uid': 'user-B',
            'passphrase': 'B-passphrase',
          });
        },
        discard: () async {},
      );
      await entered.future;
      final staleRead = E2EEBackupSetupService.to.cachedPassphrase();
      await firstRead.future;
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await writer;
      expect(await staleRead, isNull);
      expect(deletedKeys, isEmpty);
      expect(
        await E2EEBackupSetupService.to.cachedPassphrase(),
        'B-passphrase',
      );
    });

    test(
      'a late backup completion cannot restore a cleared account secret',
      () async {
        await StorageService.to.setString(Keys.currentUid, 'user-A');
        await StorageService.to.remove(Keys.currentUid);
        await expectLater(
          E2EEBackupSetupService.to.completeSetup(
            passphrase: 'synthetic-late-passphrase',
            uid: 'user-A',
          ),
          throwsStateError,
        );
        expect(secureStore, isEmpty);
        expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);
      },
    );
  });

  group('uploadWithCachedPassphrase', () {
    test('无缓存口令 → 直接跳过（ok:false，不发请求）', () async {
      final result = await E2EEBackupSetupService.to
          .uploadWithCachedPassphrase();
      expect(result.ok, isFalse);
    });

    test('有口令但密钥缺失 → 跳过（ok:false，不发请求）', () async {
      await StorageService.to.setString(Keys.currentUid, '1000000056');
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'secret-1');
      final result = await E2EEBackupSetupService.to.uploadWithCachedPassphrase(
        api: _FakeBackupApi(hasBackup: false),
      );
      expect(result.ok, isFalse);
    });

    test('读取密钥期间换号不混用 A 口令和 B 密钥上传', () async {
      await StorageService.to.setString(Keys.currentUid, 'user-A');
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'A-passphrase');
      await seedKeys();
      final reading = Completer<void>(), release = Completer<void>();
      interceptRead = (key, value) async {
        if (key == 'e2ee_public_key' && !reading.isCompleted) {
          reading.complete();
          await release.future;
        }
        return value;
      };
      final api = _FakeBackupApi();
      final upload = E2EEBackupSetupService.to.uploadWithCachedPassphrase(
        api: api,
      );
      await reading.future;
      await StorageService.to.setString(Keys.currentUid, 'user-B');
      secureStore['e2ee_private_key'] = 'B-private';
      secureStore['e2ee_public_key'] = 'B-public';
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'B-passphrase');
      release.complete();
      expect((await upload).ok, isFalse);
      expect(api.infoCalls, 0);
      expect(secureStore['e2ee_private_key'], 'B-private');
      expect(
        await E2EEBackupSetupService.to.cachedPassphrase(),
        'B-passphrase',
      );
    });

    for (final key in ['e2ee_device_id', 'e2ee_key_id']) {
      test('清理等待准备阶段 $key 读取并阻止后续上传', () async {
        await StorageService.to.setString(Keys.currentUid, 'user-A');
        await E2EEBackupSetupService.to.completeSetup(
          passphrase: 'A-passphrase',
        );
        await seedKeys();
        secureStore['e2ee_device_id'] = 'A-device';
        secureStore['e2ee_key_id'] = 'A-key';
        final owner = AccountLocalTaskOwner.capture();
        final reading = Completer<void>(), release = Completer<void>();
        interceptRead = (readKey, value) async {
          if (readKey == key && !reading.isCompleted) {
            reading.complete();
            await release.future;
          }
          return value;
        };
        final api = _FakeBackupApi();
        final upload = E2EEBackupSetupService.to.uploadWithCachedPassphrase(
          api: api,
        );
        await reading.future;
        final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
        addTearDown(cleanup.release);
        var drained = false;
        final stopped = cleanup.stopped.then((_) => drained = true);
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse);
        await StorageService.to.remove(Keys.currentUid);
        release.complete();
        expect((await upload).ok, isFalse);
        await stopped;
        expect(api.infoCalls, 0);
        expect(drained, isTrue);
      });
    }
  });
}

class _FakeBackupApi implements E2EEBackupApi {
  _FakeBackupApi({
    this.hasBackup = false,
    this.throws = false,
    this.pendingInfo,
  });

  final Future<E2EEBackupInfo>? pendingInfo;
  int infoCalls = 0;
  final infoStarted = Completer<void>();

  final bool hasBackup;
  final bool throws;

  @override
  Future<E2EEBackupInfo> info({CancelToken? cancelToken}) async {
    infoCalls++;
    if (!infoStarted.isCompleted) infoStarted.complete();
    if (pendingInfo != null) return pendingInfo!;
    if (throws) {
      throw Exception('network down');
    }
    return E2EEBackupInfo(
      hasBackup: hasBackup,
      backupVersion: hasBackup ? 3 : 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
