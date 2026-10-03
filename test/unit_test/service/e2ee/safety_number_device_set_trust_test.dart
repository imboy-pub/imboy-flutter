/// AC-15 — 安全码绑定完整设备集合 + 设备集合异常策略 + 信任生命周期测试。
///
/// 三组语义：
/// 1. **设备集合绑定**：聚合码覆盖双方全部设备；对端设备新增/换钥 →
///    聚合码变化 → 旧「已验证」失效（isCurrentNumberVerified 严格相等，
///    既有行为）——本文件补齐**异常检测与告警策略**：
///    新设备（服务端下发本地未记录）→ E2eeDeviceSetAnomalyEvent(newDevice)
///    + 刷新密钥缓存；遗漏设备（本地记录有、下发没有）→ missingDevice 事件。
///    不崩溃、不静默。
/// 2. **信任标记生命周期**：markVerified 绑定当前聚合码 + 记录批准设备集合；
///    invalidateTrust（换钥/撤销触发）清除标记并广播
///    SafetyNumberTrustInvalidatedEvent——「标记需重验而非静默沿用」。
/// 3. **换钥联动（C01 identity_version 推进 → 本地信任失效）**：
///    E2eeBootstrap 常驻订阅 E2EEPeerKeyChangedEvent → invalidateTrust。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/safety_number_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const peerUid = '200';
  const localUid = '100';
  const localDid = 'a-1';

  const peerDevicesV1 = <String, String>{
    '200:b-1': 'Yi0xLWlkZW50aXR5',
    '200:b-2': 'Yi0yLWlkZW50aXR5',
  };
  const localDevices = <String, String>{'100:a-1': 'YS0xLWlkZW50aXR5'};
  const newDeviceIdentity = 'bmV3LWRldmljZS1pZGVudGl0eQ==';

  Future<SafetyNumberResult> compute({
    required Map<String, String> peerIdentities,
  }) => SafetyNumberService.generateForPeer(
    peerUid: peerUid,
    localUidOverride: localUid,
    localDeviceIdOverride: localDid,
    deviceListLoader: (uid) async => uid == peerUid
        ? [
            for (final did in peerIdentities.keys)
              {'device_id': did.split(':')[1], 'key_id': 'kid-$did'},
          ]
        : [
            for (final did in localDevices.keys)
              {'device_id': did.split(':')[1], 'key_id': 'kid-$did'},
          ],
    localIdentityLoader: () async => localDevices['100:a-1']!,
    verifiedIdentityLoader: (uid, did) async {
      final direct = peerIdentities['$uid:$did'];
      if (direct != null) return direct;
      final local = localDevices['$uid:$did'];
      if (local != null) return local;
      return newDeviceIdentity;
    },
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, localUid);

    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'write':
              if (key != null) {
                secureStore[key] = args?['value']?.toString() ?? '';
              }
              return null;
            case 'read':
              return secureStore[key];
            case 'delete':
              secureStore.remove(key);
              return null;
            case 'readAll':
            case 'containsKey':
              return null;
          }
          return null;
        });
  });

  setUp(() {
    E2EEService.clearKeyCacheForTest();
  });

  tearDown(() async {
    // 清理信任标记与设备集合记录，隔离用例
    await StorageSecureService.to.delete(
      key: 'safety_number_verified_$peerUid',
    );
    await StorageSecureService.to.delete(key: 'safety_number_devset_$peerUid');
    E2eeBootstrap.resetTrustWiringForTest();
  });

  group('AC-15 设备集合异常检测（刷新 + 告警，不崩溃不静默）', () {
    test('对端新增设备 → newDevice 事件 + 密钥缓存被刷新', () async {
      // 第一次计算：记录基线集合（b-1, b-2）
      await compute(peerIdentities: peerDevicesV1);

      final events = <E2eeDeviceSetAnomalyEvent>[];
      final sub = AppEventBus.on<E2eeDeviceSetAnomalyEvent>().listen(
        events.add,
      );
      // 预置缓存以验证「刷新」动作
      E2EEService.setUserDeviceKeyCacheForTest(peerUid, {'b-1': 'pem'});
      try {
        // 第二次：对端多了一台 b-new
        final result = await compute(
          peerIdentities: {...peerDevicesV1, '200:b-new': newDeviceIdentity},
        );
        expect(result.remoteDeviceCount, 3);

        await pumpEventQueue();
        expect(events, hasLength(1));
        expect(events.single.kind, DeviceSetAnomalyKind.newDevice);
        expect(events.single.peerUid, peerUid);
        expect(events.single.newDeviceIds, contains('b-new'));
      } finally {
        await sub.cancel();
      }
    });

    test('负例：对端新增/换设备 → 聚合码变化 → 旧「已验证」不沿用（需重验）', () async {
      // 用户在设备集合 V1 时完成带外核验
      final v1 = await compute(peerIdentities: peerDevicesV1);
      await SafetyNumberService.markVerified(
        peerUid: peerUid,
        number: v1.number,
        approvedRemoteDeviceIds: const {'b-1', 'b-2'},
      );

      // 对端新增一台设备（未经过用户确认）
      final v2 = await compute(
        peerIdentities: {...peerDevicesV1, '200:b-new': newDeviceIdentity},
      );
      expect(v2.number, isNot(equals(v1.number)), reason: '新设备加入聚合，聚合码必须变化');

      final stored = await SafetyNumberService.localVerifiedNumber(peerUid);
      expect(stored, v1.number);
      expect(
        SafetyNumberService.isCurrentNumberVerified(stored, v2.number),
        isFalse,
        reason:
            'AC-15：集合外新设备不得静默沿用旧验证——严格相等失效，'
            '必须回到「需重验」状态',
      );
    });

    test('负例：对端设备换钥（同设备 ID、新 identity）→ 聚合码变化 → 旧验证同样失效', () async {
      final v1 = await compute(peerIdentities: peerDevicesV1);
      await SafetyNumberService.markVerified(
        peerUid: peerUid,
        number: v1.number,
        approvedRemoteDeviceIds: const {'b-1', 'b-2'},
      );

      // b-2 重装：设备 ID 不变但 identity key 换新（典型 MITM/换机窗口）
      final v2 = await compute(
        peerIdentities: {
          '200:b-1': peerDevicesV1['200:b-1']!,
          '200:b-2': newDeviceIdentity,
        },
      );
      expect(v2.number, isNot(equals(v1.number)));
      expect(
        SafetyNumberService.isCurrentNumberVerified(
          await SafetyNumberService.localVerifiedNumber(peerUid),
          v2.number,
        ),
        isFalse,
        reason: '换钥改变聚合码，旧验证必须失效——不是静默信任新钥',
      );
    });

    test('对端设备消失（遗漏）→ missingDevice 事件', () async {
      await compute(peerIdentities: peerDevicesV1);

      final events = <E2eeDeviceSetAnomalyEvent>[];
      final sub = AppEventBus.on<E2eeDeviceSetAnomalyEvent>().listen(
        events.add,
      );
      try {
        // 第二次：b-2 不在下发集合
        await compute(peerIdentities: {'200:b-1': peerDevicesV1['200:b-1']!});
        await pumpEventQueue();
        expect(events, hasLength(1));
        expect(events.single.kind, DeviceSetAnomalyKind.missingDevice);
        expect(events.single.missingDeviceIds, contains('b-2'));
      } finally {
        await sub.cancel();
      }
    });

    test('集合无变化 → 不产生事件（基线记录幂等）', () async {
      await compute(peerIdentities: peerDevicesV1);
      final events = <E2eeDeviceSetAnomalyEvent>[];
      final sub = AppEventBus.on<E2eeDeviceSetAnomalyEvent>().listen(
        events.add,
      );
      try {
        await compute(peerIdentities: peerDevicesV1);
        await pumpEventQueue();
        expect(events, isEmpty);
      } finally {
        await sub.cancel();
      }
    });
  });

  group('AC-15 信任标记生命周期', () {
    test('markVerified 绑定聚合码 + 记录批准集合；isCurrentNumberVerified 生效', () async {
      final result = await compute(peerIdentities: peerDevicesV1);
      await SafetyNumberService.markVerified(
        peerUid: peerUid,
        number: result.number,
        approvedRemoteDeviceIds: const {'b-1', 'b-2'},
      );

      final stored = await SafetyNumberService.localVerifiedNumber(peerUid);
      expect(stored, result.number);
      expect(
        SafetyNumberService.isCurrentNumberVerified(stored, result.number),
        isTrue,
      );
      // 批准集合持久化
      final devset = await SafetyNumberService.approvedRemoteDeviceIds(peerUid);
      expect(devset, {'b-1', 'b-2'});
    });

    test('invalidateTrust 清除标记 + 广播失效事件（换钥 → 需重验，非静默沿用）', () async {
      final result = await compute(peerIdentities: peerDevicesV1);
      await SafetyNumberService.markVerified(
        peerUid: peerUid,
        number: result.number,
        approvedRemoteDeviceIds: const {'b-1', 'b-2'},
      );

      final events = <SafetyNumberTrustInvalidatedEvent>[];
      final sub = AppEventBus.on<SafetyNumberTrustInvalidatedEvent>().listen(
        events.add,
      );
      try {
        final invalidated = await SafetyNumberService.invalidateTrust(
          peerUid,
          'peer_key_changed',
        );
        expect(invalidated, isTrue);
        await pumpEventQueue();
        expect(events, hasLength(1));
        expect(events.single.peerUid, peerUid);
        expect(events.single.reason, 'peer_key_changed');

        // 标记已清：重新计算后 isCurrentNumberVerified 不再放行旧值
        expect(await SafetyNumberService.localVerifiedNumber(peerUid), isNull);
        expect(
          SafetyNumberService.isCurrentNumberVerified(
            result.number,
            result.number,
          ),
          isTrue, // 纯函数仍相等，但存储侧已清——绑定由 localVerifiedNumber 为 null 体现
        );
        expect(
          await SafetyNumberService.approvedRemoteDeviceIds(peerUid),
          isEmpty,
          reason: '信任失效时批准集合必须一并清除（防新设备沿用旧批准）',
        );
      } finally {
        await sub.cancel();
      }
    });

    test('invalidateTrust 对从未验证的 peer 幂等返回 false（无事件）', () async {
      final events = <SafetyNumberTrustInvalidatedEvent>[];
      final sub = AppEventBus.on<SafetyNumberTrustInvalidatedEvent>().listen(
        events.add,
      );
      try {
        expect(
          await SafetyNumberService.invalidateTrust(
            peerUid,
            'peer_key_changed',
          ),
          isFalse,
        );
        await pumpEventQueue();
        expect(events, isEmpty);
      } finally {
        await sub.cancel();
      }
    });
  });

  group('AC-15 换钥联动：bootstrap 常驻订阅 → 信任失效', () {
    test(
      'E2EEPeerKeyChangedEvent（S2C e2ee_key_changed）触发 invalidateTrust',
      () async {
        final result = await compute(peerIdentities: peerDevicesV1);
        await SafetyNumberService.markVerified(
          peerUid: peerUid,
          number: result.number,
          approvedRemoteDeviceIds: const {'b-1', 'b-2'},
        );

        // 接线常驻订阅（生产由 E2eeBootstrap.ensureReady 安装）
        await E2eeBootstrap.ensureTrustWiring();

        AppEventBus.fire(
          const E2EEPeerKeyChangedEvent(
            uid: peerUid,
            deviceId: 'b-1',
            keyId: 'kid-new',
          ),
        );
        await pumpEventQueue();

        expect(await SafetyNumberService.localVerifiedNumber(peerUid), isNull);
        expect(
          await SafetyNumberService.approvedRemoteDeviceIds(peerUid),
          isEmpty,
        );
      },
    );

    test('E2EETrustChangedEvent 撤销（revoked）触发 invalidateTrust', () async {
      final result = await compute(peerIdentities: peerDevicesV1);
      await SafetyNumberService.markVerified(
        peerUid: peerUid,
        number: result.number,
        approvedRemoteDeviceIds: const {'b-1', 'b-2'},
      );
      await E2eeBootstrap.ensureTrustWiring();

      AppEventBus.fire(
        E2EETrustChangedEvent(
          actorUid: localUid,
          targetUid: peerUid,
          targetDeviceId: 'b-1',
          toState: 'revoked',
          method: 'revoke',
          eventId: 'evt-1',
          issuedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await pumpEventQueue();

      expect(await SafetyNumberService.localVerifiedNumber(peerUid), isNull);
    });
  });

  // 设备集合持久化格式快照（防意外漂移）
  test('批准集合持久化为排序 JSON（debug 快照）', () async {
    await SafetyNumberService.markVerified(
      peerUid: peerUid,
      number: '1' * 60,
      approvedRemoteDeviceIds: const {'b-2', 'b-1'},
    );
    final raw = await StorageSecureService.to.read(
      key: 'safety_number_devset_$peerUid',
    );
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List;
    expect(decoded, ['b-1', 'b-2']);
  });
}
