part of 'talk_record_ai_coordinator.dart';

/// One user invocation performs at most one provider query. Checkpoint operations
/// bind their original ETag/body/key before network I/O; source grants stay only
/// in the current stack. Any ambiguous submit stops; it is never replayed.
extension _TalkRecordDoubaoWorkflow on TalkRecordAiCoordinator {
  Map<String, dynamic> get _task =>
      Map<String, dynamic>.from(_checkpoint['provider_task'] as Map);
  String get _taskId => '${_task['id']}';

  Future<void> _executeDoubao() async {
    if ((_checkpoint['request_body'] as Map)['provider'] != 'doubao') {
      throw const TalkRecordAiWorkflowException(
        'legacy_checkpoint_requires_review',
      );
    }
    await _live();
    if (_checkpoint['provider_task'] == null) {
      if (!_doubaoPreparationReady) await _claim();
      await _providerCommand(
        'provider-create',
        const {},
        slot: 'provider-create',
      );
    } else if (!_providerTaskRead) {
      await _refreshProviderTask();
    }
    if (_task['state'] == 'published') {
      _checkpoint['phase'] = 'complete';
      await _save();
      return;
    }
    if ((_task['allowed_actions'] as List).isEmpty) {
      throw const TalkRecordAiWorkflowException('provider_task_cancelled');
    }
    if (_task['provider_task_id'] case final String id) {
      final saved = _checkpoint['provider_task_id'];
      if (saved != null && saved != id) {
        throw const FormatException('Provider ID changed');
      }
      _checkpoint['provider_task_id'] = id;
      await _save();
    }
    if (_checkpoint['provider_task_id'] == null) {
      if (_checkpoint['run_token'] is! String) {
        throw const TalkRecordAiWorkflowException(
          'provider_preparation_required',
        );
      }
      if (!(_task['allowed_actions'] as List).contains('submit_intent')) {
        throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
      }
      await _submitProviderTask();
    }
    await _reportSubmission();
    await _queryProviderTask();
  }

  Future<bool> _reconcilePublishedProviderTask() async {
    _checkSavedScope();
    final record = await gateway.context(recordId, _check);
    _check();
    final pins = _checkpoint['pins'] as Map;
    if ('${record['id']}' != recordId ||
        record['acl_revision'] is! int ||
        record['content_revision'] is! int ||
        (record['content_revision'] as int) <
            (_run['input_content_revision'] as int) ||
        [
          'scope',
          'organization_id',
          'workspace_id',
          'owner_user_id',
        ].any((key) => record[key] != pins[key])) {
      throw const TalkRecordAiWorkflowException('permission_or_input_changed');
    }
    final response = await gateway.request(
      recordId: recordId,
      jobId: '${_checkpoint['job_id']}',
      taskId: _taskId,
      action: 'provider-get',
      idempotencyKey: '',
      guard: _check,
    );
    _check();
    _acceptProviderTask(
      response['task'],
    ); // Original job/source/input identity.
    _providerTaskRead = true;
    if (_task['state'] != 'published') return false;
    _checkpoint.remove('blocked');
    _checkpoint['phase'] = 'complete';
    await _save();
    return true;
  }

  void _checkSavedScope() {
    final scope = _checkpoint['credential_scope'];
    if (scope is! Map ||
        scope['origin'] != credentials.scope.deploymentOrigin ||
        scope['account_id'] != credentials.scope.accountId ||
        (_checkpoint['request_body'] as Map?)?['provider'] != 'doubao') {
      throw const TalkRecordAiWorkflowException('account_changed');
    }
    _check();
  }

  Future<void> _rebindDoubaoSession() async {
    _checkSavedScope();
    await _live();
    if (_checkpoint['provider_task'] == null) {
      throw const TalkRecordAiWorkflowException('account_changed');
    }
    if (!_providerTaskRead) await _refreshProviderTask();
    if (_task['state'] == 'published') {
      _checkpoint['phase'] = 'complete';
      await _save();
      return;
    }
    if ((_task['allowed_actions'] as List).isEmpty) {
      throw const TalkRecordAiWorkflowException('provider_task_cancelled');
    }
    final id = _checkpoint['provider_task_id'] ?? _task['provider_task_id'];
    if (id is! String || id.isEmpty) {
      throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
    }
    _checkpoint['provider_task_id'] = id;
    await _reportSubmission();
    await _providerCommand('provider-query-execution', {
      'processing_consent':
          (_checkpoint['request_body'] as Map)['processing_consent'],
    }, slot: 'session-rebind-${credentials.authSessionEpoch}');
    _providerLease();
    _checkpoint['epoch'] = credentials.authSessionEpoch;
    _checkpoint['doubao_rebound_run_ready'] = true;
    await _save();
  }

  void _providerLease() {
    _check();
    if (_run['state'] != 'active' ||
        _run['lease_expires_at_unix'] is! int ||
        (_run['lease_expires_at_unix'] as int) <=
            now().millisecondsSinceEpoch ~/ 1000) {
      throw const TalkRecordAiWorkflowException('lease_expired');
    }
  }

  Future<void> _refreshProviderTask() async {
    await _live();
    final response = await gateway.request(
      recordId: recordId,
      jobId: '${_checkpoint['job_id']}',
      taskId: _taskId,
      action: 'provider-get',
      idempotencyKey: '',
      guard: _check,
    );
    _check();
    _acceptProviderTask(response['task']);
    await _save();
  }

  void _acceptProviderTask(Object? raw) {
    if (raw is! Map) throw const FormatException('Provider task');
    final task = Map<String, dynamic>.from(raw);
    final old = _checkpoint['provider_task'] as Map?;
    final assembly = task['assembly'];
    if (!_providerEntity(task['id']) ||
        '${task['source_run_id']}' !=
            '${_checkpoint['source_run_id'] ?? _runId}' ||
        '${task['job_id']}' != '${_checkpoint['job_id']}' ||
        task['provider'] != 'doubao' ||
        task['model'] != 'volc.seedasr.auc' ||
        task['resource_id'] != 'volc.seedasr.auc' ||
        task['model_name'] != 'bigmodel' ||
        task['seq'] != 0 ||
        task['etag'] is! String ||
        task['allowed_actions'] is! List ||
        !(task['allowed_actions'] as List).every((a) => a is String) ||
        task['input_manifest_hash'] != _run['input_manifest_hash'] ||
        task['input_content_revision'] != _run['input_content_revision'] ||
        task['input_transcript_version'] != _run['input_transcript_version'] ||
        (old != null && '${old['id']}' != '${task['id']}') ||
        assembly is! Map ||
        assembly['mime_type'] != 'audio/aac') {
      throw const FormatException('Provider task identity');
    }
    _sourceFor(task); // Bounded, correctly typed assembly pins.
    if (task['profile_hash'] != _doubaoProfileHash ||
        task['request_profile'] is! Map ||
        task['profile_hash'] != talkRecordAiHash(task['request_profile'])) {
      throw const FormatException('Provider request profile');
    }
    if (old != null &&
        talkRecordAiHash(old['assembly']) !=
            talkRecordAiHash(task['assembly'])) {
      throw const FormatException('Provider assembly changed');
    }
    _checkpoint['source_run_id'] ??= '${task['source_run_id']}';
    _checkpoint['provider_task'] = task;
  }

  TalkRecordDoubaoSource _sourceFor(Map<String, dynamic> task) {
    final assembly = task['assembly'] as Map;
    if (!_providerEntity(assembly['id']) ||
        assembly['sha256'] is! String ||
        assembly['byte_size'] is! int ||
        assembly['duration_ms'] is! int) {
      throw const FormatException('Provider assembly');
    }
    return TalkRecordDoubaoSource(
      sha256Hex: assembly['sha256'] as String,
      byteLength: assembly['byte_size'] as int,
      durationMs: assembly['duration_ms'] as int,
    );
  }

  Future<Map<String, dynamic>> _providerCommand(
    String action,
    Map<String, dynamic> body, {
    required String slot,
  }) async {
    await _live();
    final operation = _providerOperation(action, body, slot);
    await _save();
    final result = await gateway.request(
      recordId: recordId,
      jobId: '${_checkpoint['job_id']}',
      runId: operation['run_id'] as String,
      taskId: '${(_checkpoint['provider_task'] as Map?)?['id'] ?? ''}',
      action: action,
      body: body,
      idempotencyKey: operation['key'] as String,
      ifMatch: operation['if_match'] as String,
      token: operation['token'] as String? ?? '',
      guard: _check,
    );
    _check();
    _acceptProviderReply(action, result);
    await _save();
    return result;
  }

  Map<dynamic, dynamic> _providerOperation(
    String action,
    Map<String, dynamic> body,
    String slot,
  ) {
    final operations = _checkpoint['operations'] as Map;
    final saved = operations[slot] as Map?;
    final operation =
        saved ??
        {
          'key': TalkRecordIds.newUuidV4(),
          'body': body,
          'if_match': action == 'provider-create'
              ? '"${_run['etag']}"'
              : _task['etag'],
          'run_id': _runId,
          'token':
              {
                'provider-query-execution',
                'provider-reconcile-receipt',
                'provider-cancel',
                'provider-resubmission',
              }.contains(action)
              ? ''
              : _checkpoint['run_token'],
        };
    if (talkRecordAiHash(operation['body']) != talkRecordAiHash(body)) {
      throw const FormatException('Provider operation changed');
    }
    operations[slot] = operation;
    return operation;
  }

  void _acceptProviderReply(String action, Map<String, dynamic> response) {
    if (response['run'] case final Map<dynamic, dynamic> run) {
      _replaceProviderRun(action, response);
      _acceptRun(Map<String, dynamic>.from(run));
    }
    if (response['run_token'] case final String token) {
      _checkpoint['run_token'] = token;
    }
    if (response['task'] != null) _acceptProviderTask(response['task']);
  }

  void _replaceProviderRun(String action, Map<String, dynamic> response) {
    if (!{
      'provider-query-execution',
      'provider-resubmission',
    }.contains(action)) {
      return;
    }
    if (response['may_submit'] != false ||
        response['run_token'] is! String ||
        (response['run_token'] as String).isEmpty ||
        response.containsKey('source_url')) {
      throw const FormatException('Query/resubmission run authority');
    }
    if (action == 'provider-resubmission') {
      final old = _checkpoint['provider_task'] as Map;
      final history = (_checkpoint['provider_history'] as List?) ?? <Object?>[];
      history.add({
        'task_id': old['id'],
        'provider_task_id': old['provider_task_id'],
      });
      _checkpoint['provider_history'] = history;
      for (final key in [
        'provider_task',
        'source_run_id',
        'doubao_submit_started',
        'provider_task_id',
        'provider_dispatch_hash',
        'submission_failure',
        'query_round',
        'blocked',
      ]) {
        _checkpoint.remove(key);
      }
      _checkpoint['operations'] = <String, dynamic>{};
    }
    _checkpoint.remove('run');
    _checkpoint.remove('run_token');
  }

  Future<void> _submitProviderTask() async {
    if (_checkpoint['doubao_submit_started'] == true) {
      throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
    }
    _checkpoint['doubao_submit_started'] = true;
    await _save(); // Persist the no-replay fence BEFORE granting source access.
    final authorization = await _providerCommand('provider-submit-intent', {
      'profile_hash': _task['profile_hash'],
    }, slot: 'provider-submit-intent');
    if (authorization['may_submit'] != true ||
        authorization['source_url'] is! String) {
      throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
    }
    _sourceGrantLive();
    final url = Uri.parse(authorization['source_url'] as String);
    await _dispatchProviderSource(url);
  }

  Future<void> _dispatchProviderSource(Uri url) async {
    final source = _sourceFor(_task);
    final clientRequestId = _task['client_request_id'];
    if (clientRequestId is! String) {
      throw const FormatException('Submit identity');
    }
    final http = _providerHttp((intent) async {
      await _live();
      _sourceGrantLive();
      _providerLease();
      if (intent.inputHash != source.sha256Hex ||
          intent.inputBytes != source.byteLength) {
        throw const FormatException('Provider dispatch pins');
      }
      _checkpoint['provider_dispatch_hash'] = intent.requestHash;
      await _save();
    }, sourceGrant: true);
    try {
      await http.submitDoubao(
        source: source,
        persistedRequestId: clientRequestId,
        authorizeSource: (pins, id) async {
          await _live();
          _sourceGrantLive();
          _providerLease();
          if (id != clientRequestId || pins.sha256Hex != source.sha256Hex) {
            throw const FormatException('Source grant mismatch');
          }
          return url;
        },
        saveTask: (task) async {
          _checkpoint['provider_task_id'] = task.taskId;
          await _save(); // Encrypted before any accepted receipt is sent.
        },
        cancelToken: cancelToken,
      );
    } on TalkRecordAiProviderException catch (error) {
      await _submissionFailure(error);
    }
  }

  void _sourceGrantLive() {
    final grant = _task['source_authorization'];
    final currentSecond = now().millisecondsSinceEpoch ~/ 1000;
    if (grant is! Map ||
        grant['id'] == null ||
        grant['issued_at'] is! int ||
        grant['expires_at'] is! int ||
        (grant['issued_at'] as int) > currentSecond ||
        (grant['expires_at'] as int) <= currentSecond ||
        (grant['expires_at'] as int) - (grant['issued_at'] as int) > 300 ||
        (grant['expires_at'] as int) <= (grant['issued_at'] as int)) {
      throw const TalkRecordAiWorkflowException('source_authorization_expired');
    }
  }

  TalkRecordAiProviderHttp _providerHttp(
    TalkRecordAiBeforeDispatch gate, {
    bool sourceGrant = false,
  }) => TalkRecordAiProviderHttp(
    credentials: credentials,
    beforeDispatch: gate,
    verifyCurrent: _providerLease,
    beforeFetch: sourceGrant ? _sourceGrantLive : null,
    adapterFactory: adapterFactory,
  );

  Future<Never> _submissionFailure(TalkRecordAiProviderException error) async {
    final state = error.outcome == TalkRecordAiRequestOutcome.rejected
        ? 'rejected'
        : 'unknown';
    _checkpoint['submission_failure'] = {
      'state': state,
      if (error.httpStatus != null) 'http_status': error.httpStatus,
    };
    await _save();
    try {
      await _providerCommand('provider-submission-receipt', {
        'client_request_id': _task['client_request_id'],
        'provider_task_id': null,
        'state': state,
      }, slot: 'provider-submission-failure');
    } on Object {
      _check();
    }
    throw TalkRecordAiWorkflowException(switch (error.code) {
      TalkRecordAiFailureCode.unauthorized => 'key_invalid',
      TalkRecordAiFailureCode.insufficientBalance => 'insufficient_balance',
      _ => 'provider_outcome_unknown',
    });
  }

  Future<void> _reportSubmission() async {
    final id = _checkpoint['provider_task_id'];
    if (id is! String || id.isEmpty) {
      throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
    }
    if (_task['provider_task_id'] == id) return;
    await _providerCommand('provider-reconcile-receipt', {
      'client_request_id': _task['client_request_id'],
      'provider_task_id': id,
      'state': 'accepted',
    }, slot: 'provider-submission-accepted');
  }

  Future<void> _queryProviderTask() async {
    // A returned task ID always resumes QUERY, never submit, even after restart.
    final task = TalkRecordDoubaoTask(
      taskId: _checkpoint['provider_task_id'] as String,
      submitRequestId: _task['client_request_id'] as String,
      source: _sourceFor(_task),
    );
    final round = _checkpoint['query_round'] as int? ?? 0;
    _checkpoint['query_round'] = round + 1;
    await _save(); // A new manual continuation owns a new query-only attempt.
    final rebound =
        _checkpoint.remove('doubao_rebound_run_ready') == true &&
        _run['state'] == 'active' &&
        (_run['lease_expires_at_unix'] as int) >
            now().millisecondsSinceEpoch ~/ 1000;
    await _save();
    if (!rebound) {
      await _providerCommand('provider-query-execution', {
        'processing_consent':
            (_checkpoint['request_body'] as Map)['processing_consent'],
      }, slot: 'query-execution-$round');
    }
    if ((_task['allowed_actions'] as List?)?.contains('complete') == true) {
      await _completeProviderTask();
      return;
    }
    final result = await _safeProviderQuery(task, round);
    await _live();
    final ready = result.state == TalkRecordDoubaoQueryState.ready;
    await _providerCommand('provider-query-receipt', {
      'provider_task_id': task.taskId,
      'state': ready ? 'result_ready' : 'processing',
      if (ready) 'result': result.transcript,
      if (ready) 'result_hash': talkRecordAiHash(result.transcript),
    }, slot: 'query-receipt-$round');
    await _save();
    if (!ready) {
      throw const TalkRecordAiWorkflowException('provider_processing');
    }
    await _completeProviderTask();
  }

  Future<TalkRecordDoubaoQueryResult> _safeProviderQuery(
    TalkRecordDoubaoTask task,
    int round,
  ) async {
    try {
      return await _queryProviderHttp(task, round);
    } on TalkRecordAiProviderException catch (error) {
      await _live();
      await _providerCommand('provider-query-receipt', {
        'provider_task_id': task.taskId,
        'state': 'unknown',
      }, slot: 'query-failure-$round');
      throw TalkRecordAiWorkflowException(switch (error.code) {
        TalkRecordAiFailureCode.unauthorized => 'key_invalid',
        TalkRecordAiFailureCode.insufficientBalance => 'insufficient_balance',
        _ => 'provider_outcome_unknown',
      });
    }
  }

  Future<TalkRecordDoubaoQueryResult> _queryProviderHttp(
    TalkRecordDoubaoTask task,
    int round,
  ) async {
    final http = _providerHttp((_) async {
      throw const TalkRecordAiWorkflowException('query_only');
    });
    return http.queryDoubao(
      persistedTask: task,
      beforeQuery: (_) async {
        final permit = await _providerCommand(
          'provider-query-intent',
          const {},
          slot: 'query-intent-$round',
        );
        if (permit['may_query'] != true ||
            permit['query_task_id'] != task.taskId) {
          throw const TalkRecordAiWorkflowException('provider_outcome_unknown');
        }
        await _live();
        _providerLease();
      },
      cancelToken: cancelToken,
    );
  }

  Future<void> _completeProviderTask() async {
    await _live();
    _providerLease();
    await _providerCommand(
      'provider-complete',
      const {},
      slot: 'provider-complete-$_runId',
    );
    _checkpoint['phase'] = 'complete';
    await _save();
  }
}

extension TalkRecordDoubaoControls on TalkRecordAiCoordinator {
  bool get _canResubmitProviderTask {
    final task = _checkpoint['provider_task'];
    if (mode != 'transcribe' || task is! Map) return false;
    if (!((task['allowed_actions'] as List?)?.contains('resubmission') ??
        false)) {
      return false;
    }
    if (task['state'] == 'rejected') return true;
    final id = _checkpoint['provider_task_id'] ?? task['provider_task_id'];
    return id == null && task['state'] == 'submit_outcome_unknown';
  }

  /// Revoke backend operation/source rights; this cannot stop/refund the vendor.
  Future<void> _cancelProviderTask() async {
    cancel();
    await _providerControl(() async {
      await _providerCommand(
        'provider-cancel',
        const {},
        slot: 'provider-cancel',
      );
      _checkpoint['phase'] = 'cancelled';
      await _save();
    });
  }

  /// Never called by execute/retry. A distinct user action must acknowledge a
  /// possible second charge, while re-confirming current processing consent.
  bool get _canResumeProviderPreparation {
    final task = _checkpoint['provider_task'];
    if (mode != 'transcribe' ||
        task is! Map ||
        task['state'] != 'prepared' ||
        _checkpoint['provider_task_id'] != null ||
        task['provider_task_id'] != null ||
        !((task['allowed_actions'] as List?)?.contains('resume_preparation') ??
            false)) {
      return false;
    }
    final authorization = task['source_authorization'];
    return authorization is Map &&
        authorization['issued_at'] == null &&
        authorization['expires_at'] == null &&
        !task.containsKey('result');
  }

  Future<void> _resubmitProviderTask({
    required bool consentConfirmed,
    required bool duplicateChargeConfirmed,
  }) => _newProviderAttempt(
    consentConfirmed: consentConfirmed,
    duplicateChargeConfirmed: duplicateChargeConfirmed,
  );

  Future<void> _newProviderAttempt({
    required bool consentConfirmed,
    bool duplicateChargeConfirmed = false,
    bool preparation = false,
  }) async {
    if (!consentConfirmed || (!preparation && !duplicateChargeConfirmed)) {
      throw const TalkRecordAiWorkflowException(
        'duplicate_charge_confirmation_required',
      );
    }
    await _providerControl(() async {
      if (!(preparation
          ? _canResumeProviderPreparation
          : _canResubmitProviderTask)) {
        throw const TalkRecordAiWorkflowException('resubmission_not_allowed');
      }
      await _providerCommand(
        'provider-resubmission',
        {
          'processing_consent':
              (_checkpoint['request_body'] as Map)['processing_consent'],
          'ack_possible_duplicate_charge': !preparation,
        },
        slot: preparation
            ? 'provider-resume-preparation'
            : 'provider-resubmission',
      );
      _providerLease();
      _checkpoint['epoch'] = credentials.authSessionEpoch;
      _checkpoint['phase'] = 'request';
      await _save();
    });
  }

  Future<void> _providerControl(Future<void> Function() action) async {
    await TalkRecordAiCoordinator._locks
        .putIfAbsent(checkpoints.file.path, Lock.new)
        .synchronized(() async {
          cancelToken = CancelToken();
          _check();
          _checkpoint = await checkpoints.load() ?? {};
          if (mode != 'transcribe' || _checkpoint['provider_task'] == null) {
            throw const TalkRecordAiWorkflowException(
              'provider_control_unavailable',
            );
          }
          _checkSavedScope();
          await _live();
          await _refreshProviderTask();
          await action();
        });
  }
}

const _doubaoProfileHash =
    'd723bf03c21bf27f6d35a38d6134c2cdf33ebe4a6700b35c8bd98ec27fc4cfab';

bool _providerEntity(Object? value) =>
    RegExp(r'^[1-9][0-9]{0,19}$').hasMatch('$value');
