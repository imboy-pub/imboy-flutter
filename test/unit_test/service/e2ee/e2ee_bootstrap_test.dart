import 'dart:async';
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
import 'package:imboy/service/e2ee/policy_gate.dart';

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
  _readinessRecoveryContract();
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

void _readinessRecoveryContract() {
  group('required-suite readiness and retry', () {
    late DeviceInfoPlatform previousDeviceInfo;
    late _InitProbeProtocol olm;
    late _InitProbeProtocol megolm;
    setUp(() async {
      previousDeviceInfo = DeviceInfoPlatform.instance;
      await _installDeviceFixture();
      E2eeBootstrap.resetForTest();
      E2eeBootstrap.ensureRegistered();
      E2eeProtocolRegistry.resetForTest();
      olm = _InitProbeProtocol(protocol: 'olm');
      megolm = _InitProbeProtocol(protocol: 'megolm');
      E2eeProtocolRegistry.register(olm);
      E2eeProtocolRegistry.register(megolm);
    });
    tearDown(() {
      E2eeBootstrap.resetForTest();
      DeviceInfoPlatform.instance = previousDeviceInfo;
    });

    test(
      'failed required suite rejects and retries without repeating success',
      () async {
        olm.failure = StateError('synthetic failure');
        await expectLater(
          E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm),
          throwsA(
            isA<E2eeSecurityException>().having(
              (error) => error.reason,
              'reason',
              'e2ee_protocol_not_ready',
            ),
          ),
        );
        expect(megolm.initCalls, 1);
        olm.failure = null;
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        expect(olm.initCalls, 2);
        expect(megolm.initCalls, 1);
      },
    );

    test(
      'optional failure does not block the required working suite',
      () async {
        megolm.failure = StateError('synthetic failure');
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        expect(olm.initCalls, 1);
        expect(megolm.initCalls, 1);
        await expectLater(
          E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.megolm),
          throwsA(isA<E2eeSecurityException>()),
        );
        expect(olm.initCalls, 1);
        expect(megolm.initCalls, 2);
      },
    );

    test('default compatibility call retries only failed suites', () async {
      olm.failure = StateError('synthetic failure');
      await E2eeBootstrap.ensureReady();
      olm.failure = null;
      await E2eeBootstrap.ensureReady();
      expect(olm.initCalls, 2);
      expect(megolm.initCalls, 1);
    });

    test(
      'explicit test readiness survives replacing a registered standard suite',
      () async {
        E2eeBootstrap.debugMarkReadyForTest('synthetic-user');
        E2eeProtocolRegistry.resetForTest();
        E2eeProtocolRegistry.register(megolm);
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.megolm);
        expect(megolm.initCalls, 0);
      },
    );

    test('concurrent callers publish a successful suite once', () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      olm.onInitialize = () async {
        started.complete();
        await finish.future;
      };
      final first = E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
      await started.future;
      final second = E2eeBootstrap.ensureReady(
        requiredSuite: ProtocolSuite.olm,
      );
      finish.complete();
      await Future.wait([first, second]);
      expect(olm.initCalls, 1);
      expect(megolm.initCalls, 1);
    });

    test(
      'old in-flight initialization cannot mark a new account ready',
      () async {
        final started = Completer<void>();
        final finish = Completer<void>();
        olm.onInitialize = () async {
          started.complete();
          await finish.future;
        };
        final old = E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        final oldFailure = expectLater(
          old,
          throwsA(isA<E2eeSecurityException>()),
        );
        await started.future;
        await StorageService.to.setString(
          Keys.currentUid,
          'new-synthetic-user',
        );
        final next = E2eeBootstrap.ensureReady(
          requiredSuite: ProtocolSuite.olm,
        );
        olm.onInitialize = null;
        finish.complete();
        await oldFailure;
        await next;
        expect(olm.initCalls, 2);
        expect(olm.lastUserId, 'new-synthetic-user');
        expect(megolm.initCalls, 1);
        await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
        expect(olm.initCalls, 2);
      },
    );

    test(
      'required suite rejects missing login; default call remains a no-op',
      () async {
        await StorageService.to.setString(Keys.currentUid, '');
        await E2eeBootstrap.ensureReady();
        await expectLater(
          E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm),
          throwsA(isA<E2eeSecurityException>()),
        );
        expect(olm.initCalls, 0);
      },
    );
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
  Object? failure;
  Future<void> Function()? onInitialize;
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
    await onInitialize?.call();
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
