import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';

import 'cs_asset_put_transport.dart';
import 'cs_asset_content.dart';

enum CsAssetUploadStage {
  preparing,
  presigning,
  uploading,
  confirming,
  complete,
  cancelled,
  failed,
  unknown,
}

enum CsAssetOperationFailure {
  cancelled,
  scopeChanged,
  sizeRejected,
  putRejected,
  requestFailed,
  alreadyStarted,
  confirmationRejected,
}

class CsAssetOperationException implements Exception {
  const CsAssetOperationException(
    this.failure, {
    this.status,
    required this.requestStarted,
  });
  final CsAssetOperationFailure failure;
  final int? status;
  final bool requestStarted;
  @override
  String toString() => 'asset operation ${failure.name}';
}

class CsAssetUploadOperation {
  CsAssetUploadOperation({bool Function()? isCurrent, this.onChanged})
    : _isCurrent = isCurrent ?? (() => true);
  final bool Function() _isCurrent;
  final void Function()? onChanged;
  final CancelToken _cancel = CancelToken();
  CsAssetUploadStage stage = CsAssetUploadStage.preparing;
  int sentBytes = 0, totalBytes = 0;
  bool requestStarted = false, _used = false;
  bool _retryable = true;
  bool _notifying = false;
  bool get canRetry =>
      _current && (!requestStarted || (_retryable && !_cancel.isCancelled));
  bool Function()? _scopeGuard;
  void bindScope(bool Function() guard) {
    if (_used || _scopeGuard != null) {
      throw const CsAssetOperationException(
        CsAssetOperationFailure.alreadyStarted,
        requestStarted: false,
      );
    }
    _scopeGuard = guard;
  }

  bool get _current => _isCurrent() && (_scopeGuard?.call() ?? true);
  void cancel() {
    if (_cancel.isCancelled ||
        (stage == CsAssetUploadStage.complete && !_notifying) ||
        stage == CsAssetUploadStage.failed) {
      return;
    }
    _cancel.cancel();
    _stage(
      requestStarted
          ? CsAssetUploadStage.unknown
          : CsAssetUploadStage.cancelled,
    );
  }

  void _stage(CsAssetUploadStage next) {
    if (stage == next) return;
    stage = next;
    if (!_current) return;
    final wasNotifying = _notifying;
    _notifying = true;
    try {
      onChanged?.call();
    } finally {
      _notifying = wasNotifying;
    }
  }

  void check() {
    if (!_current || _cancel.isCancelled) {
      _stage(
        requestStarted
            ? CsAssetUploadStage.unknown
            : CsAssetUploadStage.cancelled,
      );
      throw CsAssetOperationException(
        _cancel.isCancelled
            ? CsAssetOperationFailure.cancelled
            : CsAssetOperationFailure.scopeChanged,
        requestStarted: requestStarted,
      );
    }
  }

  void begin(int size) {
    check();
    if (_used) {
      throw CsAssetOperationException(
        CsAssetOperationFailure.alreadyStarted,
        requestStarted: requestStarted,
      );
    }
    _used = true;
    if (size <= 0 || size > 25 * 1024 * 1024) {
      _stage(CsAssetUploadStage.failed);
      throw const CsAssetOperationException(
        CsAssetOperationFailure.sizeRejected,
        requestStarted: false,
      );
    }
    totalBytes = size;
  }

  void _request(CsAssetUploadStage next) {
    check();
    _stage(next);
    check();
    requestStarted = true;
    _retryable = false;
  }

  void progress(int sent, int total) {
    if (!_current || _cancel.isCancelled) return;
    sentBytes = sent.clamp(0, totalBytes);
    onChanged?.call();
  }

  Future<EnterpriseAsset> upload({
    required EnterpriseApi api,
    required CsAssetPutTransport Function() transportFactory,
    required String org,
    required String workspace,
    required String conversation,
    required String mime,
    required Uint8List bytes,
    required String fileName,
  }) async {
    begin(bytes.length);
    final input = _CsUploadInput(
      org,
      workspace,
      conversation,
      mime,
      Uint8List.fromList(bytes).asUnmodifiableView(),
      fileName,
    );
    api.dio.interceptors.removeWhere(
      (i) => i is HttpRetryInterceptor || i is LogInterceptor,
    );
    try {
      return await _perform(api, transportFactory, input);
    } on CsAssetOperationException {
      rethrow;
    } on Object catch (error) {
      check();
      return _fail(error);
    }
  }

  Future<EnterpriseAsset> _perform(
    EnterpriseApi api,
    CsAssetPutTransport Function() factory,
    _CsUploadInput input,
  ) async {
    final hash = sha256.convert(input.bytes).toString();
    _request(CsAssetUploadStage.presigning);
    final ticket = await api.presignAsset(
      input.org,
      workspaceId: input.workspace,
      conversationId: input.conversation,
      mime: input.mime,
      sizeBytes: input.bytes.length,
      objectHash: hash,
      fileName: input.fileName,
    );
    check();
    await _put(
      api,
      factory,
      ticket,
      input.org,
      input.workspace,
      input.mime,
      input.bytes,
      hash,
    );
    check();
    _request(CsAssetUploadStage.confirming);
    final asset = await _confirm(api, ticket, input, hash);
    check();
    _stage(CsAssetUploadStage.complete);
    check();
    return asset;
  }

  Future<EnterpriseAsset> _confirm(
    EnterpriseApi api,
    EnterprisePresignResult ticket,
    _CsUploadInput input,
    String hash,
  ) async {
    final response = await api.post(
      '/api/v1/enterprise/organizations/${input.org}/assets/confirm',
      data: {'workspace_id': input.workspace, 'upload_ref': ticket.uploadRef},
    );
    check();
    if (!response.ok) {
      throw EnterpriseApiException(
        response.code,
        'asset confirmation rejected',
      );
    }
    final raw = response.payload;
    final rawId = raw is Map ? raw['asset_id'] : null;
    final rawConv = raw is Map ? raw['conversation_id'] : null;
    if (raw is! Map ||
        !_boundId(rawId, ticket.assetId) ||
        !_boundId(rawConv, input.conversation) ||
        raw['status'] != 'active' ||
        raw['object_hash'] != hash ||
        raw['mime'] != input.mime ||
        raw['size_bytes'] is! int ||
        raw['size_bytes'] != input.bytes.length) {
      _stage(CsAssetUploadStage.unknown);
      throw const CsAssetOperationException(
        CsAssetOperationFailure.confirmationRejected,
        requestStarted: true,
      );
    }
    // Organization is the frozen authenticated request scope, not a server view field.
    return EnterpriseAsset(
      id: ticket.assetId,
      organizationId: input.org,
      conversationId: input.conversation,
      status: 'active',
      mime: input.mime,
      size: input.bytes.length,
    );
  }

  bool _boundId(Object? raw, String expected) {
    final text = raw is String
        ? raw
        : raw is int
        ? raw.toString()
        : '';
    return CsVerifiedAssetContent.isAssetId(text) && text == expected;
  }

  Never _fail(Object error) {
    final status = error is EnterpriseApiException
        ? error.code
        : error is CsAssetPutException
        ? error.status
        : null;
    final definite = status != null && status >= 400 && status < 500;
    _retryable =
        definite &&
        status != 401 &&
        status != 403 &&
        stage != CsAssetUploadStage.confirming &&
        _current;
    _stage(definite ? CsAssetUploadStage.failed : CsAssetUploadStage.unknown);
    throw CsAssetOperationException(
      error is CsAssetPutException
          ? CsAssetOperationFailure.putRejected
          : CsAssetOperationFailure.requestFailed,
      status: status,
      requestStarted: requestStarted,
    );
  }

  Future<void> _put(
    EnterpriseApi api,
    CsAssetPutTransport Function() factory,
    EnterprisePresignResult ticket,
    String org,
    String workspace,
    String mime,
    Uint8List bytes,
    String hash,
  ) async {
    check();
    final transport = factory();
    try {
      _request(CsAssetUploadStage.uploading);
      await transport.putMember(
        url: ticket.uploadUrl,
        apiOrigin: Uri.parse(api.dio.options.baseUrl),
        organizationId: org,
        workspaceId: workspace,
        uploadRef: ticket.uploadRef,
        assetId: ticket.assetId,
        mime: mime,
        bytes: bytes,
        objectHash: hash,
        authenticatedHeaders: Map<String, dynamic>.from(
          api.dio.options.headers,
        ),
        cancelToken: _cancel,
        onSendProgress: progress,
      );
    } finally {
      transport.close();
    }
  }
}

class _CsUploadInput {
  const _CsUploadInput(
    this.org,
    this.workspace,
    this.conversation,
    this.mime,
    this.bytes,
    this.fileName,
  );
  final String org, workspace, conversation, mime, fileName;
  final Uint8List bytes;
}
