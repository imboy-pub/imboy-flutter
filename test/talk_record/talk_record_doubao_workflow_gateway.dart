part of 'talk_record_doubao_workflow_test.dart';

class _Gateway implements TalkRecordAiExecutionGateway {
  _Gateway(this.store, this.profile);
  final TalkRecordAiCheckpointStore store;
  final Map<String, dynamic> profile;
  final actions = <String>[];
  late Map<String, dynamic> task;
  String? loseAfter;
  bool denied = false;
  bool claimed = false, prepared = false, expired = false, otherDevice = false;
  final recoveryKeys = <String>[];
  int contextRevision = 1;
  int? currentTranscript;
  bool preparationExpired = false;
  int sourceWindowSeconds = 300;
  DateTime Function() clock = DateTime.now;
  int runNumber = 4;
  Map<String, dynamic> get run => {
    'id': runNumber,
    'execution_purpose': 'submit',
    'provider_task_id': null,
    'record_id': 1,
    'job_id': 3,
    'provider': 'doubao',
    'model': 'volc.seedasr.auc',
    'policy_version': 'v1',
    'config_version': 'a' * 64,
    'input_content_revision': 1,
    'input_transcript_version': null,
    'input_manifest_hash': 'b' * 64,
    'state': 'active',
    'etag': 'client-run:$runNumber:1',
    'parts': <Object?>[],
    'lease_expires_at_unix':
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
  };
  Map<String, dynamic> initialTask() => {
    'id': 50,
    'job_id': 3,
    'source_run_id': runNumber,
    'attempt': 1,
    'seq': 0,
    'client_request_id': '550e8400-e29b-41d4-a716-446655440000',
    'provider_task_id': null,
    'provider': 'doubao',
    'model': 'volc.seedasr.auc',
    'resource_id': 'volc.seedasr.auc',
    'model_name': 'bigmodel',
    'request_profile': profile,
    'profile_hash': talkRecordAiHash(profile),
    'input_manifest_hash': 'b' * 64,
    'input_content_revision': 1,
    'input_transcript_version': null,
    'assembly': {
      'id': 9,
      'sha256': 'c' * 64,
      'byte_size': 8000,
      'duration_ms': 1000,
      'mime_type': 'audio/aac',
    },
    'source_authorization': {'id': 7, 'issued_at': null, 'expires_at': null},
    'state': 'prepared',
    'revision': 1,
    'etag': 'provider-task:50:1',
    'allowed_actions': ['submit_intent', 'resume_preparation', 'cancel'],
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
      'content_revision': contextRevision,
      'current_transcript_id': currentTranscript,
      'acl_revision': 1,
      'media_status': 'available',
      'client_processing': {
        'available': !denied,
        'execution_mode': 'client_byok',
        'policy_version': 'v1',
        'config_version': 'a' * 64,
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
    if (!{'provider-get', 'get', 'latest'}.contains(action)) {
      final disk = (await store.load())!;
      expect(
        (disk['operations'] as Map).values.any(
          (op) =>
              op['key'] == idempotencyKey &&
              talkRecordAiHash(op['body']) == talkRecordAiHash(body),
        ),
        true,
      );
      expect(ifMatch, action == 'claim' ? isEmpty : isNotEmpty);
      if (action == 'recover-unprepared') {
        expect(token, isEmpty);
        recoveryKeys.add(idempotencyKey);
      }
    }
    final result = _respond(action, body);
    if (loseAfter == action) {
      loseAfter = null;
      throw StateError('lost response');
    }
    return _copy(result);
  }

  Map<String, dynamic> _respond(String action, Map<String, dynamic> body) {
    switch (action) {
      case 'request':
        return {'job_id': 3};
      case 'claim':
        claimed = true;
        return {
          ...run,
          'run_token': 'synthetic-token',
          'input_snapshot': <String, dynamic>{},
        };
      case 'latest':
        return {
          'run': claimed
              ? {...run, if (expired) 'lease_expires_at_unix': 1}
              : null,
          'task': prepared ? task : null,
          'allowed_actions': otherDevice
              ? <String>[]
              : claimed
              ? ['recover_unprepared']
              : ['claim'],
          'recovery_status': otherDevice
              ? 'device_busy'
              : claimed
              ? 'ready'
              : 'no_execution',
        };
      case 'recover-unprepared':
        if (expired) {
          runNumber++;
          expired = false;
        }
        return {
          'run': run,
          'run_token': 'synthetic-recovered-token',
          'task': null,
          'may_submit': false,
        };
      case 'provider-get':
        return {'task': task};
      case 'provider-create':
        prepared = true;
        task = initialTask();
        if (preparationExpired) {
          task['allowed_actions'] = ['resume_preparation', 'cancel'];
          task['source_authorization'] = {
            'id': 7,
            'issued_at': null,
            'expires_at': null,
          };
        }
        break;
      case 'provider-submit-intent':
        task['state'] = 'submit_outcome_unknown';
        task['allowed_actions'] = [
          'reconcile_receipt',
          'resubmission',
          'cancel',
        ];
        final now = clock().millisecondsSinceEpoch ~/ 1000;
        task['source_authorization'] = {
          'id': 7,
          'issued_at': now,
          'expires_at': now + sourceWindowSeconds,
        };
        return {
          'task': task,
          'run': run,
          'may_submit': true,
          'source_url': 'https://synthetic.invalid/api/v1/talk-records/client-audio-source?ticket=synthetic-ticket',
        };
      case 'provider-reconcile-receipt':
        task['provider_task_id'] = body['provider_task_id'];
        task['state'] = 'accepted';
        break;
      case 'provider-submission-receipt':
        task['state'] = body['state'] == 'unknown'
            ? 'submit_outcome_unknown'
            : body['state'];
        expect(body.containsKey('status_code'), false);
        expect(body.containsKey('http_status'), false);
        break;
      case 'provider-query-execution':
        runNumber++;
        return {
          'task': task,
          'run': run,
          'run_token': 'synthetic-query-token',
          'may_submit': false,
        };
      case 'provider-query-intent':
        return {
          'task': task,
          'run': run,
          'may_query': true,
          'query_task_id': task['provider_task_id'],
        };
      case 'provider-query-receipt':
        task['state'] = body['state'] == 'unknown'
            ? 'submit_outcome_unknown'
            : body['state'];
        if (body['state'] == 'result_ready') {
          task['allowed_actions'] = ['complete'];
        }
        break;
      case 'provider-complete':
        contextRevision++;
        currentTranscript = 999;
        task['state'] = 'published';
        task['allowed_actions'] = <Object?>[];
        break;
      case 'provider-resubmission':
        expect(body['ack_possible_duplicate_charge'], !preparationExpired);
        preparationExpired = false;
        runNumber++;
        task = initialTask();
        task['id'] = 51;
        task['source_run_id'] = runNumber;
        task['client_request_id'] = '550e8400-e29b-41d4-a716-446655440001';
        task['etag'] = 'provider-task:51:1';
        return {
          'task': task,
          'run': run,
          'run_token': 'new-submit-token',
          'may_submit': false,
        };
      case 'provider-cancel':
        task['allowed_actions'] = <Object?>[];
        break;
      default:
        throw StateError('unsupported synthetic action $action');
    }
    return {'task': task, 'run': run, 'may_submit': false};
  }
}
