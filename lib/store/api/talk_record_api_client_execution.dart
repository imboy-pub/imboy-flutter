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
    required String action,
    int seq = 0,
    Map<String, dynamic> body = const {},
    required String idempotencyKey,
    String ifMatch = '',
    String token = '',
    required void Function() guard,
  }) async {
    guard();
    final base = '${API.talkRecords}/$recordId';
    final run = '$base/jobs/$jobId/client-executions/$runId';
    final (method, path) = switch (action) {
      'request' => ('POST', '$base/processing-requests'),
      'claim' => ('POST', '$base/jobs/$jobId/client-executions'),
      'get' => ('GET', run),
      'plan' => ('PUT', '$run/chunk-plan'),
      'dispatch' => ('POST', '$run/parts/$seq/dispatch-intents'),
      'result' => ('PUT', '$run/parts/$seq/result'),
      'heartbeat' || 'complete' || 'settle' => ('POST', '$run/$action'),
      _ => throw const FormatException('Invalid client action'),
    };
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
