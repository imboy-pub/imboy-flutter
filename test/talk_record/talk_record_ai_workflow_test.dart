import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_minimax_result.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'talk_record_ai_workflow_helpers.dart';

void main() {
  late Directory temporary;
  late AiTestKeys keys;
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
    temporary = await Directory.systemTemp.createTemp('talk-ai-workflow-');
    keys = AiTestKeys();
    store = TalkRecordAiCheckpointStore(
      temporary,
      keys,
      'synthetic-deployment/account/1/transcribe',
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
    await credentials.save(
      TalkRecordAiProvider.minimax,
      'synthetic-api-key-not-real',
    );
    await credentials.save(
      TalkRecordAiProvider.zhipu,
      'synthetic-api-key-not-real',
    );
    backend = AiTestBackend(store);
    provider = AiTestProvider(backend, store);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  test(
    'checkpoint encrypts secrets, randomizes nonce and survives restart',
    () async {
      final payload = {
        'text': 'sensitive-transcript',
        'token': 'synthetic-run-token',
      };
      await store.save(payload);
      final first = await store.file.readAsBytes();
      expect(
        utf8.decode(first, allowMalformed: true),
        isNot(contains('sensitive-transcript')),
      );
      expect(
        utf8.decode(first, allowMalformed: true),
        isNot(contains('synthetic-run-token')),
      );
      await store.save(payload);
      expect(await store.file.readAsBytes(), isNot(equals(first)));
      expect(
        await TalkRecordAiCheckpointStore(
          temporary,
          keys,
          store.identity,
        ).load(),
        payload,
      );
      expect(temporary.listSync().whereType<File>().length, 1);
    },
  );
  test('tamper, missing key and changed identity fail closed', () async {
    await store.save({'text': 'private'});
    final bytes = await store.file.readAsBytes();
    bytes[15] ^= 1;
    await store.file.writeAsBytes(bytes);
    await expectLater(store.load(), throwsA(anything));
    final other = TalkRecordAiCheckpointStore(temporary, keys, 'other-account');
    await other.file.writeAsBytes(bytes);
    await expectLater(other.load(), throwsStateError);
    keys.values.clear();
    await expectLater(store.load(), throwsStateError);
    await expectLater(store.save({'text': 'replacement'}), throwsStateError);
  });
  test(
    'consent cancellation causes no checkpoint, backend or provider work',
    () async {
      await expectLater(
        coordinator().execute(consentConfirmed: false),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(backend.events, isEmpty);
      expect(await store.file.exists(), isFalse);
      expect(provider.calls, 0);
    },
  );
  test('two chunks persist intent before dispatch and retain independent local S1 labels', () async {
    await coordinator().execute(consentConfirmed: true);
    expect(provider.calls, 2);
    final results = backend.requests
        .where((request) => request['action'] == 'result')
        .toList();
    expect(results.map((request) => request['seq']), [0, 1]);
    for (final request in results) {
      final result = request['body']['result'];
      expect(result['speakers'].single['label'], 'S1');
      expect(result['segments'].single['speaker_label'], 'S1');
      expect(result['segments'].single['start_ms'], 0);
      expect(result['segments'].single['end_ms'], 64);
    }
    expect((await store.load())!['phase'], 'complete');
    await coordinator().execute(consentConfirmed: true);
    expect(provider.calls, 2);
    final capture = Platform.environment['TALK_RECORD_WIRE_CAPTURE'];
    if (capture != null) {
      await File('$capture/transcribe.json').writeAsString(
        jsonEncode({
          'public': backend.policy,
          'snapshot': backend.source,
          'requests': backend.requests,
        }),
      );
    }
  });
  test(
    'summary uses current int64 segment IDs and normalized model result',
    () async {
      backend.mode = 'summarize';
      await coordinator().execute(consentConfirmed: true);
      expect(provider.calls, 1);
      final result = backend.requests.singleWhere(
        (request) => request['action'] == 'result',
      )['body']['result'];
      expect(result['decisions'].single['segment_ids'], [9007199254740993]);
      final capture = Platform.environment['TALK_RECORD_WIRE_CAPTURE'];
      if (capture != null) {
        await File('$capture/summarize.json').writeAsString(
          jsonEncode({
            'public': backend.policy,
            'snapshot': {'segments': backend.segments},
            'requests': backend.requests,
          }),
        );
      }
    },
  );
  for (final status in [401, 402, 429, 500]) {
    test(
      '$status response persists barrier across restart without provider replay',
      () async {
        provider.status = status;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        final code = (await store.load())!['blocked'];
        expect(
          code,
          status == 401
              ? 'key_invalid'
              : status == 402
              ? 'insufficient_balance'
              : 'provider_outcome_unknown',
        );
        provider.status = 200;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        expect(provider.calls, 1);
      },
    );
  }
  test('timeout is unknown and never replayed', () async {
    provider.timeout = true;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(provider.calls, 1);
  });
  test(
    'lost dispatch grant blocks provider forever including restart',
    () async {
      backend.loseDispatch = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(provider.calls, 0);
    },
  );
  test('may_dispatch false does not authorize a provider replay', () async {
    backend.denyDispatch = true;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(provider.calls, 0);
  });
  test(
    'locally durable result is resubmitted after restart without model replay',
    () async {
      backend.failAction = 'result';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsStateError,
      );
      expect(provider.calls, 1);
      expect((await store.load())!['parts']['0']['result'], isNotNull);
      backend.failAction = null;
      await coordinator().execute(consentConfirmed: true);
      expect(provider.calls, 2);
      expect(backend.events.where((event) => event == 'provider:0').length, 1);
    },
  );
  test('lost completion response reconciles terminal GET before changed content pins', () async {
    backend.loseComplete = true;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsStateError,
    );
    final before = provider.calls;
    await coordinator().execute(consentConfirmed: true);
    expect(provider.calls, before);
    expect((await store.load())!['phase'], 'complete');
  });
  for (final permission in [true, false]) {
    test(
      'changed ${permission ? 'permission' : 'input'} stops restore and clears readable payload',
      () async {
        backend.failAction = 'result';
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsStateError,
        );
        backend.failAction = null;
        if (permission) {
          backend.denied = true;
        } else {
          backend.contentRevision++;
        }
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        expect(provider.calls, 1);
        expect((await store.load())!['snapshot'], isNull);
        expect((await store.load())!['parts'], isEmpty);
      },
    );
  }
  test('same-account auth epoch change blocks restoration', () async {
    backend.failAction = 'result';
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsStateError,
    );
    epoch++;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(isA<TalkRecordAiWorkflowException>()),
    );
    expect(provider.calls, 1);
  });
  test(
    'canonical wire is order independent, int64 exact and rejects floats',
    () {
      expect(
        talkRecordAiCanonical({
          'z': 9007199254740993,
          'a': ['汉字', null, true],
        }),
        r'{"a":["\u6c49\u5b57",null,true],"z":9007199254740993}',
      );
      expect(
        () => talkRecordAiCanonical({'float': 1.5}),
        throwsFormatException,
      );
      expect(
        talkRecordAiCanonical('你好/😀\n'),
        r'"\u4f60\u597d\/\ud83d\ude00\n"',
      );
      expect(
        () => talkRecordAiCanonical(String.fromCharCode(0xd800)),
        throwsFormatException,
      );
    },
  );
  test(
    'summary rejects foreign refs, invented owner/date and unknown fields',
    () {
      for (final item in [
        {
          'text': 'x',
          'segment_ids': [99],
        },
        {
          'text': 'x',
          'segment_ids': [9007199254740993],
          'owner_user_id': 5,
        },
        {
          'text': 'x',
          'segment_ids': [9007199254740993],
          'due_date': 'tomorrow',
        },
        {
          'text': 'x',
          'segment_ids': [9007199254740993],
          'tool_call': 'do it',
        },
      ]) {
        expect(
          () => talkRecordAiSummary({
            'model_version': 'glm-5.3-flash',
            'overview': 'x',
            'decisions': [item],
            'actions': [],
          }, backend.segments),
          throwsFormatException,
        );
      }
    },
  );
  test('audio plan rejects oversized or discontinuous independent sources', () {
    for (final mutation in [
      {'duration_ms': 500001},
      {'byte_size': 50000001},
      {'offset_ms': 7},
    ]) {
      final snapshot = aiTestCopy(backend.source);
      (snapshot['parts'] as List)[0].addAll(mutation);
      expect(
        () => talkRecordAiPlan('transcribe', snapshot),
        throwsFormatException,
      );
    }
  });
  test('memory segment decrypt verifies integrity without producing plaintext file', () async {
    final plain = File('${temporary.path}/input.aac');
    await plain.writeAsBytes(aiTestAudioBytes);
    final cipher = File('${temporary.path}/cipher.enc');
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plain,
      cipherFile: cipher,
      recordKey: key,
      sessionId: 'synthetic-session',
      seq: 0,
      mime: 'audio/aac',
    );
    await plain.delete();
    expect(
      await TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: cipher,
        recordKey: key,
        sessionId: 'synthetic-session',
        seq: 0,
        info: info,
        mime: 'audio/aac',
      ),
      aiTestAudioBytes,
    );
    expect(temporary.listSync().map((file) => file.path), [cipher.path]);
    final bytes = await cipher.readAsBytes();
    bytes[0] ^= 1;
    await cipher.writeAsBytes(bytes);
    await expectLater(
      TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: cipher,
        recordKey: key,
        sessionId: 'synthetic-session',
        seq: 0,
        info: info,
        mime: 'audio/aac',
      ),
      throwsA(isA<TalkRecordSegmentCryptoException>()),
    );
  });
}
