import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as http;
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

String _validToken() {
  final payload = base64Url
      .encode(utf8.encode('{"exp":4102444800}'))
      .replaceAll('=', '');
  return 'e30.$payload.signature';
}

ResponseBody _throttled() => ResponseBody.fromString(
  '{"code":429,"msg":"throttled"}',
  429,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    'retry-after': ['3'],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond, {this.acceptHttpErrors = false});
  final Future<ResponseBody> Function() respond;
  final bool acceptHttpErrors;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    if (acceptHttpErrors) options.validateStatus = (_) => true;
    return respond();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = UserRepoLocal.to;
  var secure = <String, String>{};
  Future<String?> Function(String?)? readOverride;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo.clearAuthTransitionFailureForTest();
    secure = {
      'secure_token': _validToken(),
      'secure_refresh_token': 'refresh-b',
    };
    readOverride = null;
    await StorageService.to.setString(Keys.currentUid, '1001');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return readOverride == null
                  ? secure[key]
                  : await readOverride!(key);
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

  tearDown(() {
    http.HttpClient.adapterForTest = null;
    http.HttpClient.onAuthExpired = null;
    UserApi.refreshAdapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  ResponseBody refreshResponse(String token) => ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'payload': {'token': token},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  test(
    'direct refresh callers share one request across expiry policies',
    () async {
      final entered = Completer<void>();
      final reply = Completer<ResponseBody>();
      final adapter = _Adapter(() {
        entered.complete();
        return reply.future;
      });
      UserApi.refreshAdapterForTest = adapter;
      final first = UserApi.to.refreshAccessTokenApi(
        'refresh-b',
        checkNewToken: false,
      );
      await entered.future;
      final second = UserApi.to.refreshAccessTokenApi('refresh-b');
      final third = UserApi.to.refreshAccessTokenApi('refresh-b');
      expect(identical(first, second), isTrue);
      reply.complete(refreshResponse('fresh-shared-token'));
      expect(await Future.wait([first, second, third]), [
        'fresh-shared-token',
        'fresh-shared-token',
        'fresh-shared-token',
      ]);
      expect(adapter.requests, hasLength(1));
      expect(secure['secure_token'], 'fresh-shared-token');
    },
  );

  test(
    'failed refresh releases shared flight and the next call retries',
    () async {
      final entered = Completer<void>();
      final reply = Completer<ResponseBody>();
      final adapter = _Adapter(() {
        entered.complete();
        return reply.future;
      });
      UserApi.refreshAdapterForTest = adapter;
      final first = UserApi.to.refreshAccessTokenApi('refresh-b');
      final firstError = expectLater(first, throwsA(isA<DioException>()));
      await entered.future;
      final second = UserApi.to.refreshAccessTokenApi('refresh-b');
      final secondError = expectLater(second, throwsA(isA<DioException>()));
      reply.completeError(
        DioException(requestOptions: adapter.requests.single),
      );
      await Future.wait([firstError, secondError]);
      expect(adapter.requests, hasLength(1));
      final retryAdapter = _Adapter(() async => refreshResponse('retry-token'));
      UserApi.refreshAdapterForTest = retryAdapter;
      expect(
        await UserApi.to.refreshAccessTokenApi('refresh-b'),
        'retry-token',
      );
      expect(retryAdapter.requests, hasLength(1));
    },
  );

  test('new account never joins or receives an older refresh result', () async {
    final entered = Completer<void>();
    final reply = Completer<ResponseBody>();
    final oldAdapter = _Adapter(() {
      entered.complete();
      return reply.future;
    });
    UserApi.refreshAdapterForTest = oldAdapter;
    final old = UserApi.to.refreshAccessTokenApi('shared-refresh');
    await entered.future;
    await StorageService.to.setString(Keys.currentUid, '1002');
    final nextAdapter = _Adapter(
      () async => refreshResponse('account-b-token'),
    );
    UserApi.refreshAdapterForTest = nextAdapter;
    expect(
      await UserApi.to.refreshAccessTokenApi('shared-refresh'),
      'account-b-token',
    );
    reply.complete(refreshResponse('stale-account-a-token'));
    expect(await old, '');
    expect(nextAdapter.requests, hasLength(1));
    expect(secure['secure_token'], 'account-b-token');
    expect(repo.currentUid, '1002');
  });

  test('stale empty token cannot log out B or send A request', () async {
    final entered = Completer<void>();
    final reply = Completer<String?>();
    readOverride = (key) {
      if (key == 'secure_token') {
        entered.complete();
        return reply.future;
      }
      return Future.value(secure[key]);
    };
    final adapter = _Adapter(() async => _throttled());
    http.HttpClient.adapterForTest = adapter;
    var notifications = 0;
    http.HttpClient.onAuthExpired = () => notifications++;
    final client = http.HttpClient(
      options: BaseOptions(baseUrl: 'http://127.0.0.1'),
      retryEnabled: false,
    );
    final request = client.post('/synthetic-write', data: {'value': 1});
    await entered.future;
    await StorageService.to.setString(Keys.currentUid, '1002');
    secure['secure_token'] = 'b-token';
    reply.complete(null);
    expect((await request).code, 409);
    expect(repo.currentUid, '1002');
    expect(secure['secure_token'], 'b-token');
    expect(adapter.requests, isEmpty);
    expect(notifications, 0);
  });

  for (final refresh in [false, true]) {
    testWidgets(
      '${refresh ? 'refresh' : 'request'} stale 429 is invisible to B',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
        );
        // Completer 必须建在真实区：fake-zone future 的解析排在 fake 微任务
        // 队列（runAsync 不排空），adapter 回调在真实区 complete 后跨区等待
        // 会永久挂起。
        Completer<void>? enteredReal;
        Completer<ResponseBody>? replyReal;
        await tester.runAsync(() async {
          enteredReal = Completer<void>();
          replyReal = Completer<ResponseBody>();
        });
        final entered = enteredReal!;
        final reply = replyReal!;
        final adapter = _Adapter(() {
          entered.complete();
          return reply.future;
        }, acceptHttpErrors: true);
        http.HttpClient.adapterForTest = adapter;
        UserApi.refreshAdapterForTest = adapter;
        var notifications = 0;
        http.HttpClient.onAuthExpired = () => notifications++;
        final client = http.HttpClient(
          options: BaseOptions(
            baseUrl: 'http://127.0.0.1',
            validateStatus: (status) => status != null,
          ),
          retryEnabled: false,
        );
        await tester.runAsync(() async {
          final request = refresh
              ? UserApi.to.refreshAccessTokenApi(
                  'refresh-a',
                  checkNewToken: false,
                )
              : client.get('/synthetic-protected');
          await entered.future;
          await StorageService.to.setString(Keys.currentUid, '1002');
          secure['secure_token'] = 'b-token';
          reply.complete(_throttled());
          final result = await request;
          if (refresh) {
            expect(result, '');
          } else {
            expect((result as dynamic).code, 409);
          }
        });
        await tester.pump();
        expect(
          find.text(t.common.throttleRetryAfter(seconds: '3')),
          findsNothing,
        );
        expect(repo.currentUid, '1002');
        expect(secure['secure_token'], 'b-token');
        expect(notifications, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final silent in [false, true]) {
    testWidgets('current session 429 toast follows silent=$silent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
      );
      http.HttpClient.adapterForTest = _Adapter(() async => _throttled());
      final client = http.HttpClient(
        options: BaseOptions(
          baseUrl: 'http://127.0.0.1',
          validateStatus: (status) => status != null,
        ),
        retryEnabled: false,
      );
      await tester.runAsync(() async {
        final result = await client.get(
          '/synthetic-protected',
          options: Options(extra: {httpSuppressErrorToast: silent}),
        );
        expect(result.code, 429);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(t.common.throttleRetryAfter(seconds: '3')),
        silent ? findsNothing : findsOneWidget,
      );
      expect(repo.currentUid, '1001');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
