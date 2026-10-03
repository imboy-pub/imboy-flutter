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
import 'package:imboy/service/e2ee/capability_negotiator.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';

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

  group('FixedSuitePolicy 固定套件策略（C02 决策固化）', () {
    // 生产发送链（chat_network_service）不做运行时套件协商：
    // C2C 固定 Olm fan-out、C2G 固定 Megolm；RSA-OAEP decrypt-only 不可发送。
    // 该策略把这一结构性事实固化为显式 API + fail-closed 负例。

    test('c2c → olm；c2g → megolm（与发送链固定选择一致）', () {
      expect(FixedSuitePolicy.requiredSuiteFor('c2c'), equals('olm'));
      expect(FixedSuitePolicy.requiredSuiteFor('c2g'), equals('megolm'));
    });

    test('required 套件与注册的 ProtocolSuite 同源（不硬编码漂移）', () {
      expect(
        FixedSuitePolicy.requiredSuiteFor('c2c'),
        equals(ProtocolSuite.olm.protocol),
      );
      expect(
        FixedSuitePolicy.requiredSuiteFor('c2g'),
        equals(ProtocolSuite.megolm.protocol),
      );
    });

    test('rsa-oaep 永不作为任何 scope 的 required（decrypt-only）', () {
      for (final scope in const ['c2c', 'c2g']) {
        expect(
          FixedSuitePolicy.requiredSuiteFor(scope),
          isNot(equals(ProtocolSuite.rsa.protocol)),
        );
      }
    });

    test('未知 scope → ArgumentError（fail-closed，不猜测套件）', () {
      for (final scope in const ['control', '', 'C2C', 'group']) {
        expect(
          () => FixedSuitePolicy.requiredSuiteFor(scope),
          throwsArgumentError,
        );
      }
    });

    test('旧端只支持 rsa-oaep + c2c → FixedSuiteIncompatibleException（显式拒绝）', () {
      expect(
        () => FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2c',
          peerDeviceId: 'legacy-dev',
          peerProtocols: const {'rsa-oaep'},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
    });

    test('旧端只支持 rsa-oaep + c2g → FixedSuiteIncompatibleException', () {
      expect(
        () => FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2g',
          peerDeviceId: 'legacy-dev',
          peerProtocols: const {'rsa-oaep'},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
    });

    test('对端能力缺失（空集）→ 同样显式拒绝（不静默继续）', () {
      expect(
        () => FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2c',
          peerDeviceId: 'dev-empty',
          peerProtocols: const {},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
    });

    test('对端支持 required 套件 → 通过（无异常）', () {
      expect(
        () => FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2c',
          peerDeviceId: 'dev-1',
          peerProtocols: const {'olm', 'megolm'},
        ),
        returnsNormally,
      );
      expect(
        () => FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2g',
          peerDeviceId: 'dev-1',
          peerProtocols: const {'megolm', 'rsa-oaep'},
        ),
        returnsNormally,
      );
    });

    test('异常携带完整上下文（scope/requiredSuite/peerProtocols）', () {
      try {
        FixedSuitePolicy.enforcePeerSupportsRequired(
          scope: 'c2c',
          peerDeviceId: 'legacy-dev',
          peerProtocols: const {'rsa-oaep'},
        );
        fail('should have thrown');
      } on FixedSuiteIncompatibleException catch (e) {
        expect(e.scope, equals('c2c'));
        expect(e.requiredSuite, equals('olm'));
        expect(e.peerProtocols, equals({'rsa-oaep'}));
        expect(e.peerDeviceId, equals('legacy-dev'));
        // 显式语义：不退明文、不静默降级
        expect(e.toString(), contains('no plaintext fallback'));
      }
    });

    test('与 HWM 联动：固定套件协商结果不触发 enforceNoDowngrade 降级', () async {
      // 场景：对端 HWM=olm（历史用 Olm），本次固定套件策略产出 olm → 守护通过。
      await guard.recordHighWaterMark(
        peerUid: '500',
        peerDeviceId: 'dev-1',
        protocol: 'olm',
      );
      final suite = FixedSuitePolicy.requiredSuiteFor('c2c');
      await guard.enforceNoDowngrade(
        peerUid: '500',
        peerDeviceId: 'dev-1',
        negotiatedProtocol: suite,
      );

      // 反例：若对端宣称只支持 megolm 并被协商选中（rank 低于 HWM olm），
      // HWM 守护必须拒绝 —— 两条防线语义一致。
      expect(
        () => guard.enforceNoDowngrade(
          peerUid: '500',
          peerDeviceId: 'dev-1',
          negotiatedProtocol: 'megolm',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );
    });

    test('megolm → rsa-oaep 回退被 HWM 守护拒绝（回退套件负例）', () async {
      await guard.recordHighWaterMark(
        peerUid: '600',
        peerDeviceId: 'dev-1',
        protocol: 'megolm',
      );
      expect(
        () => guard.enforceNoDowngrade(
          peerUid: '600',
          peerDeviceId: 'dev-1',
          negotiatedProtocol: 'rsa-oaep',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );
    });

    test('固定套件产物全部位于 securityRank 内（与协商排序同源）', () {
      for (final scope in const ['c2c', 'c2g']) {
        expect(
          CapabilityNegotiator.securityRank,
          contains(FixedSuitePolicy.requiredSuiteFor(scope)),
        );
      }
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
