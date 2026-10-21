import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/organization_attachments_page.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_api.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_sheet.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _GovernanceApi extends TalkAttachmentGovernanceApi {
  int reads = 0;
  @override
  Future<TalkAttachmentGovernanceSnapshot> read(
    String org,
    String record,
    String attachment,
  ) async {
    reads++;
    expect((org, record, attachment), ('100', '50', '77'));
    return TalkAttachmentGovernanceSnapshot.parse(
      {
        'organization_id': 100,
        'record_id': 50,
        'attachment_id': 77,
        'hold_state': 'none',
        'purge_state': 'live',
        'retention_until': '2020-01-01T00:00:00Z',
      },
      '"9"',
      org,
      record,
      attachment,
    );
  }
}

class _ForeignShell extends WorkspaceShellNotifier {
  @override
  WorkspaceShellState build() =>
      const WorkspaceShellState(organizationId: '999');
}

class _Auth {
  final callbacks = <VoidCallback>[];
  VoidCallback subscribe(VoidCallback callback) {
    callbacks.add(callback);
    return () => callbacks.remove(callback);
  }

  void change() {
    for (final callback in List.of(callbacks)) {
      callback();
    }
  }
}

Map<String, dynamic> _row() => {
  'id': 77,
  'name': 'private-record.aac',
  'size': 40,
  'scope': 'talk_record',
  'scope_ref': '50',
  'record_id': '50',
  'organization_id': '100',
  'workspace_id': null,
  'open_kind': 'talk_record',
  'source_name': 'authorized title',
};

class _Api extends WorkspaceApi {
  var rows = <Map<String, dynamic>>[_row()];
  Completer<Map<String, dynamic>>? delayed;
  final calls = <String>[];
  int? failure;
  String? cursor;
  @override
  Future<Map<String, dynamic>> organizationAttachments(
    String org,
    Map<String, dynamic> filters,
  ) async {
    calls.add(org);
    if (failure != null) throw WorkspaceApiException(failure!, 'fixture');
    final gate = delayed;
    delayed = null;
    if (gate != null) return gate.future;
    return {
      'organization_id': org,
      'workspace_id': null,
      'items': List.of(rows),
      'next_cursor': cursor,
    };
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Api api,
  _Auth auth, {
  _GovernanceApi? governance,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/index/100',
    routes: [
      GoRoute(
        path: '/index/:org',
        builder: (_, state) =>
            OrganizationAttachmentsPage(orgId: state.pathParameters['org']!),
      ),
      GoRoute(
        path: '/talk_record/detail/:id',
        builder: (_, state) => Scaffold(
          body: Text('controlled record ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        if (governance != null)
          talkAttachmentGovernanceApiProvider.overrideWithValue(governance),
        workspaceShellProvider.overrideWith(_ForeignShell.new),
        talkRecordAuthSubscribeProvider.overrideWithValue(auth.subscribe),
        currentUserProvider.overrideWithValue(
          UserModel(uid: '1', nickname: 'Synthetic', account: 'synthetic'),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });
  testWidgets('authorized row opens the real metadata governance sheet', (
    tester,
  ) async {
    final api = _Api()
      ..rows = [
        {..._row(), 'can_govern': true},
      ];
    final governance = _GovernanceApi();
    await _pump(tester, api, _Auth(), governance: governance);
    await tester.tap(find.byTooltip(t.attachmentManager.governanceAction));
    await tester.pumpAndSettle();
    expect(governance.reads, 1);
    expect(find.byType(TalkAttachmentGovernanceSheet), findsOneWidget);
    expect(find.text('controlled record 50'), findsNothing);
  });

  testWidgets(
    'organization without workspace lists record and opens controlled detail',
    (tester) async {
      final api = _Api();
      final auth = _Auth();
      final router = await _pump(tester, api, auth);
      expect(api.calls, ['100']);
      expect(find.text('private-record.aac'), findsOneWidget);
      expect(
        find.byTooltip(t.attachmentManager.governanceAction),
        findsNothing,
      );
      await tester.tap(find.text('private-record.aac'));
      await tester.pumpAndSettle();
      expect(router.canPop(), true);
      expect(find.text('controlled record 50'), findsOneWidget);
    },
  );
  testWidgets(
    'same-UID authentication event clears rows and rejects late success',
    (tester) async {
      final api = _Api();
      final auth = _Auth();
      await _pump(tester, api, auth);
      final gate = api.delayed = Completer<Map<String, dynamic>>();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      api.rows = [];
      auth.change();
      await tester.pumpAndSettle();
      expect(find.text('private-record.aac'), findsNothing);
      gate.complete({
        'items': [_row()],
        'next_cursor': null,
      });
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('private-record.aac'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(auth.callbacks, isEmpty);
    },
  );
  testWidgets('switching organization rejects old response and old failure', (
    tester,
  ) async {
    for (final fail in [false, true]) {
      final api = _Api();
      final auth = _Auth();
      final router = await _pump(tester, api, auth);
      final gate = api.delayed = Completer<Map<String, dynamic>>();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      api.rows = [];
      router.go('/index/200');
      await tester.pumpAndSettle();
      if (fail) {
        gate.completeError(Exception('old request'));
      } else {
        gate.complete({
          'items': [_row()],
          'next_cursor': null,
        });
      }
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('private-record.aac'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
  for (final code in [401, 403, 404, 410, 503]) {
    testWidgets(
      'load-more $code clears denied rows but preserves transient retry',
      (tester) async {
        final api = _Api()..cursor = '77';
        await _pump(tester, api, _Auth());
        expect(find.text('private-record.aac'), findsOneWidget);
        api.failure = code;
        await tester.ensureVisible(find.text(t.attachmentManager.loadMore));
        await tester.tap(find.text(t.attachmentManager.loadMore));
        await tester.pumpAndSettle();
        expect(
          find.text('private-record.aac'),
          code == 503 ? findsOneWidget : findsNothing,
        );
        if (code != 503) expect(find.text('authorized title'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
