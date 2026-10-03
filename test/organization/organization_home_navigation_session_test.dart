/// Offline synthetic session invalidation; secure writes stop login commit.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _Adapter implements HttpClientAdapter {
  int invitations = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final mine = options.path.endsWith('/organizations/mine');
    if (options.path.endsWith('/invitations/mine')) invitations++;
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': mine
            ? {
                'list': [
                  {
                    'id': 7001,
                    'name': 'synthetic organization',
                    'status': 'active',
                  },
                ],
                'page': 1,
                'size': 100,
                'total': 1,
                'total_page': 1,
              }
            : {'list': <dynamic>[]},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // Initialize the serialized session queue outside the widget fake-async zone.
    UserRepoLocal.to.sessionGeneration;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'write') {
              throw PlatformException(code: 'synthetic-secure-write-stop');
            }
            return null;
          },
        );
    HttpClient.adapterForTest = _Adapter();
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  for (final entry in ['directory', 'invitations', 'detail']) {
    for (final stale in [false, true]) {
      testWidgets('$entry ${stale ? "失效会话禁止导航" : "当前会话正常导航"}', (tester) async {
        final router = GoRouter(
          initialLocation: '/organization',
          routes: [
            GoRoute(
              path: '/organization',
              builder: (context, state) =>
                  const OrganizationHomePage(accountKey: '91001'),
            ),
            GoRoute(
              path: '/organization/7001/directory',
              builder: (context, state) =>
                  const Scaffold(body: Text('destination-directory')),
            ),
            GoRoute(
              path: '/organization/0/invitations',
              builder: (context, state) =>
                  const Scaffold(body: Text('destination-invitations')),
            ),
            GoRoute(
              path: '/organization/7001',
              builder: (context, state) =>
                  const Scaffold(body: Text('destination-detail')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await frames(tester);
        expect(find.text('synthetic organization'), findsOneWidget);
        if (stale) {
          final repo = UserRepoLocal.to;
          final generation = repo.sessionGeneration;
          var notifications = 0;
          void notified() => notifications++;
          repo.addListener(notified);
          try {
            await tester.runAsync(() async {
              await expectLater(
                repo
                    .loginAfter('synthetic-session', {
                      'uid': '91002',
                      'token': 'synthetic-access-value',
                      'refreshtoken': 'synthetic-refresh-value',
                    })
                    .timeout(const Duration(seconds: 5)),
                throwsA(isA<PlatformException>()),
              );
            });
          } finally {
            repo.removeListener(notified);
          }
          expect(repo.sessionGeneration, generation + 1);
          expect(repo.currentUid, isEmpty);
          expect(notifications, 0);
        }
        final target = switch (entry) {
          'directory' => find.byKey(
            const ValueKey('organization-home-directory-entry'),
          ),
          'invitations' => find.widgetWithIcon(IconButton, CupertinoIcons.mail),
          _ => find.text('synthetic organization'),
        };
        await tester.tap(target);
        await frames(tester);
        expect(
          find.text('destination-$entry'),
          stale ? findsNothing : findsOneWidget,
        );
        if (stale) {
          expect(find.text('synthetic organization'), findsOneWidget);
        } else {
          final element = tester.element(find.text('destination-$entry'));
          expect(GoRouterState.of(element).uri.path, switch (entry) {
            'directory' => '/organization/7001/directory',
            'invitations' => '/organization/0/invitations',
            _ => '/organization/7001',
          });
        }
      });
    }
  }
  for (final stale in [false, true]) {
    testWidgets('邀请页返回${stale ? "跨账号代次不刷新" : "当前账号刷新"}角标', (tester) async {
      final adapter = _Adapter();
      HttpClient.adapterForTest = adapter;
      final account = ValueNotifier('91001');
      addTearDown(account.dispose);
      final router = GoRouter(
        initialLocation: '/organization',
        routes: [
          GoRoute(
            path: '/organization',
            builder: (context, state) => ValueListenableBuilder<String>(
              valueListenable: account,
              builder: (context, value, child) =>
                  OrganizationHomePage(accountKey: value),
            ),
          ),
          GoRoute(
            path: '/organization/0/invitations',
            builder: (context, state) =>
                const Scaffold(body: Text('destination-invitations')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await frames(tester);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, CupertinoIcons.mail),
      );
      final action = (button.onPressed as dynamic)() as Future<void>;
      await frames(tester);
      expect(find.text('destination-invitations'), findsOneWidget);
      if (stale) {
        account.value = '91002';
        await frames(tester);
        account.value = '91001';
        await frames(tester);
      }
      final before = adapter.invitations;
      router.pop();
      var done = false;
      final completion = action.whenComplete(() => done = true);
      for (var i = 0; i < 30 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(done, isTrue, reason: 'Actual invitation callback must finish');
      await completion;
      await frames(tester);
      expect(adapter.invitations, before + (stale ? 0 : 1));
    });
  }
}
