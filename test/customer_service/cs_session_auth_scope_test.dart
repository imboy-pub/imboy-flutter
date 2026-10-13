import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'cs_session_attachment_page_test.dart'
    show AttachmentPageAdapter, mount, settle;
import 'cs_auth_fixture.dart';

class SyntheticAuthReader extends ChangeNotifier implements AuthSessionReader {
  SyntheticAuthReader(this.current);
  @override
  AuthSessionScope current;
  void publish(AuthSessionScope scope) {
    current = scope;
    notifyListeners();
  }

  @override
  bool isCurrent(AuthSessionScope captured) =>
      captured.uid.isNotEmpty &&
      !current.transitioning &&
      !captured.transitioning &&
      current == captured;
}

Future<void> mountReader(
  WidgetTester tester,
  AttachmentPageAdapter adapter,
  AuthSessionReader reader,
) async {
  HttpClient.adapterForTest = adapter;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home: CsSessionPage(
        orgId: '7266418340025468901',
        workspaceId: '7266418340025468921',
        sessionId: '7266418340025468940',
        conversationId: '7266418340025468950',
        identityId: '7266418340025468902',
        authReader: reader,
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpUntil(WidgetTester tester, bool Function() terminal) async {
  for (var i = 0; i < 100 && !terminal(); i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    terminal(),
    isTrue,
    reason: 'fixture task must reach its observed terminal state',
  );
}

void main() {
  final user = UserRepoLocal.to;
  Future<void> Function()? beforeWrite;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
    beforeWrite = null;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'readAll') return <String, String>{};
            if (call.method == 'read') return token;
            if (call.method == 'write') await beforeWrite?.call();
            return null;
          },
        );
  });
  testWidgets(
    'queued logout intent synchronously removes page body and draft before cleanup starts',
    (tester) async {
      final adapter = AttachmentPageAdapter();
      await mount(tester, adapter);
      expect(find.text('authorized body'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'old account draft');
      final entered = Completer<void>(), release = Completer<void>();
      beforeWrite = () async {
        entered.complete();
        await release.future;
      };
      final captured = authSessionReader.current;
      final write = user.saveAccessTokenForSession(
        captured.generation,
        'synthetic-held-token',
      );
      await pumpUntil(tester, () => entered.isCompleted);
      final logout = user.quitLogin(expectedGeneration: captured.generation);
      expect(authSessionReader.current.transitioning, isTrue);
      expect(user.isClearingSession, isFalse);
      await tester.pump();
      try {
        expect(find.text('authorized body'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse,
        );
      } finally {
        beforeWrite = () async =>
            throw PlatformException(code: 'synthetic-login-refused');
        var finished = false;
        final failed = expectLater(
          user.loginAfter('synthetic', {
            'uid': captured.uid,
            'token': 'synthetic-valid-token',
            'refreshtoken': 'synthetic-valid-refresh',
          }),
          throwsA(isA<PlatformException>()),
        );
        release.complete();
        final terminal = Future.wait([write, logout, failed])
            .whenComplete(() => finished = true);
        await pumpUntil(tester, () => finished);
        await terminal;
        expect(await logout, isFalse);
        beforeWrite = null;
        await drainCsAuthQueue(tester);
        await tester.pumpWidget(const SizedBox());
        PersistentMessageQueue.to.dispose();
      }
    },
  );
  testWidgets(
    'auth reader transition clears body and draft without implicit new scope fetch',
    (tester) async {
      final stable = (
        uid: '7266418340025468999',
        generation: 1,
        transitioning: false,
      );
      final reader = SyntheticAuthReader(stable),
          adapter = AttachmentPageAdapter();
      await mountReader(tester, adapter, reader);
      expect(find.text('authorized body'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'private draft');
      final count = adapter.requests.length;
      reader.publish((uid: stable.uid, generation: 2, transitioning: true));
      await tester.pump();
      expect(find.text('authorized body'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(adapter.requests.length, count);
      reader.publish((uid: stable.uid, generation: 2, transitioning: true));
      await tester.pump();
      expect(adapter.requests.length, count);
      await tester.pumpWidget(const SizedBox());
      reader.dispose();
    },
  );
  testWidgets(
    'only stable changed reader scope resumes page and profile event never rebinds',
    (tester) async {
      final stable = (
        uid: '7266418340025468999',
        generation: 1,
        transitioning: false,
      );
      final reader = SyntheticAuthReader(stable),
          adapter = AttachmentPageAdapter();
      await mountReader(tester, adapter, reader);
      final count = adapter.requests.length;
      reader.publish(stable);
      await tester.pump();
      expect(adapter.requests.length, count);
      reader.publish((uid: stable.uid, generation: 2, transitioning: true));
      await tester.pump();
      expect(find.text('authorized body'), findsNothing);
      reader.publish((uid: stable.uid, generation: 2, transitioning: false));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('authorized body'), findsOneWidget);
      expect(adapter.requests.length, greaterThan(count));
      await tester.pumpWidget(const SizedBox());
      reader.dispose();
    },
  );

  testWidgets(
    'failed login keeps default reader page withdrawn until actual successful login',
    (tester) async {
      await tester.runAsync(establishCsAuthFixture);
      final adapter = AttachmentPageAdapter();
      await mount(tester, adapter);
      expect(find.text('authorized body'), findsOneWidget);
      final count = adapter.requests.length;
      await tester.runAsync(
        () => user.changeInfo({'nickname': 'synthetic profile'}),
      );
      await tester.pump();
      expect(adapter.requests.length, count);
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-login-refused');
      await tester.runAsync(
        () => expectLater(
          user.loginAfter('synthetic', {
            'uid': '7266418340025468999',
            'token': 'synthetic-valid-token',
            'refreshtoken': 'synthetic-valid-refresh',
          }),
          throwsA(isA<PlatformException>()),
        ),
      );
      await tester.pump();
      expect(find.text('authorized body'), findsNothing);
      expect(authSessionReader.current.transitioning, isTrue);
      await tester.runAsync(
        () =>
            StorageService.to.setString(Keys.currentUid, '7266418340025468999'),
      );
      await tester.pump();
      expect(find.text('authorized body'), findsNothing);
      expect(adapter.requests.length, count);
      beforeWrite = null;
      await tester.runAsync(establishCsAuthFixture);
      await settle(tester);
      expect(find.text('authorized body'), findsOneWidget);
      expect(authSessionReader.current.transitioning, isFalse);
      await tester.pumpWidget(const SizedBox());
      PersistentMessageQueue.to.dispose();
    },
  );
}
