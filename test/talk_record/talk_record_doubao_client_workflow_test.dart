import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_minimax_result.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

class _Keys implements TalkRecordKeyStore {
  final values = <String, Uint8List>{};
  @override
  Future<Uint8List?> readRecordKey(String id) async => values[id];
  @override
  Future<void> writeRecordKey(String id, Uint8List key) async {
    values[id] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteRecordKey(String id) async => values.remove(id);
}

class _Secrets implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _Backend implements TalkRecordAiExecutionGateway {
  _Backend(this.store);
  final TalkRecordAiCheckpointStore store;
  final events = <String>[];
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? run;
  String? failAction;
  bool loseComplete = false;
  bool denyDispatch = false;
  bool loseDispatch = false;
  bool denied = false;
  int contentRevision = 1;
  String mode = 'summarize';
  final source = <String, dynamic>{
    'parts': List.generate(
      2,
      (seq) => {
        'seq': seq,
        'part_id': seq + 10,
        'attachment_id': seq + 20,
        'sha256': sha256.convert(_audioBytes).toString(),
        'byte_size': 8,
        'offset_ms': seq * 64,
        'duration_ms': 64,
      },
    ),
    'total_duration_ms': 128,
  };
  final segments = [
    {'id': 9007199254740993, 'start_ms': 0, 'end_ms': 64, 'text': '只记录确定事项'},
  ];
  Map<String, dynamic> get policy => {
    'available': !denied,
    'execution_mode': 'client_byok',
    'policy_version': 'v1',
    'config_version': 'a' * 64,
    'providers': {
      'transcribe': {'provider': 'minimax', 'model': 'asr-1.0'},
      'summarize': {'provider': 'zhipu', 'model': 'glm-5.3-flash'},
    },
  };

  @override
  Future<Map<String, dynamic>> context(String id, void Function() guard) async {
    guard();
    return {
      'id': 1,
      'scope': 'personal',
      'owner_user_id': 2,
      'organization_id': null,
      'workspace_id': null,
      'revision': 3,
      'content_revision': contentRevision,
      'acl_revision': 1,
      'media_status': 'available',
      'client_processing': policy,
    };
  }

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
  }) async {
    guard();
    final disk = await store.load();
    if (action != 'get') {
      expect(
        (disk!['operations'] as Map).values.any(
          (saved) =>
              saved['key'] == idempotencyKey &&
              talkRecordAiHash(saved['body']) == talkRecordAiHash(body),
        ),
        isTrue,
      );
      expect(idempotencyKey, isNotEmpty);
    }
    events.add('be:$action:$seq');
    requests.add({
      'action': action,
      'seq': seq,
      'body': _copy(body),
      'if_match': ifMatch,
      'token': token,
    });
    if (failAction == action) throw StateError('synthetic lost response');
    if (action == 'request') {
      expect(body['processing_consent'], {
        'confirmed': true,
        'execution_mode': 'client_byok',
        'provider': mode == 'transcribe' ? 'minimax' : 'zhipu',
        'model': mode == 'transcribe' ? 'asr-1.0' : 'glm-5.3-flash',
        'policy_version': 'v1',
        'config_version': 'a' * 64,
      });
      expect(body['mode'], mode);
      expect(ifMatch, '"3"');
      return {'job_id': 3, 'record_id': 1, 'revision': 4};
    }
    if (action == 'claim') {
      run ??= {
        'id': 4,
        'record_id': 1,
        'job_id': 3,
        'attempt': 1,
        'provider': mode == 'transcribe' ? 'minimax' : 'zhipu',
        'model': mode == 'transcribe' ? 'asr-1.0' : 'glm-5.3-flash',
        'policy_version': 'v1',
        'config_version': 'a' * 64,
        'input_content_revision': 1,
        'input_transcript_version': null,
        'input_manifest_hash': 'b' * 64,
        'chunk_plan_hash': null,
        'state': 'active',
        'revision': 1,
        'etag': 'client-run:4:1',
        'lease_expires_at_unix':
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
        'parts': <Map<String, dynamic>>[],
      };
      return {
        ..._copy(run!),
        'run_token': 'synthetic-run-token',
        'input_snapshot': mode == 'transcribe'
            ? source
            : {'segments': segments},
      };
    }
    if (action == 'get') return _copy(run!);
    expect(token, 'synthetic-run-token');
    expect(ifMatch, '"${run!['etag']}"');
    if (action == 'plan') {
      run!['chunk_plan_hash'] = talkRecordAiHash(body);
      run!['parts'] = (body['chunks'] as List)
          .map(
            (chunk) => {
              'seq': chunk['seq'],
              'provider_state': 'not_dispatched',
              'result_hash': null,
              'dispatch_intent_id': null,
            },
          )
          .toList();
    }
    if (action == 'dispatch') {
      expect((disk!['parts'] as Map)['$seq']['intent'], isNotNull);
      final part = (run!['parts'] as List)[seq] as Map;
      part['provider_state'] = 'dispatching';
      part['dispatch_intent_id'] = seq + 100;
    }
    if (action == 'result') {
      final part = (run!['parts'] as List)[seq] as Map;
      part['provider_state'] = 'confirmed';
      part['result_hash'] = body['result_hash'];
    }
    if (action == 'complete') {
      run!['state'] = 'complete';
      contentRevision++;
    }
    if (action == 'settle') run!['state'] = body['state'];
    run!['revision'] = (run!['revision'] as int) + 1;
    run!['etag'] = 'client-run:4:${run!['revision']}';
    if (action == 'complete' && loseComplete ||
        action == 'dispatch' && loseDispatch) {
      throw StateError('synthetic committed response lost');
    }
    return {
      ..._copy(run!),
      if (action == 'dispatch') ...{
        'may_dispatch': !denyDispatch,
        'dispatch_intent_id': seq + 100,
      },
    };
  }
}

final _audioBytes = Uint8List.fromList([
  0xff,
  0xf1,
  0x60,
  0x40,
  1,
  0x1f,
  0xfc,
  0,
]);

class _Provider implements HttpClientAdapter {
  _Provider(this.backend, this.store);
  final _Backend backend;
  final TalkRecordAiCheckpointStore store;
  int calls = 0;
  int status = 200;
  bool timeout = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final disk = await store.load();
    final seq = calls++;
    expect((disk!['parts'] as Map)['$seq']['intent'], isNotNull);
    expect((disk['parts'] as Map)['$seq']['dispatch_intent_id'], seq + 100);
    expect(backend.events.last, 'be:dispatch:$seq');
    backend.events.add('provider:$seq');
    if (stream != null) await stream.drain<void>();
    if (timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    final result = backend.mode == 'transcribe'
        ? {
            'text': '你好',
            'duration': 0.064,
            'n_speakers': 1,
            'segments': [
              {'start': 0, 'end': 0.064, 'speaker': 'S1', 'text': '你好'},
            ],
          }
        : {
            'model': 'glm-5.3-flash',
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'role': 'assistant',
                  'content': jsonEncode({
                    'model_version': 'glm-5.3-flash',
                    'overview': '只记录确定事项',
                    'decisions': [
                      {
                        'text': '只记录确定事项',
                        'segment_ids': [9007199254740993],
                      },
                    ],
                    'actions': <Object?>[],
                  }),
                },
              },
            ],
          };
    return ResponseBody.fromString(jsonEncode(result), status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Doubao enabled workflow', () {
    late Directory temporary;
    late _Keys keys;
    late TalkRecordAiCheckpointStore store;
    late TalkRecordAiCredentials credentials;
    late _Backend backend;
    late _Provider provider;
    var epoch = 1;
    TalkRecordAiCoordinator coordinator() => TalkRecordAiCoordinator(
      asrProvider: TalkRecordAiProvider.doubao,
      recordId: '1',
      mode: backend.mode,
      credentials: credentials,
      checkpoints: store,
      gateway: backend,
      guard: () {},
      adapterFactory: () => provider,
      audio: (chunk) async => TalkRecordAiAudioChunk.fromAdts(
        _audioBytes,
        expectedSha256: sha256.convert(_audioBytes).toString(),
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
      keys = _Keys();
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
        store: _Secrets(),
      );
      await credentials.save(
        TalkRecordAiProvider.minimax,
        'synthetic-api-key-not-real',
      );
      await credentials.save(
        TalkRecordAiProvider.zhipu,
        'synthetic-api-key-not-real',
      );
      backend = _Backend(store);
      provider = _Provider(backend, store);
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
      final other = TalkRecordAiCheckpointStore(
        temporary,
        keys,
        'other-account',
      );
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
    test(
      'historical MiniMax configuration is not silently migrated to Doubao',
      () async {
        backend.mode =
            'transcribe'; // Backend advertises the historical MiniMax contract.
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(
            isA<TalkRecordAiWorkflowException>().having(
              (e) => e.code,
              'code',
              'processing_unavailable',
            ),
          ),
        );
        expect(provider.calls, 0);
        expect(backend.requests, isEmpty);
        expect(await store.file.exists(), false);
      },
    );
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
    test('locally durable result is resubmitted after restart without model replay', () async {
      backend.failAction = 'result';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsStateError,
      );
      expect(provider.calls, 1);
      expect((await store.load())!['parts']['0']['result'], isNotNull);
      backend.failAction = null;
      await coordinator().execute(consentConfirmed: true);
      expect(provider.calls, 1);
      expect(backend.events.where((event) => event == 'provider:0').length, 1);
    });
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
    test(
      'audio plan rejects oversized or discontinuous independent sources',
      () {
        for (final mutation in [
          {'duration_ms': 500001},
          {'byte_size': 50000001},
          {'offset_ms': 7},
        ]) {
          final snapshot = _copy(backend.source);
          (snapshot['parts'] as List)[0].addAll(mutation);
          expect(
            () => talkRecordAiPlan('transcribe', snapshot),
            throwsFormatException,
          );
        }
      },
    );
    test('memory segment decrypt verifies integrity without producing plaintext file', () async {
      final plain = File('${temporary.path}/input.aac');
      await plain.writeAsBytes(_audioBytes);
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
        _audioBytes,
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
  }, skip: !TalkRecordAiProvider.doubaoEnabled);
}
