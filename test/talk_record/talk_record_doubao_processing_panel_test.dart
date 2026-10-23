import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_processing_panel.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_providers.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_runtime.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

class _UnusedKeys implements TalkRecordKeyStore {
  @override
  Future<Uint8List?> readRecordKey(String id) async =>
      throw StateError('unused');
  @override
  Future<void> writeRecordKey(String id, Uint8List key) async =>
      throw StateError('unused');
  @override
  Future<void> deleteRecordKey(String id) async => throw StateError('unused');
}

class _UnusedGateway implements TalkRecordAiExecutionGateway {
  @override
  Future<Map<String, dynamic>> context(
    String id,
    void Function() guard,
  ) async => throw StateError('unused');
  @override
  Future<Map<String, dynamic>> request({
    required String recordId,
    String jobId = '',
    String runId = '',
    String taskId = '',
    required String action,
    int seq = 0,
    Map<String, dynamic> body = const {},
    required String idempotencyKey,
    String ifMatch = '',
    String token = '',
    required void Function() guard,
  }) async => throw StateError('unused');
}

class _Coordinator extends TalkRecordAiCoordinator {
  _Coordinator(
    TalkRecordAiCredentials credentials,
    TalkRecordAiCheckpointStore store,
  ) : super(
        recordId: '1',
        mode: 'transcribe',
        credentials: credentials,
        checkpoints: store,
        gateway: _UnusedGateway(),
        guard: () {},
        audio: (_) async => throw StateError('unused'),
      );
  int executions = 0, submissions = 0, cancellations = 0, preparations = 0;
  bool preparation = false;
  bool processingFromFirstQuery = false;
  @override
  bool get canResumeProviderPreparation => preparation;
  @override
  bool get canResubmitProviderTask => !preparation;
  @override
  Future<void> execute({
    required bool consentConfirmed,
    TalkRecordAiRecovery? recoveryConfirmation,
  }) async {
    expect(consentConfirmed, true);
    executions++;
    throw TalkRecordAiWorkflowException(
      executions == 1 && !processingFromFirstQuery
          ? 'provider_outcome_unknown'
          : 'provider_processing',
    );
  }

  @override
  Future<void> resubmitProviderTask({
    required bool consentConfirmed,
    required bool duplicateChargeConfirmed,
  }) async {
    expect(consentConfirmed, true);
    expect(duplicateChargeConfirmed, true);
    submissions++;
  }

  @override
  Future<void> resumeProviderPreparation({
    required bool consentConfirmed,
  }) async {
    expect(consentConfirmed, true);
    preparations++;
  }

  @override
  Future<void> cancelProviderTask() async {
    cancellations++;
  }
}

void main() {
  group('Doubao enabled processing controls', () {
    late Directory temporary;
    late _Coordinator coordinator;
    late TalkRecordAiIdentity? identity;
    late List<VoidCallback> listeners;
    setUpAll(() async => LocaleSettings.setLocale(AppLocale.zhCn));
    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('doubao-panel-');
      final scope = TalkRecordAiCredentialScope(
        deploymentOrigin: 'https://synthetic.invalid',
        accountId: '2',
      );
      identity = TalkRecordAiIdentity(scope, 1);
      listeners = [];
      coordinator = _Coordinator(
        TalkRecordAiCredentials(
          scope: scope,
          currentScope: () => identity?.scope,
          authSessionEpoch: 1,
          currentAuthSessionEpoch: () => identity?.epoch,
        ),
        TalkRecordAiCheckpointStore(
          temporary,
          _UnusedKeys(),
          'synthetic-panel',
        ),
      );
    });
    tearDown(() async => temporary.delete(recursive: true));
    Future<void> mount(
      WidgetTester tester, {
      ValueNotifier<String>? record,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordAiIdentityReaderProvider.overrideWithValue(
              () => identity,
            ),
            talkRecordAuthSubscribeProvider.overrideWithValue((callback) {
              listeners.add(callback);
              return () => listeners.remove(callback);
            }),
            talkRecordAiRuntimeProvider.overrideWith(
              (ref, task) async => coordinator,
            ),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: SafeArea(
                child: record == null
                    ? const TalkRecordAiProcessingPanel(recordId: '1')
                    : ValueListenableBuilder<String>(
                        valueListenable: record,
                        builder: (_, id, _) =>
                            TalkRecordAiProcessingPanel(recordId: id),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(t.talkRecord.aiDoubaoTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.talkRecord.aiProcessTranscribe));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(t.talkRecord.aiDoubaoExternalNotice),
        findsOneWidget,
      );
      await tester.tap(find.text(t.common.confirm));
      await tester.pumpAndSettle();
      expect(
        find.text(
          coordinator.processingFromFirstQuery
              ? t.talkRecord.aiProviderPending
              : t.talkRecord.aiProcessingUnknown,
        ),
        findsOneWidget,
      );
    }

    testWidgets(
      'first processing query and continue remain pending without resubmission',
      (tester) async {
        coordinator.processingFromFirstQuery = true;
        await mount(tester);
        expect(find.text(t.talkRecord.aiProcessingStopped), findsNothing);
        expect(coordinator.executions, 1);
        expect(coordinator.submissions, 0);
        await tester.tap(find.text(t.talkRecord.aiProcessTranscribe));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(find.text(t.talkRecord.aiProviderPending), findsOneWidget);
        expect(find.text(t.talkRecord.aiProcessingStopped), findsNothing);
        expect(coordinator.executions, 2);
        expect(coordinator.submissions, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'resume preparation asks stage consent without charge-risk prompt',
      (tester) async {
        coordinator.preparation = true;
        await mount(tester);
        await tester.tap(find.text(t.talkRecord.aiProviderResumePreparation));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(t.talkRecord.aiProviderResumeNotice),
          findsOneWidget,
        );
        expect(
          find.textContaining(t.talkRecord.aiProviderResubmitNotice),
          findsNothing,
        );
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.preparations, 1);
        expect(coordinator.submissions, 0);
      },
    );

    testWidgets(
      'resubmit requires a separate duplicate-charge consent and cancel performs no action',
      (tester) async {
        await mount(tester);
        await tester.tap(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderResubmit),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(t.talkRecord.aiProviderResubmitNotice),
          findsOneWidget,
        );
        expect(coordinator.submissions, 0);
        await tester.tap(
          find.widgetWithText(CupertinoDialogAction, t.talkRecord.aiCancel),
        );
        await tester.pumpAndSettle();
        expect(coordinator.submissions, 0);
        await tester.tap(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderResubmit),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.submissions, 1);
        expect(coordinator.executions, 2);
        expect(find.text(t.talkRecord.aiProviderPending), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'stop confirmation explains provider limits and only revokes after confirmation',
      (tester) async {
        await mount(tester);
        await tester.tap(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderCancel),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.talkRecord.aiProviderCancelNotice), findsOneWidget);
        expect(coordinator.cancellations, 0);
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.cancellations, 1);
        expect(coordinator.submissions, 0);
        expect(find.text(t.talkRecord.aiProviderCancelled), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'account change while confirmation is open cannot resubmit old account work',
      (tester) async {
        await mount(tester);
        await tester.tap(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderResubmit),
        );
        await tester.pumpAndSettle();
        identity = null;
        for (final callback in List<VoidCallback>.of(listeners)) {
          callback();
        }
        await tester.pump();
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.submissions, 0);
        expect(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderResubmit),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'record switch while a stop dialog is open cannot cancel previous record',
      (tester) async {
        final record = ValueNotifier<String>('1');
        await mount(tester, record: record);
        await tester.tap(
          find.widgetWithText(CupertinoButton, t.talkRecord.aiProviderCancel),
        );
        await tester.pumpAndSettle();
        record.value = '2';
        await tester.pump();
        await tester.tap(find.text(t.common.confirm));
        await tester.pumpAndSettle();
        expect(coordinator.cancellations, 0);
        expect(coordinator.submissions, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        record.dispose();
      },
    );
  }, skip: !TalkRecordAiProvider.doubaoEnabled);
}
