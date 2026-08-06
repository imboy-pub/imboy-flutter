/// S6: Capability 降级检测 — TDD 测试
///
/// 防御协议降级攻击（T2）：对端设备历史最高协商等级（HWM）一旦记录，
/// 后续协商结果不得低于 HWM（除非用户显式确认）。
/// 验证：
/// - HWM 存储与加载
/// - 首次协商：记录 HWM（无告警）
/// - 后续协商等级不变/升级：正常通过
/// - 后续协商等级下降：抛 CapabilityDowngradeException
/// - 用户确认后：HWM 覆写，恢复正常
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/capability_guard.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late CryptoStore store;
  late CapabilityGuard guard;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
    guard = CapabilityGuard(store);
  });

  tearDown(() async => db.close());

  group('CapabilityGuard HWM 存储', () {
    test('首次记录 + 加载往返', () async {
      await guard.recordHighWaterMark(
        peerUid: '100',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );

      final hwm = await guard.loadHighWaterMark(
        peerUid: '100',
        peerDeviceId: 'dev-1',
      );
      expect(hwm, equals('olm'));
    });

    test('未知对端返回 null', () async {
      final hwm = await guard.loadHighWaterMark(
        peerUid: '999',
        peerDeviceId: 'dev-X',
      );
      expect(hwm, isNull);
    });

    test('不同设备独立 HWM', () async {
      await guard.recordHighWaterMark(
        peerUid: '100',
        peerDeviceId: 'phone',
        protocol: 'olm',
      );
      await guard.recordHighWaterMark(
        peerUid: '100',
        peerDeviceId: 'tablet',
        protocol: 'megolm',
      );

      expect(
        await guard.loadHighWaterMark(peerUid: '100', peerDeviceId: 'phone'),
        equals('olm'),
      );
      expect(
        await guard.loadHighWaterMark(peerUid: '100', peerDeviceId: 'tablet'),
        equals('megolm'),
      );
    });
  });

  group('CapabilityGuard 降级检测', () {
    test('首次协商：无 HWM → 记录并通过（不抛）', () async {
      // 不应抛异常
      await guard.enforceNoDowngrade(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        negotiatedProtocol: 'megolm',
      );

      // HWM 已记录
      final hwm = await guard.loadHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
      );
      expect(hwm, equals('megolm'));
    });

    test('等级不变 → 正常通过', () async {
      await guard.recordHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );

      // 同等级：不抛
      await guard.enforceNoDowngrade(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        negotiatedProtocol: 'olm',
      );
    });

    test('等级升级 → 正常通过 + HWM 更新', () async {
      await guard.recordHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        protocol: 'megolm',
      );

      // 升级到 olm（更高）：不抛，且 HWM 更新
      await guard.enforceNoDowngrade(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        negotiatedProtocol: 'olm',
      );

      final hwm = await guard.loadHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
      );
      expect(hwm, equals('olm'));
    });

    test('等级降级 → 抛 CapabilityDowngradeException（fail-closed）', () async {
      await guard.recordHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );

      // 降级到 rsa-oaep：必须抛
      expect(
        () => guard.enforceNoDowngrade(
          peerUid: '200',
          peerDeviceId: 'dev-1',
          negotiatedProtocol: 'rsa-oaep',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );
    });

    test('降级异常携带完整上下文', () async {
      await guard.recordHighWaterMark(
        peerUid: '300',
        peerDeviceId: 'dev-A',
        protocol: 'olm',
      );

      try {
        await guard.enforceNoDowngrade(
          peerUid: '300',
          peerDeviceId: 'dev-A',
          negotiatedProtocol: 'rsa-oaep',
        );
        fail('should have thrown');
      } on CapabilityDowngradeException catch (e) {
        expect(e.peerUid, equals('300'));
        expect(e.peerDeviceId, equals('dev-A'));
        expect(e.previousProtocol, equals('olm'));
        expect(e.attemptedProtocol, equals('rsa-oaep'));
      }
    });

    test('用户确认降级后：HWM 覆写，后续正常', () async {
      await guard.recordHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );

      // 降级被检测到
      expect(
        () => guard.enforceNoDowngrade(
          peerUid: '200',
          peerDeviceId: 'dev-1',
          negotiatedProtocol: 'megolm',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );

      // 用户确认：覆写 HWM
      await guard.confirmDowngrade(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        newProtocol: 'megolm',
      );

      // 后续同等级不再抛
      await guard.enforceNoDowngrade(
        peerUid: '200',
        peerDeviceId: 'dev-1',
        negotiatedProtocol: 'megolm',
      );

      final hwm = await guard.loadHighWaterMark(
        peerUid: '200',
        peerDeviceId: 'dev-1',
      );
      expect(hwm, equals('megolm'));
    });
  });

  group('CapabilityGuard 边界', () {
    test('未知协议名 → 视为最低等级（fail-closed 保守）', () async {
      await guard.recordHighWaterMark(
        peerUid: '400',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );

      // 未知协议 'mls' 不在 securityRank 中 → rank = maxInt → 降级
      expect(
        () => guard.enforceNoDowngrade(
          peerUid: '400',
          peerDeviceId: 'dev-1',
          negotiatedProtocol: 'mls',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );
    });

    test('crypto_capability_hwm 表存在', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'crypto_capability_hwm'",
      );
      expect(tables.length, equals(1));
    });
  });
}
