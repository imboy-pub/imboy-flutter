import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// E2EE-062：**`publishIdentityAndPrekeys` 只应对新建账号无条件铺满 OTK 池**。
///
/// == 缺口（本轮自查发现，是我自己上上轮引入的回归）==
///
/// `E2EE-062-client-refill-wiring.md` 那一刀把注册路径改成
/// `_refillOneTimeKeys(account, seed: true)`，注释写的是「首次注册：池必然为空」。
/// **该注释对这个调用点是错的**：`publishIdentityAndPrekeys` 由
/// `passport_notifier.dart` 与 `olm_protocol.dart` 调用，**每次登录都会跑**，
/// 且函数内没有任何幂等守卫。
///
/// 后果：`report_one_time_keys` 是**全量替换式**（先删后插），于是
/// **每次登录都会把一个健康的 OTK 池推倒重建一次**——正是那一刀自己指认为
/// 有害的 churn（该 evidence §1.1）。低水位判断因 `seed: true` 被完全绕过。
///
/// == 守护 ==
///
/// 1. 【对照组】账号是**新建**的 → 必须铺满（否则新设备一把 OTK 都没有）。
///    这条红 = harness 没驱动起发布流程，此时"不重发"的绿毫无意义；
/// 2. 账号从 pickle **载入**且服务端池健康 → **不得**重发 OTK；
/// 3. 【正向可用性】账号载入但池**见底** → 仍必须补传。
///    一个「载入账号一律不补」的实现在"不 churn"上恒满分，被这条否掉。
///
/// 用真 vodozemac 账号 + 假 `OlmApi` 记录调用，断言的是**有没有发出上报**，
/// 不是内部函数的返回值。
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

class _FakeOlmApi extends OlmApi {
  _FakeOlmApi({required this.countResult});

  final int? countResult;
  int reportPrekeysCalls = 0;
  int reportIdentityCalls = 0;
  int countCalls = 0;

  @override
  Future<bool> reportIdentity({
    required String deviceId,
    required String deviceType,
    required String ed25519Key,
    required String curve25519Key,
    required String signature,
  }) async {
    reportIdentityCalls++;
    return true;
  }

  @override
  Future<int?> countPrekeys() async {
    countCalls++;
    return countResult;
  }

  @override
  Future<int> reportPrekeys({
    required String deviceId,
    required List<Map<String, String>> keys,
  }) async {
    reportPrekeysCalls++;
    return keys.length;
  }

  @override
  Future<bool> reportFallbackKey({
    required String deviceId,
    required String keyId,
    required String keyBase64,
    String signature = '',
  }) async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              secureStore[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return secureStore[call.arguments['key'] as String];
            case 'delete':
              secureStore.remove(call.arguments['key'] as String);
              return null;
            case 'deleteAll':
              secureStore.clear();
              return null;
            case 'readAll':
              return Map<String, String?>.from(secureStore);
            case 'containsKey':
              return secureStore.containsKey(call.arguments['key'] as String);
          }
          return null;
        });
    // vod.init 全进程只能调一次
    await vod.init(libraryPath: _spikeLibDir);
    OlmSessionService.debugMarkVodReady();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  setUp(() {
    secureStore.clear();
    OlmSessionService.to.debugResetAccountCache();
  });

  test('对照组：新建账号必须铺满 OTK 池', () async {
    final api = _FakeOlmApi(countResult: 50);
    await OlmSessionService.to.publishIdentityAndPrekeys(api: api);

    expect(api.reportIdentityCalls, 1, reason: '对照组红 = 发布流程根本没跑起来');
    expect(api.reportPrekeysCalls, 1, reason: '新建账号服务端一把 OTK 都没有，必须无条件铺满');
    expect(api.countCalls, 0, reason: '新建账号不该依赖查询——查询一失败就永远没有 OTK');
  });

  test('从 pickle 载入 + 池健康 → 不得重发 OTK', () async {
    // 第一次：新建并持久化
    await OlmSessionService.to.publishIdentityAndPrekeys(
      api: _FakeOlmApi(countResult: 50),
    );
    // 清掉内存缓存，使下次走 pickle 载入路径
    OlmSessionService.to.debugResetAccountCache();

    final api = _FakeOlmApi(countResult: 50);
    await OlmSessionService.to.publishIdentityAndPrekeys(api: api);

    expect(api.reportIdentityCalls, 1, reason: '身份仍应上报（幂等 upsert）');
    expect(api.countCalls, 1, reason: '载入账号必须去查真实余量');
    expect(
      api.reportPrekeysCalls,
      0,
      reason:
          'report_one_time_keys 是全量替换式；'
          '池健康仍重发 = 每次登录把整个池推倒重建',
    );
  });

  test('正向可用性：载入账号但池见底 → 仍必须补传', () async {
    await OlmSessionService.to.publishIdentityAndPrekeys(
      api: _FakeOlmApi(countResult: 50),
    );
    OlmSessionService.to.debugResetAccountCache();

    final api = _FakeOlmApi(countResult: 0);
    await OlmSessionService.to.publishIdentityAndPrekeys(api: api);

    expect(
      api.reportPrekeysCalls,
      1,
      reason: '「载入账号一律不补」在"不 churn"指标上恒满分，必须被这条否掉',
    );
  });
}
