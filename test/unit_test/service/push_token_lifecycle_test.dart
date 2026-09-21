// EPGZ-07 — Flutter push token 生命周期测试（W2 转 GREEN）
//
// W1 骨架的 2 条「错位快照」已翻转为真实 PushApi 合同断言，
// 10 条 skip 中的注册/刷新/注销/登出清理/登出后不导航已全部转实跑：
// - 字段合同：经注入 HttpClientAdapter 捕获真实 PushApi.register 构造的
//   body（镜像 test/organization/organization_api_contract_test.dart 基建）；
// - 生命周期：对 PushNotificationService 单例做行为测试（StorageService
//   mock 出登录态），HTTP 出口同样经 adapter 捕获，零真实网络；
// - 接线（loginAfter/quitLogin/_navigateByResult 守卫）：源码接线断言
//   （镜像 test/unit_test/page/glass_app_bar_policy_test.dart 的
//   readAsStringSync 惯用法）——接线点本身是被测物，无法经行为覆盖。
//
// 合同来源：
// - 计划 §7.4（JPush）：注册、刷新、注销、登出清理、登出后不导航。
// - 后端合同：imboy user_device_handler push_register + push_token CHECK
//   （body {device_id, device_type, platform, token}，
//    device_type ∈ {android, ios, web}，platform ∈ {fcm, apns, web_push, jpush}）
//
// 运行：flutter test test/unit_test/service/push_token_lifecycle_test.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/push_api.dart';

const Set<String> kContractDeviceTypes = {'android', 'ios', 'web'};
const Set<String> kContractProviders = {'fcm', 'apns', 'web_push', 'jpush'};

/// 记录请求 + 恒返指定响应的出口（不触网）
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  int statusCode;
  dynamic body;

  /// 每次请求的 (method, path, data, queryParameters)
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.path,
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
    ));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

/// 手工构造的非过期 JWT（exp=2286 年）：让 HttpClient._setDefaultConfig
/// 走「已登录 + 有效 token」分支，避免触发 _handleTokenExpired →
/// quitLogin（清空登录态/关闭 WS/DB，污染用例）。
String fakeJwt() {
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  final header = b64('{"alg":"HS256","typ":"JWT"}');
  final payload = b64('{"exp":9999999999}');
  final sig = b64('test-signature');
  return '$header.$payload.$sig';
}

void main() {
  // 单一共享 adapter：PushNotificationService 单例（含其 PushApi/Dio）跨
  // 用例复用，Dio 的 adapter 只在构造时绑定——若每个用例各建一个 adapter，
  // 单例的 Dio 永远持有第一个，后续用例的 adapter 收不到请求。
  // 共享实例 + 每用例清空 requests 列表，兼顾单例现实与用例隔离。
  final adapter = _RecordingAdapter(200, okEnvelope());

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    deviceId = 'did-android-1';
    // 铁律：adapterForTest 只在 HttpClient 构造时绑定——必须先设 adapter，
    // 再触碰 PushNotificationService.instance（其字段初始化即构造 PushApi/Dio）。
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    adapter.requests.clear();
    // 预置非过期登录 token：注册请求需要「已登录且 token 有效」的头部环境
    FlutterSecureStorage.setMockInitialValues({
      'secure_token': fakeJwt(),
      'secure_refresh_token': fakeJwt(),
    });
    PushNotificationService.instance.resetForTest();
  });

  /// 写入/清除登录态（mock storage）
  Future<void> loginAs(int uid) async {
    await StorageService.to.setString(Keys.currentUid, uid.toString());
  }

  Future<void> logoutLocal() async {
    await StorageService.to.remove(Keys.currentUid);
  }

  // ---------------------------------------------------------------------------
  // 1. 注册请求字段合同（W1 错位快照已翻转：真实 PushApi body 断言）
  // ---------------------------------------------------------------------------
  group('注册请求字段合同 — {device_id, device_type, platform, token}', () {
    test('W1 错位 1 翻转：body 含 device_type 键且值在合同值域', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      final ok = await PushApi().register(
        token: 'rid-jpush-001',
        deviceType: 'android',
        platform: 'jpush',
        deviceId: 'did-android-1',
      );
      expect(ok, isTrue);
      expect(adapter.requests, hasLength(1));
      final body = adapter.requests.single.$3 as Map<String, dynamic>;
      // W1 快照断言 body.containsKey('device_type') == isFalse —— 已翻转为：
      expect(body.containsKey('device_type'), isTrue);
      expect(kContractDeviceTypes.contains(body['device_type']), isTrue);
    });

    test('W1 错位 2 翻转：platform 是 provider 值（不再误传 device_type 值）', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await PushApi().register(
        token: 'rid-jpush-001',
        deviceType: 'android',
        platform: 'jpush',
        deviceId: 'did-android-1',
      );
      final body = adapter.requests.single.$3 as Map<String, dynamic>;
      // W1 快照断言 'android' 不在 provider 值域 —— 现在真实 body 的
      // platform 必须落在 provider 值域内
      expect(kContractProviders.contains(body['platform']), isTrue);
      expect(body['platform'], isNot(anyOf('android', 'ios')));
    });

    test('Android + JPush 组合：完整 body 形状', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      final ok = await PushApi().register(
        token: 'rid-jpush-001',
        deviceType: 'android',
        platform: 'jpush',
        deviceId: 'did-android-1',
      );
      expect(ok, isTrue);
      final req = adapter.requests.single;
      expect(req.$1, 'POST');
      expect(req.$2, '/api/v1/push/register');
      expect(req.$3, {
        'token': 'rid-jpush-001',
        'device_type': 'android',
        'platform': 'jpush',
        'device_id': 'did-android-1',
      });
    });

    test('Android + FCM 组合仍兼容：platform=fcm 不受 JPush 接入影响', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await PushApi().register(
        token: 'fcm-token-x',
        deviceType: 'android',
        platform: 'fcm',
        deviceId: 'did-android-1',
      );
      final body = adapter.requests.single.$3 as Map<String, dynamic>;
      expect(body['platform'], 'fcm');
      expect(body['device_type'], 'android');
    });

    test(
      'iOS 组合不受影响：device_type=ios、platform=apns（一期 JPush 仅 Android）',
      () async {
        // adapter 由 setUp 注入（见 setUp 铁律注释）
        await PushApi().register(
          token: 'apns-token-x',
          deviceType: 'ios',
          platform: 'apns',
          deviceId: 'did-ios-1',
        );
        final body = adapter.requests.single.$3 as Map<String, dynamic>;
        expect(body['device_type'], 'ios');
        expect(body['platform'], 'apns');
      },
    );

    test('provider 语义拆分（F2）：deviceTypeId/fcmProviderId 纯函数', () {
      expect(PushNotificationService.deviceTypeId(isIOS: true), 'ios');
      expect(PushNotificationService.deviceTypeId(isIOS: false), 'android');
      expect(PushNotificationService.fcmProviderId(isIOS: true), 'apns');
      expect(PushNotificationService.fcmProviderId(isIOS: false), 'fcm');
      expect(PushNotificationService.jpushProviderId, 'jpush');
      // device_type 值与 provider 值域不相交（历史错位的类型级防线）
      for (final dt in kContractDeviceTypes) {
        expect(kContractProviders.contains(dt), isFalse, reason: dt);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. token 生命周期合同（J1/J2：注册、刷新、注销）
  // ---------------------------------------------------------------------------
  group('token 生命周期', () {
    test('未登录时 setToken 只存不注册（守卫保留：静默跳过）', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await PushNotificationService.instance.setToken('rid-jpush-001');
      expect(adapter.requests, isEmpty);
      expect(PushNotificationService.instance.pushToken, 'rid-jpush-001');
    });

    test('无 token 时 registerToken 静默跳过（不注册、不炸）', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await loginAs(1001);
      await PushNotificationService.instance.registerToken();
      expect(adapter.requests, isEmpty);
    });

    test('登录后 setToken 注册：device_type=android、platform=jpush', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await loginAs(1001);
      await PushNotificationService.instance.setToken(
        'rid-jpush-001',
        providerId: 'jpush',
      );
      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.$2, '/api/v1/push/register');
      // 测试宿主为非 iOS（macOS/Linux），deviceType 恒 android
      expect(req.$3, {
        'token': 'rid-jpush-001',
        'device_type': 'android',
        'platform': 'jpush',
        'device_id': 'did-android-1',
      });
      expect(PushNotificationService.instance.isRegistered, isTrue);
    });

    test('token 刷新后重新注册（JPush RegistrationID 变化路径）', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await loginAs(1001);
      await PushNotificationService.instance.setToken(
        'rid-jpush-001',
        providerId: 'jpush',
      );
      // 刷新：同一 setToken 入路换新 rid（FCM 侧等价 onTokenRefresh 分支）
      await PushNotificationService.instance.setToken(
        'rid-jpush-002-new',
        providerId: 'jpush',
      );
      expect(adapter.requests, hasLength(2));
      // 新请求携带新 token（同设备旧 token 由后端 upsert 先 deactivate，
      // 对应后端 J1 刷新合同）
      final body = adapter.requests.last.$3 as Map<String, dynamic>;
      expect(body['token'], 'rid-jpush-002-new');
      expect(body['platform'], 'jpush');
      expect(body['device_type'], 'android');
    });

    test('注销请求只带 device_id', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      final ok = await PushApi().unregister(deviceId: 'did-android-1');
      expect(ok, isTrue);
      final req = adapter.requests.single;
      expect(req.$2, '/api/v1/push/unregister');
      expect(req.$3, {'device_id': 'did-android-1'});
    });

    test('注销成功后状态复位：再次 unregisterToken 静默（幂等清理）', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await loginAs(1001);
      final svc = PushNotificationService.instance;
      await svc.setToken('rid-jpush-001', providerId: 'jpush');
      expect(adapter.requests, hasLength(1));
      await svc.unregisterToken();
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.$2, '/api/v1/push/unregister');
      expect(svc.isRegistered, isFalse);
      // 第二次注销：未注册状态静默跳过，不再发请求
      await svc.unregisterToken();
      expect(adapter.requests, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. 登录/登出接线（F4）与「登出后不导航」守卫
  // ---------------------------------------------------------------------------
  group('登出清理与接线', () {
    // 接线点本身是被测物（loginAfter/quitLogin/守卫在私有方法内），
    // 经源码接线断言覆盖（readAsStringSync 惯用法，同 glass_app_bar_policy_test）。
    final repoSrc = File('lib/store/repository/user_repo_local.dart')
        .readAsStringSync();
    final serviceSrc = File('lib/service/push_notification_service.dart')
        .readAsStringSync();

    test('loginAfter 接线：登录成功后触发 registerToken（F4）', () {
      expect(
        repoSrc.contains('PushNotificationService.instance.registerToken()'),
        isTrue,
        reason: 'loginAfter 建立 uid/token 后必须注册 push token',
      );
    });

    test('quitLogin 先注销 push token 再清本地状态（F4，顺序契约）', () {
      final quitStart = repoSrc.indexOf('Future<bool> quitLogin');
      expect(quitStart, greaterThan(0));
      final quitBody = repoSrc.substring(quitStart);
      final unregIdx = quitBody.indexOf(
        'PushNotificationService.instance.unregisterToken()',
      );
      expect(unregIdx, greaterThan(0), reason: 'quitLogin 必须注销 push token');
      // 注销必须先于本地登录态清除（注销 API 依赖登录态 JWT）
      final clearUidIdx = quitBody.indexOf('Keys.currentUid');
      final clearTokenIdx = quitBody.indexOf('SecureTokenStorageService.clear');
      expect(clearUidIdx, greaterThan(unregIdx));
      expect(clearTokenIdx, greaterThan(unregIdx));
    });

    test('登出后通知点击不得导航（_navigateByResult isLoggedIn 守卫）', () {
      final navIdx = serviceSrc.indexOf('void _navigateByResult(');
      expect(navIdx, greaterThan(0));
      final navBody = serviceSrc.substring(navIdx);
      // 守卫必须出现在获取路由 context 之前
      final guardIdx = navBody.indexOf('isLoggedIn');
      final ctxIdx = navBody.indexOf('navigatorKey.currentContext');
      expect(guardIdx, greaterThan(0), reason: '导航前必须检查登录态');
      expect(guardIdx, lessThan(ctxIdx));
    });

    test('登出后（本地已清 uid）不自动重注册：等待下次登录事件', () async {
      // adapter 由 setUp 注入（见 setUp 铁律注释）
      await loginAs(1001);
      final svc = PushNotificationService.instance;
      await svc.setToken('rid-jpush-001', providerId: 'jpush');
      expect(adapter.requests, hasLength(1));
      // 登出：本地登录态清除 + push 注销
      await svc.unregisterToken();
      await logoutLocal();
      // 残留 token 存在也不再重注册（无重注册循环；后端已下线该 token）
      await svc.registerToken();
      expect(
        adapter.requests.where((r) => r.$2 == '/api/v1/push/register').length,
        1,
      );
    });
  });
}
