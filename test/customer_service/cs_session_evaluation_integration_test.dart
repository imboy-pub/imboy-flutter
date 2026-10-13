import 'dart:async';

import 'cs_auth_fixture.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/service/storage.dart';

class RatingAdapter implements HttpClientAdapter {
  Map<String, Object?> facts;
  String status = 'closed';
  int detailFailure = 0;
  int casWrites = 0;
  Future<ResponseBody>? heldDetail;
  RatingAdapter(this.facts);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' &&
        (options.path.endsWith('/close') ||
            options.path.endsWith('/transfer'))) {
      casWrites++;
    }
    Object? payload;
    if (options.path.endsWith('/sessions/4') && heldDetail != null) {
      return heldDetail!;
    }
    if (options.path.contains('/sessions/') &&
        !options.path.endsWith('/read-cursor') &&
        !options.path.endsWith('/close')) {
      if (detailFailure != 0) {
        return ResponseBody.fromString(
          jsonEncode({'code': detailFailure, 'msg': 'denied'}),
          detailFailure,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      payload = {
        'id': options.path.split('/').last,
        'organization_id': '1',
        'workspace_id': '2',
        'conversation_id': '3',
        'business_identity_id': '5',
        'version': 2,
        'status': status,
        ...facts,
      };
    } else if (options.path.endsWith('/read-cursor')) {
      payload = {
        'session_id': '4',
        'last_read_message_id': 0,
        'unread_count': 0,
      };
    } else if (options.path.endsWith('/messages')) {
      payload = <Object>[];
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String token() {
  String part(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
}

bool fixtureAuthEstablished = false;
bool authExpiryCompleted = false;

Future<void> pumpPage(WidgetTester tester, {String session = '4'}) async {
  if (!fixtureAuthEstablished) {
    await establishCsWidgetAuthFixture(tester, uid: '9');
    fixtureAuthEstablished = true;
  }
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home: CsSessionPage(
        orgId: '1',
        workspaceId: '2',
        sessionId: session,
        conversationId: '3',
        identityId: '5',
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    fixtureAuthEstablished = false;
    authExpiryCompleted = false;
    HttpClient.onAuthExpired = () => authExpiryCompleted = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'readAll') return <String, String>{};
            if (call.method == 'read' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              return token();
            }
            return null;
          },
        );
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '9');
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    HttpClient.onAuthExpired = null;
  });
  test('public GET DTO Flow never marks malformed evaluation rated; true response replaces old rating', () async {
    final adapter = RatingAdapter({'rating': 4, 'rating_at': 1700000000});
    HttpClient.adapterForTest = adapter;
    final flow = CsSessionFlow(
      orgId: '1',
      workspaceId: '2',
      sessionId: '4',
      conversationId: '3',
      identityId: '5',
      store: EnterpriseMemoryStore(),
    );
    await flow.refreshSessionState();
    expect(flow.machine.phase, CsSeatSessionPhase.rated);
    for (final facts in <Map<String, Object?>>[
      {'rating': true, 'rating_at': 1700000000},
      {'rating': '4', 'rating_at': 1700000000},
      {'rating': 6, 'rating_at': 1700000000},
      {'rating': 4},
      {'rating': 4, 'rating_at': -1},
    ]) {
      adapter.facts = facts;
      await flow.refreshSessionState();
      expect(flow.detail!.evaluationState.name, 'unknown');
      expect(flow.detail!.ratingAt, isNull);
      final fresh = CsSessionFlow(
        orgId: '1',
        workspaceId: '2',
        sessionId: '4',
        conversationId: '3',
        identityId: '5',
        store: EnterpriseMemoryStore(),
      );
      await fresh.refreshSessionState();
      expect(fresh.machine.phase, CsSeatSessionPhase.closed);
      fresh.dispose();
    }
    flow.dispose();
  });
  testWidgets(
    'actual Page distinguishes unknown, explicit unrated, true UTC rated',
    (tester) async {
      final samples = <(Map<String, Object?>, String)>[
        ({'rating': '4', 'rating_at': 1700000000}, '评价状态未知'),
        ({'rating': null, 'rating_at': null}, '等待客户评分'),
        ({'rating': 4, 'rating_at': 1700000000}, '2023-11-14 22:13:20 UTC'),
      ];
      for (final (facts, expected) in samples) {
        HttpClient.adapterForTest = RatingAdapter(facts);
        await pumpPage(tester);
        expect(find.textContaining(expected), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse,
        );
        if (expected == '评价状态未知') {
          expect(find.textContaining('等待客户评分'), findsNothing);
          expect(find.textContaining('客户评分：'), findsNothing);
        }
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();
      }
    },
  );
  testWidgets(
    'actual Page refresh removes previous rating text/time for unknown facts',
    (tester) async {
      final adapter = RatingAdapter({'rating': 4, 'rating_at': 1700000000});
      HttpClient.adapterForTest = adapter;
      await pumpPage(tester);
      expect(find.textContaining('客户评分：4'), findsOneWidget);
      adapter.facts = {};
      await tester.runAsync(
        () => tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh(),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('评价状态未知'), findsOneWidget);
      expect(find.textContaining('客户评分：'), findsNothing);
      expect(find.textContaining('2023-11-14'), findsNothing);
      expect(find.textContaining('已评分结束'), findsNothing);
      expect(find.textContaining('客户已完成评分'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    },
  );
  testWidgets(
    'close success keeps old active evaluation unknown until real closed detail',
    (tester) async {
      final adapter = RatingAdapter({'rating': null, 'rating_at': null})
        ..status = 'active';
      HttpClient.adapterForTest = adapter;
      await pumpPage(tester);
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '关闭会话').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('评价状态未知'), findsOneWidget);
      expect(find.textContaining('等待客户评分'), findsNothing);
      adapter.status = 'closed';
      await tester.runAsync(
        () => tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh(),
      );
      await tester.pump();
      expect(find.textContaining('等待客户评分'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    },
  );
  for (final code in [401, 403]) {
    testWidgets('actual Page $code invalidates prior rating projection', (
      tester,
    ) async {
      final adapter = RatingAdapter({'rating': 4, 'rating_at': 1700000000});
      HttpClient.adapterForTest = adapter;
      await pumpPage(tester);
      expect(find.textContaining('客户评分：4'), findsOneWidget);
      adapter.detailFailure = code;
      await tester.runAsync(
        () => tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh(),
      );
      if (code == 401) {
        expect(authExpiryCompleted, isTrue);
        await drainCsAuthQueue(tester);
      }
      await tester.pump();
      expect(find.textContaining('客户评分：'), findsNothing);
      expect(find.textContaining('2023-11-14'), findsNothing);
      expect(find.textContaining('已评分结束'), findsNothing);
      expect(find.textContaining('客户已完成评分'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    });
  }
  testWidgets('late A detail denial does not erase current B rating facts', (
    tester,
  ) async {
    final adapter = RatingAdapter({'rating': 4, 'rating_at': 1700000000});
    HttpClient.adapterForTest = adapter;
    await pumpPage(tester);
    final held = Completer<ResponseBody>();
    adapter.heldDetail = held.future;
    late Future<void> refresh;
    await tester.runAsync(() async {
      refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await pumpPage(tester, session: '6');
    held.complete(
      ResponseBody.fromString(
        jsonEncode({'code': 403, 'msg': 'old denied'}),
        403,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    await tester.runAsync(() => refresh);
    await tester.pump();
    expect(find.textContaining('客户评分：4'), findsOneWidget);
    expect(find.textContaining('2023-11-14 22:13:20 UTC'), findsOneWidget);
  });
  testWidgets(
    'auth loss removes only owned action dialog and clears the old draft',
    (tester) async {
      final adapter = RatingAdapter({'rating': null, 'rating_at': null})
        ..status = 'active';
      HttpClient.adapterForTest = adapter;
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField).first, 'old A draft');
      final held = Completer<ResponseBody>();
      adapter.heldDetail = held.future;
      late Future<void> refresh;
      await tester.runAsync(() async {
        refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '关闭会话'), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(CsSessionPage)),
          builder: (_) => const AlertDialog(title: Text('foreign owned route')),
        ),
      );
      await tester.pumpAndSettle();
      held.complete(
        ResponseBody.fromString(
          jsonEncode({'code': 401, 'msg': 'denied'}),
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.runAsync(() => refresh);
      expect(authExpiryCompleted, isTrue);
      await drainCsAuthQueue(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('关闭会话'), findsNothing);
      expect(find.text('foreign owned route'), findsOneWidget);
      final inputs = tester.widgetList<TextField>(
        find.byType(TextField, skipOffstage: false),
      );
      expect(inputs.first.controller!.text, isEmpty);
      expect(inputs.first.enabled, isFalse);
      expect(adapter.casWrites, 0);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
    },
  );
  testWidgets('late A denial cannot clear current B draft or action dialog', (
    tester,
  ) async {
    final adapter = RatingAdapter({'rating': null, 'rating_at': null})
      ..status = 'active';
    HttpClient.adapterForTest = adapter;
    await pumpPage(tester);
    final held = Completer<ResponseBody>();
    adapter.heldDetail = held.future;
    late Future<void> refresh;
    await tester.runAsync(() async {
      refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await pumpPage(tester, session: '6');
    await tester.enterText(find.byType(TextField).first, 'B draft');
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
    await tester.pumpAndSettle();
    held.complete(
      ResponseBody.fromString(
        jsonEncode({'code': 403, 'msg': 'old denied'}),
        403,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    await tester.runAsync(() => refresh);
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '关闭会话'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField, skipOffstage: false))
          .first
          .controller!
          .text,
      'B draft',
    );
    expect(adapter.casWrites, 0);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}
