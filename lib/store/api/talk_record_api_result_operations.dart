part of 'talk_record_api.dart';

/// Result operations use the same authenticated client and envelope handling.
extension TalkRecordResultOperations on TalkRecordApi {
  /// Actor and physical eligibility are independently rechecked by the server.
  Future<void> retryPhysicalCleanup(
    EntityId id, {
    required String etag,
    required int generation,
    required String idempotencyKey,
    void Function()? requestGuard,
  }) async {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(id) ||
        !RegExp(r'^"[1-9][0-9]*"$').hasMatch(etag) ||
        generation < 0 ||
        generation > 9223372036854775807 ||
        idempotencyKey.isEmpty ||
        idempotencyKey.length > 128) {
      throw const TalkRecordApiException(422, 'Invalid cleanup retry request');
    }
    final status = _CleanupRetryStatus();
    dio.interceptors.add(status);
    late IMBoyHttpResponse response;
    try {
      requestGuard?.call();
      response = await post(
        '${API.talkRecordDetail(id)}/cleanup/retry',
        data: {'cleanup_generation': generation},
        options: Options(
          headers: {'If-Match': etag, 'Idempotency-Key': idempotencyKey},
          extra: {
            httpNoAutoRetry: true,
            httpRequestGuard: requestGuard,
            _CleanupRetryStatus.tag: status,
          },
        ),
      );
    } finally {
      dio.interceptors.remove(status);
    }
    if (!response.ok && status.code != null && status.code! >= 400) {
      throw TalkRecordApiException(
        status.code!,
        response.msg,
        response.payload,
      );
    }
    final payload = _ensureOk(response);
    final reopened = payload['reopened_resources'];
    if (entityIdOf(payload['job_id']).isEmpty ||
        reopened is! int ||
        reopened <= 0 ||
        payload['cleanup_generation'] != generation + 1 ||
        payload['revision'] is! int ||
        (payload['revision'] as int) <= 0) {
      throw const FormatException('Invalid cleanup retry acceptance');
    }
  }

  Future<Map<String, dynamic>> exportStatePayload(
    EntityId id,
    EntityId exportId,
  ) async {
    final response = await get(API.talkRecordExportState(id, exportId));
    return Map<String, dynamic>.unmodifiable(_ensureOk(response));
  }

  Future<Map<String, dynamic>> transferOwnershipPayload(
    EntityId id, {
    required EntityId targetUserId,
    required bool keepAccess,
    required String ifMatch,
    required String idempotencyKey,
  }) async {
    final response = await post(
      API.talkRecordOwnershipTransfers(id),
      data: {'target_user_id': targetUserId, 'keep_access': keepAccess},
      options: _options(ifMatch: ifMatch, idempotencyKey: idempotencyKey),
    );
    return Map<String, dynamic>.unmodifiable(_ensureOk(response));
  }
}

/// Response status belongs to this request, including Dio's non-2xx path.
/// Generic envelope codes (e.g. 400 inside HTTP409) must not erase retry CAS.
class _CleanupRetryStatus extends Interceptor {
  static const tag = 'talk_record_cleanup_response_status';
  int? code;
  void capture(RequestOptions request, int? status) {
    if (identical(request.extra[tag], this)) code = status;
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    capture(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    capture(error.requestOptions, error.response?.statusCode);
    handler.next(error);
  }
}
