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
