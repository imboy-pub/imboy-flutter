import 'package:imboy/modules/talk_record/application/talk_record_upload_progress.dart';
import 'package:imboy/modules/talk_record/application/talk_record_capture_api_gateway.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';

import 'dart:async';

import 'package:imboy/modules/talk_record/application/talk_record_processing_consent.dart';

import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_pending_uploads.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/i18n/strings.g.dart';

class _PolicyListService extends Fake implements TalkRecordListService {
  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async =>
      const TalkRecordCapabilitiesModel(
        policyVersion: 'current-v2',
        recordingEnabled: true,
      );
}

class _Directory extends TalkRecordParticipantDirectory {
  @override
  bool get isAvailable => true;
  @override
  Future<List<TalkRecordParticipantOption>> search(
    String org,
    String q,
  ) async => [];
}

class _ProgressRuntime extends Fake implements TalkRecordRecordingCoordinator {
  _ProgressRuntime(this.pending);
  TalkRecordPendingEnded pending;
  int reads = 0;
  bool uploading = false;
  final progress = StreamController<TalkRecordUploadSnapshot>.broadcast();
  TalkRecordUploadSnapshot? latest;
  @override
  Stream<TalkRecordUploadSnapshot> get uploadUpdates => progress.stream;
  @override
  TalkRecordUploadSnapshot? get uploadSnapshot => latest;
  @override
  Future<List<TalkRecordPendingEnded>> pendingEnded() async {
    reads++;
    if (uploading) throw StateError('Recording operation in progress');
    return [pending];
  }

  void publish(TalkRecordUploadPhase phase) {
    latest = TalkRecordUploadSnapshot(
      account: pending.binding.account,
      recordId: pending.binding.recordId,
      sessionId: pending.binding.sessionId,
      totalParts: 1,
      confirmedParts: 0,
      phase: phase,
      pendingBinding: pending.binding,
    );
    progress.add(latest!);
  }
}

void main() {
  const account = TalkRecordAccount('https://synthetic.test', 'owner');
  const personal = TalkRecordEntryContext.personal();
  const org = TalkRecordEntryContext(
    scope: TalkRecordScope.organization,
    organizationId: 'org',
  );
  const ws = TalkRecordEntryContext(
    scope: TalkRecordScope.organization,
    organizationId: 'org',
    workspaceId: 'ws',
  );
  TalkRecordPendingEnded item(
    String title,
    TalkRecordEntryContext context, [
    TalkRecordAccount owner = account,
  ]) => TalkRecordPendingEnded(
    TalkRecordLocalBinding(
      account: owner,
      clientRecordingId: title,
      context: context,
      title: title,
      processingMode: 'record_only',
      recordId: 'bound-$title',
      uploadAttempted: true,
      deviceSessionId: 'session',
    ),
    100,
    1,
  );
  final items = [
    item('PERSONAL', personal),
    item('ORG', org),
    item('WORKSPACE', ws),
    item(
      'FOREIGN',
      personal,
      const TalkRecordAccount('https://other.test', 'owner'),
    ),
  ];

  Future<void> mount(
    WidgetTester tester,
    TalkRecordEntryContext filter, {
    Future<void> Function(TalkRecordPendingEnded)? retry,
    Future<void> Function(
      TalkRecordPendingEnded,
      List<TalkRecordParticipantInput>,
    )?
    edit,
    TalkRecordAccount owner = account,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          talkRecordPendingAccountProvider.overrideWithValue(owner),
          talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
          talkRecordParticipantDirectoryProvider.overrideWithValue(
            _Directory(),
          ),
          talkRecordPendingParticipantsEditProvider.overrideWithValue(
            edit ?? (_, _) async {},
          ),
          talkRecordPendingUploadsProvider.overrideWith((ref) async => items),
          talkRecordUploadProgressProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
          talkRecordPendingRetryProvider.overrideWithValue(
            retry ?? (_) async {},
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: TalkRecordPendingUploads(contextFilter: filter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in {
    'PERSONAL': personal,
    'ORG': org,
    'WORKSPACE': ws,
  }.entries) {
    testWidgets('pending records isolate ${entry.key} scope and account', (
      tester,
    ) async {
      await mount(tester, entry.value);
      for (final title in ['PERSONAL', 'ORG', 'WORKSPACE', 'FOREIGN']) {
        expect(
          find.text(title),
          title == entry.key ? findsOneWidget : findsNothing,
        );
      }
    });
  }
  testWidgets(
    'explicit pending participant edit returns corrected facts to retry action',
    (tester) async {
      List<TalkRecordParticipantInput>? corrected;
      TalkRecordPendingEnded? target;
      await mount(
        tester,
        personal,
        edit: (item, selected) async {
          target = item;
          corrected = selected;
        },
      );
      await tester.tap(
        find.text('${t.talkRecord.collabParticipantsLabel} · ${t.common.edit}'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'New guest');
      await tester.tap(find.text(t.talkRecord.participantsAddGuest));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonAccomplish));
      await tester.pumpAndSettle();
      expect(target!.binding.clientRecordingId, 'PERSONAL');
      expect(target!.binding.context, personal);
      expect(corrected!.single.toJson(), {'display_name': 'New guest'});
      expect(find.text('PERSONAL'), findsOneWidget);
    },
  );

  testWidgets('anonymous transition hides pending recordings', (tester) async {
    await mount(
      tester,
      personal,
      owner: const TalkRecordAccount('https://synthetic.test', ''),
    );
    expect(find.text('PERSONAL'), findsNothing);
    expect(find.byType(CupertinoButton), findsNothing);
  });
  testWidgets(
    'first binding projects progress without re-entering the upload mutex',
    (tester) async {
      final unbound = item('FIRST', personal).binding.copyWith(
        recordId: '',
        sessionId: 'local-session',
        uploadAttempted: false,
      );
      final runtime = _ProgressRuntime(TalkRecordPendingEnded(unbound, 100, 1));
      final completion = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordPendingAccountProvider.overrideWithValue(account),
            talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
            talkRecordRecordingRuntimeProvider.overrideWith(
              (ref) async => runtime,
            ),
            talkRecordPendingRetryProvider.overrideWithValue((requested) {
              expect(requested.binding.recordId, isEmpty);
              runtime.uploading = true;
              // The bind/store save boundary updates the authoritative pending item
              // before the upload gateway publishes its first server-bound phase.
              runtime.pending = TalkRecordPendingEnded(
                requested.binding.copyWith(recordId: 'new-server-record'),
                100,
                1,
              );
              runtime.publish(TalkRecordUploadPhase.register);
              runtime.publish(TalkRecordUploadPhase.upload);
              return completion.future;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TalkRecordPendingUploads(contextFilter: personal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(runtime.pending.binding.recordId, isEmpty);
      final initialReads = runtime.reads;
      await tester.tap(find.text(t.talkRecord.uploadRecording));
      await tester.pumpAndSettle();
      expect(runtime.reads, initialReads);
      expect(runtime.uploading, isTrue);
      expect(
        find.text(talkRecordUploadProgressLabel(runtime.latest!)),
        findsOneWidget,
      );
      expect(runtime.latest!.matches(runtime.pending.binding), isTrue);
      final boundReads = runtime.reads;
      runtime.publish(TalkRecordUploadPhase.confirm);
      await tester.pumpAndSettle();
      expect(runtime.reads, boundReads);
      expect(
        find.text(talkRecordUploadProgressLabel(runtime.latest!)),
        findsOneWidget,
      );
      runtime.uploading = false;
      completion.completeError(StateError('retryable upload failure'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.progress.close();
    },
  );

  testWidgets('retry is exclusive and failure never removes local item', (
    tester,
  ) async {
    final complete = Completer<void>();
    var calls = 0;
    await mount(
      tester,
      personal,
      retry: (_) {
        calls++;
        return complete.future;
      },
    );
    await tester.tap(find.text(t.talkRecord.retryRecordingUpload));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<CupertinoButton>(
            find.ancestor(
              of: find.text(t.common.uploading),
              matching: find.byType(CupertinoButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text(t.common.uploading));
    await tester.pump();
    expect(calls, 1);
    complete.completeError(StateError('synthetic failure'));
    await tester.pumpAndSettle();
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text(t.common.retryFailedPleaseCheckNetwork), findsOneWidget);
    expect(find.text(t.talkRecord.retryRecordingUpload), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final transition in [false, true]) {
    testWidgets(
      'explicit upload notice cancel/auth transition does not retry $transition',
      (tester) async {
        void Function()? changed;
        var calls = 0;
        final draft = TalkRecordPendingEnded(
          TalkRecordLocalBinding(
            account: account,
            clientRecordingId: 'offline',
            context: personal,
            title: 'Offline draft',
            processingMode: 'record_only',
            deviceSessionId: 'session',
          ),
          100,
          1,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              talkRecordUploadProgressProvider.overrideWith(
                (ref) => const Stream.empty(),
              ),
              talkRecordPendingAccountProvider.overrideWithValue(account),
              talkRecordAuthSubscribeProvider.overrideWithValue((cb) {
                changed = cb;
                return () {};
              }),
              talkRecordListServiceProvider.overrideWithValue(
                _PolicyListService(),
              ),
              talkRecordPendingUploadsProvider.overrideWith(
                (ref) async => [draft],
              ),
              talkRecordPendingRetryProvider.overrideWithValue((_) async {
                calls++;
                throw const TalkRecordUploadPolicyRequired();
              }),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: TalkRecordPendingUploads(contextFilter: personal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.talkRecord.uploadRecording), findsOneWidget);
        expect(find.text(t.talkRecord.retryRecordingUpload), findsNothing);
        await tester.tap(find.text(t.talkRecord.uploadRecording));
        await tester.pumpAndSettle();
        expect(find.text(t.talkRecord.uploadNoticeTitle), findsOneWidget);
        expect(find.textContaining('current-v2'), findsOneWidget);
        if (transition) changed!();
        await tester.tap(
          find.text(transition ? t.common.confirm : t.common.cancel),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(draft.binding.policyVersion, isEmpty);
        expect(draft.binding.uploadPolicyAcknowledgedAt, isNull);
      },
    );
  }
  for (final width in [320.0, 390.0, 1000.0]) {
    testWidgets(
      'processing consent cancellation keeps local audio at width $width 2x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              talkRecordUploadProgressProvider.overrideWith(
                (ref) => const Stream.empty(),
              ),
              talkRecordPendingAccountProvider.overrideWithValue(account),
              talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
              talkRecordPendingUploadsProvider.overrideWith(
                (ref) async => [
                  TalkRecordPendingEnded(
                    TalkRecordLocalBinding.fromJson({
                      ...items.first.binding.toJson(),
                      'processing_mode': 'transcribe',
                    }),
                    items.first.durationMs,
                    items.first.segmentCount,
                  ),
                ],
              ),
              talkRecordPendingRetryProvider.overrideWithValue((_) async {
                calls++;
                throw const TalkRecordProcessingConsentRequired(
                  TalkRecordCapabilitiesModel(
                    recordingEnabled: true,
                    processingAvailable: true,
                    asrEnabled: true,
                    summaryEnabled: true,
                    policyVersion: 'current-policy-long-version',
                    processorConfigVersion: 'current-processor-long-version',
                    processorLocationCategory: 'self_hosted',
                  ),
                );
              }),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(
                body: TalkRecordPendingUploads(contextFilter: personal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.talkRecord.retryRecordingUpload));
        await tester.pumpAndSettle();
        expect(find.text(t.talkRecord.processingRecoveryTitle), findsOneWidget);
        await tester.tap(find.text(t.talkRecord.keepRecordingLocal));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(items.first.binding.processingConsentAcknowledgedAt, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
