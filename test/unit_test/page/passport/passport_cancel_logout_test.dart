import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_field.dart';
import 'package:imboy/config/init.dart'
    show currentEnv, navigatorKey, serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/login_page.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../../env_test_pin.dart';

/// A01-NC-4：登录响应 status==2（账号处于注销冷静期）的行为验证。
///
/// 源码考察结论（详见 A01_APP_TEST_REPORT.md PD-2）：
/// `PassportNotifier._login/_loginByCode` 对 `payload.status==2` 的账号
/// 直接执行 loginAfter 建立完整会话并返回 1，`_handleLoginStatus` 的
/// status==2 分支（`_showCancelLogoutDialog` → `userApi.cancelLogout`
/// → 换页）在两条登录路径上都**不可达**（`_login/_loginByCode` 只返回
/// 0/1，从不透传服务端 status）。因此取消注销确认弹窗永远不会出现。
///
/// 本用例按现行行为特征化（M02 规则：缺陷存在时测试锁定现状）：
/// - status==2 登录成功 → 建立会话并导航 /bottom_navigation
/// - 取消注销弹窗不出现、/user/cancel_logout 请求不发出
/// - 凭据在本机完整落盘（注销中账号可直接进入主界面——风险面）
/// 修复（透传 status 或移除死分支）后应同步改写本用例。

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const MethodChannel _deviceInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/device_info',
);

class _RouterAdapter implements HttpClientAdapter {
  final List<String> requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    if (options.path == API.login) {
      return ResponseBody.fromString(
        '{"code":0,"payload":{"status":2,"uid":"2002",'
        '"token":"synthetic-status2-access-token",'
        '"refreshtoken":"synthetic-status2-refresh",'
        '"account":"alice_status2@imboy.pub","nickname":"Alice2"}}',
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

/// wsUrl 为空的 loopback 环境：阻断登录成功腿 openSocket 的真实连接。
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

GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  // 必须复用全局 navigatorKey：_showCancelLogoutDialog 取
  // navigatorKey.currentContext 弹窗，弹窗断言要在同一棵树上做
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/sign_in',
    routes: [
      GoRoute(path: '/sign_in', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/bottom_navigation',
        builder: (_, _) => stub('bottom_nav stub'),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secure = <String, String>{};
  late _RouterAdapter adapter;

  setUpAll(() {
    envMap['dev'] = const _NoWsLoopbackEnv();
    currentEnv = 'dev';
  });

  tearDownAll(pinLoopbackTestEnv);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    SqliteService.setDbUnavailableForTest();
    secure.clear();
    secure[Keys.publicKey] = 'test-public-key-pem';

    adapter = _RouterAdapter();
    HttpClient.adapterForTest = adapter;
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
              'systemGUID': 'test-device-guid-2002',
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

  Finder _fieldByHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  testWidgets(
    'status==2 注销冷静期账号登录：现行行为=直接建立会话，无取消注销弹窗、无 cancelLogout 请求（PD-2 特征化）',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [passportProvider.overrideWith(PassportNotifier.new)],
          child: TranslationProvider(
            child: MaterialApp.router(routerConfig: _stubRouter()),
          ),
        ),
      );
      await tester.pump();

      // 切到邮箱 Tab（验证码登录 → _loginByCode 路径）
      await tester.tap(find.text('邮箱').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        _fieldByHint(t.passport.hintEmail),
        'alice_status2@imboy.pub',
      );
      await tester.enterText(
        _fieldByHint(t.passport.hintVerifyCode).last,
        '123456',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('login_submit_button')));
      // 推进 fake-async：微任务 + _loginByCode 内 100ms 延迟
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // ① 现行行为：登录被放行，页面导航到主界面
      expect(
        find.text('bottom_nav stub'),
        findsOneWidget,
        reason: 'status==2 现行行为：loginAfter 建立会话后 context.go 主界面',
      );

      // ② 取消注销确认弹窗从未出现（PD-2：status==2 分支不可达）
      expect(
        find.byType(CupertinoAlertDialog),
        findsNothing,
        reason: '_showCancelLogoutDialog 分支不可达：_loginByCode 只返回 0/1',
      );
      expect(find.text(t.common.cancelLogoutTitle), findsNothing);

      // ③ 取消注销接口零调用
      expect(
        adapter.requests,
        isNot(contains(API.userCancelLogout)),
        reason: '不可达分支的另一面：cancelLogout 网络请求不发出',
      );
      expect(adapter.requests.where((p) => p == API.login).length, 1);

      // ④ 风险面：注销中账号在本机建立了完整会话（凭据已落盘）
      expect(UserRepoLocal.to.isLoggedIn, isTrue);
      expect(UserRepoLocal.to.currentUid, '2002');
      expect(secure['secure_token'], 'synthetic-status2-access-token');
      expect(secure['secure_refresh_token'], 'synthetic-status2-refresh');
      final currentUser = StorageService.getMap(Keys.currentUser);
      expect(currentUser['status'], 2, reason: '注销状态原样存入 currentUser');
      expect(currentUser['account'], 'alice_status2@imboy.pub');

      // 登录成功腿会让 WS 单例 init（重连定时器）、拉起消息队列定期清理
      // 定时器，且 feature refresh loop 会因 manifest 不一致排 2s 重试；
      // 测试结束前统一销毁，满足 pending-timer 不变量
      RuntimeFeatureRecovery.dispose();
      WebSocketService.to.dispose();
      PersistentMessageQueue.to.dispose();
    },
  );
}
