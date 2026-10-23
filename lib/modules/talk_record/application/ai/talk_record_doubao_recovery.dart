part of 'talk_record_ai_coordinator.dart';

/// Discovery grants no supplier access. Recovery is only the server-confirmed,
/// never-dispatched case, using a new operation rather than replaying claim.
extension _TalkRecordDoubaoRecovery on TalkRecordAiCoordinator {
  Future<void> _discoverDoubaoExecution() async {
    _checkSavedScope();
    await _discoveryContext();
    final latest = await gateway.request(
      recordId: recordId,
      jobId: '${_checkpoint['job_id']}',
      action: 'latest',
      idempotencyKey: '',
      guard: _check,
    );
    _check();
    if (latest.containsKey('run_token') ||
        latest.containsKey('source_url') ||
        latest['allowed_actions'] is! List) {
      throw const FormatException('Execution discovery authority');
    }
    final run = latest['run'];
    if (run is! Map) {
      await _claimDiscoveredEmpty(latest);
      return;
    }
    _replaceDiscoveredRun(Map<String, dynamic>.from(run));
    if (latest['task'] != null) {
      _acceptDiscoveredTask(latest['task']);
      if (_task['state'] == 'published') {
        _checkpoint.remove('blocked');
        _checkpoint['phase'] = 'complete';
      } else {
        await _live();
      }
      _providerTaskRead = true;
      await _save();
      return;
    }
    if (!(latest['allowed_actions'] as List).contains('recover_unprepared')) {
      throw TalkRecordAiWorkflowException(
        latest['recovery_status'] == 'device_busy'
            ? 'execution_device_busy'
            : 'execution_reconciliation_required',
      );
    }
    await _recoverUnpreparedDoubao();
  }

  Future<void> _claimDiscoveredEmpty(Map<String, dynamic> latest) async {
    if (latest['run'] != null ||
        latest['task'] != null ||
        _checkpoint['run'] != null ||
        latest['recovery_status'] != 'no_execution' ||
        !(latest['allowed_actions'] as List).contains('claim')) {
      throw const TalkRecordAiWorkflowException(
        'execution_reconciliation_required',
      );
    }
    await _live();
    await _command('claim', {
      'processing_consent':
          (_checkpoint['request_body'] as Map)['processing_consent'],
    }, slot: 'claim-after-empty-discovery');
    _providerLease();
    _checkpoint['epoch'] = credentials.authSessionEpoch;
    _doubaoPreparationReady = true;
    await _save();
  }

  void _acceptDiscoveredTask(Object? raw) {
    if (raw is! Map ||
        !_providerEntity(raw['source_run_id']) ||
        !_providerEntity(raw['id'])) {
      throw const FormatException('Discovered task origin');
    }
    final purpose = _run['execution_purpose'];
    final bound = purpose == 'submit'
        ? '${raw['source_run_id']}' == _runId
        : purpose == 'query_only' &&
              '${_run['provider_task_id']}' == '${raw['id']}';
    if (!bound) throw const FormatException('Discovered run task binding');
    final origin = _checkpoint['source_run_id'];
    if (origin != null && origin != '${raw['source_run_id']}') {
      throw const FormatException('Discovered task origin changed');
    }
    _checkpoint['source_run_id'] = '${raw['source_run_id']}';
    _acceptProviderTask(raw);
  }

  Future<void> _discoveryContext() async {
    final record = await gateway.context(recordId, _check);
    _check();
    final pins = _checkpoint['pins'] as Map;
    if ('${record['id']}' != recordId ||
        record['acl_revision'] is! int ||
        record['content_revision'] is! int ||
        (record['content_revision'] as int) <
            (pins['content_revision'] as int) ||
        [
          'scope',
          'organization_id',
          'workspace_id',
          'owner_user_id',
        ].any((key) => record[key] != pins[key])) {
      throw const TalkRecordAiWorkflowException('permission_or_input_changed');
    }
  }

  void _replaceDiscoveredRun(Map<String, dynamic> run) {
    final previous = _checkpoint['run'] as Map?;
    if (run['input_manifest_hash'] is! String ||
        (previous != null &&
            previous['input_manifest_hash'] != run['input_manifest_hash']) ||
        run['input_transcript_version'] !=
            (_checkpoint['pins'] as Map)['current_transcript_id']) {
      throw const FormatException('Execution discovery input');
    }
    _checkpoint.remove('run');
    _checkpoint.remove('run_token');
    _acceptRun(run);
  }

  Future<void> _recoverUnpreparedDoubao() async {
    await _live();
    final body = <String, dynamic>{
      'processing_consent':
          (_checkpoint['request_body'] as Map)['processing_consent'],
    };
    final operations = _checkpoint['operations'] as Map;
    final slot = 'recover-unprepared:$_runId:${_run['etag']}';
    final operation =
        operations[slot] as Map? ??
        {
          'key': TalkRecordIds.newUuidV4(),
          'body': body,
          'if_match': '"${_run['etag']}"',
        };
    if (talkRecordAiHash(operation['body']) != talkRecordAiHash(body)) {
      throw const FormatException('Recovery consent changed');
    }
    operations[slot] = operation;
    await _save();
    final response = await gateway.request(
      recordId: recordId,
      jobId: '${_checkpoint['job_id']}',
      action: 'recover-unprepared',
      body: body,
      idempotencyKey: operation['key'] as String,
      ifMatch: operation['if_match'] as String,
      guard: _check,
    );
    _check();
    _acceptUnpreparedRecovery(response);
    _providerLease();
    _checkpoint['epoch'] = credentials.authSessionEpoch;
    _doubaoPreparationReady = true;
    await _save();
  }

  void _acceptUnpreparedRecovery(Map<String, dynamic> response) {
    if (response['task'] != null ||
        response['may_submit'] != false ||
        response['run_token'] is! String ||
        (response['run_token'] as String).isEmpty ||
        response.containsKey('source_url') ||
        response['run'] is! Map) {
      throw const FormatException('Unprepared recovery authority');
    }
    _replaceDiscoveredRun(Map<String, dynamic>.from(response['run'] as Map));
    _checkpoint['run_token'] = response['run_token'];
    // A lost preparation request may carry the expired run ETag and token.
    (_checkpoint['operations'] as Map).remove('provider-create');
  }
}
