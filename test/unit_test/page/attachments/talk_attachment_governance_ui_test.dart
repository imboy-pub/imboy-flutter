import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_api.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_sheet.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

TalkAttachmentGovernanceSnapshot snap({
  bool purged = false,
  int revision = 9,
  String holdReason = '',
}) => TalkAttachmentGovernanceSnapshot.parse(
  {
    'organization_id': 100,
    'record_id': 50,
    'attachment_id': 77,
    'hold_state': holdReason.isEmpty ? 'none' : 'held',
    'hold_reason': holdReason,
    'purge_state': purged ? 'purged' : 'live',
    'retention_until': '2020-01-01T00:00:00Z',
    'cleanup_status': 'pending',
    'lifecycle_state': 'available',
  },
  '"$revision"',
  '100',
  '50',
  '77',
);

class Api extends TalkAttachmentGovernanceApi {
  int reads = 0;
  int? readError;
  String holdReason = '';
  final intents = <String>[];
  final bodies = <Map<String, dynamic>>[];
  bool conflict = false;
  bool fail = false;
  bool purged = false;
  Completer<TalkAttachmentGovernanceSnapshot>? delayed;
  @override
  Future<TalkAttachmentGovernanceSnapshot> read(
    String o,
    String r,
    String a,
  ) async {
    reads++;
    if (readError != null) throw WorkspaceApiException(readError!, 'fixture');
    return delayed?.future ?? snap(purged: purged, holdReason: holdReason);
  }

  @override
  Future<TalkAttachmentGovernanceSnapshot> mutate(
    String o,
    String r,
    String a, {
    required String etag,
    required String intent,
    required Map<String, dynamic> body,
  }) async {
    intents.add(intent);
    bodies.add(Map.of(body));
    if (conflict) throw const WorkspaceApiException(412, 'conflict');
    if (fail) throw const WorkspaceApiException(503, 'retry');
    return snap(revision: 10);
  }
}

Future<void> pump(
  WidgetTester tester,
  Api api,
  List<VoidCallback> listeners,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        talkAttachmentGovernanceApiProvider.overrideWithValue(api),
        talkRecordAuthSubscribeProvider.overrideWithValue((callback) {
          listeners.add(callback);
          return () => listeners.remove(callback);
        }),
        currentUserProvider.overrideWithValue(
          UserModel(uid: '1', nickname: 'Synthetic', account: 'synthetic'),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const TalkAttachmentGovernanceSheet(
                    organizationId: '100',
                    recordId: '50',
                    attachmentId: '77',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

Future<void> hold(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'preserve this input');
  await tester.ensureVisible(find.byKey(const ValueKey('governance-hold')));
  await tester.tap(find.byKey(const ValueKey('governance-hold')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(t.common.buttonConfirm));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });
  testWidgets(
    'GET never mutates; fresh explicit actions use new intent, failure retries reuse',
    (tester) async {
      final api = Api();
      await pump(tester, api, []);
      await tester.pumpAndSettle();
      expect(api.intents, isEmpty);
      await hold(tester);
      await hold(tester);
      expect(api.intents.toSet().length, 2);
      api.fail = true;
      await hold(tester);
      final failed = api.intents.last;
      await hold(tester);
      expect(api.intents.last, failed);
    },
  );
  testWidgets(
    '412 preserves reason and disables submit until explicit refresh',
    (tester) async {
      final api = Api()..conflict = true;
      await pump(tester, api, []);
      await tester.pumpAndSettle();
      await hold(tester);
      expect(
        find.text(t.attachmentManager.governanceRefreshConflict),
        findsOneWidget,
      );
      expect(find.text('preserve this input'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('governance-hold')),
            )
            .onPressed,
        isNull,
      );
      api.conflict = false;
      await tester.tap(find.text(t.attachmentManager.retryAction));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(find.text('preserve this input'), findsOneWidget);
    },
  );
  testWidgets('approval does not claim physical removal', (tester) async {
    final api = Api()..purged = true;
    await pump(tester, api, []);
    await tester.pumpAndSettle();
    expect(
      find.text(t.attachmentManager.governancePurgeApproved),
      findsWidgets,
    );
    expect(find.text(t.enterpriseApp.purgePurged), findsNothing);
    expect(
      find.text(t.attachmentManager.governancePhysicalPending),
      findsOneWidget,
    );
  });
  testWidgets('auth transition closes modal and rejects late metadata', (
    tester,
  ) async {
    final gate = Completer<TalkAttachmentGovernanceSnapshot>();
    final api = Api()..delayed = gate;
    final listeners = <VoidCallback>[];
    await pump(tester, api, listeners);
    listeners.single();
    await tester.pumpAndSettle();
    gate.complete(snap());
    await tester.pumpAndSettle();
    expect(find.byType(TalkAttachmentGovernanceSheet), findsNothing);
    expect(listeners, isEmpty);
    expect(api.intents, isEmpty);
  });
  testWidgets('cancel confirmation never submits an operation', (tester) async {
    final api = Api();
    await pump(tester, api, []);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'review');
    await tester.ensureVisible(find.byKey(const ValueKey('governance-hold')));
    await tester.tap(find.byKey(const ValueKey('governance-hold')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(api.intents, isEmpty);
  });

  testWidgets('local date and time selection submits UTC and survives 412', (
    tester,
  ) async {
    final api = Api()..conflict = true;
    await pump(tester, api, []);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 300));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    final dateOk = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(dateOk));
    await tester.pump(const Duration(milliseconds: 300));
    final timeOk = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(timeOk));
    await tester.pumpAndSettle();
    final selection = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!
        .text;
    expect(selection, contains(tomorrow.timeZoneName));
    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-extend_retention')),
    );
    await tester.tap(find.byKey(const ValueKey('governance-extend_retention')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(t.common.buttonConfirm));
    await tester.pumpAndSettle();
    expect(
      DateTime.parse(api.bodies.single['retention_until'] as String).isUtc,
      true,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      selection,
    );
  });
  for (final code in [401, 403, 404, 410]) {
    testWidgets(
      'refresh $code removes previous metadata, form and operation intent',
      (tester) async {
        final api = Api()..holdReason = 'stored confidential reason';
        await pump(tester, api, []);
        await tester.pumpAndSettle();
        api.fail = true;
        await hold(tester);
        final oldIntent = api.intents.single;
        expect(find.text('preserve this input'), findsOneWidget);
        expect(
          find.textContaining('stored confidential reason'),
          findsOneWidget,
        );
        api.readError = code;
        await tester.tap(find.text(t.attachmentManager.retryAction));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('preserve this input'), findsNothing);
        expect(find.textContaining('stored confidential reason'), findsNothing);
        expect(find.byKey(const ValueKey('governance-hold')), findsNothing);
        api.readError = null;
        api.fail = false;
        await tester.tap(find.text(t.attachmentManager.retryAction));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty,
        );
        await hold(tester);
        expect(api.intents.last, isNot(oldIntent));
      },
    );
  }
  testWidgets('transient read error keeps form available for explicit retry', (
    tester,
  ) async {
    final api = Api();
    await pump(tester, api, []);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'unsent reason');
    api.readError = 503;
    await tester.tap(find.text(t.attachmentManager.retryAction));
    await tester.pumpAndSettle();
    expect(find.text('unsent reason'), findsOneWidget);
    expect(find.byKey(const ValueKey('governance-hold')), findsOneWidget);
  });
}
