import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

import 'package:flutter/foundation.dart';
// B.2 守护测试：三套件注册引导 + Registry 路由（不触发 vodozemac）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
import 'package:imboy/service/e2ee/rsa_legacy_protocol.dart';

class _SyntheticDeviceInfo extends DeviceInfoPlatform {
  @override
  Future<BaseDeviceInfo> deviceInfo() async {
    // Linux uses a typed platform implementation, not a MethodChannel map.
    if (Platform.isLinux) {
      return LinuxDeviceInfo(
        name: 'test',
        id: 'synthetic-device',
        prettyName: 'test',
        machineId: 'synthetic-machine',
      );
    }
    return BaseDeviceInfo({
      'computerName': 'test',
      'hostName': 'test',
      'arch': 'arm64',
      'model': 'test',
      'modelName': 'test',
      'kernelVersion': 'test',
      'osRelease': 'test',
      'majorVersion': 1,
      'minorVersion': 0,
      'patchVersion': 0,
      'activeCPUs': 1,
      'memorySize': 1,
      'cpuFrequency': 1,
      'systemGUID': 'synthetic-device',
    });
  }
}

Future<void> _installDeviceFixture() async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  await StorageService.to.setString(Keys.currentUid, 'synthetic-user');
  DeviceInfoPlatform.instance = _SyntheticDeviceInfo();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ensureReady 调用注册套件并隔离失败日志', () async {
    const canary = 'synthetic-private-initialize-key';
    final previousDeviceInfo = DeviceInfoPlatform.instance;
    await _installDeviceFixture();
    E2eeBootstrap.resetForTest();
    E2eeBootstrap.ensureRegistered();
    E2eeProtocolRegistry.resetForTest();
    final failing = _InitProbeProtocol(failure: StateError(canary));
    final succeeding = _InitProbeProtocol(protocol: 'probe-success');
    E2eeProtocolRegistry.register(failing);
    E2eeProtocolRegistry.register(succeeding);
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await E2eeBootstrap.ensureReady();
      expect(failing.initCalls, 1);
      expect(succeeding.initCalls, 1);
      expect(succeeding.lastUserId, 'synthetic-user');
      expect(succeeding.lastDeviceId, 'synthetic-device');
      expect(
        logs,
        contains('[E2eeBootstrap] initialize probe failed: StateError'),
      );
      expect(logs.join('\n'), isNot(contains(canary)));
    } finally {
      debugPrint = previousDebugPrint;
      DeviceInfoPlatform.instance = previousDeviceInfo;
      E2eeBootstrap.resetForTest();
    }
  });
  _bug72InitializationContract();
  group('E2eeBootstrap.ensureRegistered', () {
    setUp(E2eeBootstrap.resetForTest);
    tearDown(E2eeBootstrap.resetForTest);

    test('注册 olm/megolm/rsa-oaep 三套件，不含 mls（ADR 02 §8 占位）', () {
      E2eeBootstrap.ensureRegistered();
      final protos = E2eeProtocolRegistry.all().map((s) => s.protocol).toSet();
      expect(protos, {'olm', 'megolm', 'rsa-oaep'});
      expect(protos.contains('mls'), isFalse);
    });

    test('幂等：重复 ensureRegistered 不抛（不重复注册）', () {
      E2eeBootstrap.ensureRegistered();
      expect(E2eeBootstrap.ensureRegistered, returnsNormally);
    });

    test('3 种 v1 legacy 字符串各路由到正确协议实现', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        E2eeProtocolRegistry.resolve({'e2ee_suite': 'OLM.V1'}),
        isA<OlmProtocol>(),
      );
      expect(
        E2eeProtocolRegistry.resolve({'e2ee_suite': 'MEGOLM.V1'}),
        isA<MegolmProtocol>(),
      );
      expect(
        E2eeProtocolRegistry.resolve({
          'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        }),
        isA<RsaLegacyProtocol>(),
      );
    });

    test('v2 三元组路由（双写消息优先按 protocol）', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        E2eeProtocolRegistry.resolve({
          'protocol': 'olm',
          'version': 1,
          'e2ee_suite': 'MEGOLM.V1',
        }),
        isA<OlmProtocol>(),
      );
    });

    test('未知套件抛 FormatException（不静默 fallback，ADR 02 §4.3）', () {
      E2eeBootstrap.ensureRegistered();
      expect(
        () => E2eeProtocolRegistry.resolve({'e2ee_suite': 'X.V9'}),
        throwsFormatException,
      );
    });

    test('RsaLegacyProtocol.encrypt 抛 UnsupportedError（ADR 02 §5.2 防降级）', () {
      expect(
        () => RsaLegacyProtocol().encrypt(
          plaintext: 'x',
          recipients: const [],
          context: const E2eeContext(scope: 'c2c'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

/// BUG#72 契约：注册之后**必须**有人调用 initialize。
///
/// 生产实测（2026-08-04，把 e2ee_mode 改成 required 后）第一条单聊消息即抛
/// `Bad state: OlmProtocol not initialized (missing self uid)` —— 因为
/// `E2eeSessionProtocol.initialize` 三个实现都写好了，却**全项目零调用点**。
/// 这里把「ensureReady 会把 initialize 传导到每个已注册实现」钉成断言。
void _bug72InitializationContract() {
  group('初始化探针的字段记录', () {
    test('直接调用探针记录 userId / deviceId', () async {
      E2eeBootstrap.resetForTest();
      final probe = _InitProbeProtocol();
      E2eeProtocolRegistry.register(probe);

      await probe.initialize(userId: 'u-50', deviceId: 'dev-1');

      expect(probe.initCalls, 1, reason: 'initialize 必须被调用，否则 selfUid 为 null');
      expect(probe.lastUserId, 'u-50');
      expect(probe.lastDeviceId, 'dev-1');

      E2eeBootstrap.resetForTest();
    });
  });
}

class _InitProbeProtocol implements E2eeSessionProtocol {
  _InitProbeProtocol({this.failure, this.protocol = 'probe'});
  final Object? failure;
  final String protocol;
  int initCalls = 0;
  String? lastUserId;
  String? lastDeviceId;

  @override
  ProtocolSuite get suite => ProtocolSuite(protocol, 1, 'none-$protocol');

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    initCalls++;
    lastUserId = userId;
    lastDeviceId = deviceId;
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
