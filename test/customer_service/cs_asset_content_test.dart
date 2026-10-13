import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_content.dart';

void main() {
  final bytes = Uint8List.fromList([0, 255, 65]);
  Response<dynamic> response(Map<String, List<String>> headers) => Response(
    requestOptions: RequestOptions(path: '/synthetic-content'),
    data: bytes,
    statusCode: 200,
    headers: Headers.fromMap(headers),
  );
  Map<String, List<String>> valid() => {
    'x-asset-id': ['9'],
    'x-asset-sha256': [sha256.convert(bytes).toString()],
    'content-length': ['3'],
    'content-type': ['application/octet-stream'],
  };
  test('verified content retains exact bytes and server hash', () {
    final content = CsVerifiedAssetContent.fromResponse(response(valid()), '9');
    expect(content.bytes, bytes);
    expect(content.objectHash, sha256.convert(bytes).toString());
  });
  test('verified bytes cannot be mutated after verification', () {
    final content = CsVerifiedAssetContent.fromResponse(response(valid()), '9');
    expect(() => content.bytes[0] = 42, throwsUnsupportedError);
    expect(content.bytes, bytes);
  });
  for (final header in ['x-asset-id', 'x-asset-sha256', 'content-length']) {
    test('missing $header cannot be called verified', () {
      final headers = valid()..remove(header);
      expect(
        () => CsVerifiedAssetContent.fromResponse(response(headers), '9'),
        throwsFormatException,
      );
    });
    test('mismatched $header cannot be called verified', () {
      final headers = valid()..[header] = ['0'];
      expect(
        () => CsVerifiedAssetContent.fromResponse(response(headers), '9'),
        throwsFormatException,
      );
    });
  }
}
