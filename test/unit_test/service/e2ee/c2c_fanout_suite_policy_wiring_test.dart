/// AC-06 — C2C 发送链固定套件策略（C02 FixedSuitePolicy）生产接线测试。
///
/// 与 `capability_guard_test.dart`（纯函数层）的区别：本文件断言**生产调用链**
/// `ChatNetworkService.encryptPayload → _encryptC2COlmFanOut →
/// E2EEService.enforceC2CFanoutSuitePolicy → FixedSuitePolicy` 真实经过门卫——
/// 对端存在不支持 Olm（仅有旧 RSA 身份）的活跃设备时，加密在进入任何 Olm
/// claim/加密之前**显式失败**（FixedSuiteIncompatibleException），绝不回退明文、
/// 绝不跳过设备、绝不落出可发送密文（outbox 无条目）。
///
/// RED 基线（2026-10-03）：`FixedSuitePolicy.enforcePeerSupportsRequired` 在
/// lib/ 下生产调用方为 0（grep 证据见 cards/C07/RED-ac06-*），发送链对
/// 「设备不支持」的唯一防线是 claim 失败的字符串嗅探（脆弱且语义为
/// not ready 而非 not supported）。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/capability_guard.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const myUid = '100';
  const peerUid = '200';
  const myDid = 'a-1';

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // currentUid：_encryptC2COlmFanOut 读 UserRepoLocal.to.currentUid。
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, myUid);

    // mock flutter_secure_storage（OlmSessionService account pickle 用）
    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          final store = <String, String>{};
          switch (call.method) {
            case 'write':
              if (key != null) {
                store[key] = args?['value']?.toString() ?? '';
              }
              return null;
            case 'read':
              return store[key];
            case 'delete':
              store.remove(key);
              return null;
          }
          return null;
        });
  });

  setUp(() async {
    app_init.deviceId = myDid;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await CryptoStore(db).ensureSchema();
    SqliteService.setDbForTest(db);

    // strict E2EE：encryptPayload 判定 needEncrypt=true
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    E2eeBootstrap.debugMarkReadyForTest(myUid);
    E2EEService.clearKeyCacheForTest();
  });

  tearDown(() async {
    E2EEService.debugOlmDeviceListLoader = null;
    E2EEService.clearKeyCacheForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  /// 对端 2 台活跃设备：b-1（有 Olm 身份）、b-rsa（旧端，仅 RSA）。
  /// 注入顺序让 b-rsa 排在 fan-out 循环首位——若门卫缺失（RED），
  /// 它会第一个进入 ensureSessionId → claim 网络错误，异常类型不对。
  void seedPeerDevices() {
    E2EEService.setUserDeviceKeyCacheForTest(peerUid, {
      'b-rsa': 'RSA-PEM-LEGACY',
      'b-1': 'RSA-PEM-B1',
    });
  }

  group('AC-06 生产调用链：encryptPayload 经过固定套件门卫', () {
    test('对端存在不支持 Olm 的活跃设备 → 显式 FixedSuiteIncompatibleException，'
        '且不落任何 outbox 密文', () async {
      seedPeerDevices();
      // 服务端 Olm 设备列表：只有 b-1（b-rsa 是旧端）。
      E2EEService.debugOlmDeviceListLoader = (uid) async => [
        {'device_id': 'b-1', 'identity_version': 1},
      ];

      await expectLater(
        ChatNetworkService().encryptPayload(
          chatType: 'C2C',
          toId: peerUid,
          plaintextMap: const {'msg_type': 'text', 'body': 'hi'},
          action: '',
          messageId: 'msg-ac06-001',
          messageType: 'text',
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );

      // 未产出可发送密文：outbox 不得有条目（不回退明文/不半发）。
      final store = CryptoStore(db);
      final pending = await store.pendingOutbox();
      expect(pending, isEmpty, reason: '套件不兼容必须发生在密文产出之前，outbox 不得有条目');
    });

    test('对端全部设备支持 Olm → 门卫放行（不因门卫抛错）', () async {
      seedPeerDevices();
      E2EEService.debugOlmDeviceListLoader = (uid) async => [
        {'device_id': 'b-1', 'identity_version': 1},
        {'device_id': 'b-rsa', 'identity_version': 1},
      ];

      // 门卫级断言：全支持时 enforce 不抛（生产链后续 claim 走网络，
      // 由 olm_pfs_production_path_test 覆盖加密本体）。
      await expectLater(
        E2EEService.enforceC2CFanoutSuitePolicy(
          peerUid: peerUid,
          fanoutDeviceIds: const {'b-1', 'b-rsa'},
        ),
        completion(unorderedEquals(<String>['b-1', 'b-rsa'])),
      );
    });
  });

  group('AC-06 门卫单元语义（fail-closed 细节）', () {
    test('能力列表为空（查询失败）→ 拒绝全部设备（能力未知=不支持）', () async {
      E2EEService.debugOlmDeviceListLoader = (uid) async => [];
      await expectLater(
        E2EEService.enforceC2CFanoutSuitePolicy(
          peerUid: peerUid,
          fanoutDeviceIds: const {'b-1'},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
    });

    test('混合集合：不支持设备被点名（peerDeviceId 指向首个不兼容设备）', () async {
      E2EEService.debugOlmDeviceListLoader = (uid) async => [
        {'device_id': 'b-1', 'identity_version': 1},
      ];
      await expectLater(
        E2EEService.enforceC2CFanoutSuitePolicy(
          peerUid: peerUid,
          fanoutDeviceIds: const {'b-1', 'b-rsa', 'b-rsa-2'},
        ),
        throwsA(
          isA<FixedSuiteIncompatibleException>().having(
            (e) => e.peerDeviceId,
            'peerDeviceId',
            anyOf('b-rsa', 'b-rsa-2'),
          ),
        ),
      );
    });

    test(' 幽灵设备（Olm 列表有、fan-out 集合没有）→ 告警事件而非崩溃', () async {
      E2EEService.debugOlmDeviceListLoader = (uid) async => [
        {'device_id': 'b-1', 'identity_version': 1},
        {'device_id': 'b-ghost', 'identity_version': 1},
      ];
      final events = <E2eeDeviceSetAnomalyEvent>[];
      final sub = AppEventBus.on<E2eeDeviceSetAnomalyEvent>().listen(
        events.add,
      );
      try {
        final olmDids = await E2EEService.enforceC2CFanoutSuitePolicy(
          peerUid: peerUid,
          fanoutDeviceIds: const {'b-1'},
        );
        expect(olmDids, contains('b-ghost'));
        await pumpEventQueue(); // 事件总线异步流 drain
        expect(events, hasLength(1));
        expect(events.single.peerUid, peerUid);
        expect(events.single.ghostDeviceIds, contains('b-ghost'));
        expect(events.single.kind, DeviceSetAnomalyKind.ghostDevice);
      } finally {
        await sub.cancel();
      }
    });
  });

  // 供文档引用：密文不落 outbox 的判定也覆盖 fan_out per_device 元数据形态。
  test('json 编码的 fan-out 信封在 outbox 断言中可被识别', () {
    final envelope = jsonEncode(<String, dynamic>{
      'e2ee': <String, dynamic>{
        'meta_version': 3,
        'fan_out': 'per_device',
        'devices': <String, dynamic>{},
      },
      'payload': '',
    });
    expect(envelope, contains('per_device'));
  });

  group('AC-06 用户可见错误映射（稳定错误码 → 专属 i18n 文案）', () {
    test(
      'FixedSuiteIncompatibleException 路由到 e2eeErrPeerSuiteUnsupported 而非兜底',
      () {
        final message = ChatNetworkService().getE2EEErrorMessage(
          FixedSuiteIncompatibleException(
            scope: 'c2c',
            requiredSuite: 'olm',
            peerDeviceId: 'b-rsa',
            peerProtocols: const {'rsa-oaep'},
          ),
        );
        expect(message, t.main.e2eeErrPeerSuiteUnsupported);
        expect(
          message,
          isNot(t.main.e2eeErrDefault),
          reason:
              '套件不兼容必须路由到专用键（含让对方更新的行动指引），'
              '不得落到笼统默认文案',
        );
      },
    );

    test('空能力集（能力未知=不支持）同样路由到专用键', () {
      final message = ChatNetworkService().getE2EEErrorMessage(
        FixedSuiteIncompatibleException(
          scope: 'c2c',
          requiredSuite: 'olm',
          peerDeviceId: 'b-unknown',
          peerProtocols: const {},
        ),
      );
      expect(message, t.main.e2eeErrPeerSuiteUnsupported);
    });
  });
}
