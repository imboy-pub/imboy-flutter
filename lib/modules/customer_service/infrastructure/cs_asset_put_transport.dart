import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

enum CsAssetPutFailure {
  invalidTarget,
  credentialMissing,
  cancelled,
  networkFailure,
  rejected,
  invalidAcknowledgement,
}

class CsAssetPutException implements Exception {
  final CsAssetPutFailure failure;
  final int? status;
  final bool requestStarted;
  const CsAssetPutException(
    this.failure, {
    this.status,
    this.requestStarted = false,
  });
  @override
  String toString() => 'asset PUT ${failure.name}';
}

/// The only byte PUT engine. No inherited auth, cookies, logging or retries.
class CsAssetPutTransport {
  CsAssetPutTransport({HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          followRedirects: false,
          maxRedirects: 0,
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (_) => true,
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }
  final Dio _dio;
  void close() => _dio.close(force: true);

  Future<void> putMember({
    required String url,
    required Uri apiOrigin,
    required String organizationId,
    required String workspaceId,
    required String uploadRef,
    required String assetId,
    required String mime,
    required Uint8List bytes,
    required String objectHash,
    required Map<String, dynamic> authenticatedHeaders,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final target = _memberTarget(
      url,
      apiOrigin,
      organizationId,
      workspaceId,
      uploadRef,
    );
    final authorization = _authorization(authenticatedHeaders);
    _validateBytes(assetId, objectHash, bytes);
    final response = await _put(
      target,
      bytes,
      {'authorization': authorization},
      cancelToken,
      onSendProgress,
      ResponseType.json,
    );
    if (response.statusCode != 200) {
      throw CsAssetPutException(
        CsAssetPutFailure.invalidAcknowledgement,
        status: response.statusCode,
        requestStarted: true,
      );
    }
    _memberAcknowledgement(
      response.data,
      assetId,
      mime,
      bytes.length,
      objectHash,
    );
  }

  void _validateBytes(String assetId, String objectHash, Uint8List bytes) {
    if (!_positiveId(assetId) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(objectHash) ||
        sha256.convert(bytes).toString() != objectHash) {
      throw const CsAssetPutException(CsAssetPutFailure.invalidAcknowledgement);
    }
  }

  /// Only a separately trusted producer origin can authorize a no-auth object PUT.
  Future<void> putObject({
    required String url,
    required Uri permittedOrigin,
    required Uint8List bytes,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final target = _target(url, permittedOrigin);
    if (target.queryParametersAll.containsKey('upload_ref')) {
      throw const CsAssetPutException(CsAssetPutFailure.invalidTarget);
    }
    await _put(
      target,
      bytes,
      {},
      cancelToken,
      onSendProgress,
      ResponseType.plain,
    );
  }

  Uri _target(String url, Uri permittedOrigin) {
    try {
      final target = Uri.parse(url);
      if (target.scheme != 'https' ||
          !target.hasAuthority ||
          target.userInfo.isNotEmpty ||
          target.hasFragment ||
          permittedOrigin.userInfo.isNotEmpty ||
          target.origin != permittedOrigin.origin) {
        throw const CsAssetPutException(CsAssetPutFailure.invalidTarget);
      }
      return target;
    } on FormatException {
      throw const CsAssetPutException(CsAssetPutFailure.invalidTarget);
    }
  }

  Uri _memberTarget(
    String url,
    Uri origin,
    String org,
    String workspace,
    String ref,
  ) {
    final target = _target(url, origin);
    final query = target.queryParametersAll;
    if (!_positiveId(org) ||
        !_positiveId(workspace) ||
        ref.isEmpty ||
        target.path != '/api/v1/enterprise/organizations/$org/assets/presign' ||
        query.length != 2 ||
        query['workspace_id']?.length != 1 ||
        query['upload_ref']?.length != 1 ||
        query['workspace_id']?.single != workspace ||
        query['upload_ref']?.single != ref) {
      throw const CsAssetPutException(CsAssetPutFailure.invalidTarget);
    }
    return target;
  }

  String _authorization(Map<String, dynamic> headers) {
    final values = headers.entries
        .where((e) => e.key.toLowerCase() == 'authorization')
        .toList();
    final value = values.length == 1 ? values.single.value : null;
    if (value is! String ||
        value.trim().isEmpty ||
        value.contains('\r') ||
        value.contains('\n')) {
      throw const CsAssetPutException(CsAssetPutFailure.credentialMissing);
    }
    return value;
  }

  Future<Response<Object?>> _put(
    Uri target,
    Uint8List bytes,
    Map<String, String> headers,
    CancelToken? cancel,
    ProgressCallback? progress,
    ResponseType responseType,
  ) async {
    if (cancel?.isCancelled == true) {
      throw const CsAssetPutException(CsAssetPutFailure.cancelled);
    }
    try {
      final response = await _dio.putUri<Object?>(
        target,
        data: Stream<List<int>>.value(bytes),
        cancelToken: cancel,
        onSendProgress: progress,
        options: Options(
          responseType: responseType,
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytes.length,
            ...headers,
          },
        ),
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw CsAssetPutException(
          CsAssetPutFailure.rejected,
          status: response.statusCode,
          requestStarted: true,
        );
      }
      return response;
    } on DioException catch (e) {
      throw CsAssetPutException(
        e.type == DioExceptionType.cancel
            ? CsAssetPutFailure.cancelled
            : CsAssetPutFailure.networkFailure,
        requestStarted: true,
      );
    }
  }

  bool _positiveId(String raw) =>
      RegExp(r'^[1-9][0-9]*$').hasMatch(raw) &&
      raw.length <= 19 &&
      BigInt.parse(raw) <= BigInt.parse('9223372036854775807');

  bool _idMatches(Object? raw, String expected) =>
      (raw is String && _positiveId(raw) && raw == expected) ||
      (raw is int && _positiveId(raw.toString()) && raw.toString() == expected);

  void _memberAcknowledgement(
    Object? data,
    String id,
    String mime,
    int size,
    String hash,
  ) {
    final payload = data is Map ? data['payload'] : null;
    if (data is! Map ||
        data['code'] != 0 ||
        payload is! Map ||
        !_idMatches(payload['asset_id'], id) ||
        payload['status'] != 'pending_confirm' ||
        payload['object_hash'] != hash ||
        payload['size_bytes'] != size ||
        payload['mime'] != mime) {
      throw const CsAssetPutException(
        CsAssetPutFailure.invalidAcknowledgement,
        requestStarted: true,
      );
    }
  }
}
