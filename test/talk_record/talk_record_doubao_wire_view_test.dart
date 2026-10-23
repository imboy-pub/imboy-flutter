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
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

part 'talk_record_doubao_recovery_wire_cases.dart';

class _Keys implements TalkRecordKeyStore {
  final _values = <String, Uint8List>{};
  @override
  Future<Uint8List?> readRecordKey(String id) async => _values[id];
  @override
  Future<void> writeRecordKey(String id, Uint8List key) async {
    _values[id] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteRecordKey(String id) async {
    _values.remove(id);
  }
}

class _NoVendor implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('Unexpected provider call');
  @override
  void close({bool force = false}) {}
}

class _ViewGateway implements TalkRecordAiExecutionGateway {
  _ViewGateway(this.task, this.published);
  Map<String, dynamic> task;
  final Map<String, dynamic> published;
  final actions = <String>[];
  bool publishedContext = false;
  Map<String, dynamic> get run => {
    'id': 1003,
    'record_id': 1,
    'job_id': 1002,
    'provider': 'doubao',
    'model': 'volc.seedasr.auc',
    'policy_version': 'v1',
    'config_version': 'cfg',
    'input_content_revision': 1,
    'input_transcript_version': null,
    'input_manifest_hash': 'a' * 64,
    'state': 'active',
    'etag': 'client-run:1003:1',
    'lease_expires_at_unix':
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
    'parts': <Object?>[],
  };
  @override
  Future<Map<String, dynamic>> context(String id, void Function() guard) async {
    guard();
    return {
      'id': 1,
      'scope': 'personal',
      'owner_user_id': 2,
      'content_revision': publishedContext ? 2 : 1,
      'current_transcript_id': publishedContext ? 999 : null,
      'acl_revision': 1,
      'media_status': 'available',
      'client_processing': {
        'available': true,
        'execution_mode': 'client_byok',
        'policy_version': 'v1',
        'config_version': 'cfg',
        'providers': {
          'transcribe': {'provider': 'doubao', 'model': 'volc.seedasr.auc'},
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
    actions.add(action);
    if (action == 'provider-get') return {'task': task};
    if (action == 'provider-query-execution') {
      // Actual protocol permits reuse of the same exact task's active run.
      return {
        'task': task,
        'run': run,
        'run_token': 'synthetic-query-token',
        'may_submit': false,
      };
    }
    if (action == 'provider-complete') {
      task = published;
      return {
        'task': task,
        'run': {...run, 'state': 'complete'},
      };
    }
    throw StateError('Unexpected wire-view mutation: $action');
  }
}

Future<void> _seed(
  TalkRecordAiCheckpointStore store,
  _ViewGateway gateway,
  TalkRecordAiCredentialScope scope,
) async {
  final record = await gateway.context('1', () {});
  final policy = record['client_processing'];
  await store.save({
    'epoch': 1,
    'credential_scope': {
      'origin': scope.deploymentOrigin,
      'account_id': scope.accountId,
    },
    'record_id': '1',
    'mode': 'transcribe',
    'phase': 'request',
    'job_id': 1002,
    'run': gateway.run,
    'run_token': 'synthetic-original-token',
    'provider_task': gateway.task,
    'source_run_id': '1003',
    'operations': <String, dynamic>{},
    'parts': <String, dynamic>{},
    'request_body': {
      'provider': 'doubao',
      'processing_consent': {
        'confirmed': true,
        'execution_mode': 'client_byok',
        'provider': 'doubao',
        'model': 'volc.seedasr.auc',
        'policy_version': 'v1',
        'config_version': 'cfg',
      },
    },
    'pins': {
      for (final name in [
        'scope',
        'organization_id',
        'workspace_id',
        'content_revision',
        'acl_revision',
        'owner_user_id',
        'current_transcript_id',
      ])
        name: record[name],
      'client_processing': policy,
    },
  });
}

void main() {
  group('Doubao enabled wire workflow', () {
    late Directory temporary;
    late Map<String, dynamic> cases;
    late TalkRecordAiCheckpointStore store;
    late TalkRecordAiCredentialScope scope;
    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      temporary = await Directory.systemTemp.createTemp('doubao-be-view-');
      store = TalkRecordAiCheckpointStore(
        temporary,
        _Keys(),
        'synthetic-scope',
      );
      scope = TalkRecordAiCredentialScope(
        deploymentOrigin: 'https://synthetic.invalid',
        accountId: '2',
      );
      final raw = await File(
        'test/talk_record/fixtures/doubao_provider_task_views_r5.json',
      ).readAsBytes();
      // Exact bytes generated by actual frozen Erlang view/1, not hand-built App projections.
      expect(
        sha256.convert(raw).toString(),
        'ffa6ec27b23d0dd4d683c7368f4d7eb36141730ea86275a4c6d25afe950f0afa',
      );
      cases =
          (jsonDecode(utf8.decode(raw)) as Map)['cases']
              as Map<String, dynamic>;
    });
    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await temporary.delete(recursive: true);
    });
    _registerActualRecoveryWireCases(() => store, () => scope);
    test(
      'actual R5 actions distinguish preparation and known-ID uncertainty',
      () {
        expect(
          (cases['prepared'] as Map)['allowed_actions'],
          contains('resume_preparation'),
        );
        final unknown = cases['query_outcome_unknown'] as Map;
        expect(unknown['provider_task_id'], isNotNull);
        expect(unknown['allowed_actions'], ['query_execution', 'cancel']);
        expect((cases['failed_legacy'] as Map)['allowed_actions'], ['cancel']);
      },
    );
    for (final name in [
      'published',
      'cancelled_fact',
      'submit_outcome_unknown',
      'result_ready',
    ]) {
      test(
        'actual BE view/$name is interpreted without provider submit or guessed states',
        () async {
          final task = Map<String, dynamic>.from(cases[name] as Map);
          expect(
            talkRecordAiHash(task['request_profile']),
            task['profile_hash'],
          );
          final gateway = _ViewGateway(
            task,
            Map<String, dynamic>.from(cases['published'] as Map),
          );
          await _seed(store, gateway, scope);
          if (name == 'published') {
            gateway.publishedContext = true;
            final saved = (await store.load())!;
            saved['epoch'] =
                0; // Cold start does not authorize any new dispatch.
            await store.save(saved);
          }
          final credentials = TalkRecordAiCredentials(
            scope: scope,
            currentScope: () => scope,
            authSessionEpoch: 1,
            currentAuthSessionEpoch: () => 1,
          );
          final coordinator = TalkRecordAiCoordinator(
            asrProvider: TalkRecordAiProvider.doubao,
            recordId: '1',
            mode: 'transcribe',
            credentials: credentials,
            checkpoints: store,
            gateway: gateway,
            guard: () {},
            audio: (_) async => throw StateError('no legacy audio'),
            adapterFactory: _NoVendor.new,
          );
          if (name == 'cancelled_fact' || name == 'submit_outcome_unknown') {
            await expectLater(
              coordinator.execute(consentConfirmed: true),
              throwsA(
                isA<TalkRecordAiWorkflowException>().having(
                  (e) => e.code,
                  'code',
                  name == 'cancelled_fact'
                      ? 'provider_task_cancelled'
                      : 'provider_outcome_unknown',
                ),
              ),
            );
            expect(
              coordinator.canResubmitProviderTask,
              name == 'submit_outcome_unknown',
            );
            expect(gateway.actions, ['provider-get']);
          } else {
            await coordinator.execute(consentConfirmed: true);
            expect((await store.load())!['phase'], 'complete');
            expect(
              gateway.actions,
              name == 'published'
                  ? ['provider-get']
                  : [
                      'provider-get',
                      'provider-query-execution',
                      'provider-complete',
                    ],
            );
          }
        },
      );
    }
  }, skip: !TalkRecordAiProvider.doubaoEnabled);
}
