import 'dart:async';

import 'cs_auth_fixture.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_put_transport.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:imboy/modules/customer_service/presentation/cs_message_bubble.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_attachment_preparation.dart';
import 'package:imboy/modules/customer_service/presentation/cs_attachment_save.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'cs_session_attachment_preparation_test.dart' show SyntheticPickedFile;

const org = '7266418340025468901', ws = '7266418340025468921';
const sid = '7266418340025468940',
    conv = '7266418340025468950',
    identity = '7266418340025468902';
const aid = '7266418340025468971';
bool authExpiryCompleted = false;
bool fixtureAuthEstablished = false;

class AttachmentPageAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final uploadSteps = <String>[];
  final uploadedBytes = <int>[];
  String? hold;
  final held = Completer<ResponseBody>();
  int sendStatus = 200;
  bool emptyHistory = false;
  Map<String, dynamic>? sentPayload;
  bool silentLogout = false;
  Map<String, dynamic> declared = {};
  ResponseBody json(Object payload, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode({'code': status == 200 ? 0 : status, 'payload': payload}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? bytes,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    final path = o.uri.path;
    final step = path.endsWith('/assets/confirm')
        ? 'confirm'
        : path.endsWith('/assets/presign')
        ? (o.method == 'PUT' ? 'put' : 'presign')
        : '';
    if (step.isNotEmpty) uploadSteps.add(step);
    if (step == 'put' && bytes != null) {
      await for (final chunk in bytes) {
        uploadedBytes.addAll(chunk);
      }
    }
    if (step == 'presign') declared = Map<String, dynamic>.from(o.data as Map);
    if (step == hold) {
      if (cancel == null) return held.future;
      return Future.any([
        held.future,
        cancel.then<ResponseBody>(
          (_) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.cancel,
          ),
        ),
      ]);
    }
    if (step.isNotEmpty) return uploadResponse(step);
    return _response(o);
  }

  Future<ResponseBody> _response(RequestOptions o) async {
    if (o.method == 'POST' && o.path.endsWith('/messages')) {
      if (hold == 'send') return held.future;
      if (silentLogout) await StorageService.to.remove(Keys.currentUid);
      return sendStatus == 200
          ? json(sentPayload ?? message(body: '', sender: 'business_identity'))
          : json({}, status: sendStatus);
    }
    if (o.path.endsWith('/events')) {
      return ResponseBody.fromString(
        '',
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      );
    }
    if (o.path.endsWith('/read-cursor') || o.path.endsWith('/ack')) {
      return json({
        'session_id': sid,
        'last_read_message_id': null,
        'unread_count': 0,
      });
    }
    if (o.path.endsWith('/messages')) {
      return json(emptyHistory ? [] : [message()]);
    }
    if (o.path.endsWith('/content')) return contentResponse();
    return json({
      'session_id': sid,
      'organization_id': org,
      'conversation_id': conv,
      'status': 'active',
      'version': 5,
      'business_identity_id': identity,
    });
  }

  ResponseBody uploadResponse(String step) {
    if (step == 'presign') {
      return json({
        'asset_id': aid,
        'upload_ref': 'synthetic-ref',
        'upload': {
          'url':
              'https://member.invalid/api/v1/enterprise/organizations/$org/assets/presign?workspace_id=$ws&upload_ref=synthetic-ref',
        },
      });
    }
    return json({
      'asset_id': aid,
      'status': step == 'put' ? 'pending_confirm' : 'active',
      'object_hash': declared['object_hash'],
      'mime': declared['mime'],
      'size_bytes': declared['size_bytes'],
      'conversation_id': conv,
    });
  }

  Map<String, dynamic> message({
    String body = 'authorized body',
    String sender = 'contact',
  }) => {
    'id': '7266418340025468961',
    'conversation_id': conv,
    'organization_id': org,
    'sender_type': sender,
    'sender_contact_id': sender == 'contact' ? '7266418340025468941' : null,
    'sender_business_identity_id': sender == 'business_identity'
        ? identity
        : null,
    'body': body,
    'assets': [
      {
        'id': aid,
        'file_name': '../sample.pdf',
        'mime': 'application/pdf',
        'status': 'active',
        'size_bytes': 6,
      },
    ],
  };
  ResponseBody contentResponse() {
    final data = utf8.encode('%PDF-A');
    return ResponseBody.fromBytes(
      data,
      200,
      headers: {
        'content-type': ['application/pdf'],
        'content-length': ['${data.length}'],
        'x-asset-id': [aid],
        'x-asset-sha256': [sha256.convert(data).toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> finishLogout(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (authExpiryCompleted &&
        !UserRepoLocal.to.isClearingSession &&
        find.text('authorized body').evaluate().isEmpty) {
      await tester.pump(const Duration(seconds: 3));
      await drainCsAuthQueue(tester);
      PersistentMessageQueue.to.dispose();
      return;
    }
  }
  fail('fixture_logout_not_terminal');
}

CsSessionPage page(
  AttachmentPageAdapter adapter, {
  CsAttachmentSave? save,
  String session = sid,
}) => CsSessionPage(
  orgId: org,
  sessionId: session,
  workspaceId: ws,
  conversationId: conv,
  identityId: identity,
  attachmentSave: save,
  csApi: CsApi(
    assetApiFactory: () =>
        EnterpriseApi()..dio.options.baseUrl = 'https://member.invalid',
    putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
  ),
  attachmentPreparation: CsSessionAttachmentPreparation(
    pickFiles: () async => [SyntheticPickedFile()],
    readHead: (_) async => Uint8List.fromList([65]),
    readBytes: (_) async => Uint8List.fromList([65]),
  ),
);
Future<void> mount(
  WidgetTester tester,
  AttachmentPageAdapter adapter, {
  CsAttachmentSave? save,
  String session = sid,
}) async {
  if (!fixtureAuthEstablished) {
    await establishCsWidgetAuthFixture(tester);
    fixtureAuthEstablished = true;
  }
  HttpClient.adapterForTest = adapter;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home: page(adapter, save: save, session: session),
    ),
  );
  await settle(tester);
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    authExpiryCompleted = false;
    fixtureAuthEstablished = false;
    HttpClient.onAuthExpired = () => authExpiryCompleted = true;
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (UserRepoLocal.to.isClearingSession) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('fixture_logout_pending');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
    String part(Object v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final token =
        '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'readAll') return <String, String>{};
            if (call.method == 'read' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              return token;
            }
            return null;
          },
        );
  });
  tearDown(() {
    PersistentMessageQueue.to.dispose();
    HttpClient.adapterForTest = null;
    HttpClient.onAuthExpired = null;
  });
  testWidgets(
    'same page attachment success renders canonical message immediately',
    (tester) async {
      const messageId = '7266418340025468962';
      final adapter = AttachmentPageAdapter()..emptyHistory = true;
      adapter.sentPayload = {
        'accepted': true,
        'message_id': messageId,
        'replayed': false,
        'message': {
          ...adapter.message(body: '', sender: 'business_identity'),
          'id': messageId,
          'created_at': '2026-10-14T08:00:00Z',
        },
      };
      await mount(tester, adapter);
      final originalState = tester.state(find.byType(CsSessionPage));
      expect(find.text('../sample.pdf'), findsNothing);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(CsSessionPage)), same(originalState));
      expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
      expect(adapter.uploadedBytes, [65]);
      final sends = adapter.requests
          .where((r) => r.method == 'POST' && r.path.endsWith('/messages'))
          .toList();
      expect(sends, hasLength(1));
      expect((sends.single.data as Map)['asset_ids'], [aid]);
      final bubble = tester.widget<CsMessageBubble>(
        find.byWidgetPredicate(
          (w) => w is CsMessageBubble && w.message.id == messageId,
        ),
      );
      expect(bubble.isSeat, isTrue);
      expect(bubble.message.content, isEmpty);
      expect(bubble.assets.single.id, aid);
      expect(find.text('../sample.pdf'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [401, 403]) {
    testWidgets(
      'attachment message $status withdraws current body and writes',
      (tester) async {
        final adapter = AttachmentPageAdapter()..sendStatus = status;
        await mount(tester, adapter);
        expect(find.text('authorized body'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find
                    .ancestor(
                      of: find.byIcon(CupertinoIcons.paperclip),
                      matching: find.byType(IconButton),
                    )
                    .first,
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byIcon(CupertinoIcons.paperclip));
        await settle(tester);
        expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
        expect(adapter.uploadedBytes, [65]);
        expect(
          adapter.requests.any(
            (o) => o.method == 'POST' && o.path.endsWith('/messages'),
          ),
          isTrue,
        );
        if (status == 401) await finishLogout(tester);
        expect(find.text('authorized body'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'silent UID refusal after attachment send withdraws scope without rebind',
    (tester) async {
      final adapter = AttachmentPageAdapter()
        ..sendStatus = 401
        ..silentLogout = true;
      await mount(tester, adapter);
      expect(find.text('authorized body'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
      expect(adapter.uploadedBytes, [65]);
      expect(
        adapter.requests.any(
          (o) => o.method == 'POST' && o.path.endsWith('/messages'),
        ),
        isTrue,
      );
      expect(find.text('authorized body'), findsNothing);
      expect(find.byKey(const ValueKey('cs-retry-upload')), findsNothing);
      expect(
        adapter.requests
            .where((o) => o.method == 'GET' && o.path.contains('/sessions/'))
            .length,
        lessThanOrEqualTo(2),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'actual Page cancelled PUT remains unknown and never confirms or sends',
    (tester) async {
      final adapter = AttachmentPageAdapter()..hold = 'put';
      await mount(tester, adapter);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put']);
      expect(find.byKey(const ValueKey('cs-cancel-upload')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cs-cancel-upload')));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put']);
      expect(
        adapter.requests.where(
          (o) => o.method == 'POST' && o.uri.path.endsWith('/messages'),
        ),
        isEmpty,
      );
      expect(find.byKey(const ValueKey('cs-retry-upload')), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byIcon(CupertinoIcons.paperclip),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'actual Page confirm malformed receipt is unknown without send or automatic retry',
    (tester) async {
      final adapter = AttachmentPageAdapter()..hold = 'confirm';
      await mount(tester, adapter);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
      adapter.held.complete(
        adapter.json({'asset_id': aid, 'status': 'pending_confirm'}),
      );
      await settle(tester);
      expect(
        adapter.requests.where(
          (o) => o.method == 'POST' && o.uri.path.endsWith('/messages'),
        ),
        isEmpty,
      );
      expect(find.byKey(const ValueKey('cs-retry-upload')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'actual Page saved binary retains exact verified bytes and history basename',
    (tester) async {
      final adapter = AttachmentPageAdapter();
      Uint8List? saved;
      String? name;
      String? mime;
      final save = CsAttachmentSave(
        saveFile:
            ({required fileName, required bytes, required mimeType}) async {
              saved = bytes;
              name = fileName;
              mime = mimeType;
              return Uri.file('/synthetic/saved.pdf');
            },
      );
      await mount(tester, adapter, save: save);
      await tester.tap(find.text('../sample.pdf'));
      await settle(tester);
      expect(find.text('%PDF-A'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cs-save-attachment')));
      await settle(tester);
      expect(saved, utf8.encode('%PDF-A'));
      expect(name, 'sample.pdf');
      expect(mime, 'application/pdf');
      final context = tester.element(
        find.byKey(const ValueKey('cs-save-attachment')),
      );
      expect(find.text(context.t.customerService.attachSaved), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'actual Page save is single flight and null cancellation reports no success',
    (tester) async {
      final pending = Completer<Uri?>();
      var calls = 0;
      final save = CsAttachmentSave(
        saveFile: ({required fileName, required bytes, required mimeType}) {
          calls++;
          return pending.future;
        },
      );
      await mount(tester, AttachmentPageAdapter(), save: save);
      await tester.tap(find.text('../sample.pdf'));
      await settle(tester);
      final button = find.byKey(const ValueKey('cs-save-attachment'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(calls, 1);
      pending.complete(null);
      await settle(tester);
      final context = tester.element(button);
      expect(find.text(context.t.customerService.attachSaved), findsNothing);
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'actual Page late saved file never projects success into changed business scope',
    (tester) async {
      final pending = Completer<Uri?>();
      var calls = 0;
      final adapter = AttachmentPageAdapter();
      final save = CsAttachmentSave(
        saveFile: ({required fileName, required bytes, required mimeType}) {
          calls++;
          return pending.future;
        },
      );
      await mount(tester, adapter, save: save);
      await tester.tap(find.text('../sample.pdf'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('cs-save-attachment')));
      await tester.pump();
      expect(calls, 1);
      await mount(tester, adapter, save: save, session: '7266418340025468942');
      pending.complete(Uri.file('/synthetic/saved.pdf'));
      await settle(tester);
      expect(find.byKey(const ValueKey('cs-save-attachment')), findsNothing);
      final context = tester.element(find.byType(CsSessionPage));
      expect(find.text(context.t.customerService.attachSaved), findsNothing);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'uploaded asset with failed message reports send failure without repeated upload',
    (tester) async {
      final adapter = AttachmentPageAdapter()..sendStatus = 500;
      await mount(tester, adapter);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
      expect(
        adapter.requests
            .where(
              (o) => o.method == 'POST' && o.uri.path.endsWith('/messages'),
            )
            .length,
        1,
      );
      final context = tester.element(find.byType(CsSessionPage));
      expect(
        find.text(context.t.customerService.attachUploadFailed),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('cs-retry-upload')), findsNothing);
      expect(
        find.text(context.t.customerService.attachUploadedNotSent),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'late old attachment message 403 never revokes new scope or draft',
    (tester) async {
      final adapter = AttachmentPageAdapter()..hold = 'send';
      await mount(tester, adapter);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await settle(tester);
      expect(adapter.uploadSteps, ['presign', 'put', 'confirm']);
      expect(
        adapter.requests
            .where(
              (o) => o.method == 'POST' && o.uri.path.endsWith('/messages'),
            )
            .length,
        1,
      );
      await mount(tester, adapter, session: '7266418340025468942');
      await tester.enterText(find.byType(TextField).first, 'new scope draft');
      adapter.held.complete(adapter.json({}, status: 403));
      await settle(tester);
      expect(find.text('authorized body'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'new scope draft',
      );
      expect(find.byKey(const ValueKey('cs-upload-status')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'actual Page failed save stays retryable and reports success only after retry',
    (tester) async {
      var calls = 0;
      final save = CsAttachmentSave(
        saveFile:
            ({required fileName, required bytes, required mimeType}) async {
              calls++;
              if (calls == 1) throw StateError('synthetic_save_failure');
              return Uri.file('/synthetic/saved.pdf');
            },
      );
      await mount(tester, AttachmentPageAdapter(), save: save);
      await tester.tap(find.text('../sample.pdf'));
      await settle(tester);
      final button = find.byKey(const ValueKey('cs-save-attachment'));
      await tester.tap(button);
      await settle(tester);
      final context = tester.element(button);
      expect(
        find.text(context.t.customerService.attachSaveFailed),
        findsOneWidget,
      );
      expect(find.text(context.t.customerService.attachSaved), findsNothing);
      await tester.tap(button);
      await settle(tester);
      expect(calls, 2);
      expect(find.text(context.t.customerService.attachSaved), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'safe cancel while picker is pending permits selecting again with zero writes',
    (tester) async {
      var picks = 0;
      final pending = Completer<List<PlatformFile>>();
      final adapter = AttachmentPageAdapter();
      HttpClient.adapterForTest = adapter;
      final preparation = CsSessionAttachmentPreparation(
        pickFiles: () {
          picks++;
          return pending.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              TranslationProvider(child: AppLoading.init()(context, child)),
          home: CsSessionPage(
            orgId: org,
            sessionId: sid,
            workspaceId: ws,
            conversationId: conv,
            identityId: identity,
            attachmentPreparation: preparation,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await tester.pump();
      expect(picks, 1);
      await tester.tap(find.byKey(const ValueKey('cs-cancel-upload')));
      pending.complete([]);
      await settle(tester);
      await tester.tap(find.byIcon(CupertinoIcons.paperclip));
      await tester.pump();
      expect(picks, 2);
      expect(
        adapter.requests.where(
          (o) =>
              o.method == 'POST' &&
              (o.uri.path.contains('/assets/') ||
                  o.uri.path.endsWith('/messages')),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
