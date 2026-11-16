part of 'attachment_direct_api.dart';

Future<DirectUploadResult> _uploadDirectSource(
  DirectUploadSource source, {
  required String fileName,
  required String mime,
  String scope = 'private',
  String? scopeRef,
  String? clientUploadId,
  String? cipher,
  String purpose = 'attachment',
  String? anchorMsgId,

  /// 非 null 时本地取消该 attempt（AbortSignal 语义）：中断流并抛
  /// [DirectUploadCancelled]，不调 finalize。
  VoidCallback? registerCancelHandler,
  DirectSessionFn? sessionFn,
  CancelToken? cancelToken,
  DirectSourcePutFn? putFn,
  void Function(int sent, int total)? onProgress,
  Future<void> Function(DirectCheckpoint event)? checkpoint,
}) async {
  DirectAttachmentApi._checkCancelled(cancelToken);
  if (mime == 'image/jpg') mime = 'image/jpeg';
  final int size = source.length;
  final String? validationError = AttachmentApi.validateUpload(size, mime);
  if (validationError != null) {
    throw Exception(validationError);
  }

  Future<IMBoyHttpResponse> session(
    String action, {
    Map<String, dynamic>? body,
  }) async {
    DirectAttachmentApi._checkCancelled(cancelToken);
    final String path = '/api/v1/attachment/direct/$action';
    final response = sessionFn != null
        ? await sessionFn(path, body: body)
        : await HttpClient.client.post(
            path,
            data: body,
            cancelToken: cancelToken,
          );
    DirectAttachmentApi._checkCancelled(cancelToken);
    return response;
  }

  // 1. register（RESERVED，无写能力/R08）：同 client_upload_id 同声明幂等。
  String registeredState = '';
  final String objectKey = await DirectAttachmentApi.registerSession(
    fileName: fileName,
    scope: scope,
    scopeRef: scopeRef,
    clientUploadId: clientUploadId,
    cipher: cipher,
    purpose: purpose,
    anchorMsgId: anchorMsgId,
    sessionFn: sessionFn,
    cancelToken: cancelToken,
    onState: (state) => registeredState = state,
  );
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  await checkpoint?.call(
    DirectCheckpoint(
      DirectCheckpointStage.registered,
      objectKey: objectKey,
      clientUploadId: clientUploadId,
    ),
  );

  if (registeredState == DirectAttachmentApi.stateConfirmed ||
      registeredState == 'GRANTED' ||
      registeredState == DirectAttachmentApi.stateFinalizing) {
    return DirectAttachmentApi.resumeSource(
      objectKey: objectKey,
      source: source,
      mime: mime,
      sessionFn: sessionFn,
      cancelToken: cancelToken,
      putFn: putFn,
      onProgress: onProgress,
      checkpoint: checkpoint,
    );
  }

  if (registeredState != 'RESERVED' && registeredState != 'DECLARED') {
    throw StateError('direct session terminal: $registeredState');
  }

  // 2. declare：expected 冻结（同值幂等；异值 expected_conflict）。
  final String sha256Hex = await _sha256OfSource(source, cancelToken);
  final IMBoyHttpResponse decl = await session(
    'declare',
    body: <String, dynamic>{
      'object_key': objectKey,
      'sha256': sha256Hex,
      'size_bytes': size,
      'mime': mime,
    },
  );
  if (!decl.ok) {
    throw Exception('direct declare 失败: code=${decl.code} msg=${decl.msg}');
  }
  await checkpoint?.call(
    DirectCheckpoint(DirectCheckpointStage.declared, objectKey: objectKey),
  );

  // 3..N grant → 流式 PUT → finalize；失败/隔离只能 renew 新 attempt。
  int attemptId = 0;
  for (int round = 1; round <= DirectAttachmentApi.maxAttempts; round++) {
    final IMBoyHttpResponse grantResp = round == 1
        ? await session(
            'grant',
            body: <String, dynamic>{
              'object_key': objectKey,
              'sha256': sha256Hex,
            },
          )
        : await session(
            'renew',
            body: <String, dynamic>{
              'object_key': objectKey,
              'sha256': sha256Hex,
            },
          );
    if (!grantResp.ok) {
      // 预算耗尽等：把信封语义上抛（40904 attempt_budget_exhausted）。
      throw Exception(
        'direct grant 失败: code=${grantResp.code} msg=${grantResp.msg}',
      );
    }
    final confirmed = await _finishIfConfirmedDirect(
      grantResp.payload,
      objectKey: objectKey,
      cancelToken: cancelToken,
      checkpoint: checkpoint,
    );
    if (confirmed != null) return confirmed;
    final DirectGrantDescriptor grant = DirectAttachmentApi.grantOf(
      grantResp.payload,
    );
    attemptId = grant.attemptId;
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.granted,
        objectKey: objectKey,
        attemptId: attemptId,
      ),
    );

    DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
    bool cancelled = false;
    bool putFailed = false;
    try {
      source._requireDispatch();
      final Future<void> putting = putFn != null
          ? putFn(
              grant.url,
              source,
              size,
              grant.requiredHeaders,
              cancelToken: cancelToken,
              onProgress: onProgress,
            )
          : _putSource(
              grant.url,
              source,
              size,
              grant.requiredHeaders,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
      registerCancelHandler?.call();
      await putting;
      DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
    } on DirectUploadDispatchRejected {
      rethrow;
    } on DirectUploadCancelled {
      cancelled = true;
    } catch (_) {
      DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
      // 普通 PUT 失败（网络/5xx）：该 attempt 已 dispatch、无 closed 证据，
      // 不得 finalize 它；URL 是单次授权，重放同一 URL 无意义（I05）——
      // 直接 renew 新 attempt。预算由服务端 23514 硬门兜底。
      putFailed = round != DirectAttachmentApi.maxAttempts;
      if (!putFailed) rethrow;
    }
    if (cancelled) {
      // 本地取消：不 finalize（服务端会话超期由 sweep 收敛，物理残留由
      // step-7 cleanup 账本收敛）。重试必须新 attempt。
      throw DirectUploadCancelled(objectKey);
    }
    if (putFailed) {
      continue;
    }
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.putDone,
        objectKey: objectKey,
        attemptId: attemptId,
      ),
    );

    final IMBoyHttpResponse fin = await session(
      'finalize',
      body: <String, dynamic>{'object_key': objectKey, 'attempt_id': attemptId},
    );
    if (fin.ok) {
      final String state = DirectAttachmentApi.str(fin.payload, 'state');
      // confirmed checkpoint 只对应真 CONFIRMED——UNKNOWN 封存态（FINALIZING）
      // 发 confirmed 会让持久化该 checkpoint 的调用方误判"已确认"而发出
      // 未证明附件，与下方 quarantined 标志自相矛盾。
      if (state == DirectAttachmentApi.stateConfirmed) {
        await checkpoint?.call(
          DirectCheckpoint(
            DirectCheckpointStage.confirmed,
            objectKey: objectKey,
            attemptId: attemptId,
          ),
        );
      }
      DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
      return DirectUploadResult(
        objectKey: objectKey,
        state: state,
        attemptId: attemptId,
        // UNKNOWN_QUARANTINED：本次 attempt 已被服务端隔离，调用方不得
        // 把附件发出（重试走 resumeDirect/新 attempt）
        quarantined:
            DirectAttachmentApi.str(fin.payload, 'outcome') ==
            'UNKNOWN_QUARANTINED',
      );
    }
    // 非确认信封：rejected（可重试新 attempt）或预算耗尽（40904 上抛）。
    final int code = fin.code;
    final bool retryable = code == 409; // 409 attempt_rejected/illegal_state
    if (!retryable || round == DirectAttachmentApi.maxAttempts) {
      throw Exception('direct finalize 失败: code=$code msg=${fin.msg}');
    }
  }
  throw StateError('direct upload exhausted attempts (objectKey=$objectKey)');
}

Future<DirectUploadResult> _resumeDirectSource({
  required String objectKey,
  required DirectUploadSource source,
  required String mime,
  DirectSessionFn? sessionFn,
  CancelToken? cancelToken,
  DirectSourcePutFn? putFn,
  void Function(int sent, int total)? onProgress,
  Future<void> Function(DirectCheckpoint event)? checkpoint,
}) async {
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  if (mime == 'image/jpg') mime = 'image/jpeg';
  final int size = source.length;
  Future<IMBoyHttpResponse> session(
    String action, {
    Map<String, dynamic>? body,
  }) async {
    DirectAttachmentApi._checkCancelled(cancelToken);
    final String path = '/api/v1/attachment/direct/$action';
    final response = sessionFn != null
        ? await sessionFn(path, body: body)
        : await HttpClient.client.post(
            path,
            data: body,
            cancelToken: cancelToken,
          );
    DirectAttachmentApi._checkCancelled(cancelToken);
    return response;
  }

  const String statusPath = '/api/v1/attachment/direct/status';
  final Map<String, dynamic> statusQuery = {'object_key': objectKey};
  final IMBoyHttpResponse st = sessionFn != null
      ? await sessionFn(statusPath, body: statusQuery)
      : await HttpClient.client.get(
          statusPath,
          queryParameters: statusQuery,
          cancelToken: cancelToken,
        );
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  if (!st.ok) {
    throw Exception('direct status 失败: code=${st.code} msg=${st.msg}');
  }
  final String state = DirectAttachmentApi.str(st.payload, 'state');
  if (state != DirectAttachmentApi.stateConfirmed &&
      state != 'GRANTED' &&
      state != DirectAttachmentApi.stateFinalizing) {
    throw StateError('direct session terminal: $state');
  }
  final payload = IMBoyHttpResponse.payloadAsMap(st.payload);
  final rawExpected = payload['expected'];
  final dynamic decoded = rawExpected is String
      ? jsonDecode(rawExpected)
      : rawExpected;
  final sha256Hex = await _sha256OfSource(source, cancelToken);
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  if (decoded is! Map ||
      decoded['sha256'] != sha256Hex ||
      decoded['size_bytes']?.toString() != size.toString() ||
      decoded['mime'] != mime) {
    throw StateError('direct upload does not match local file');
  }
  if (state == DirectAttachmentApi.stateConfirmed) {
    return DirectUploadResult(objectKey: objectKey, state: state, attemptId: 0);
  }
  final int used = DirectAttachmentApi.attemptCount(st.payload);
  if (used >= DirectAttachmentApi.maxAttempts) {
    throw StateError('direct attempt budget exhausted (remote)');
  }
  final IMBoyHttpResponse renew = await session(
    'renew',
    body: <String, dynamic>{'object_key': objectKey, 'sha256': sha256Hex},
  );
  if (!renew.ok) {
    throw Exception('direct renew 失败: code=${renew.code} msg=${renew.msg}');
  }
  final confirmed = await _finishIfConfirmedDirect(
    renew.payload,
    objectKey: objectKey,
    cancelToken: cancelToken,
    checkpoint: checkpoint,
  );
  if (confirmed != null) return confirmed;
  final DirectGrantDescriptor grant = DirectAttachmentApi.grantOf(
    renew.payload,
  );
  await checkpoint?.call(
    DirectCheckpoint(
      DirectCheckpointStage.granted,
      objectKey: objectKey,
      attemptId: grant.attemptId,
    ),
  );
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  source._requireDispatch();
  if (putFn != null) {
    await putFn(
      grant.url,
      source,
      size,
      grant.requiredHeaders,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  } else {
    await _putSource(
      grant.url,
      source,
      size,
      grant.requiredHeaders,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  await checkpoint?.call(
    DirectCheckpoint(
      DirectCheckpointStage.putDone,
      objectKey: objectKey,
      attemptId: grant.attemptId,
    ),
  );
  final IMBoyHttpResponse fin = await session(
    'finalize',
    body: <String, dynamic>{
      'object_key': objectKey,
      'attempt_id': grant.attemptId,
    },
  );
  if (!fin.ok) {
    throw Exception('direct finalize 失败: code=${fin.code} msg=${fin.msg}');
  }
  // 与 uploadFile 同规则：confirmed checkpoint 只对应真 CONFIRMED
  //（UNKNOWN 封存态不得让调用方误判"已确认"）。
  if (DirectAttachmentApi.str(fin.payload, 'state') ==
      DirectAttachmentApi.stateConfirmed) {
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.confirmed,
        objectKey: objectKey,
        attemptId: grant.attemptId,
      ),
    );
  }
  DirectAttachmentApi._checkCancelled(cancelToken, objectKey);
  return DirectUploadResult(
    objectKey: objectKey,
    state: DirectAttachmentApi.str(fin.payload, 'state'),
    attemptId: grant.attemptId,
    // 与 uploadFile 同合同：UNKNOWN 封存态不得把附件发出
    quarantined:
        DirectAttachmentApi.str(fin.payload, 'outcome') ==
        'UNKNOWN_QUARANTINED',
  );
}
