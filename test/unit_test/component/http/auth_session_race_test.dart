import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/init.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.response, {this.onRequest});
  final void Function(RequestOptions)? onRequest;
  final Future<ResponseBody> Function() response;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    onRequest?.call(options);
    return response();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final repo = UserRepoLocal.to;
  Map<String, String> secure = {};
  final requests = <String>[];
  Future<ResponseBody> Function() transport = () async =>
      ResponseBody.fromString(
        '{"code":0,"payload":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  Future<void> Function()? beforeWrite;
  Future<void> Function(String?)? beforeDelete;
  Map<String, dynamic> payload() => {
    'uid': '1001',
    'token': 'synthetic-token-long',
    'refreshtoken': 'synthetic-refresh',
    'nickname': 'Synthetic',
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    secure = {};
    requests.clear();
    transport = () async => ResponseBody.fromString(
      '{"code":0,"payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    HttpClient.adapterForTest = _ResponseAdapter(
      () => transport(),
      onRequest: (o) => requests.add(o.path),
    );
    beforeWrite = null;
    beforeDelete = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
          (call) async {
            if (call.method == 'getDatabasesPath') {
              return '/nonexistent-synthetic-auth-test';
            }
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'write':
              await beforeWrite?.call();
              secure[key!] = args['value'] as String;
              return null;
            case 'delete':
              await beforeDelete?.call(key);
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
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
          null,
        );
    HttpClient.adapterForTest = null;
    HttpClient.onAuthExpired = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'UID remains unpublished while token persistence is pending/fails',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeWrite = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        throw PlatformException(code: 'synthetic-write-failure');
      };
      final login = repo.loginAfter('synthetic', payload());
      final failure = expectLater(login, throwsA(isA<PlatformException>()));
      await entered.future;
      expect(repo.currentUid, isEmpty);
      expect(repo.isLoggedIn, isFalse);
      release.complete();
      await failure;
      expect(repo.currentUid, isEmpty);
    },
  );
  test(
    'stale logout and refresh cannot touch a newer session generation',
    () async {
      final old = repo.sessionGeneration;
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-failure');
      await expectLater(
        repo.loginAfter('synthetic', payload()),
        throwsA(isA<PlatformException>()),
      );
      await StorageService.to.setString(Keys.currentUid, '1001');
      secure['secure_token'] = 'new-session-token';
      expect(await repo.quitLogin(expectedGeneration: old), isFalse);
      expect(
        await repo.saveAccessTokenForSession(old, 'old-response-token'),
        isFalse,
      );
      expect(repo.currentUid, '1001');
      expect(secure['secure_token'], 'new-session-token');
    },
  );
  test('auth expiry still notifies when secret purge needs recovery', () async {
    await StorageService.to.setString(Keys.currentUid, '1001');
    final part = base64Url
        .encode(utf8.encode('{"exp":4102444800}'))
        .replaceAll('=', '');
    secure['secure_token'] = 'e30.$part.signature';
    secure['e2ee_synthetic'] = 'synthetic-secret';
    beforeDelete = (key) async {
      if (key == 'e2ee_synthetic') {
        throw PlatformException(code: 'synthetic-purge-failure');
      }
    };
    var notifications = 0;
    HttpClient.onAuthExpired = () => notifications++;
    transport = () async => ResponseBody.fromString(
      '{"code":401,"msg":"synthetic expired"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    final client = HttpClient(
      options: BaseOptions(baseUrl: 'http://127.0.0.1'),
    );
    final response = await client.get('/synthetic-protected');
    expect(response.code, 401);
    expect(repo.isLoggedIn, isFalse);
    expect(secure['secure_token'], isNull);
    expect(StorageService.to.getBool(Keys.e2eePurgePending), isTrue);
    expect(notifications, 1);
    await expectLater(
      repo.loginAfter('synthetic', payload()),
      throwsA(isA<Exception>()),
    );
    expect(repo.isLoggedIn, isFalse);
  });
  test('public login 401 does not expire the existing session', () async {
    await StorageService.to.setString(Keys.currentUid, '1001');
    var notifications = 0;
    HttpClient.onAuthExpired = () => notifications++;
    HttpClient.adapterForTest = _ResponseAdapter(
      () async => ResponseBody.fromString(
        '{"code":401,"msg":"synthetic rejected","payload":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final client = HttpClient(
      options: BaseOptions(baseUrl: 'http://127.0.0.1'),
    );
    final result = await client.post(API.login, data: {'account': 'synthetic'});
    expect(result.code, 401);
    expect(repo.currentUid, '1001');
    expect(notifications, 0);
  });
  test(
    'same UID old protected response is rejected after a new login attempt',
    () async {
      await StorageService.to.setString(Keys.currentUid, '1001');
      final part = base64Url
          .encode(utf8.encode('{"exp":4102444800}'))
          .replaceAll('=', '');
      secure['secure_token'] = 'e30.$part.signature';
      final entered = Completer<void>();
      final reply = Completer<ResponseBody>();
      var notifications = 0;
      HttpClient.onAuthExpired = () => notifications++;
      HttpClient.adapterForTest = _ResponseAdapter(() {
        entered.complete();
        return reply.future;
      });
      final client = HttpClient(
        options: BaseOptions(baseUrl: 'http://127.0.0.1'),
      );
      final oldRequest = client.get('/synthetic-protected');
      await entered.future;
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-failure');
      await expectLater(
        repo.loginAfter('synthetic', payload()),
        throwsA(isA<PlatformException>()),
      );
      reply.complete(
        ResponseBody.fromString(
          '{"code":401,"msg":"rejected"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect((await oldRequest).code, 409);
      expect(repo.currentUid, '1001');
      expect(notifications, 0);
    },
  );
  test(
    'login credential writes wait until logout secret cleanup completes',
    () async {
      await StorageService.to.setString(Keys.currentUid, '1001');
      final deleting = Completer<void>();
      final release = Completer<void>();
      beforeDelete = (key) async {
        if (key == 'secure_token' && !deleting.isCompleted) {
          deleting.complete();
          await release.future;
        }
      };
      final logout = repo.quitLogin();
      await deleting.future;
      var loginWrites = 0;
      beforeWrite = () async {
        loginWrites++;
        throw PlatformException(code: 'synthetic-failure');
      };
      final login = repo.loginAfter('synthetic', payload());
      final failed = expectLater(login, throwsA(isA<PlatformException>()));
      await Future<void>.delayed(Duration.zero);
      expect(loginWrites, 0);
      release.complete();
      await logout;
      await failed;
      expect(loginWrites, 1);
    },
  );
  for (final token in ['', 'e30.eyJleHAiOjF9.signature']) {
    test(
      'persisted push binding cleanup does not reenter auth with ${token.isEmpty ? 'empty' : 'expired'} token',
      () async {
        deviceId = 'synthetic-device';
        await StorageService.to.setString(Keys.currentUid, '1001');
        await StorageService.to.setString(
          Keys.pushRegisteredDeviceId,
          deviceId,
        );
        secure['secure_token'] = token;
        secure['secure_refresh_token'] = 'synthetic-refresh';
        expect(PushNotificationService.instance.hasServerBinding(), isTrue);
        transport = () async => ResponseBody.fromString(
          '{"code":401,"msg":"synthetic expired"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
        final completed = await repo.quitLogin().timeout(
          const Duration(seconds: 5),
        );
        expect(completed, isTrue);
        expect(repo.currentUid, isEmpty);
        expect(requests, [API.pushUnregister]);
        expect(secure['secure_token'], isNull);
        expect(secure['secure_refresh_token'], isNull);
        await StorageService.to.remove(Keys.pushRegisteredDeviceId);
        deviceId = '';
      },
    );
  }
  testWidgets('socket expiry waits for logout before navigating', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/safe',
      routes: [
        GoRoute(path: '/safe', builder: (_, state) => const Text('safe')),
        GoRoute(path: '/sign_in', builder: (_, state) => const Text('signin')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await StorageService.to.setString(Keys.currentUid, '1001');
    await tester.runAsync(() async {
      await quitLoginAndNavigateToSignIn(source: 'synthetic-socket');
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('signin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'queued expired navigation cannot override a newer login generation',
    (tester) async {
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/safe',
        routes: [
          GoRoute(path: '/safe', builder: (_, state) => const Text('safe')),
          GoRoute(
            path: '/sign_in',
            builder: (_, state) => const Text('signin'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      navigateToSignIn(source: 'synthetic-old-session');
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-failure');
      await tester.runAsync(() async {
        await expectLater(
          repo.loginAfter('synthetic', payload()),
          throwsA(isA<PlatformException>()),
        );
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('safe'), findsOneWidget);
      expect(find.text('signin'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
