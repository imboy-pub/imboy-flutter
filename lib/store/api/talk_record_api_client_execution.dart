part of 'talk_record_api.dart';

extension TalkRecordClientExecutionApi on TalkRecordApi {
  Future<Map<String, dynamic>> clientProcessingContext(
    EntityId recordId,
    void Function() guard,
  ) async {
    guard();
    final response = await get(
      API.talkRecordDetail(recordId),
      options: Options(extra: {httpNoAutoRetry: true, httpRequestGuard: guard}),
    );
    guard();
    return _ensureOk(response);
  }

  Future<Map<String, dynamic>> clientExecutionRequest({
    required EntityId recordId,
    EntityId jobId = '',
    EntityId runId = '',
    EntityId taskId = '',
    required String action,
    int seq = 0,
    Map<String, dynamic> body = const {},
    required String idempotencyKey,
    String ifMatch = '',
    String token = '',
    required void Function() guard,
  }) async {
    guard();
    final (method, path) = _clientExecutionPath(
      recordId,
      jobId,
      runId,
      taskId,
      action,
      seq,
    );
    final options = Options(
      headers: {
        if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
        if (ifMatch.isNotEmpty) 'If-Match': ifMatch,
        if (token.isNotEmpty) 'X-Talk-Run-Token': token,
      },
      extra: {httpNoAutoRetry: true, httpRequestGuard: guard},
    );
    final response = switch (method) {
      'GET' => await get(path, options: options),
      'PUT' => await put(path, data: body, options: options),
      _ => await post(path, data: body, options: options),
    };
    guard();
    return _ensureOk(response);
  }
}

(String, String) _clientExecutionPath(
  EntityId recordId,
  EntityId jobId,
  EntityId runId,
  EntityId taskId,
  String action,
  int seq,
) {
  final base = '${API.talkRecords}/$recordId';
  final run = '$base/jobs/$jobId/client-executions/$runId';
  if (action.startsWith('provider-')) {
    return _providerExecutionPath(base, run, taskId, action);
  }
  return switch (action) {
    'request' => ('POST', '$base/processing-requests'),
    'claim' => ('POST', '$base/jobs/$jobId/client-executions'),
    'latest' => ('GET', '$base/jobs/$jobId/client-executions/latest'),
    'recover-unprepared' => (
      'POST',
      '$base/jobs/$jobId/client-executions/recover-unprepared',
    ),
    'get' => ('GET', run),
    'plan' => ('PUT', '$run/chunk-plan'),
    'dispatch' => ('POST', '$run/parts/$seq/dispatch-intents'),
    'result' => ('PUT', '$run/parts/$seq/result'),
    'heartbeat' || 'complete' || 'settle' => ('POST', '$run/$action'),
    _ => throw const FormatException('Invalid client action'),
  };
}

(String, String) _providerExecutionPath(
  String base,
  String run,
  EntityId taskId,
  String action,
) {
  final provider = '$run/provider-tasks/$taskId';
  return switch (action) {
    'provider-create' => ('POST', '$run/provider-tasks'),
    'provider-get' => ('GET', '$base/provider-tasks/$taskId'),
    'provider-reconcile-receipt' => (
      'POST',
      '$base/provider-tasks/$taskId/reconcile-receipt',
    ),
    'provider-resubmission' => (
      'POST',
      '$base/provider-tasks/$taskId/resubmissions',
    ),
    'provider-cancel' => ('POST', '$base/provider-tasks/$taskId/cancel'),
    'provider-query-execution' => (
      'POST',
      '$base/provider-tasks/$taskId/query-executions',
    ),
    'provider-submit-intent' => ('POST', '$provider/submit-intents'),
    'provider-submission-receipt' => ('POST', '$provider/submission-receipts'),
    'provider-query-intent' => ('POST', '$provider/query-intents'),
    'provider-query-receipt' => ('POST', '$provider/query-receipts'),
    'provider-complete' => ('POST', '$provider/complete'),
    _ => throw const FormatException('Invalid provider task action'),
  };
}
