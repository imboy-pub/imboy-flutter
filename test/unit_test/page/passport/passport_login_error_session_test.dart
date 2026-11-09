import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_field.dart';
import 'package:imboy/config/init.dart' show currentEnv, serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../../env_test_pin.dart';

/// A01-NC-2（notifier 腿）登录错误响应不写登录态。
///
/// 用真实 PassportNotifier（非 spy）驱动 `loginUserByCode`：
/// 验证码登录（_loginByCode 路径）对 API.login 返回 401 errorPassword 时，
/// 断言 secure_token / current_uid / current_user 全部零写入、isLoggedIn
/// 保持 false——错误响应只允许置 state.error，绝不调用 loginAfter 落盘
///（对应源码防线 passport_notifier.dart:635-641 `!resp2.ok` 分支）。
///
/// 不起完整 widget 树，规避 JVerify platform channel timer 泄漏
///（login_page_test.dart 头部注释记录的坑）。

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const MethodChannel _deviceInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/device_info',
);

/// 按 path 路由响应并记录请求序的测试适配器。
class _RouterAdapter implements HttpClientAdapter {
  final List<String> requests = <String>[];

  /// 对照组开关：true 时 login 返回 status==1 成功 payload。
  bool respondLoginOk = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    if (options.path == API.login) {
      if (respondLoginOk) {
        return ResponseBody.fromString(
          '{"code":0,"payload":{"status":1,"uid":"2003",'
          '"token":"synthetic-access-token-ok",'
          '"refreshtoken":"synthetic-refresh-ok",'
          '"account":"+8613800000001","nickname":"Synthetic"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        '{"code":401,"msg":"errorPassword"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"code":0,"payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// wsUrl 为空的 loopback 测试环境：登录成功腿会让 notifier 触发
/// openSocket，空 wsUrl 使其在「URL 未配置」分支直接返回，
/// 不产生真实 WebSocket 连接与重连定时器。
class _NoWsLoopbackEnv implements Env, EnvField {
  const _NoWsLoopbackEnv();

  @override
  String get apiBaseUrl => 'http://127.0.0.1:9800';

  @override
  String get wsUrl => '';

  @override
  String get iosAppId => '';

  @override
  String get solidifiedKey => '';

  @override
  String get solidifiedKeyIv => '';

  @override
  String get aMapIosKey => '';

  @override
  String get aMapAndroidKey => '';

  @override
  String get aMapWebKey => '';

  @override
  String get jiguangAppKey => '';

  @override
  String get alipayAppId => '';

  @override
  String get alipayUniversalLink => '';

  @override
  String get openaiApiKey => '';

  @override
  String get anthropicApiKey => '';

  @override
  bool get aiTestEnabled => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secure = <String, String>{};
  late _RouterAdapter adapter;

  setUpAll(() {
    // notifier 的 _localizedAuthErrMsg 需要可用的 t（slang 全局翻译）
    LocaleSettings.setLocaleSync(AppLocale.zhCn);
    // 阻断 openSocket 真连接（成功对照腿会触发）；套件结束恢复
    envMap['dev'] = const _NoWsLoopbackEnv();
    currentEnv = 'dev';
  });

  tearDownAll(pinLoopbackTestEnv);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // _commitLogin 会触达 SqliteService.to.db；测试内直接声明不可用，
    // db getter 走受控 null 分支（sqlite.dart setDbUnavailableForTest）
    SqliteService.setDbUnavailableForTest();
    secure.clear();
    // 预置 RSA 公钥，跳过 PointyCastle 真密钥生成（慢）
    secure[Keys.publicKey] = 'test-public-key-pem';

    adapter = _RouterAdapter();
    HttpClient.adapterForTest = adapter;
    // notifier 经 HttpClient.client（serviceContainer 定位）发请求，
    // 测试进程不跑 AppInitializer，需手动注册一个挂测试适配器的实例
    serviceContainer.put(
      HttpClient(options: BaseOptions(baseUrl: Env().apiBaseUrl)),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'write':
              secure[key!] = args['value'] as String;
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            case 'readAll':
              return secure;
            case 'deleteAll':
              secure.clear();
              return null;
          }
          return null;
        });
    // DeviceExt.to.detail 在 macOS 测试宿主走 macOsInfo 平台通道
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceInfoChannel, (call) async {
          if (call.method == 'getDeviceInfo') {
            return <String, dynamic>{
              'computerName': 'imboy-test',
              'hostName': 'imboy-test.local',
              'arch': 'arm64',
              'model': 'MacTest',
              'modelName': 'MacTest',
              'kernelVersion': 'test-kernel',
              'osRelease': '27.0.0',
              'majorVersion': 27,
              'minorVersion': 0,
              'patchVersion': 0,
              'activeCPUs': 8,
              'memorySize': 16,
              'cpuFrequency': 3200,
              'systemGUID': 'test-device-guid',
            };
          }
          return null;
        });
  });

  tearDown(() async {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceInfoChannel, null);
  });

  test('登录 401 errorPassword：notifier 置错且凭据零落盘（A01-NC-2）', () async {
    final container = ProviderContainer(
      overrides: [passportProvider.overrideWith(PassportNotifier.new)],
    );
    addTearDown(container.dispose);
    // autoDispose provider 必须挂监听保活，否则 await 期间 provider 被回收，
    // safeUpdateState/ref.mounted 全部失效（UnmountedRefException）
    final sub = container.listen(passportProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(passportProvider.notifier);

    final err = await notifier.loginUserByCode(
      'mobile',
      '+8613800000000',
      '000000',
    );

    // 1. 错误反馈到位（错验证码绝不静默）
    expect(err, isNotNull, reason: '401 必须向调用方返回错误消息');
    expect(err, isNotEmpty);
    expect(
      container.read(passportProvider).error,
      isNotEmpty,
      reason: 'state.error 必须置位供页面展示',
    );
    // 错误经 _localizedAuthErrMsg 本地化（errorPassword → 密码错误），
    // 英文错误码不得裸露给用户
    expect(err, '密码错误');

    // 2. 凭据/登录态零落盘（A01 行①页面/notifier 层断言）
    expect(
      secure.containsKey('secure_token'),
      isFalse,
      reason: '失败响应不得写入 access token',
    );
    expect(
      secure.containsKey('secure_refresh_token'),
      isFalse,
      reason: '失败响应不得写入 refresh token',
    );
    expect(
      StorageService.to.getString(Keys.currentUid),
      isEmpty,
      reason: '失败响应不得写入 current_uid',
    );
    expect(
      StorageService.getMap(Keys.currentUser),
      isEmpty,
      reason: '失败响应不得写入 current_user',
    );
    expect(
      StorageService.to.getStringList(Keys.loginHistory),
      isNull,
      reason: '失败响应不得写入登录历史',
    );
    expect(UserRepoLocal.to.currentUid, isEmpty);
    expect(UserRepoLocal.to.isLoggedIn, isFalse);

    // 3. 网络行为：登录恰好请求 1 次（_loginByCode 无 md5 重试路径），
    //    且绝不触发取消注销接口
    expect(adapter.requests.where((p) => p == API.login).length, 1);
    expect(adapter.requests, isNot(contains(API.userCancelLogout)));
  });

  test('登录成功后才可能落盘：401 后紧跟的正确请求走真实 loginAfter（对照）', () async {
    // 对照组：同一容器内把登录响应从 401 切到成功 status==1，
    // 证明「零落盘」断言的不是环境恰好没写，而是错误分支真的没走 loginAfter。
    adapter.requests.clear();
    final container = ProviderContainer(
      overrides: [passportProvider.overrideWith(PassportNotifier.new)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(passportProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(passportProvider.notifier);

    // 先错误（保持零落盘）
    await notifier.loginUserByCode('mobile', '+8613800000001', '000000');
    expect(secure.containsKey('secure_token'), isFalse);

    // 再成功：动态改写 login 响应为 status==1 全字段 payload
    adapter.respondLoginOk = true;
    final err2 = await notifier.loginUserByCode(
      'mobile',
      '+8613800000001',
      '123456',
    );
    expect(err2, isNull, reason: '成功响应返回 null');
    expect(
      secure['secure_token'],
      'synthetic-access-token-ok',
      reason: '成功路径必须真实落盘 access token',
    );
    expect(UserRepoLocal.to.isLoggedIn, isTrue);
    expect(UserRepoLocal.to.currentUid, '2003');
  });
}
