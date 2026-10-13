/// Device-component regression with fake HTTP/storage/database.
/// These cases are not real-backend, real-store or deployment acceptance.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:imboy/modules/customer_service/presentation/cs_message_bubble.dart';
import 'package:imboy/service/storage.dart';

import '../../test/customer_service/cs_auth_fixture.dart';

class CsComponentAdapter implements HttpClientAdapter {
  String status = 'active';
  int version = 5, sends = 0, closes = 0;
  int? rating;
  int? ratingAt;
  final List<String> requests = [];
  static const session = '/api/v1/cs/organizations/1/sessions/4';
  static const history = '/api/v1/enterprise/conversations/3/messages';
  static const send =
      '/api/v1/enterprise/organizations/1/conversations/3/messages';

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${o.method}:${o.uri.path}');
    final path = o.uri.path;
    if (o.method == 'GET' && path == session) {
      expectSync(o.queryParameters, {'workspace_id': '2'});
      return _json({
        'id': '4',
        'organization_id': '1',
        'workspace_id': '2',
        'conversation_id': '3',
        'business_identity_id': '5',
        'version': version,
        'status': status,
        'rating': rating,
        'rating_at': ratingAt,
      });
    }
    if (o.method == 'GET' && path == history) {
      expectSync(o.queryParameters, {
        'organization_id': '1',
        'workspace_id': '2',
        'limit': 50,
        'order': 'desc',
      });
      return _json([
        {
          'id': '100',
          'organization_id': '1',
          'conversation_id': '3',
          'sender_type': 'contact',
          'sender_contact_id': '6',
          'body': 'component-authorized-body',
        },
      ]);
    }
    return _other(o);
  }

  ResponseBody _other(RequestOptions o) {
    final path = o.uri.path;
    if (path == '$session/read-cursor' && ['GET', 'POST'].contains(o.method)) {
      expectSync(o.queryParameters, {'workspace_id': '2'});
      if (o.method == 'POST') {
        expectSync(o.data, {'last_read_message_id': '100'});
      }
      return _json({
        'session_id': '4',
        'last_read_message_id': 100,
        'unread_count': 0,
      });
    }
    if (o.method == 'POST' && path == '$send/100/ack') {
      expectSync(o.queryParameters, isEmpty);
      expectSync((o.data as Map)['workspace_id'], '2');
      expectSync((o.data as Map)['recipient_ref'], 'identity:5');
      return _json(null);
    }
    if (o.method == 'POST' && path == send) {
      sends++;
      expectSync((o.data as Map)['workspace_id'], '2');
      expectSync((o.data as Map)['identity_id'], '5');
      return _json(null, statusCode: 403);
    }
    if (o.method == 'POST' && path == '$session/close') {
      closes++;
      expectSync((o.data as Map)['workspace_id'], '2');
      expectSync((o.data as Map)['expected_version'], version);
      status = 'closed';
      version++;
      return _json(null);
    }
    if (o.method == 'GET' &&
        path == '/api/v1/cs/organizations/1/seats/me/events') {
      expectSync(o.queryParameters, {'workspace_id': '2'});
      return ResponseBody(
        Stream.value(Uint8List(0)),
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      );
    }
    throw StateError('CS_COMPONENT_UNEXPECTED_REQUEST');
  }

  ResponseBody _json(Object? payload, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode({
          'code': statusCode == 200 ? 0 : statusCode,
          'msg': statusCode == 200 ? 'success' : 'denied',
          'payload': payload,
        }),
        statusCode,
        headers: {
          'content-type': ['application/json'],
        },
      );
  @override
  void close({bool force = false}) {}
}

String _componentJwt() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'uid': '9', 'exp': 4102444800})}.'
      '${part('synthetic-component-only')}';
}

Future<void> _openComponent(
  WidgetTester tester,
  CsComponentAdapter adapter,
) async {
  SharedPreferences.setMockInitialValues({});
  final secrets = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map? ?? {};
        final key = args['key']?.toString() ?? '';
        if (call.method == 'write') secrets[key] = args['value'].toString();
        if (call.method == 'delete') secrets.remove(key);
        if (call.method == 'deleteAll') secrets.clear();
        if (call.method == 'read' && key == 'secure_token') {
          return _componentJwt();
        }
        if (call.method == 'read') return secrets[key];
        if (call.method == 'readAll') return Map.of(secrets);
        return null;
      });
  await StorageService.init();
  HttpClient.adapterForTest = adapter;
  await establishCsWidgetAuthFixture(tester, uid: '9');
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home: const CsSessionPage(
        orgId: '1',
        sessionId: '4',
        workspaceId: '2',
        conversationId: '3',
        identityId: '5',
        contactName: '合成客户',
      ),
    ),
  );
  await _settleComponent(tester);
}

Future<void> _settleComponent(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> _finishComponent(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await drainCsAuthQueue(tester);
  HttpClient.adapterForTest = null;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _registerSendRefusal();
  _registerCloseConfirmation();
  _registerRatingProjection();
}

void _registerSendRefusal() {
  testWidgets(
    'component send403 withdraws rendered privacy and stops further I/O',
    (tester) async {
      final a = CsComponentAdapter();
      try {
        await _openComponent(tester, a);
        expect(find.text('component-authorized-body'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'synthetic-reply');
        await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
        await _settleComponent(tester);
        expect(
          a.sends,
          1,
          reason: 'actual production message POST reached refusal',
        );
        expect(find.byType(CsMessageBubble), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          false,
        );
        final count = a.requests.length;
        await _settleComponent(tester);
        expect(a.requests.length, count);
      } finally {
        await _finishComponent(tester);
      }
    },
  );
}

void _registerCloseConfirmation() {
  testWidgets(
    'component close cancellation is zero CAS; explicit confirm uses frozen version',
    (tester) async {
      final a = CsComponentAdapter();
      try {
        await _openComponent(tester, a);
        await tester.enterText(find.byType(TextField).first, 'synthetic-draft');
        await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
        await _settleComponent(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await _settleComponent(tester);
        expect(a.closes, 0);
        await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
        await _settleComponent(tester);
        await tester.tap(find.byType(FilledButton));
        await _settleComponent(tester);
        expect(a.closes, 1);
        expect(a.status, 'closed');
        expect(find.text(t.customerService.waitingRatingTitle), findsNothing);
        expect(
          find.text(t.customerService.ratingUnknownTitle),
          findsOneWidget,
          reason: 'close acknowledgement does not fabricate authoritative rating fields',
        );
      } finally {
        await _finishComponent(tester);
      }
    },
  );
}

void _registerRatingProjection() {
  testWidgets(
    'component displays actual rated score/time rather than fabricated pending',
    (tester) async {
      final a = CsComponentAdapter()
        ..status = 'closed'
        ..rating = 4
        ..ratingAt = 1700000000;
      try {
        await _openComponent(tester, a);
        expect(find.text(t.customerService.waitingRatingTitle), findsNothing);
        expect(find.textContaining('4'), findsWidgets);
        expect(find.textContaining('2023'), findsOneWidget);
      } finally {
        await _finishComponent(tester);
      }
    },
  );
}
