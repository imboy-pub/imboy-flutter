import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_api.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_sheet.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_cleanup_retry_control.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_delete_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_cleanup_retry_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

const _cap = TalkRecordCleanupRetryCapability(
  allowed: true,
  generation: 2,
  exhaustedResources: 1,
  reason: 'eligible',
);

class _Results extends FixtureTalkRecordResultsService {
  _Results() : super([]);
  int reads = 0;
  bool failRead = false;
  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(String id) async {
    reads++;
    if (failRead) throw const TalkRecordApiException(503, 'read failed');
    return TalkRecordFetched(
      TalkRecordModel(
        id: id,
        cleanupStatus: TalkRecordCleanupStatus.failed,
        deletedAt: DateTime.utc(2026),
        cleanupGeneration: 2,
        cleanupRetry: _cap,
      ),
      etag: '"3"',
    );
  }
}

class _Retry extends TalkRecordCleanupRetryClient {
  int posts = 0;
  Future<void> Function()? beforeDispatch;
  Future<void> Function()? response;
  Object? guardError;
  @override
  Future<void> retry(
    String id,
    String etag,
    int generation,
    String key,
    void Function() guard,
  ) async {
    await beforeDispatch?.call();
    try {
      guard();
    } catch (error) {
      guardError = error;
      rethrow;
    }
    posts++;
    await response?.call();
  }
}

class _Workspace extends WorkspaceShellNotifier {
  @override
  WorkspaceShellState build() => const WorkspaceShellState(
    organizationId: '100',
    currentWorkspaceId: '10',
  );
  void switchSpace() {
    state = state.copyWith(currentWorkspaceId: '20');
  }
}

class _Governance extends TalkAttachmentGovernanceApi {
  int reads = 0;
  @override
  Future<TalkAttachmentGovernanceSnapshot> read(
    String org,
    String record,
    String attachment,
  ) async {
    reads++;
    return TalkAttachmentGovernanceSnapshot.parse(
      {
        'organization_id': 100,
        'record_id': 50,
        'attachment_id': 77,
        'hold_state': 'none',
        'purge_state': 'live',
        'logical_deleted': true,
        'cleanup_status': 'failed',
        'cleanup_generation': 2,
        'cleanup_retry': {
          'allowed': true,
          'generation': 2,
          'exhausted_resources': 1,
          'reason': 'eligible',
        },
      },
      '"3"',
      org,
      record,
      attachment,
    );
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });
  final action = find.byKey(const ValueKey('cleanup-retry-action'));
  testWidgets(
    'real delete route accepted POST then failed GET and route remount requires successful refresh',
    (tester) async {
      final service = _Results();
      final retry = _Retry()
        ..response = () async {
          service.failRead = true;
        };
      final router = GoRouter(
        initialLocation: '/cleanup',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/cleanup',
            builder: (_, _) => const TalkRecordDeletePage(recordId: '50'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordResultsServiceProvider.overrideWithValue(service),
            talkRecordCleanupRetryClientProvider.overrideWithValue(retry),
            talkRecordCleanupSessionProvider.overrideWithValue(() => 'actor'),
            talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(retry.posts, 1);
      expect(service.reads, 2);
      expect(action, findsNothing);
      router.go('/');
      await tester.pumpAndSettle();
      router.go('/cleanup');
      await tester.pumpAndSettle();
      expect(retry.posts, 1);
      expect(action, findsNothing);
      await tester.tap(find.byKey(const ValueKey('talk_record_delete_retry')));
      await tester.pumpAndSettle();
      expect(retry.posts, 1);
      expect(action, findsNothing);
      service.failRead = false;
      await tester.tap(find.byKey(const ValueKey('talk_record_delete_retry')));
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      expect(retry.posts, 1);
    },
  );
  for (final beforeDispatch in [false, true]) {
    testWidgets(
      'real governance modal workspace switch fences ${beforeDispatch ? "dispatch" : "late result"}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _Governance();
        final gate = Completer<void>();
        final retry = _Retry();
        if (beforeDispatch) {
          retry.beforeDispatch = () => gate.future;
        } else {
          retry.response = () => gate.future;
        }
        final workspace = _Workspace();
        final container = ProviderContainer(
          overrides: [
            workspaceShellProvider.overrideWith(() => workspace),
            talkAttachmentGovernanceApiProvider.overrideWithValue(api),
            talkRecordCleanupRetryClientProvider.overrideWithValue(retry),
            talkRecordCleanupSessionProvider.overrideWithValue(() => 'actor'),
            talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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
                          workspaceId: '10',
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
        await tester.pumpAndSettle();
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(retry.posts, beforeDispatch ? 0 : 1);
        workspace.switchSpace();
        await tester.pumpAndSettle();
        expect(find.byType(TalkAttachmentGovernanceSheet), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(api.reads, 1);
        expect(retry.posts, beforeDispatch ? 0 : 1);
        expect(container.read(workspaceShellProvider).currentWorkspaceId, '20');
        expect(action, findsNothing);
        if (beforeDispatch) expect(retry.guardError, isStateError);
      },
    );
  }
}
