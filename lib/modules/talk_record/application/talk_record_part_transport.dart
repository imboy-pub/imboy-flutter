/// PUTs use the existing authenticated HTTP client and scoped gateway ticket.
library;

import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:crypto/crypto.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

abstract interface class TalkRecordPartTransport {
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  );
}

/// V3-18：按服务端投影形态分派——direct s3_put descriptor（新）走
/// S3Put 直传；旧 gateway ticket 形态保留原路径（V3-20 退役后仅剩
/// s3_put）。运输形态由服务端声明，客户端不猜 URL。
class TalkRecordDispatchPartTransport implements TalkRecordPartTransport {
  TalkRecordDispatchPartTransport({TalkRecordPartTransport? gatewayFallback})
    : _gatewayFallback = gatewayFallback ?? TalkRecordGatewayPartTransport();
  final TalkRecordPartTransport _gatewayFallback;

  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  ) {
    if (ticket.isS3Put) {
      return TalkRecordS3PutPartTransport().put(ticket, plaintext, guard);
    }
    return _gatewayFallback.put(ticket, plaintext, guard);
  }
}

class TalkRecordGatewayPartTransport implements TalkRecordPartTransport {
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  ) async {
    guard();
    // Current backend always emits same-origin gateway tickets. Do not send JWT
    // to an arbitrary presigned destination or create a second upload session.
    if (!ticket.gateway || !ticket.canUploadAt(DateTime.now())) {
      throw StateError('Scoped upload ticket unavailable');
    }
    final bytes = await plaintext.readAsBytes();
    guard();
    final hash = sha256.convert(bytes).toString();
    final response = await HttpClient.client.put(
      ticket.putUrl,
      data: bytes,
      httpTransformer: TalkRecordUploadReceiptTransformer(hash, bytes.length),
      options: Options(
        extra: {httpNoAutoRetry: true, httpRequestGuard: guard},
        contentType: 'audio/aac',
        followRedirects: false,
        headers: {'Content-Length': bytes.length},
      ),
    );
    guard();
    if (!response.ok) throw StateError('Scoped audio upload failed');
  }
}

/// Gateway receipts are byte acknowledgements, not business API envelopes.
class TalkRecordUploadReceiptTransformer extends HttpTransformer {
  TalkRecordUploadReceiptTransformer(this.expectedHash, this.expectedSize);
  final String expectedHash;
  final int expectedSize;

  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    final body = response.data;
    if (response.statusCode != 200 ||
        body is! Map ||
        body['pinned'] != true ||
        body['sha256'] is! String ||
        body['sha256'] != expectedHash ||
        body['size'] is! int ||
        body['size'] != expectedSize) {
      return IMBoyHttpResponse.failure(errMsg: 'Invalid scoped upload receipt');
    }
    return IMBoyHttpResponse.success(body);
  }
}

/// V3-18 direct s3_put：字节直传对象存储（presign URL + 服务端签发的
/// required_headers——含 content-type 与 x-amz-checksum-sha256，客户端
/// 原样发送不重算）。绝不携带业务 JWT/Cookie 到存储（headers 白名单=
/// descriptor 显式集合）。2xx 即 S3 接收成功；内容校验由 S3 checksum
/// 在 PUT 时完成（不匹配即 400）。
class TalkRecordS3PutPartTransport implements TalkRecordPartTransport {
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  ) async {
    guard();
    if (!ticket.isS3Put || !ticket.canUploadAt(DateTime.now())) {
      throw StateError('s3_put descriptor unavailable');
    }
    final length = await plaintext.length();
    guard();
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        maxRedirects: 0,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    )..interceptors.add(HttpRequestGuardInterceptor());
    try {
      final response = await dio.put<void>(
        ticket.grantUrl,
        data: plaintext.openRead().map((chunk) {
          guard();
          return chunk;
        }),
        options: Options(
          extra: {httpRequestGuard: guard},
          headers: {...ticket.requiredHeaders, 'Content-Length': length},
        ),
      );
      guard();
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw StateError('s3_put upload failed: $code');
      }
    } finally {
      dio.close(force: true);
    }
  }
}
