// 成功回调
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/error_code.dart';

import 'http_exceptions.dart';
import 'http_response.dart';
import 'http_transformer.dart';
import 'package:imboy/i18n/strings.g.dart';

IMBoyHttpResponse handleResponse(
  Response<dynamic>? response, {
  required String uri,
  HttpTransformer? httpTransformer,
}) {
  httpTransformer ??= DefaultHttpTransformer.getInstance();

  // 返回值异常
  if (response == null) {
    return IMBoyHttpResponse.failureFromError();
  }

  // 接口调用成功
  if (_isRequestSuccess(response.statusCode)) {
    return httpTransformer.parse(response, uri);
  } else {
    iPrint(
      "handleResponse_response $uri : ${response.toString() == ''} ${response.toString()}; ",
    );
    if (response.toString() == '' || response.data == null) {
      // 当响应体为空时，使用状态码生成错误信息
      return IMBoyHttpResponse.failure(
        errMsg: _getErrorMessageForStatusCode(response.statusCode),
        errCode: response.statusCode,
        payload: null,
      );
    }
    // 安全访问响应数据
    final data = response.data;
    final code = data is Map
        ? _normalizeErrorCode(data['code'], response.statusCode)
        : (response.statusCode ?? 1);
    final msg = data is Map
        ? '${data['msg'] ?? _getErrorMessageForStatusCode(response.statusCode)}'
        : _getErrorMessageForStatusCode(response.statusCode);
    final payload = data is Map ? data['payload'] : null;

    // 处理 429 Too Many Requests
    if (int.tryParse('$code') == ErrorCode.TOO_MANY_REQUESTS) {
      // 检查 Retry-After header，显示倒计时提示
      final retryAfter = response.headers.value('retry-after');
      final retrySeconds = int.tryParse(retryAfter ?? '');
      if (retrySeconds != null && retrySeconds > 0) {
        AppLoading.showError(
          t.common.throttleRetryAfter(seconds: '$retrySeconds'),
          duration: Duration(seconds: retrySeconds.clamp(2, 10)),
        );
      } else {
        AppLoading.showError(t.common.throttleWarning);
      }
    }
    // 接口调用失败
    return IMBoyHttpResponse.failure(
      errMsg: msg,
      errCode: code,
      payload: payload,
    );
  }
}

IMBoyHttpResponse handleException(String uri, Exception exception) {
  var parseException = _parseException(exception);
  return IMBoyHttpResponse.failureFromError(error: parseException);
}

int _normalizeErrorCode(dynamic rawCode, int? fallbackStatus) {
  if (rawCode is int) return rawCode;
  if (rawCode is num) return rawCode.toInt();
  final parsed = int.tryParse('$rawCode');
  if (parsed != null) return parsed;
  return fallbackStatus ?? 1;
}

/// 请求成功
bool _isRequestSuccess(int? statusCode) {
  return (statusCode != null && statusCode >= 200 && statusCode < 300);
}

/// 根据状态码获取错误消息
String _getErrorMessageForStatusCode(int? statusCode) {
  switch (statusCode) {
    case ErrorCode.BAD_REQUEST:
      return t.common.errorRequestSyntax;
    case ErrorCode.UNAUTHORIZED:
      return t.common.noPermission;
    case ErrorCode.FORBIDDEN:
      return t.common.errorServerRefused;
    case ErrorCode.NOT_FOUND:
      return t.common.errorFailedConnectServer;
    case ErrorCode.METHOD_NOT_ALLOWED:
      return t.common.errorRequestForbidden;
    case ErrorCode.TOO_MANY_REQUESTS:
      return t.common.errorManyRequest;
    case ErrorCode.INTERNAL_SERVER_ERROR:
      return t.common.errorInternalServer;
    case ErrorCode.BAD_GATEWAY:
      return t.common.errorInvalidRequest;
    case ErrorCode.SERVICE_UNAVAILABLE:
      return t.common.errorServerDown;
    default:
      return 'HTTP $statusCode ${t.common.errorUnexpected}';
  }
}

HttpException _parseException(Exception error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException(message: error.message);
      case DioExceptionType.cancel:
        return CancelException(error.message);
      case DioExceptionType.badResponse:
        try {
          int? errCode = error.response?.statusCode;
          switch (errCode) {
            case ErrorCode.BAD_REQUEST:
              // 请求语法错误
              return BadRequestException(
                message: t.common.errorRequestSyntax,
                code: errCode,
              );
            case ErrorCode.UNAUTHORIZED:
              // 没有权限
              return UnauthorisedException(
                message: t.common.noPermission,
                code: errCode,
              );
            case ErrorCode.FORBIDDEN:
              // 服务器拒绝执行
              return BadRequestException(
                message: t.common.errorServerRefused,
                code: errCode,
              );
            case ErrorCode.NOT_FOUND:
              // 无法连接服务器
              return BadRequestException(
                message: t.common.errorFailedConnectServer,
                code: errCode,
              );
            case ErrorCode.METHOD_NOT_ALLOWED:
              // 请求方法被禁止
              return BadRequestException(
                message: t.common.errorRequestForbidden,
                code: errCode,
              );
            case ErrorCode.TOO_MANY_REQUESTS:
              return BadRequestException(
                message: t.common.errorManyRequest,
                code: errCode,
              );

            case ErrorCode.INTERNAL_SERVER_ERROR:
              // 服务器内部错误
              return BadServiceException(
                message: t.common.errorInternalServer,
                code: errCode,
              );
            case ErrorCode.BAD_GATEWAY:
              // 无效的请求
              return BadServiceException(
                message: t.common.errorInvalidRequest,
                code: errCode,
              );
            case ErrorCode.SERVICE_UNAVAILABLE:
              // 服务器挂了
              return BadServiceException(
                message: t.common.errorServerDown,
                code: errCode,
              );
            case 505:
              // 不支持HTTP协议请求
              return UnauthorisedException(
                message: t.common.errorHttpNotSupported,
                code: errCode,
              );
            default:
              return UnknownException(error.message);
          }
        } on Exception catch (_) {
          return UnknownException(error.message);
        }

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return NetworkException(message: error.message);
        } else {
          return UnknownException(error.message);
        }
      default:
        return UnknownException(error.message);
    }
  } else {
    return UnknownException(error.toString());
  }
}
