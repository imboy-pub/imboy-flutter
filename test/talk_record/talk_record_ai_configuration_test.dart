import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';

class _Store implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  String? fail;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (fail == 'read') throw StateError('secret-do-not-display');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    writeStarted?.complete();
    await writeGate?.future;
    if (fail == 'write') throw StateError('secret-do-not-display');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (fail == 'delete') throw StateError('secret-do-not-display');
    values.remove(key);
  }
}

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [
        talkRecordAiSecureStoreProvider.overrideWithValue(store),
        talkRecordAiIdentityReaderProvider.overrideWithValue(() => identity),
        talkRecordAuthSubscribeProvider.overrideWithValue((listener) {
          listeners.add(listener);
          return () => listeners.remove(listener);
        }),
      ],
    );
    router = GoRouter(
      initialLocation: '$kTalkRecordAiServicesPath/minimax',
      routes: talkRecordRoutes(),
    );
  }
  final store = _Store();
  final listeners = <VoidCallback>[];
  TalkRecordAiIdentity? identity = TalkRecordAiIdentity(
    TalkRecordAiCredentialScope(
      deploymentOrigin: 'https://example.test',
      accountId: '101',
    ),
    1,
  );
  late ProviderContainer container;
  late GoRouter router;
  void changeAccount(String? account, int epoch) {
    identity = account == null
        ? null
        : TalkRecordAiIdentity(
            TalkRecordAiCredentialScope(
              deploymentOrigin: 'https://example.test',
              accountId: account,
            ),
            epoch,
          );
    for (final listener in List<VoidCallback>.of(listeners)) {
      listener();
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          themeMode: theme,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  }
}

void _androidTest(String description, WidgetTesterCallback body) {
  testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

void main() {
  const key = 'synthetic-api-key-not-a-real-key';
  const field = ValueKey('talk_record_ai_key_input');
  const save = ValueKey('talk_record_ai_save');
  const remove = ValueKey('talk_record_ai_delete');
  late _Harness h;
  setUpAll(() async => LocaleSettings.setLocale(AppLocale.zhCn));
  setUp(() => h = _Harness());

  Future<void> enterAndSave(WidgetTester tester, [String value = key]) async {
    await tester.enterText(find.byKey(field), value);
    await tester.ensureVisible(find.byKey(save));
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
  }

  _androidTest(
    'save is device-only, clears input and never claims validation',
    (tester) async {
      await h.pump(tester);
      expect(h.store.writes, 0);
      await enterAndSave(tester);
      expect(h.store.values.values.single, key);
      expect(find.text(t.talkRecord.aiSaved), findsOneWidget);
      expect(find.textContaining('••••••••'), findsOneWidget);
      final input = tester.widget<CupertinoTextField>(find.byKey(field));
      expect(input.controller!.text, isEmpty);
      expect(input.obscureText, isTrue);
      expect(find.text(key), findsNothing);
      await h.dispose(tester);
    },
  );

  _androidTest('replacement requires explicit confirmation', (tester) async {
    await h.pump(tester);
    await enterAndSave(tester);
    await enterAndSave(tester, '$key-new');
    expect(find.text(t.talkRecord.aiReplaceTitle), findsOneWidget);
    expect(h.store.values.values.single, key);
    await tester.tap(find.text(t.talkRecord.aiCancel));
    await tester.pumpAndSettle();
    expect(h.store.values.values.single, key);
    await enterAndSave(tester, '$key-new');
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, t.talkRecord.aiReplaceAction),
    );
    await tester.pumpAndSettle();
    expect(h.store.values.values.single, '$key-new');
    await h.dispose(tester);
  });

  _androidTest('delete confirmation preserves foreign values', (tester) async {
    h.store.values['foreign'] = 'untouched';
    await h.pump(tester);
    await enterAndSave(tester);
    await tester.ensureVisible(find.byKey(remove));
    await tester.tap(find.byKey(remove));
    await tester.pumpAndSettle();
    expect(h.store.values.length, 2);
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, t.talkRecord.aiDeleteAction),
    );
    await tester.pumpAndSettle();
    expect(h.store.values, {'foreign': 'untouched'});
    expect(find.text(t.talkRecord.aiDeleted), findsOneWidget);
    await h.dispose(tester);
  });

  _androidTest('delete failure never reports deletion or raw exception', (
    tester,
  ) async {
    await h.pump(tester);
    await enterAndSave(tester);
    h.store.fail = 'delete';
    await tester.ensureVisible(find.byKey(remove));
    await tester.tap(find.byKey(remove));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, t.talkRecord.aiDeleteAction),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.aiDeleted), findsNothing);
    expect(find.text(t.talkRecord.aiStorageFailed), findsOneWidget);
    expect(find.textContaining('secret-do-not-display'), findsNothing);
    expect(h.store.values.values.single, key);
    await h.dispose(tester);
  });

  _androidTest('save failure is visible and does not claim success', (
    tester,
  ) async {
    h.store.fail = 'write';
    await h.pump(tester);
    await enterAndSave(tester);
    expect(find.text(t.talkRecord.aiStorageFailed), findsOneWidget);
    expect(find.text(t.talkRecord.aiSaved), findsNothing);
    expect(h.store.values, isEmpty);
    await h.dispose(tester);
  });

  _androidTest('account switch clears input and expires old page', (
    tester,
  ) async {
    await h.pump(tester);
    await tester.enterText(find.byKey(field), key);
    final controller = tester
        .widget<CupertinoTextField>(find.byKey(field))
        .controller!;
    h.changeAccount('102', 2);
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(find.byKey(field), findsNothing);
    expect(find.text(t.talkRecord.aiAccountChanged), findsOneWidget);
    expect(h.store.writes, 0);
    await h.dispose(tester);
  });

  _androidTest(
    'late save result after logout and same-account login is hidden',
    (tester) async {
      await h.pump(tester);
      h.store.writeGate = Completer<void>();
      h.store.writeStarted = Completer<void>();
      await tester.enterText(find.byKey(field), key);
      await tester.ensureVisible(find.byKey(save));
      await tester.tap(find.byKey(save));
      await h.store.writeStarted!.future;
      h.changeAccount(null, 2);
      await tester.pump();
      h.changeAccount('101', 3);
      await tester.pump();
      h.store.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.aiSaved), findsNothing);
      expect(find.byKey(field), findsNothing);
      expect(find.text(t.talkRecord.aiAccountChanged), findsOneWidget);
      await h.dispose(tester);
    },
  );

  _androidTest('services list navigates to fixed Zhipu API fee explanation', (
    tester,
  ) async {
    h.router.go(kTalkRecordAiServicesPath);
    await h.pump(tester);
    await tester.tap(find.byKey(const ValueKey('talk_record_ai_zhipu')));
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.aiMaxNotice), findsOneWidget);
    expect(find.text(TalkRecordAiProvider.zhipu.endpoint), findsOneWidget);
    expect(h.store.writes, 0);
    await h.dispose(tester);
  });

  _androidTest('Doubao remains a device-only pending configuration slot', (
    tester,
  ) async {
    h.router.go(kTalkRecordAiServicesPath);
    await h.pump(tester);
    expect(find.text(t.talkRecord.aiAsrOptionalNotice), findsOneWidget);
    expect(
      find.textContaining(t.talkRecord.aiDoubaoPendingNotice),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_ai_doubao')));
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.aiDoubaoPendingNotice), findsWidgets);
    expect(find.text(t.talkRecord.aiAudioExternalNotice), findsNothing);
    await enterAndSave(tester);
    final credentials = h.container.read(talkRecordAiCredentialsProvider)!;
    expect(
      (await credentials.status(TalkRecordAiProvider.doubao)).configured,
      isTrue,
    );
    expect(
      (await credentials.status(TalkRecordAiProvider.minimax)).configured,
      isFalse,
    );
    expect(h.store.values.values.single, key);
    expect(find.text(t.talkRecord.aiSaved), findsOneWidget);
    await h.dispose(tester);
  });

  _androidTest('large text, dark theme and keyboard remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await h.pump(tester, scale: 2, theme: ThemeMode.dark);
    await tester.ensureVisible(find.byKey(field));
    await tester.enterText(find.byKey(field), key);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.ensureVisible(find.byKey(save));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
