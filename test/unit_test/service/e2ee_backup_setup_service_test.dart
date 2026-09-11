import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';

/// 路径3 编排服务：首启判定 / 完成回执 / 换号防呆 / 无口令跳过自动重传。
///
/// 安全存储用可持久化的 mock（helper 的 sqflite_test_helper 固定返 null，
/// 读不回写不进，无法覆盖「缓存口令→再读出」链）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String?>{};

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    secureStore.clear();
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
                return secureStore[args['key'] as String];
              case 'delete':
                final args = call.arguments as Map<Object?, Object?>;
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
      await E2EEBackupSetupService.to.completeSetup(passphrase: 'x');
      expect(await E2EEBackupSetupService.to.needsSetup(), isFalse);
    });
  });

  group('shouldPromptNow', () {
    test('服务端已有备份 → 静默补完成标记并返回 false', () async {
      await seedKeys();
      final prompt = await E2EEBackupSetupService.to.shouldPromptNow(
        api: _FakeBackupApi(hasBackup: true),
      );
      expect(prompt, isFalse);
      expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isTrue);
    });

    test('服务端无备份 → true；推过一次后本次会话不再推', () async {
      await seedKeys();
      expect(
        await E2EEBackupSetupService.to.shouldPromptNow(
          api: _FakeBackupApi(hasBackup: false),
        ),
        isTrue,
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
      await E2EEBackupSetupService.to.completeSetup(
        passphrase: 'old-user-pwd',
        uid: 'user-A',
      );
      expect(await E2EEBackupSetupService.to.cachedPassphrase(), isNull);
      expect(secureStore.containsKey(kE2eeBackupPassphraseSecureKey), isTrue);
    });

    test('换号防呆：已登录账号与缓存归属不同 → 读不到并清除', () async {
      await E2EEBackupSetupService.to.completeSetup(
        passphrase: 'old-user-pwd',
        uid: 'user-A',
      );
      await StorageService.to.setString(Keys.currentUid, 'user-B');
      expect(await E2EEBackupSetupService.to.cachedPassphrase(), isNull);
      expect(secureStore.containsKey(kE2eeBackupPassphraseSecureKey), isFalse);
    });
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
  });
}

class _FakeBackupApi implements E2EEBackupApi {
  _FakeBackupApi({bool hasBackup = false, bool throws = false})
    : _hasBackup = hasBackup,
      _throws = throws;

  final bool _hasBackup;
  final bool _throws;

  @override
  Future<E2EEBackupInfo> info() async {
    if (_throws) {
      throw Exception('network down');
    }
    return E2EEBackupInfo(
      hasBackup: _hasBackup,
      backupVersion: _hasBackup ? 3 : 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
