import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const httpNoAutoRetry = 'http_no_auto_retry';
const httpRequestGuard = 'http_request_guard';

/// Diagnostic URLs never include credentials, query values or fragments.
String safeHttpUri(Object uri) {
  final parsed = Uri.tryParse('$uri');
  if (parsed == null) return '[invalid-url]';
  return parsed
      .replace(
        userInfo: '',
        fragment: '',
        queryParameters: parsed.hasQuery
            ? {
                for (final key in parsed.queryParametersAll.keys)
                  key: '[REDACTED]',
              }
            : null,
      )
      .toString();
}

/// Runs last in the request chain, after asynchronous configuration/signing.
class HttpRequestGuardInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final guard = options.extra[httpRequestGuard];
      if (guard != null) (guard as void Function())();
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Request guard rejected',
        ),
      );
    }
  }
}

/// Do not delegate to Dio's logger: it serializes full URLs and exceptions.
class SafeHttpLogInterceptor extends Interceptor {
  SafeHttpLogInterceptor({void Function(String)? log})
    : log = log ?? debugPrint;
  final void Function(String) log;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('HTTP ${options.method} ${safeHttpUri(options.uri)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log(
      'HTTP ${response.statusCode} ${safeHttpUri(response.requestOptions.uri)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('HTTP ${err.type.name} ${safeHttpUri(err.requestOptions.uri)}');
    handler.next(err);
  }
}
