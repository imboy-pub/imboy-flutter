import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/i18n/strings.g.dart';

void main() {
  group('handleResponse', () {
    test('maps successful payload on code 0', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ok'),
        statusCode: 200,
        data: {
          'code': 0,
          'msg': 'success',
          'payload': {'id': 1},
        },
      );

      final resp = handleResponse(response, uri: '/ok');
      expect(resp.ok, isTrue);
      expect(resp.code, 0);
      expect(resp.msg, 'success');
      expect(resp.payload, {'id': 1});
    });

    test('maps business failure when status is 2xx but code is non-zero', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/biz-fail'),
        statusCode: 200,
        data: {
          'code': 9001,
          'msg': 'biz failed',
          'payload': {'reason': 'x'},
        },
      );

      final resp = handleResponse(response, uri: '/biz-fail');
      expect(resp.ok, isFalse);
      expect(resp.code, 9001);
      expect(resp.msg, 'biz failed');
      expect(resp.payload, {'reason': 'x'});
      expect(resp.error, isA<BadRequestException>());
    });

    test('treats string code "0" as success', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ok-string-code'),
        statusCode: 200,
        data: {
          'code': '0',
          'msg': 'success',
          'payload': {'id': 2},
        },
      );

      final resp = handleResponse(response, uri: '/ok-string-code');
      expect(resp.ok, isTrue);
      expect(resp.code, 0);
      expect(resp.payload, {'id': 2});
    });

    test('maps non-2xx response by using response data code/msg/payload', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/http-fail'),
        statusCode: 500,
        data: {
          'code': 5001,
          'msg': 'server failed',
          'payload': {'trace': 'id-1'},
        },
      );

      final resp = handleResponse(response, uri: '/http-fail');
      expect(resp.ok, isFalse);
      expect(resp.code, 5001);
      expect(resp.msg, 'server failed');
      expect(resp.payload, {'trace': 'id-1'});
    });

    test('normalizes non-2xx string code to int', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/http-fail-string-code'),
        statusCode: 400,
        data: {
          'code': '4008',
          'msg': 'string code',
          'payload': {'trace': 'id-2'},
        },
      );

      final resp = handleResponse(response, uri: '/http-fail-string-code');
      expect(resp.ok, isFalse);
      expect(resp.code, 4008);
      expect(resp.msg, 'string code');
      expect(resp.payload, {'trace': 'id-2'});
    });
  });

  group('handleException', () {
    test('maps Dio badResponse 401 to unauthorized code correctly', () {
      final requestOptions = RequestOptions(path: '/unauthorized');
      final response = Response(
        requestOptions: requestOptions,
        statusCode: 401,
        data: {'msg': 'unauthorized'},
      );
      final exception = DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final resp = handleException('/unauthorized', exception);
      expect(resp.ok, isFalse);
      expect(resp.error, isA<UnauthorisedException>());
      expect(resp.code, 401);
    });

    test('passes component HttpException through keeping human message', () {
      // 回归：断网前置分支抛 NetworkException(「无网络」)曾被打成
      // "Instance of 'NetworkException'"（error.toString() 重包），
      // 经 resp.msg 污染到 WorkspaceApiException 一路显示到 UI。
      final resp = handleException(
        '/offline',
        NetworkException(message: '无网络'),
      );
      expect(resp.ok, isFalse);
      expect(resp.error, isA<NetworkException>());
      expect(resp.msg, '无网络');
    });

    test('maps Dio connectionError to NetworkException with connect tip', () {
      // 回归：连接被拒/不可达（如 adb reverse 断开）曾落入 default 分支
      // 变成 UnknownException（非人话）。
      final exception = DioException(
        requestOptions: RequestOptions(path: '/refused'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );

      final resp = handleException('/refused', exception);
      expect(resp.ok, isFalse);
      expect(resp.error, isA<NetworkException>());
      expect(resp.msg, t.common.tipConnectDesc);
    });
  });
}
