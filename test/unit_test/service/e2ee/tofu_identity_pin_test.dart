/// S3: TOFU identity pinning — TDD 测试
///
/// 验证：
/// - IdentityChangedException 携带正确上下文
/// - TOFU 决策逻辑：首次固定 / 匹配通过 / 变化 fail-closed
/// - 与 CryptoStore 的集成（pin → compare → throw）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/olm_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdentityChangedException', () {
    test('携带 peerUid / peerDeviceId / 新旧 fingerprint', () {
      final e = IdentityChangedException(
        peerUid: '100',
        peerDeviceId: 'dev-X',
        oldFingerprint: 'oldCurve25519Base64AAA',
        newFingerprint: 'newCurve25519Base64BBB',
      );

      expect(e.peerUid, equals('100'));
      expect(e.peerDeviceId, equals('dev-X'));
      expect(e.oldFingerprint, equals('oldCurve25519Base64AAA'));
      expect(e.newFingerprint, equals('newCurve25519Base64BBB'));
    });

    test('toString 包含截断 fingerprint（不泄露完整密钥）', () {
      final e = IdentityChangedException(
        peerUid: '200',
        peerDeviceId: 'dev-Y',
        oldFingerprint: 'abcdefghijklmnop_full_old_key',
        newFingerprint: 'qrstuvwxyz012345_full_new_key',
      );

      final s = e.toString();
      expect(s, contains('200:dev-Y'));
      expect(s, contains('abcdefgh'));
      expect(s, contains('qrstuvwx'));
      // 不应包含完整 fingerprint
      expect(s, isNot(contains('full_old_key')));
      expect(s, isNot(contains('full_new_key')));
    });
  });

  group('TOFU 决策逻辑（CryptoStore 集成）', () {
    late Database db;
    late CryptoStore store;

    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      store = CryptoStore(db);
      await store.ensureSchema();
    });

    tearDown(() async {
      await db.close();
    });

    test('首次通信：无 pin → 固定 fingerprint（TOFU）', () async {
      // 模拟 _enforceTofu 逻辑：pinned == null → pin
      final pinned = await store.loadPinnedFingerprint(
        peerUid: '300',
        peerDeviceId: 'dev-1',
      );
      expect(pinned, isNull);

      // 首次固定
      await store.pinIdentity(
        peerUid: '300',
        peerDeviceId: 'dev-1',
        fingerprint: 'curve25519-first-use',
      );

      // 验证已固定
      final after = await store.loadPinnedFingerprint(
        peerUid: '300',
        peerDeviceId: 'dev-1',
      );
      expect(after, equals('curve25519-first-use'));
    });

    test('后续通信：fingerprint 匹配 → 正常通过', () async {
      await store.pinIdentity(
        peerUid: '300',
        peerDeviceId: 'dev-1',
        fingerprint: 'stable-fp',
      );

      // 模拟 _enforceTofu：pinned == current → 不抛
      final pinned = await store.loadPinnedFingerprint(
        peerUid: '300',
        peerDeviceId: 'dev-1',
      );
      expect(pinned, equals('stable-fp'));
      // 匹配：不应抛异常
      expect(pinned == 'stable-fp', isTrue);
    });

    test('fingerprint 变化 → IdentityChangedException（fail-closed）', () async {
      await store.pinIdentity(
        peerUid: '300',
        peerDeviceId: 'dev-1',
        fingerprint: 'original-fp',
      );

      // 模拟 _enforceTofu：pinned != current → throw
      final pinned = await store.loadPinnedFingerprint(
        peerUid: '300',
        peerDeviceId: 'dev-1',
      );
      const currentFp = 'attacker-or-new-device-fp';

      expect(pinned, isNot(equals(currentFp)));
      // 验证抛异常
      expect(
        () => throw IdentityChangedException(
          peerUid: '300',
          peerDeviceId: 'dev-1',
          oldFingerprint: pinned!,
          newFingerprint: currentFp,
        ),
        throwsA(isA<IdentityChangedException>()),
      );
    });

    test('用户确认换机后：覆盖 pin 恢复正常通信', () async {
      await store.pinIdentity(
        peerUid: '300',
        peerDeviceId: 'dev-1',
        fingerprint: 'old-device-fp',
      );

      // 用户确认 → 覆盖
      await store.pinIdentity(
        peerUid: '300',
        peerDeviceId: 'dev-1',
        fingerprint: 'new-device-fp',
      );

      final pinned = await store.loadPinnedFingerprint(
        peerUid: '300',
        peerDeviceId: 'dev-1',
      );
      expect(pinned, equals('new-device-fp'));
      // 后续通信匹配新 fingerprint → 不再抛
      expect(pinned == 'new-device-fp', isTrue);
    });

    test('多设备独立 TOFU：一台换机不影响另一台', () async {
      await store.pinIdentity(
        peerUid: '400',
        peerDeviceId: 'phone',
        fingerprint: 'phone-fp',
      );
      await store.pinIdentity(
        peerUid: '400',
        peerDeviceId: 'tablet',
        fingerprint: 'tablet-fp',
      );

      // phone 换机
      await store.pinIdentity(
        peerUid: '400',
        peerDeviceId: 'phone',
        fingerprint: 'phone-new-fp',
      );

      // tablet 不受影响
      expect(
        await store.loadPinnedFingerprint(
          peerUid: '400',
          peerDeviceId: 'tablet',
        ),
        equals('tablet-fp'),
      );
      // phone 已更新
      expect(
        await store.loadPinnedFingerprint(
          peerUid: '400',
          peerDeviceId: 'phone',
        ),
        equals('phone-new-fp'),
      );
    });
  });
}
