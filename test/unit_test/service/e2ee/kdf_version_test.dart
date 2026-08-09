/// S7: 版本化 KDF 调度层 — TDD 测试
///
/// 防御 T6（KDF 可迁移）：KDF 参数必须自描述、可升级、可审计。
/// 验证：
/// - v1 (PBKDF2) 派生与既有 E2EECryptoService.deriveKey 逐字节一致（向后兼容）
/// - 确定性：相同 (version,password,salt,params) → 相同密钥
/// - 版本分发：dispatch 按 version 路由到正确 KDF
/// - 未知版本 → fail-closed 抛异常
/// - 迁移检测：needsMigration + 迁移后版本提升
/// - 降级拒绝：目标版本 < 当前版本 → 抛异常
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee/kdf_version.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
  const password = 'correct-horse-battery-staple';

  group('KdfVersion v1 向后兼容', () {
    test('v1 派生与 E2EECryptoService.deriveKey 逐字节一致', () async {
      final legacy = await E2EECryptoService.deriveKey(password, salt);
      final versioned = await KdfVersion.derive(
        version: 1,
        password: password,
        salt: salt,
      );

      expect(versioned, equals(legacy));
      expect(versioned.length, equals(32));
    });

    test('PBKDF2-HMAC-SHA256 310k 已知向量逐字节一致', () async {
      // 独立实现（Python hashlib.pbkdf2_hmac）生成，锁死跨平台算法行为：
      // 任何优化改动若改变派生结果，将使既有备份文件无法解密。
      final key = await E2EECryptoService.deriveKey(password, salt);
      expect(
        E2EECryptoService.toHex(key),
        equals(
          '721ae75360a174a162d045911113778ad7ec5baee2bc406f8e04311f0d808ef4',
        ),
      );
    });

    test('确定性：相同输入 → 相同密钥', () async {
      final a = await KdfVersion.derive(
        version: 1,
        password: password,
        salt: salt,
      );
      final b = await KdfVersion.derive(
        version: 1,
        password: password,
        salt: salt,
      );
      expect(a, equals(b));
    });

    test('不同 salt → 不同密钥', () async {
      final salt2 = Uint8List.fromList(List<int>.generate(16, (i) => i + 100));
      final a = await KdfVersion.derive(
        version: 1,
        password: password,
        salt: salt,
      );
      final b = await KdfVersion.derive(
        version: 1,
        password: password,
        salt: salt2,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('KdfVersion 版本分发', () {
    test('latest 当前为 1', () {
      expect(KdfVersion.latest, equals(1));
    });

    test('isSupported: 1 支持，0/2/99 不支持', () {
      expect(KdfVersion.isSupported(1), isTrue);
      expect(KdfVersion.isSupported(0), isFalse);
      expect(KdfVersion.isSupported(2), isFalse);
      expect(KdfVersion.isSupported(99), isFalse);
    });

    test('未知版本 → 抛 UnsupportedKdfVersionException（fail-closed）', () async {
      expect(
        () => KdfVersion.derive(version: 99, password: password, salt: salt),
        throwsA(isA<UnsupportedKdfVersionException>()),
      );
    });

    test('异常携带版本号', () async {
      try {
        await KdfVersion.derive(version: 42, password: password, salt: salt);
        fail('should throw');
      } on UnsupportedKdfVersionException catch (e) {
        expect(e.version, equals(42));
      }
    });
  });

  group('KdfVersion 迁移', () {
    test('needsMigration: 低于 latest 需迁移，等于 latest 不需要', () {
      expect(KdfVersion.needsMigration(0), isTrue);
      expect(KdfVersion.needsMigration(1), isFalse);
    });

    test('migrate: v0 → v1 成功，密钥可用 latest 派生复现', () async {
      final migrated = await KdfVersion.migrate(
        fromVersion: 0,
        password: password,
        salt: salt,
      );

      expect(migrated.fromVersion, equals(0));
      expect(migrated.toVersion, equals(1));
      expect(migrated.toVersion, equals(KdfVersion.latest));

      // 迁移后派生的密钥 == 直接用 latest 派生
      final direct = await KdfVersion.derive(
        version: KdfVersion.latest,
        password: password,
        salt: salt,
      );
      expect(migrated.key, equals(direct));
    });

    test('migrate: 降级（from > latest）→ 抛 KdfDowngradeException', () async {
      // 模拟：未来 latest=1，尝试从 v5 "迁移"（实为降级）
      expect(
        () => KdfVersion.migrate(
          fromVersion: 5,
          password: password,
          salt: salt,
          toVersion: 1,
        ),
        throwsA(isA<KdfDowngradeException>()),
      );
    });

    test('migrate: 目标版本不支持 → 抛 UnsupportedKdfVersionException', () async {
      expect(
        () => KdfVersion.migrate(
          fromVersion: 0,
          password: password,
          salt: salt,
          toVersion: 99,
        ),
        throwsA(isA<UnsupportedKdfVersionException>()),
      );
    });
  });

  group('KdfVersion 边界', () {
    test('空密码 → 抛 ArgumentError（fail-closed）', () async {
      expect(
        () => KdfVersion.derive(version: 1, password: '', salt: salt),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('错误 salt 长度 → 抛 ArgumentError', () async {
      final badSalt = Uint8List(8);
      expect(
        () => KdfVersion.derive(version: 1, password: password, salt: badSalt),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
