import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/fallback_rotation_policy.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// E2EE-062：**fallback key 周期轮换的接线实证**。
///
/// 纯策略由 `fallback_rotation_policy_test.dart` 覆盖；本文件断言的是
/// **生产入口 `maybeRotateFallbackKey` 到底有没有真的换出并上报新 key**。
///
/// 守护：
/// 1. 从未记录过轮换时刻（升级上来的老账号）→ **必须轮换并上报**；
/// 2. 【对照组】刚轮换过 → **不得**再次上报。
///    它红说明轮换判据没生效、每次入站建会话都会重发一次 fallback key；
/// 3. 时刻过期 → 再次轮换，且 **keyId 与上一次不同**（真换，不是重发同一把）。
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

class _FakeOlmApi extends OlmApi {
  final List<String> reportedKeyIds = [];
  final List<String> signatures = [];

  @override
  Future<bool> reportFallbackKey({
    required String deviceId,
    required String keyId,
    required String keyBase64,
    String signature = '',
  }) async {
    reportedKeyIds.add(keyId);
    signatures.add(signature);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};
  const rotatedAtKey = 'olm_fallback_rotated_at';

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

  // ⚠️ 与策略**无关**的 harness 对照组。
  //
  // 下面两条业务对照组（"刚轮换过不得再报"）都依赖"第一次轮换成功"这个前置条件，
  // 因此在判据被人为摘除时它们会因**前置不成立**而红，而不是因被测性质失效——
  // 这削弱了"对照组红 = harness 缺陷"这个信号。本条只验 harness 本身
  // （secure storage mock 通道是活的），在任何实现状态下都必须绿。
  test('对照组（harness）：secure storage mock 通道可读写', () async {
    await StorageSecureService.to.write(key: 'probe', value: 'v1');
    expect(await StorageSecureService.to.read(key: 'probe'), 'v1');
    expect(secureStore['probe'], 'v1');
  });

  test('从未记录过轮换时刻 → 必须轮换并上报', () async {
    final api = _FakeOlmApi();
    final rotated = await OlmSessionService.to.maybeRotateFallbackKey(api: api);

    expect(rotated, isTrue);
    expect(api.reportedKeyIds.length, 1);
    expect(
      api.signatures.single,
      isNotEmpty,
      reason: '轮换出来的 key 同样必须带签名，否则绕过了服务端验签那一刀',
    );
    expect(
      secureStore[rotatedAtKey],
      isNotNull,
      reason: '不记录时刻的话，下一次入站建会话又会再换一把',
    );
  });

  test('对照组：刚轮换过 → 不得再次上报', () async {
    final first = _FakeOlmApi();
    await OlmSessionService.to.maybeRotateFallbackKey(api: first);
    expect(first.reportedKeyIds.length, 1);

    final second = _FakeOlmApi();
    final rotated = await OlmSessionService.to.maybeRotateFallbackKey(
      api: second,
    );

    expect(rotated, isFalse);
    expect(
      second.reportedKeyIds,
      isEmpty,
      reason:
          '对照组红 = 轮换判据没生效，'
          '每次入站建会话都会重发一次 fallback key',
    );
  });

  test('时刻过期 → 再次轮换，且 keyId 与上一次不同', () async {
    final first = _FakeOlmApi();
    await OlmSessionService.to.maybeRotateFallbackKey(api: first);
    final firstKeyId = first.reportedKeyIds.single;

    // 把上次轮换时刻拨回一个周期以前
    final expired =
        DateTime.now().millisecondsSinceEpoch -
        kFallbackRotationInterval.inMilliseconds -
        1000;
    secureStore[rotatedAtKey] = expired.toString();

    final second = _FakeOlmApi();
    final rotated = await OlmSessionService.to.maybeRotateFallbackKey(
      api: second,
    );

    expect(rotated, isTrue);
    expect(
      second.reportedKeyIds.single,
      isNot(firstKeyId),
      reason: '若 keyId 不变，则只是把同一把 key 重发了一遍，暴露窗口没有缩短',
    );
  });
}
