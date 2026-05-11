import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/http_response.dart';

void main() {
  group('IMBoyHttpResponse', () {
    test('failure assigns payload and error fields', () {
      final resp = IMBoyHttpResponse.failure(
        errMsg: 'bad request',
        errCode: 400,
        payload: {'k': 'v'},
      );

      expect(resp.ok, isFalse);
      expect(resp.code, 400);
      expect(resp.msg, 'bad request');
      expect(resp.payload, {'k': 'v'});
      expect(resp.error, isA<BadRequestException>());
    });

    test('failureFormResponse assigns safe defaults', () {
      final resp = IMBoyHttpResponse.failureFormResponse(payload: {'raw': true});

      expect(resp.ok, isFalse);
      expect(resp.code, 1);
      expect(resp.msg, 'bad response');
      expect(resp.payload, {'raw': true});
      expect(resp.error, isA<BadResponseException>());
    });

    test('failureFromError uses exception details when msg/code are absent', () {
      final resp = IMBoyHttpResponse.failureFromError(
        error: NetworkException(message: 'network down', code: 503),
      );

      expect(resp.ok, isFalse);
      expect(resp.code, 503);
      expect(resp.msg, 'network down');
      expect(resp.payload, <String, dynamic>{});
      expect(resp.error, isA<NetworkException>());
    });

    test('failureFromError prefers explicit msg/code overrides', () {
      final resp = IMBoyHttpResponse.failureFromError(
        error: NetworkException(message: 'network down', code: 503),
        errCode: 520,
        errMsg: 'overridden',
      );

      expect(resp.ok, isFalse);
      expect(resp.code, 520);
      expect(resp.msg, 'overridden');
      expect(resp.payload, <String, dynamic>{});
      expect(resp.error, isA<NetworkException>());
    });
  });
}
