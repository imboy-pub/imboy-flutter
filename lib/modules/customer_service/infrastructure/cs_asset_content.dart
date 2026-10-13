import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';

class CsVerifiedAssetContent {
  const CsVerifiedAssetContent._(
    this.assetId,
    this.objectHash,
    this.mime,
    this.bytes,
  );
  final String assetId, objectHash, mime;
  final Uint8List bytes;
  int get size => bytes.length;
  static CsVerifiedAssetContent fromResponse(
    Response<dynamic> response,
    String expectedId,
  ) {
    final id = _one(response.headers, 'x-asset-id');
    final hash = _one(response.headers, 'x-asset-sha256');
    final length = _one(response.headers, 'content-length');
    final raw = response.data;
    if (response.statusCode != 200 ||
        raw is! List<int> ||
        !isAssetId(id) ||
        !isAssetId(expectedId) ||
        raw.isEmpty ||
        raw.length > 25 * 1024 * 1024 ||
        raw.any((n) => n < 0 || n > 255) ||
        id != expectedId ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(length) ||
        int.tryParse(length) != raw.length ||
        sha256.convert(raw).toString() != hash) {
      throw const FormatException('asset content integrity refused');
    }
    return CsVerifiedAssetContent._(
      id,
      hash,
      _one(response.headers, 'content-type'),
      Uint8List.fromList(raw).asUnmodifiableView(),
    );
  }

  static bool isAssetId(String id) =>
      RegExp(r'^[1-9][0-9]*$').hasMatch(id) &&
      id.length <= 19 &&
      BigInt.parse(id) <= BigInt.parse('9223372036854775807');
  static String _one(Headers headers, String name) {
    final values = headers[name];
    if (values == null || values.length != 1 || values.single.isEmpty) {
      throw const FormatException('asset content metadata refused');
    }
    return values.single;
  }
}

class CsAssetContentTransformer extends HttpTransformer {
  CsAssetContentTransformer(this.expectedId);
  final String expectedId;
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    if (response.statusCode != 200) {
      return IMBoyHttpResponse.failure(
        errCode: response.statusCode ?? 0,
        errMsg: 'asset content rejected',
      );
    }
    try {
      return IMBoyHttpResponse.success(
        CsVerifiedAssetContent.fromResponse(response, expectedId),
      );
    } on FormatException {
      return IMBoyHttpResponse.failure(
        errCode: 0,
        errMsg: 'asset content integrity refused',
      );
    }
  }
}
