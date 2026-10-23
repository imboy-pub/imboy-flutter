// T14 text-level zero-tolerance fact gate (deterministic, fake transport
// only, zero real network). Positives prove grounded persons/amounts/dates —
// including 中文数字 <-> 阿拉伯数字 normalization and legal speaker labels —
// pass; negatives prove fabricated surfaces block publication through the
// same failure path as the citation gate (blocked summary, no result send,
// no provider retry). Blind spots are documented in the W11 result.json.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_factcheck.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart'
    show TalkRecordKeyStore;

const _fakeKey = 'synthetic-byok-key-not-real-000000';

Map<String, Object?> seg(
  String text, {
  Object id = 9007199254740993,
  String? label,
}) => {
  'id': id,
  'start_ms': 0,
  'end_ms': 64,
  'text': text,
  'speaker_label': ?label,
};

Map<String, Object?> summary({
  String overview = '记录了讨论要点',
  List<Map<String, Object?>> decisions = const [],
  List<Map<String, Object?>> actions = const [],
}) => {
  'model_version': 'glm-5.3-flash',
  'overview': overview,
  'decisions': decisions,
  'actions': actions,
};

List<String> _codes(List<TalkRecordAiFactViolation> violations) =>
    violations.map((item) => item.code).toSet().toList()..sort();

void main() {
  group('persons', () {
    test('grounded Chinese names pass in overview and item texts', () {
      final input = [seg('李明说预算五万元，王芳表示同意交付')];
      final violations = talkRecordAiSummaryFactViolations(
        summary(
          overview: '李明确认预算，王芳表示同意',
          decisions: [
            {
              'text': '王芳同意交付',
              'segment_ids': [9007199254740993],
            },
          ],
        ),
        input,
      );
      expect(violations, isEmpty);
    });

    test('speaker labels from diarization results are legal', () {
      final input = [seg('开始讨论方案', label: '1:S1')];
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: 'S1表示方案确定'), input),
        isEmpty,
      );
      // A label the input never carried is fabricated, exactly like a name.
      final flagged = talkRecordAiSummaryFactViolations(
        summary(overview: 'S9表示方案确定'),
        input,
      );
      expect(_codes(flagged), ['fabricated_person']);
      expect(flagged.single.fragment, 'S9');
    });

    test('generic referents and roles do not collapse normal text', () {
      expect(
        talkRecordAiSummaryFactViolations(
          summary(overview: '团队确认了方案，双方同意延期，负责人汇报进度'),
          [seg('延期到月底再说')],
        ),
        isEmpty,
      );
    });

    test('grounded Latin name passes', () {
      expect(
        talkRecordAiSummaryFactViolations(
          summary(overview: 'Tom said the budget works'),
          [seg('Tom said the budget works')],
        ),
        isEmpty,
      );
    });

    test('fabricated name is rejected with field and fragment evidence', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(overview: '张伟说今天继续推进'),
        [seg('李明说今天继续推进')],
      );
      expect(_codes(violations), ['fabricated_person']);
      expect(violations.single.field, 'overview');
      expect(violations.single.fragment, '张伟');
      expect(violations.single.evidence, contains('person'));
    });

    test('quoted appelations are checked', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(overview: '他叫「赵六」，后续跟进'),
        [seg('他说继续跟进')],
      );
      expect(_codes(violations), ['fabricated_person']);
      expect(violations.single.fragment, '赵六');
    });

    test('conjunction pairs check both sides', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(overview: '李明和王芳说好了'),
        [seg('李明说好了')],
      );
      expect(_codes(violations), ['fabricated_person']);
      expect(violations.single.fragment, '王芳');
    });
  });

  group('amounts', () {
    test('Chinese and Arabic numerals normalize to the same fact', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '预算5万元'), [
          seg('预算五万元'),
        ]),
        isEmpty,
      );
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '预算五万元'), [
          seg('预算50000元'),
        ]),
        isEmpty,
      );
    });

    test('percent surfaces normalize (百分之/个百分点/成/%)', () {
      for (final pair in [
        ('增长20%', '增长百分之二十'),
        ('提升3个百分点', '提升三个百分点'),
        ('约50%流失', '约五成流失'),
      ]) {
        expect(
          talkRecordAiSummaryFactViolations(summary(overview: pair.$1), [
            seg(pair.$2),
          ]),
          isEmpty,
          reason: pair.$1,
        );
      }
    });

    test('currency symbols and counts stay out of the way', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '花了120元，讨论了三个方案'), [
          seg('花了¥120，讨论了三个方案'),
        ]),
        isEmpty,
      );
    });

    test('amount inside a grounded surface is not a basis (五元 vs 五万元)', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(overview: '预算五元'),
        [seg('预算五万元')],
      );
      expect(_codes(violations), ['fabricated_amount']);
      expect(violations.single.fragment, '五元');
    });

    test('digit corruption is rejected (300 vs 3000)', () {
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(summary(overview: '预算300元'), [
            seg('预算3000元'),
          ]),
        ),
        ['fabricated_amount'],
      );
    });

    test('currency substitution is rejected (美元 vs 元)', () {
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(summary(overview: '预算5万元'), [
            seg('预算5万美元'),
          ]),
        ),
        ['fabricated_amount'],
      );
    });

    test('bare 万 money matches by value and rejects drift', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '预算约五万'), [
          seg('预算约50000元'),
        ]),
        isEmpty,
      );
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(summary(overview: '预算约五万'), [
            seg('预算约四万'),
          ]),
        ),
        ['fabricated_amount'],
      );
      // Counts after 万 stay legal: 五万人 is not money.
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '影响五万人'), [
          seg('影响五万人'),
        ]),
        isEmpty,
      );
    });
  });

  group('dates', () {
    test('absolute dates match across numeral scripts and separators', () {
      for (final pair in [
        ('定在二〇二六年十月二十二日评审', '定在2026年10月22日评审'),
        ('定在2026年10月22日评审', '定在2026-10-22评审'),
      ]) {
        expect(
          talkRecordAiSummaryFactViolations(summary(overview: pair.$1), [
            seg(pair.$2),
          ]),
          isEmpty,
          reason: pair.$1,
        );
      }
    });

    test('weekday terms match including the modifier', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '下周一开会'), [
          seg('下周一开会'),
        ]),
        isEmpty,
      );
    });

    test('relative day terms match by class (明天 == 明日)', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '明日交付'), [
          seg('明天交付'),
        ]),
        isEmpty,
      );
    });

    test('relative terms fold against the record time base', () {
      final base = DateTime(2026, 10, 22);
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '明天交付'), [
          seg('定在2026年10月23日交付'),
        ], timeBase: base),
        isEmpty,
      );
      expect(
        talkRecordAiSummaryFactViolations(
          summary(overview: '定在2026年10月23日交付'),
          [seg('明天交付')],
          timeBase: base,
        ),
        isEmpty,
      );
    });

    test('shifted day is rejected', () {
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(summary(overview: '定在10月25日'), [
            seg('定在10月22日'),
          ]),
        ),
        ['fabricated_date'],
      );
    });

    test('weekday modifier mismatch is rejected (conservative)', () {
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(summary(overview: '本周五截止'), [
            seg('下周五截止'),
          ]),
        ),
        ['fabricated_date'],
      );
    });

    test('without a time base there is no folding', () {
      expect(
        _codes(
          talkRecordAiSummaryFactViolations(
            summary(overview: '定在2026年10月23日'),
            [seg('明天交付')],
          ),
        ),
        ['fabricated_date'],
      );
    });
  });

  group('boundaries', () {
    test('entity-free summary over empty-ish input passes', () {
      expect(
        talkRecordAiSummaryFactViolations(summary(overview: '记录了讨论要点'), [
          seg('嗯'),
        ]),
        isEmpty,
      );
    });

    test('all three fabricated kinds are reported together', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(overview: '张伟说预算四万元，定在2026年10月25日'),
        [seg('李明说预算五万元，定在2026年10月22日')],
      );
      expect(_codes(violations), [
        'fabricated_amount',
        'fabricated_date',
        'fabricated_person',
      ]);
      expect(violations.every((item) => item.field == 'overview'), isTrue);
    });

    test('item text paths are reported precisely', () {
      final violations = talkRecordAiSummaryFactViolations(
        summary(
          decisions: [
            {
              'text': '张伟负责跟进',
              'segment_ids': [9007199254740993],
            },
          ],
        ),
        [seg('李明负责跟进')],
      );
      expect(_codes(violations), ['fabricated_person']);
      expect(violations.single.field, 'decisions[0].text');
    });
  });

  group('wire gate integration', () {
    final segments = [seg('李明说预算五万元，定在2026年10月22日评审，王芳表示同意')];

    test('grounded summary passes the wire gate untouched', () {
      final wire = talkRecordAiSummary({
        'model_version': 'glm-5.3-flash',
        'overview': '李明确认预算五万元',
        'decisions': [
          {
            'text': '评审定在2026年10月22日',
            'segment_ids': [9007199254740993],
          },
        ],
        'actions': <Object?>[],
      }, segments);
      expect(wire['overview'], '李明确认预算五万元');
    });

    test('fabricated person throws the typed violation exception', () {
      expect(
        () => talkRecordAiSummary({
          'model_version': 'glm-5.3-flash',
          'overview': '张伟说预算五万元',
          'decisions': <Object?>[],
          'actions': <Object?>[],
        }, segments),
        throwsA(
          isA<TalkRecordAiFactViolationException>()
              .having(
                (error) => error.violations.map((item) => item.code).toList(),
                'codes',
                ['fabricated_person'],
              )
              .having(
                (error) => '$error',
                'toString',
                'TalkRecordAiFactViolationException(fabricated_person)',
              ),
        ),
      );
    });

    test('citation gate still rejects unknown references first', () {
      expect(
        () => talkRecordAiSummary({
          'model_version': 'glm-5.3-flash',
          'overview': '张伟说预算五万元',
          'decisions': [
            {
              'text': '只记录确定事项',
              'segment_ids': [99],
            },
          ],
          'actions': <Object?>[],
        }, segments),
        throwsFormatException,
      );
    });
  });

  group('coordinator end-to-end', () {
    late Directory temporary;
    late TalkRecordAiCheckpointStore checkpoint;
    late TalkRecordAiCredentials credentials;
    late _FakeBackend backend;
    late _FakeProvider provider;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final scope = TalkRecordAiCredentialScope(
        deploymentOrigin: 'https://synthetic.invalid',
        accountId: '2',
      );
      credentials = TalkRecordAiCredentials(
        scope: scope,
        currentScope: () => scope,
        authSessionEpoch: 1,
        currentAuthSessionEpoch: () => 1,
        store: _Store(),
      );
      await credentials.save(TalkRecordAiProvider.zhipu, _fakeKey);
      temporary = await Directory.systemTemp.createTemp('talk-fact-');
      checkpoint = TalkRecordAiCheckpointStore(
        temporary,
        _Keys(),
        'synthetic-fact-gate/summarize',
      );
      backend = _FakeBackend();
      provider = _FakeProvider();
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await temporary.delete(recursive: true);
    });

    TalkRecordAiCoordinator coordinator() => TalkRecordAiCoordinator(
      recordId: '1',
      mode: 'summarize',
      credentials: credentials,
      checkpoints: checkpoint,
      gateway: backend,
      guard: () {},
      adapterFactory: () => provider,
      audio: (chunk) async => throw StateError('summarize needs no audio'),
    );

    test('grounded summary publishes and completes', () async {
      provider.handle = (_) async => _glm({
        'model_version': 'glm-5.3-flash',
        'overview': '李明确认预算五万元，评审定在2026年10月22日',
        'decisions': [
          {
            'text': '王芳表示同意评审安排',
            'segment_ids': [9007199254740993],
          },
        ],
        'actions': <Object?>[],
      });
      await coordinator().execute(consentConfirmed: true);
      expect((await checkpoint.load())!['phase'], 'complete');
      expect(provider.calls, 1);
      expect(
        backend.requests.any((request) => request['action'] == 'result'),
        isTrue,
      );
    });

    test(
      'fabricated person blocks publication without retry or key leak',
      () async {
        provider.handle = (_) async => _glm({
          'model_version': 'glm-5.3-flash',
          'overview': '张伟说预算五万元',
          'decisions': <Object?>[],
          'actions': <Object?>[],
        });
        late Object failure;
        try {
          await coordinator().execute(consentConfirmed: true);
          fail('must reject');
        } on Object catch (error) {
          failure = error;
        }
        // Same blocking semantics as the citation gate: persisted blocked
        // state, zero result sends, single provider call, no key material.
        expect(failure, isA<TalkRecordAiWorkflowException>());
        expect('$failure', isNot(contains(_fakeKey)));
        expect(
          backend.requests.any((request) => request['action'] == 'result'),
          isFalse,
        );
        expect(
          (await checkpoint.load())!['blocked'],
          'provider_outcome_unknown',
        );
        expect(provider.calls, 1);
      },
    );
  });
}

ResponseBody _body(Object? payload, int status) =>
    ResponseBody.fromString(jsonEncode(payload), status);

ResponseBody _glm(Map<String, Object?> content) => _body({
  'model': 'glm-5.3-flash',
  'choices': [
    {
      'finish_reason': 'stop',
      'message': {'role': 'assistant', 'content': jsonEncode(content)},
    },
  ],
}, 200);

class _Store implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Keys implements TalkRecordKeyStore {
  final values = <String, Uint8List>{};
  @override
  Future<Uint8List?> readRecordKey(String id) async => values[id];
  @override
  Future<void> writeRecordKey(String id, Uint8List key) async =>
      values[id] = Uint8List.fromList(key);
  @override
  Future<void> deleteRecordKey(String id) async => values.remove(id);
}

class _FakeProvider implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions)? handle;
  RequestOptions? last;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    last = options;
    if (requestStream != null) await requestStream.drain<void>();
    return handle!(options);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _FakeBackend implements TalkRecordAiExecutionGateway {
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? run;
  final segments = <Map<String, dynamic>>[
    {
      'id': 9007199254740993,
      'start_ms': 0,
      'end_ms': 64,
      'text': '李明说预算五万元，定在2026年10月22日评审，王芳表示同意',
    },
  ];

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
      'content_revision': 1,
      'acl_revision': 1,
      'media_status': 'available',
      'client_processing': {
        'available': true,
        'execution_mode': 'client_byok',
        'policy_version': 'v1',
        'config_version': 'a' * 64,
        'providers': {
          'transcribe': {'provider': 'minimax', 'model': 'asr-1.0'},
          'summarize': {'provider': 'zhipu', 'model': 'glm-5.3-flash'},
        },
      },
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
    requests.add({'action': action, 'seq': seq, 'body': _copy(body)});
    if (action == 'request') {
      return {'job_id': 3, 'record_id': 1, 'revision': 4};
    }
    if (action == 'claim') {
      run = {
        'id': 4,
        'record_id': 1,
        'job_id': 3,
        'attempt': 1,
        'provider': 'zhipu',
        'model': 'glm-5.3-flash',
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
      return _copy({
        ...run!,
        'run_token': 'synthetic-run-token',
        'input_snapshot': {'segments': segments},
      });
    }
    final current = run!;
    if (action == 'plan') {
      current['chunk_plan_hash'] = talkRecordAiHash(body);
      current['parts'] = (body['chunks'] as List)
          .map(
            (chunk) => {
              'seq': chunk['seq'],
              'provider_state': 'not_dispatched',
              'result_hash': null,
              'dispatch_intent_id': null,
            },
          )
          .toList();
    } else if (action == 'dispatch') {
      ((current['parts'] as List)[seq] as Map)['provider_state'] =
          'dispatching';
      ((current['parts'] as List)[seq] as Map)['dispatch_intent_id'] =
          seq + 100;
    } else if (action == 'result') {
      ((current['parts'] as List)[seq] as Map)['provider_state'] = 'confirmed';
      ((current['parts'] as List)[seq] as Map)['result_hash'] =
          body['result_hash'];
    } else if (action == 'complete') {
      current['state'] = 'complete';
    } else if (action == 'settle') {
      current['state'] = body['state'];
    }
    current['revision'] = (current['revision'] as int) + 1;
    current['etag'] = 'client-run:4:${current['revision']}';
    return _copy({
      ...current,
      if (action == 'dispatch') ...{
        'may_dispatch': true,
        'dispatch_intent_id': seq + 100,
      },
    });
  }
}
