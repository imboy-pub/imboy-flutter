import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

class AiTestKeys implements TalkRecordKeyStore {
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

class AiTestSecrets implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Map<String, dynamic> aiTestCopy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class AiTestBackend implements TalkRecordAiExecutionGateway {
  AiTestBackend(this.store);
  final TalkRecordAiCheckpointStore store;
  final events = <String>[];
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? run;
  String? failAction;
  bool loseComplete = false;
  bool denyDispatch = false;
  bool loseDispatch = false;
  bool denied = false;
  bool loseClaim = false;
  bool rejectClaim = false;
  bool skipReuse = false;
  int? loseResultSeq;
  final previousRuns = <Map<String, dynamic>>[];
  final claimReceipts = <String, Map<String, dynamic>>{};
  int contentRevision = 1;
  String mode = 'transcribe';
  final source = <String, dynamic>{
    'parts': List.generate(
      2,
      (seq) => {
        'seq': seq,
        'part_id': seq + 10,
        'attachment_id': seq + 20,
        'sha256': sha256.convert(aiTestAudioBytes).toString(),
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
      'body': aiTestCopy(body),
      'if_match': ifMatch,
      'token': token,
      'job_id': jobId,
      'run_id': runId,
      'key': idempotencyKey,
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
      expect(jobId, '3');
      expect(body.keys.toSet(), contains('processing_consent'));
      if (claimReceipts[idempotencyKey]
          case final Map<String, dynamic> receipt) {
        expect(run!['state'], 'active');
        return aiTestCopy(receipt);
      }
      if (rejectClaim) throw StateError('synthetic claim rejected');
      if (run != null) {
        if (run!['state'] == 'provider_outcome_unknown') {
          expect(body.keys.toSet(), {
            'processing_consent',
            'previous_run_id',
            'ack_possible_duplicate_charge',
          });
          expect(body['previous_run_id'], run!['id']);
          expect(body['ack_possible_duplicate_charge'], isTrue);
          expect(ifMatch, '"${run!['etag']}"');
        } else {
          expect(run!['state'], 'expired');
          expect(body.keys.toSet(), {'processing_consent'});
        }
        previousRuns.add(aiTestCopy(run!));
      } else {
        expect(body.keys.toSet(), {'processing_consent'});
        expect(ifMatch, isEmpty);
      }
      final attempt = previousRuns.length + 1;
      final nextId = 3 + attempt;
      run = {
        'id': nextId,
        'record_id': 1,
        'job_id': 3,
        'attempt': attempt,
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
        'etag': 'client-run:$nextId:1',
        'lease_expires_at_unix':
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
        'parts': <Map<String, dynamic>>[],
      };
      final receipt = {
        ...aiTestCopy(run!),
        'run_token': 'synthetic-run-token',
        'input_snapshot': mode == 'transcribe'
            ? source
            : {'segments': segments},
      };
      claimReceipts[idempotencyKey] = aiTestCopy(receipt);
      if (loseClaim) {
        throw StateError('synthetic committed claim response lost');
      }
      return receipt;
    }
    if (action == 'get') return aiTestCopy(run!);
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
      if (!skipReuse) {
        for (final previous in previousRuns.reversed) {
          if (previous['chunk_plan_hash'] != run!['chunk_plan_hash']) continue;
          for (final part in previous['parts'] as List) {
            final next = (run!['parts'] as List)[part['seq'] as int] as Map;
            if (part['provider_state'] == 'confirmed' &&
                next['provider_state'] == 'not_dispatched') {
              next.addAll(Map<String, dynamic>.from(part as Map));
            }
          }
        }
      }
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
    run!['etag'] = 'client-run:${run!['id']}:${run!['revision']}';
    if (action == 'complete' && loseComplete ||
        action == 'dispatch' && loseDispatch ||
        action == 'result' && seq == loseResultSeq) {
      throw StateError('synthetic committed response lost');
    }
    return {
      ...aiTestCopy(run!),
      if (action == 'dispatch') ...{
        'may_dispatch': !denyDispatch,
        'dispatch_intent_id': seq + 100,
      },
    };
  }
}

final aiTestAudioBytes = Uint8List.fromList([
  0xff,
  0xf1,
  0x60,
  0x40,
  1,
  0x1f,
  0xfc,
  0,
]);

class AiTestProvider implements HttpClientAdapter {
  AiTestProvider(this.backend, this.store);
  final AiTestBackend backend;
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
    final seq = backend.requests.last['seq'] as int;
    calls++;
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
