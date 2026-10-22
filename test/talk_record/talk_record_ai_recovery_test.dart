import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_minimax_result.dart';

import 'talk_record_ai_workflow_helpers.dart';

void main() {
  late Directory temporary;
  late TalkRecordAiCheckpointStore store;
  late TalkRecordAiCredentials credentials;
  late AiTestBackend backend;
  late AiTestProvider provider;
  var epoch = 1;
  TalkRecordAiCoordinator coordinator() => TalkRecordAiCoordinator(
    recordId: '1',
    mode: backend.mode,
    credentials: credentials,
    checkpoints: store,
    gateway: backend,
    guard: () {},
    adapterFactory: () => provider,
    audio: (chunk) async => TalkRecordAiAudioChunk.fromAdts(
      aiTestAudioBytes,
      expectedSha256: sha256.convert(aiTestAudioBytes).toString(),
      expectedByteLength: 8,
      expectedDurationMs: 64,
      chunkId: 'c${chunk['seq']}',
      offsetMs: chunk['offset_ms'] as int,
    ),
  );
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    epoch = 1;
    temporary = await Directory.systemTemp.createTemp('talk-ai-recovery-');
    store = TalkRecordAiCheckpointStore(
      temporary,
      AiTestKeys(),
      'recovery/account/1',
    );
    final scope = TalkRecordAiCredentialScope(
      deploymentOrigin: 'https://synthetic.invalid',
      accountId: '2',
    );
    credentials = TalkRecordAiCredentials(
      scope: scope,
      currentScope: () => scope,
      authSessionEpoch: 1,
      currentAuthSessionEpoch: () => epoch,
      store: AiTestSecrets(),
    );
    await credentials.save(TalkRecordAiProvider.minimax, 'synthetic-not-a-key');
    backend = AiTestBackend(store);
    provider = AiTestProvider(backend, store);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  Future<void> partiallyConfirmed() async {
    backend.loseResultSeq = 0;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsStateError,
    );
    expect(provider.calls, 1);
    expect(backend.run!['parts'][0]['provider_state'], 'confirmed');
    expect(backend.run!['parts'][1]['provider_state'], 'not_dispatched');
    backend.loseResultSeq = null;
    backend.run!['state'] = 'expired';
  }

  Future<TalkRecordAiRecovery> unknown() async {
    provider.timeout = true;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(provider.calls, 1);
    expect(backend.run!['state'], 'provider_outcome_unknown');
    try {
      await coordinator().execute(consentConfirmed: true);
    } on TalkRecordAiWorkflowException catch (error) {
      expect(error.code, 'provider_outcome_unknown');
      return error.recovery!;
    }
    throw StateError('missing unknown confirmation challenge');
  }

  test('run1 confirmed chunk survives expired same-job successor without paying twice', () async {
    await partiallyConfirmed();
    final old = aiTestCopy(backend.run!);
    await coordinator().execute(consentConfirmed: true);
    expect(provider.calls, 2);
    expect(backend.run!['attempt'], 2);
    expect(backend.run!['state'], 'complete');
    final claims = backend.requests
        .where((request) => request['action'] == 'claim')
        .toList();
    expect(claims.length, 2);
    expect(claims.map((claim) => claim['job_id']), ['3', '3']);
    expect(claims.last['body'].keys.toSet(), {'processing_consent'});
    expect(claims.last['key'], isNot(claims.first['key']));
    expect(backend.events.where((event) => event == 'provider:0').length, 1);
    final disk = (await store.load())!;
    expect(disk['history'].single['run'], old);
    expect(disk['required_confirmed']['0'], old['parts'][0]['result_hash']);
    expect(disk['history'].single['parts']['0']['result'], isNotNull);
  });

  test(
    'missing BE confirmed reuse stops before any new provider dispatch',
    () async {
      await partiallyConfirmed();
      backend.skipReuse = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(
          isA<TalkRecordAiWorkflowException>().having(
            (error) => error.code,
            'code',
            'confirmed_reuse_missing',
          ),
        ),
      );
      expect(provider.calls, 1);
      expect(
        backend.requests
            .where((request) => request['action'] == 'dispatch')
            .length,
        1,
      );
    },
  );

  test('unknown ordinary execute only queries and offers concrete predecessor challenge', () async {
    final challenge = await unknown();
    final before = backend.requests.length;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(backend.requests.skip(before).map((request) => request['action']), [
      'get',
    ]);
    expect(challenge.previousRunId, '4');
    expect(challenge.etag, backend.run!['etag']);
    expect(challenge.intentDetails, '0 / 100');
    expect(provider.calls, 1);
    expect((await store.load())!['recovery'], isNull);
  });

  test('explicit bound acknowledgement claims a new attempt and preserves unknown facts', () async {
    final challenge = await unknown();
    final old = aiTestCopy(backend.run!);
    provider.timeout = false;
    await coordinator().execute(
      consentConfirmed: true,
      recoveryConfirmation: challenge,
    );
    final claim = backend.requests.lastWhere(
      (request) => request['action'] == 'claim',
    );
    expect(claim['if_match'], '"${old['etag']}"');
    expect(claim['body']['previous_run_id'], 4);
    expect(claim['body']['ack_possible_duplicate_charge'], isTrue);
    expect(claim['body'].keys.toSet(), {
      'processing_consent',
      'previous_run_id',
      'ack_possible_duplicate_charge',
    });
    expect(provider.calls, 3);
    final disk = (await store.load())!;
    expect(disk['history'].single['run'], old);
    expect(disk['history'].single['blocked'], 'provider_outcome_unknown');
    expect(disk['history'].single['parts']['0']['intent'], isNotNull);
    expect(disk['phase'], 'complete');
    expect(backend.previousRuns.single, old);
    final capture = Platform.environment['TALK_RECORD_WIRE_CAPTURE'];
    if (capture != null) {
      await File('$capture/recovery.json').writeAsString(
        jsonEncode({'requests': backend.requests, 'previous_run': old}),
      );
    }
  });

  for (final field in ['predecessor', 'etag', 'intent']) {
    test(
      'wrong $field confirmation never issues a claim or provider call',
      () async {
        final challenge = await unknown();
        final wrong = TalkRecordAiRecovery(
          previousRunId: field == 'predecessor'
              ? '99'
              : challenge.previousRunId,
          etag: field == 'etag' ? 'client-run:4:999' : challenge.etag,
          fingerprint: field == 'intent' ? 'wrong' : challenge.fingerprint,
          intentDetails: challenge.intentDetails,
        );
        final before = backend.requests.length;
        await expectLater(
          coordinator().execute(
            consentConfirmed: true,
            recoveryConfirmation: wrong,
          ),
          throwsA(
            isA<TalkRecordAiWorkflowException>().having(
              (error) => error.code,
              'code',
              'recovery_conflict',
            ),
          ),
        );
        expect(
          backend.requests.skip(before).map((request) => request['action']),
          ['get'],
        );
        expect(provider.calls, 1);
      },
    );
  }

  test('cancelled acknowledgement sends zero requests and keeps unknown checkpoint', () async {
    final challenge = await unknown();
    final before = backend.requests.length;
    final disk = await store.load();
    await expectLater(
      coordinator().execute(
        consentConfirmed: false,
        recoveryConfirmation: challenge,
      ),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(backend.requests.length, before);
    expect(provider.calls, 1);
    expect(await store.load(), disk);
  });

  test(
    'foreign recovery challenge cannot initialize a different job',
    () async {
      await expectLater(
        coordinator().execute(
          consentConfirmed: true,
          recoveryConfirmation: const TalkRecordAiRecovery(
            previousRunId: '99',
            etag: 'client-run:99:1',
            fingerprint: 'foreign',
            intentDetails: '0 / 1',
          ),
        ),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(backend.requests, isEmpty);
      expect(provider.calls, 0);
      expect(await store.file.exists(), isFalse);
    },
  );

  for (final afterCommit in [false, true]) {
    test(
      'unknown claim ${afterCommit ? 'receipt lost' : 'rejected'} persists exact intent and never dispatches before receipt',
      () async {
        final challenge = await unknown();
        backend.loseClaim = afterCommit;
        backend.rejectClaim = !afterCommit;
        await expectLater(
          coordinator().execute(
            consentConfirmed: true,
            recoveryConfirmation: challenge,
          ),
          throwsStateError,
        );
        final pending = (await store.load())!['recovery'];
        expect(pending['body']['ack_possible_duplicate_charge'], isTrue);
        expect(pending['previous_run']['id'], 4);
        expect(provider.calls, 1);
        final first = backend.requests.last;
        backend.loseClaim = false;
        backend.rejectClaim = false;
        provider.timeout = false;
        await coordinator().execute(consentConfirmed: true);
        final claims = backend.requests
            .where((request) => request['action'] == 'claim')
            .toList();
        expect(claims.length, 3);
        expect(claims.last, first);
        expect(backend.previousRuns.length, 1);
        expect(provider.calls, 3);
        expect(backend.run!['attempt'], 2);
      },
    );
  }

  test('locally durable result on expired unknown is submitted on successor without provider replay', () async {
    backend.failAction = 'result';
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsStateError,
    );
    backend.failAction = null;
    backend.run!['state'] = 'provider_outcome_unknown';
    final originalResult = (await store.load())!['parts']['0']['result'];
    final challenge = TalkRecordAiRecovery.fromRun(backend.run!);
    await coordinator().execute(
      consentConfirmed: true,
      recoveryConfirmation: challenge,
    );
    expect(provider.calls, 2);
    expect(backend.events.where((event) => event == 'provider:0').length, 1);
    expect(
      (await store.load())!['history'].single['parts']['0']['result'],
      originalResult,
    );
    expect(backend.run!['state'], 'complete');
  });

  for (final change in ['epoch', 'input', 'permission']) {
    test(
      'changed $change refuses unknown confirmation before successor claim',
      () async {
        final challenge = await unknown();
        final claims = backend.requests
            .where((request) => request['action'] == 'claim')
            .length;
        if (change == 'epoch') epoch++;
        if (change == 'input') backend.contentRevision++;
        if (change == 'permission') backend.denied = true;
        await expectLater(
          coordinator().execute(
            consentConfirmed: true,
            recoveryConfirmation: challenge,
          ),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        expect(
          backend.requests
              .where((request) => request['action'] == 'claim')
              .length,
          claims,
        );
        expect(provider.calls, 1);
      },
    );
  }

  for (final status in [401, 402]) {
    test(
      '$status barrier cannot be bypassed using unknown recovery confirmation',
      () async {
        provider.status = status;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        backend.run!['state'] = 'provider_outcome_unknown';
        final before = backend.requests.length;
        provider.status = 200;
        await expectLater(
          coordinator().execute(
            consentConfirmed: true,
            recoveryConfirmation: TalkRecordAiRecovery.fromRun(backend.run!),
          ),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        expect(backend.requests.length, before);
        expect(provider.calls, 1);
      },
    );
  }
}
