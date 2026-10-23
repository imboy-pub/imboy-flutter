part of 'talk_record_doubao_wire_view_test.dart';

class _DiscoveryGateway implements TalkRecordAiExecutionGateway {
  _DiscoveryGateway(this.discovery);
  final Map<String, dynamic> discovery;
  final actions = <String>[];
  bool publishedContext = false;
  @override
  Future<Map<String, dynamic>> context(String id, void Function() guard) async {
    guard();
    return {
      'id': 1000,
      'scope': 'personal',
      'owner_user_id': 2,
      'organization_id': null,
      'workspace_id': null,
      'acl_revision': 1,
      'content_revision': publishedContext ? 2 : 1,
      'current_transcript_id': publishedContext ? 999 : null,
      'media_status': 'available',
      'client_processing': {
        'available': true,
        'execution_mode': 'client_byok',
        'policy_version': 'p1',
        'config_version': 'c' * 64,
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
    if (action == 'latest') return discovery;
    // Stop before granting a run or any provider access. These tests assert
    // actual BE discovery projection is accepted and selects the safe action.
    throw StateError('synthetic stop before $action authority');
  }
}

Future<void> _seedDiscovery(
  TalkRecordAiCheckpointStore store,
  TalkRecordAiCredentialScope scope,
  _DiscoveryGateway gateway,
) async {
  final record = await gateway.context('1000', () {});
  final policy = record['client_processing'] as Map;
  await store.save({
    'epoch': 1,
    'credential_scope': {
      'origin': scope.deploymentOrigin,
      'account_id': scope.accountId,
    },
    'record_id': '1000',
    'mode': 'transcribe',
    'phase': 'request',
    'job_id': 1002,
    'operations': <String, dynamic>{},
    'parts': <String, dynamic>{},
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
    'request_body': {
      'provider': 'doubao',
      'processing_consent': {
        'confirmed': true,
        'execution_mode': 'client_byok',
        'provider': 'doubao',
        'model': 'volc.seedasr.auc',
        'policy_version': 'p1',
        'config_version': 'c' * 64,
      },
    },
  });
}

void _registerActualRecoveryWireCases(
  TalkRecordAiCheckpointStore Function() store,
  TalkRecordAiCredentialScope Function() scope,
) {
  for (final name in [
    'no_execution',
    'claim_response_lost',
    'expired_unprepared',
    'prepare_response_lost',
    'latest_query_only',
    'device_busy',
    'published',
    'cancelled',
  ]) {
    test(
      'actual BE R6 discovery $name grants no provider submission',
      () async {
        final raw = await File(
          'test/talk_record/fixtures/doubao_discovery_views_r6.json',
        ).readAsBytes();
        expect(
          sha256.convert(raw).toString(),
          '06275d10a0a7c12a5998f7f79e884c9993d408a4b86dec354aa2575c6aecdd7e',
        );
        final fixture = Map<String, dynamic>.from(
          (jsonDecode(utf8.decode(raw)) as Map)['cases'][name] as Map,
        );
        final gateway = _DiscoveryGateway(fixture);
        await _seedDiscovery(store(), scope(), gateway);
        gateway.publishedContext = name == 'published';
        final coordinator = TalkRecordAiCoordinator(
          asrProvider: TalkRecordAiProvider.doubao,
          recordId: '1000',
          mode: 'transcribe',
          checkpoints: store(),
          gateway: gateway,
          credentials: TalkRecordAiCredentials(
            scope: scope(),
            currentScope: scope,
            authSessionEpoch: 1,
            currentAuthSessionEpoch: () => 1,
          ),
          guard: () {},
          audio: (_) async => throw StateError('no legacy audio'),
          adapterFactory: _NoVendor.new,
        );
        if (name == 'published') {
          await coordinator.execute(consentConfirmed: true);
          expect((await store().load())!['phase'], 'complete');
        } else {
          await expectLater(
            coordinator.execute(consentConfirmed: true),
            throwsA(anything),
          );
        }
        expect(gateway.actions.first, 'latest');
        expect(gateway.actions, isNot(contains('provider-submit-intent')));
        if (name == 'latest_query_only') {
          final saved = (await store().load())!;
          expect(saved['source_run_id'], '1003');
          expect((saved['run'] as Map)['id'], 1010);
          expect((saved['provider_task'] as Map)['id'], 1001);
        }
        if (name == 'device_busy') expect(gateway.actions, ['latest']);
        if (name == 'no_execution') {
          expect(gateway.actions, ['latest', 'claim']);
        }
      },
    );
  }
}
