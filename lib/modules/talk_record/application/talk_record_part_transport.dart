/// Capture part PUT bytes go straight to object storage through the
/// server-signed s3_put descriptor; the BEAM never relays the body.
library;

import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

abstract interface class TalkRecordPartTransport {
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard, {
    CancelToken? cancelToken,
  });
}

/// V3-18 direct s3_put：字节直传对象存储（presign URL + 服务端签发的
/// required_headers——含 content-type 与 x-amz-checksum-sha256，客户端
/// 原样发送不重算）。绝不携带业务 JWT/Cookie 到存储（headers 白名单=
/// descriptor 显式集合）。2xx 即 S3 接收成功；内容校验由 S3 checksum
/// 在 PUT 时完成（不匹配即 400）。旧 gateway ticket 传输已随 backend
/// V3-20 零签发退役（CONFIRMED_DECISIONS 决策 5：S3-only）。
class TalkRecordS3PutPartTransport implements TalkRecordPartTransport {
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard, {
    CancelToken? cancelToken,
  }) async {
    guard();
    if (!ticket.uploadable) {
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
        cancelToken: cancelToken,
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
