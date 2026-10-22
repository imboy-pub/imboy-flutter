import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_processing_panel.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_providers.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_runtime.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';

import 'talk_record_ai_workflow_helpers.dart';

class _BeforeJobBackend extends AiTestBackend {
  _BeforeJobBackend(super.store);
  int contextReads = 0;
  @override
  Future<Map<String, dynamic>> context(String id, void Function() guard) {
    contextReads++;
    return super.context(id, guard);
  }
}

class _RecoveryCoordinator extends TalkRecordAiCoordinator {
  _RecoveryCoordinator(
    TalkRecordAiCheckpointStore store,
    TalkRecordAiCredentials keys,
  ) : super(
        recordId: '1',
        mode: 'transcribe',
        credentials: keys,
        checkpoints: store,
        gateway: AiTestBackend(store),
        guard: () {},
        audio: (_) => throw StateError('UI must not read audio'),
      );
  final confirmations = <TalkRecordAiRecovery?>[];
  static const challenge = TalkRecordAiRecovery(
    previousRunId: '9007199254740993',
    etag: 'client-run:9007199254740993:7',
    fingerprint: 'synthetic-binding',
    intentDetails: '1 / 9007199254740995',
  );
  @override
  Future<void> execute({
    required bool consentConfirmed,
    TalkRecordAiRecovery? recoveryConfirmation,
  }) async {
    expect(consentConfirmed, isTrue);
    confirmations.add(recoveryConfirmation);
    throw TalkRecordAiWorkflowException(
      'provider_outcome_unknown',
      recovery: recoveryConfirmation == null ? challenge : null,
    );
  }
}

void main() {
  for (final hasCheckpoint in [false, true]) {
    test('pending Doubao refuses before context, job, audio and dispatch '
        'with checkpoint=$hasCheckpoint', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final temporary = await Directory.systemTemp.createTemp(
        'talk-ai-pending-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final store = TalkRecordAiCheckpointStore(
        temporary,
        AiTestKeys(),
        'pending',
      );
      if (hasCheckpoint) {
        await store.save({'historical_unknown': 'preserve-existing-facts'});
      }
      final before = hasCheckpoint ? await store.file.readAsBytes() : null;
      final scope = TalkRecordAiCredentialScope(
        deploymentOrigin: 'https://synthetic.invalid',
        accountId: '2',
      );
      final credentials = TalkRecordAiCredentials(
        scope: scope,
        currentScope: () => scope,
        authSessionEpoch: 1,
        currentAuthSessionEpoch: () => 1,
        store: AiTestSecrets(),
      );
      await credentials.save(
        TalkRecordAiProvider.doubao,
        'synthetic-key-not-real',
      );
      final backend = _BeforeJobBackend(store);
      var audioReads = 0;
      var adapters = 0;
      final coordinator = TalkRecordAiCoordinator(
        recordId: '1',
        mode: 'transcribe',
        asrProvider: TalkRecordAiProvider.doubao,
        credentials: credentials,
        checkpoints: store,
        gateway: backend,
        guard: () {},
        audio: (_) {
          audioReads++;
          throw StateError('must not read audio');
        },
        adapterFactory: () {
          adapters++;
          throw StateError('must not construct a transport');
        },
      );
      await expectLater(
        coordinator.execute(consentConfirmed: true),
        throwsA(
          isA<TalkRecordAiWorkflowException>().having(
            (error) => error.code,
            'safe code',
            'provider_not_integrated',
          ),
        ),
      );
      expect(backend.contextReads, 0);
      expect(backend.requests, isEmpty);
      expect(audioReads, 0);
      expect(adapters, 0);
      expect(await store.file.exists(), hasCheckpoint);
      if (hasCheckpoint) expect(await store.file.readAsBytes(), before);
    });
  }

  testWidgets('pending Doubao selection never opens consent or reads runtime', (
    tester,
  ) async {
    var runtimeReads = 0;
    final container = ProviderContainer(
      overrides: [
        talkRecordAiIdentityReaderProvider.overrideWithValue(() => null),
        talkRecordAuthSubscribeProvider.overrideWithValue((listener) => () {}),
        talkRecordAiRuntimeProvider.overrideWith((ref, task) async {
          runtimeReads++;
          throw StateError('pending provider must not reach runtime');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TalkRecordAiProcessingPanel(recordId: '1')),
        ),
      ),
    );
    await tester.tap(find.text(t.talkRecord.aiDoubaoTitle));
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.aiDoubaoPendingNotice), findsOneWidget);
    final transcribe = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, t.talkRecord.aiProcessTranscribe),
    );
    expect(transcribe.onPressed, isNull);
    await tester
        .state<TalkRecordAiProcessingPanelState>(
          find.byType(TalkRecordAiProcessingPanel),
        )
        .start('transcribe');
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(runtimeReads, 0);
    await tester.tap(find.text(t.talkRecord.aiMinimaxTitle));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoButton>(
            find.widgetWithText(
              CupertinoButton,
              t.talkRecord.aiProcessTranscribe,
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(runtimeReads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in ['cancel', 'confirm', 'account-change']) {
    testWidgets(
      'unknown recovery $action binds concrete run and never implicitly acknowledges',
      (tester) async {
        final temporary = Directory.systemTemp.createTempSync(
          'talk-ai-recovery-ui-',
        );
        addTearDown(() => temporary.deleteSync(recursive: true));
        final scope = TalkRecordAiCredentialScope(
          deploymentOrigin: 'https://synthetic.invalid',
          accountId: '2',
        );
        final credentials = TalkRecordAiCredentials(
          scope: scope,
          currentScope: () => scope,
          authSessionEpoch: 1,
          currentAuthSessionEpoch: () => 1,
          store: AiTestSecrets(),
        );
        final coordinator = _RecoveryCoordinator(
          TalkRecordAiCheckpointStore(temporary, AiTestKeys(), 'ui'),
          credentials,
        );
        TalkRecordAiIdentity? identity = TalkRecordAiIdentity(scope, 1);
        final container = ProviderContainer(
          overrides: [
            talkRecordAiIdentityReaderProvider.overrideWithValue(
              () => identity,
            ),
            talkRecordAuthSubscribeProvider.overrideWithValue(
              (listener) => () {},
            ),
            talkRecordAiRuntimeProvider.overrideWith(
              (ref, task) async => coordinator,
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: TalkRecordAiProcessingPanel(recordId: '1')),
            ),
          ),
        );
        await tester.tap(find.text(t.talkRecord.aiProcessTranscribe));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.confirmations, [null]);
        await tester.tap(find.text(t.talkRecord.aiUnknownRecoveryTitle));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(_RecoveryCoordinator.challenge.previousRunId),
          findsOneWidget,
        );
        expect(
          find.textContaining(_RecoveryCoordinator.challenge.intentDetails),
          findsOneWidget,
        );
        expect(
          find.textContaining(t.talkRecord.aiUnknownRecoveryNotice),
          findsOneWidget,
        );
        if (action == 'account-change') {
          identity = null;
          container.invalidate(talkRecordAiSessionProvider);
          await tester.pump();
        }
        await tester.tap(
          find.text(
            action == 'cancel'
                ? t.talkRecord.aiCancel
                : t.talkRecord.aiUnknownRecoveryConfirm,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          coordinator.confirmations,
          action == 'confirm' ? [null, _RecoveryCoordinator.challenge] : [null],
        );
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final confirm in [false, true]) {
    testWidgets(
      'processing consent ${confirm ? 'confirmation connects runtime' : 'cancel keeps runtime untouched'}',
      (tester) async {
        var runtimeReads = 0;
        final container = ProviderContainer(
          overrides: [
            talkRecordAiIdentityReaderProvider.overrideWithValue(
              () => TalkRecordAiIdentity(
                TalkRecordAiCredentialScope(
                  deploymentOrigin: 'https://synthetic.invalid',
                  accountId: '2',
                ),
                1,
              ),
            ),
            talkRecordAuthSubscribeProvider.overrideWithValue(
              (listener) => () {},
            ),
            talkRecordAiRuntimeProvider.overrideWith((ref, task) async {
              runtimeReads++;
              expect(task, (
                recordId: '1',
                mode: 'transcribe',
                provider: TalkRecordAiProvider.minimax,
              ));
              throw const TalkRecordAiWorkflowException('key_invalid');
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: TalkRecordAiProcessingPanel(recordId: '1')),
            ),
          ),
        );
        await tester.tap(find.text(t.talkRecord.aiProcessTranscribe));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(runtimeReads, 0);
        await tester.tap(
          find.text(confirm ? t.common.confirm : t.talkRecord.aiCancel),
        );
        await tester.pumpAndSettle();
        expect(runtimeReads, confirm ? 1 : 0);
        if (confirm) {
          expect(
            find.text(t.talkRecord.aiProcessingKeyInvalid),
            findsOneWidget,
          );
        }
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
