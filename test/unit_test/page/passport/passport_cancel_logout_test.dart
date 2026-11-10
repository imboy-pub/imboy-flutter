import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
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

/// A01-NC-4: status==2 retains the authenticated session but requires the
/// cancellation confirmation before the login page can leave for home.
/// The request and session writes use the real notifier and local repository.

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _SyntheticDeviceInfo extends DeviceInfoPlatform {
  @override
  Future<BaseDeviceInfo> deviceInfo() async {
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

/// Observe completion without replacing the production authentication path.
class _AwaitablePassportNotifier extends PassportNotifier {
  late Future<String?> loginRequest;

  @override
  Future<String?> loginUserByCode(String type, String account, String code) {
    loginRequest = super.loginUserByCode(type, account, code);
    return loginRequest;
  }
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
  late DeviceInfoPlatform originalDeviceInfo;

  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    envMap['dev'] = const _NoWsLoopbackEnv();
    currentEnv = 'dev';
  });

  tearDownAll(pinLoopbackTestEnv);

  setUp(() async {
    originalDeviceInfo = DeviceInfoPlatform.instance;
    DeviceInfoPlatform.instance = _SyntheticDeviceInfo();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // Initialize the session-write queue in setUp's real async zone, matching
    // the login submitted through runAsync rather than the widget's FakeAsync.
    expect(UserRepoLocal.to.isLoggedIn, isFalse);
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
  });

  tearDown(() async {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
    DeviceInfoPlatform.instance = originalDeviceInfo;
  });

  Finder fieldByHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  testWidgets('status==2 注销冷静期账号登录：显示取消注销确认，取消后不导航、不请求 cancelLogout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final notifier = _AwaitablePassportNotifier();
    final router = _stubRouter();
    addTearDown(router.dispose);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [passportProvider.overrideWith(() => notifier)],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: AppLoading.init(),
            ),
          ),
        ),
      );
      await tester.pump();

      // The email tab drives the real verification-code login path.
      await tester.tap(find.text('邮箱').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        fieldByHint(t.passport.hintEmail),
        'alice_status2@imboy.pub',
      );
      await tester.enterText(
        fieldByHint(t.passport.hintVerifyCode).last,
        '123456',
      );
      await tester.pump();

      final submit = tester
          .widget<CupertinoButton>(find.byKey(const Key('login_submit_button')))
          .onPressed!;
      // The session-write queue may have been created in the real zone.
      // Wait for the complete real request instead of estimating frame delays.
      await tester.runAsync(() async {
        submit();
        final result = await notifier.loginRequest.timeout(
          const Duration(seconds: 5),
        );
        expect(result, t.common.cancelLogoutTitle);
      });
      await tester.pump();
      unawaited(AppLoading.dismiss(animation: false));
      await tester.pumpAndSettle();

      expect(find.text('bottom_nav stub'), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text(t.common.cancelLogoutTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text(t.common.cancelLogoutBody),
        ),
        findsOneWidget,
      );
      expect(
        adapter.requests,
        isNot(contains(API.userCancelLogout)),
        reason: '用户确认前不得发出取消注销请求',
      );
      expect(adapter.requests.where((p) => p == API.login).length, 1);

      // Status propagation does not alter the pre-existing session semantics.
      expect(UserRepoLocal.to.isLoggedIn, isTrue);
      expect(UserRepoLocal.to.currentUid, '2002');
      expect(secure['secure_token'], 'synthetic-status2-access-token');
      expect(secure['secure_refresh_token'], 'synthetic-status2-refresh');
      final currentUser = StorageService.getMap(Keys.currentUser);
      expect(currentUser['status'], 2, reason: '注销状态原样存入 currentUser');
      expect(currentUser['account'], 'alice_status2@imboy.pub');

      await tester.tap(
        find.widgetWithText(CupertinoButton, t.common.buttonCancel),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('bottom_nav stub'), findsNothing);
      expect(adapter.requests, isNot(contains(API.userCancelLogout)));
      expect(secure['secure_token'], 'synthetic-status2-access-token');
      expect(tester.takeException(), isNull);
    } finally {
      RuntimeFeatureRecovery.dispose();
      WebSocketService.to.dispose();
      PersistentMessageQueue.to.dispose();
      unawaited(AppLoading.dismiss(animation: false));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
