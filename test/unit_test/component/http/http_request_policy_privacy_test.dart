import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';

const _url =
    'https://userinfo_secret:password_secret@synthetic.invalid/resource'
    '?token=query_secret#fragment_secret';
const _authSecret = 'authorization_secret';
const _sourceSecret = 'source_secret';
const _messageSecret = 'message_secret';
const _stackSecret = 'stack_secret';
const _secrets = [
  'userinfo_secret',
  'password_secret',
  'query_secret',
  'fragment_secret',
  _authSecret,
  _sourceSecret,
  _messageSecret,
  _stackSecret,
];

class _MemoryAdapter implements HttpClientAdapter {
  _MemoryAdapter({this.body = '{}', this.errorType});

  final String body;
  final DioExceptionType? errorType;
  DioException? emittedError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (errorType != null) {
      final error = DioException(
        requestOptions: options,
        type: errorType!,
        error: const FormatException('synthetic', _sourceSecret),
        message: _messageSecret,
        stackTrace: StackTrace.fromString(_stackSecret),
      );
      emittedError = error;
      throw error;
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

void _expectNoSecrets(List<String> logs) {
  for (final secret in _secrets) {
    expect(logs.join('\n'), isNot(contains(secret)));
  }
}

void main() {
  test('safeHttpUri strips user info, query values and fragment', () {
    final safe = Uri.parse(safeHttpUri(_url));
    expect(safe.scheme, 'https');
    expect(safe.host, 'synthetic.invalid');
    expect(safe.path, '/resource');
    expect(safe.userInfo, isEmpty);
    expect(safe.queryParameters, {'token': '[REDACTED]'});
    expect(safe.fragment, isEmpty);
    _expectNoSecrets([safe.toString()]);
  });

  test(
    'request and response retain safe logging and normal response',
    () async {
      final logs = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _MemoryAdapter(body: '{"ok":true}')
        ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
      addTearDown(() => dio.close(force: true));

      final response = await dio.get<dynamic>(
        _url,
        options: Options(headers: {'Authorization': 'Bearer $_authSecret'}),
      );
      final safeUri = safeHttpUri(response.requestOptions.uri);
      expect(response.data, {'ok': true});
      expect(logs, ['HTTP GET $safeUri', 'HTTP 200 $safeUri']);
      _expectNoSecrets(logs);
    },
  );

  test(
    'malformed JSON stays unknown and passes through without source logging',
    () async {
      const body = '{"value":"$_sourceSecret","invalid":}';
      final logs = <String>[];
      DioException? beforeLogger;
      final dio = Dio()
        ..httpClientAdapter = _MemoryAdapter(body: body)
        ..interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) {
              beforeLogger = error;
              handler.next(error);
            },
          ),
        )
        ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
      addTearDown(() => dio.close(force: true));

      DioException? caught;
      try {
        await dio.get<dynamic>(
          _url,
          options: Options(
            headers: {'Authorization': 'Bearer $_authSecret'},
            // Keep Dio's JSON parser but make its FormatException source a String.
            responseDecoder: (bytes, _, _) => utf8.decode(bytes),
          ),
        );
        fail('Expected malformed JSON to fail');
      } on DioException catch (error) {
        caught = error;
      }

      expect(caught, same(beforeLogger));
      expect(caught.type, DioExceptionType.unknown);
      expect(caught.error, isA<FormatException>());
      final formatError = caught.error! as FormatException;
      expect(formatError.source, body);
      expect(formatError.toString(), contains(_sourceSecret));
      final safeUri = safeHttpUri(caught.requestOptions.uri);
      expect(logs, ['HTTP GET $safeUri', 'HTTP unknown $safeUri']);
      _expectNoSecrets(logs);
    },
  );

  for (final type in [
    DioExceptionType.unknown,
    DioExceptionType.connectionError,
  ]) {
    test(
      '$type keeps the original exception without logging its details',
      () async {
        final logs = <String>[];
        final adapter = _MemoryAdapter(errorType: type);
        final dio = Dio()
          ..httpClientAdapter = adapter
          ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
        addTearDown(() => dio.close(force: true));

        DioException? caught;
        try {
          await dio.get<dynamic>(
            _url,
            options: Options(headers: {'Authorization': 'Bearer $_authSecret'}),
          );
          fail('Expected adapter error');
        } on DioException catch (error) {
          caught = error;
        }

        expect(caught, same(adapter.emittedError));
        expect(caught.type, type);
        expect(caught.message, _messageSecret);
        expect((caught.error! as FormatException).source, _sourceSecret);
        expect(caught.stackTrace.toString(), _stackSecret);
        final safeUri = safeHttpUri(caught.requestOptions.uri);
        expect(logs, ['HTTP GET $safeUri', 'HTTP ${type.name} $safeUri']);
        _expectNoSecrets(logs);
      },
    );
  }
}
