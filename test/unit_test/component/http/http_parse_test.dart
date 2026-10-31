import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';

// Raw server fixtures must never be built via numeric literals/JS Number.
class _RawJsonAdapter implements HttpClientAdapter {
  _RawJsonAdapter(this.body);
  final String body;
  final requests = <RequestOptions>[];
  final requestBodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      requestBodies.add(
        utf8.decode(await requestStream.expand((chunk) => chunk).toList()),
      );
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('J27.d/e: raw JSON VM boundary (not Web/device/backend acceptance)', () {
    for (final digits in [
      '9007199254740991',
      '9007199254740992',
      '9007199254740993',
      '9223372036854775807',
    ]) {
      test(
        'J27.d: $digits survives raw decode, model and wire serialization',
        () async {
          final raw =
              '{"code":0,"msg":"success","payload":'
              '{"id":$digits,"creator_uid":$digits,"name":"synthetic",'
              '"created_at":1761868800000,"updated_at":1761868800000}}';
          final adapter = _RawJsonAdapter(raw);
          final dio = Dio()..httpClientAdapter = adapter;
          addTearDown(() => dio.close(force: true));
          final response = await dio.get<dynamic>(
            'https://synthetic.invalid/channel',
            options: Options(
              responseDecoder: channelIdResponseDecoder(
                ChannelResponseShape.detail,
              ),
            ),
          );
          final envelope = handleResponse(response, uri: '/channel');
          expect(envelope.ok, isTrue);
          expect(envelope.payload['id'], digits);
          expect(envelope.payload['creator_uid'], digits);
          final model = ChannelModel.fromJson(
            Map<String, dynamic>.from(envelope.payload as Map),
          );
          expect(model.id, digits);
          expect(model.creatorId, digits);
          expect(model.toJson()['id'], digits);
          // Synthetic request capture, not a production route/backend echo.
          await dio.post<dynamic>(
            'https://synthetic.invalid/channel/${model.id}',
            data: {'channel_id': decimalIdForWire(model.id)},
          );
          expect(adapter.requests.last.uri.pathSegments.last, digits);
          expect(adapter.requestBodies.single, '{"channel_id":$digits}');
        },
      );
    }

    test('J27.e: non-ID text, timestamps, money, decimals and Xid retain meaning', () async {
      const raw =
          r'{"code":0,"payload":{"id":9007199254740993,"creator_uid":9007199254740991,"name":"synthetic","created_at":1761868800000,"updated_at":1761868800000,"price":1299,"amount":12.5,"negative":-7,"text":"00092233720368547758071234567890","escaped":"quote: \"9007199254740993\"","message_id":"d3gk0m1r8s9t2u3v4w5x","nested":{"id":42},"enabled":true,"nothing":null}}';
      final adapter = _RawJsonAdapter(raw);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final response = await dio.get<dynamic>(
        'https://synthetic.invalid/channel',
        options: Options(
          responseDecoder: channelIdResponseDecoder(
            ChannelResponseShape.detail,
          ),
        ),
      );
      final envelope = handleResponse(response, uri: '/channel');
      final payload = Map<String, dynamic>.from(envelope.payload as Map);
      expect(payload['id'], '9007199254740993');
      expect(payload['created_at'], isA<int>());
      expect(payload['created_at'], 1761868800000);
      expect(payload['price'], isA<int>());
      expect(payload['price'], 1299);
      expect(payload['amount'], isA<double>());
      expect(payload['amount'], 12.5);
      expect(payload['negative'], -7);
      expect(payload['text'], '00092233720368547758071234567890');
      expect(payload['escaped'], 'quote: "9007199254740993"');
      expect(payload['message_id'], 'd3gk0m1r8s9t2u3v4w5x');
      expect(payload['nested'], {'id': 42});
      expect(payload['enabled'], isTrue);
      expect(payload['nothing'], isNull);
      final model = ChannelModel.fromJson(payload);
      expect(model.price, 1299);
      expect(model.createdAt.millisecondsSinceEpoch, 1761868800000);
      final preserved = Map<String, dynamic>.from(payload)
        ..remove('id')
        ..remove('creator_uid');
      await dio.post<dynamic>(
        'https://synthetic.invalid/echo',
        data: preserved,
      );
      expect(jsonDecode(adapter.requestBodies.single), preserved);
    });

    for (final token in [
      '0',
      '-1',
      '12.5',
      '1e3',
      'true',
      'null',
      '9223372036854775808',
      '"not-a-decimal-id"',
      '"12.5"',
    ]) {
      test(
        'J27.e: decimal validation rejects raw ID $token without truncation',
        () async {
          final adapter = _RawJsonAdapter('{"code":0,"payload":{"id":$token}}');
          final dio = Dio()..httpClientAdapter = adapter;
          addTearDown(() => dio.close(force: true));
          final response = await dio.get<dynamic>(
            'https://synthetic.invalid/channel',
            options: Options(
              responseDecoder: channelIdResponseDecoder(
                ChannelResponseShape.detail,
              ),
            ),
          );
          final envelope = handleResponse(response, uri: '/channel');
          expect(channelDecimalId(envelope.payload['id']), isNull);
          // This validator returns null. ChannelModel.fromJson currently substitutes
          // '0'; that is NOT explicit model/API rejection and does not close J27.e.
        },
      );
    }
  });
  group('server clock envelope', () {
    setUp(
      () => NtpHelper.updateOffsetFromServer(
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    tearDown(
      () => NtpHelper.updateOffsetFromServer(
        DateTime.now().millisecondsSinceEpoch,
      ),
    );

    test(
      'top-level millisecond clock updates without changing map payload',
      () {
        final payload = {'id': 1};
        final serverTs = DateTime.now().millisecondsSinceEpoch + 120000;
        final response = handleResponse(
          Response(
            requestOptions: RequestOptions(path: '/clock'),
            statusCode: 200,
            data: {'code': 0, 'sv_ts': serverTs, 'payload': payload},
          ),
          uri: '/clock',
        );
        expect(response.ok, isTrue);
        expect(response.payload, same(payload));
        expect(NtpHelper.offset, closeTo(120000, 2000));
      },
    );

    test('top-level clock wins over legacy nested clock', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {'sv_ts': now - 240000};
      final response = handleResponse(
        Response(
          requestOptions: RequestOptions(path: '/clock'),
          statusCode: 200,
          data: {'code': 0, 'sv_ts': now + 120000, 'payload': payload},
        ),
        uri: '/clock',
      );
      expect(response.payload, same(payload));
      expect(NtpHelper.offset, closeTo(120000, 2000));
    });

    test('legacy nested timestamp remains supported', () {
      final serverTs = DateTime.now().millisecondsSinceEpoch - 120000;
      handleResponse(
        Response(
          requestOptions: RequestOptions(path: '/clock'),
          statusCode: 200,
          data: {
            'code': 0,
            'payload': {'sv_ts': serverTs},
          },
        ),
        uri: '/clock',
      );
      expect(NtpHelper.offset, closeTo(-120000, 2000));
    });

    test(
      'top-level clock works with null and list payload without injection',
      () {
        for (final payload in [
          null,
          [1, 2],
        ]) {
          final response = handleResponse(
            Response(
              requestOptions: RequestOptions(path: '/clock'),
              statusCode: 200,
              data: {
                'code': 0,
                'sv_ts': DateTime.now().millisecondsSinceEpoch + 120000,
                'payload': payload,
              },
            ),
            uri: '/clock',
          );
          expect(response.payload, same(payload));
          expect(NtpHelper.offset, closeTo(120000, 2000));
        }
      },
    );

    test(
      'invalid, seconds and excessive-skew timestamps retain prior offset',
      () {
        final initial = NtpHelper.offset;
        for (final value in [
          'invalid',
          0,
          -1,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          DateTime.now().millisecondsSinceEpoch + 48 * 3600000,
        ]) {
          final response = handleResponse(
            Response(
              requestOptions: RequestOptions(path: '/clock'),
              statusCode: 200,
              data: {
                'code': 0,
                'sv_ts': value,
                'payload': {'id': 1},
              },
            ),
            uri: '/clock',
          );
          expect(response.ok, isTrue);
          expect(NtpHelper.offset, initial);
        }
      },
    );

    test('business failure keeps existing success-only clock behavior', () {
      final initial = NtpHelper.offset;
      final response = handleResponse(
        Response(
          requestOptions: RequestOptions(path: '/clock'),
          statusCode: 200,
          data: {
            'code': 1,
            'sv_ts': DateTime.now().millisecondsSinceEpoch + 120000,
            'payload': <String, dynamic>{},
          },
        ),
        uri: '/clock',
      );
      expect(response.ok, isFalse);
      expect(NtpHelper.offset, initial);
    });
  });

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
