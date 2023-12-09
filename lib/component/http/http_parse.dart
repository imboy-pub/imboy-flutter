// 成功回调
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as getx;

import 'http_exceptions.dart';
import 'http_response.dart';
import 'http_transformer.dart';

IMBoyHttpResponse handleResponse(Response? response,
    {HttpTransformer? httpTransformer}) {
  httpTransformer ??= DefaultHttpTransformer.getInstance();

  // 返回值异常
  if (response == null) {
    return IMBoyHttpResponse.failureFromError();
  }

  // 接口调用成功
  if (_isRequestSuccess(response.statusCode)) {
    return httpTransformer.parse(response);
  } else {
    // 接口调用失败
    return IMBoyHttpResponse.failure(
      errMsg: response.data['msg'],
      errCode: response.data['code'],
      payload: response.data['payload'],
    );
  }
}

IMBoyHttpResponse handleException(Exception exception) {
  var parseException = _parseException(exception);
  debugPrint("> on handleException: ${parseException.message.toString()}");
  return IMBoyHttpResponse.failureFromError(error: parseException);
}

/// 请求成功
bool _isRequestSuccess(int? statusCode) {
  return (statusCode != null && statusCode >= 200 && statusCode < 300);
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
            case 400:
              return BadRequestException(message: '请求语法错误'.tr, code: errCode);
            case 401:
              return UnauthorisedException(message: '没有权限'.tr, code: errCode);
            case 403:
              return BadRequestException(message: '服务器拒绝执行'.tr, code: errCode);
            case 404:
              return BadRequestException(message: '无法连接服务器'.tr, code: errCode);
            case 405:
              return BadRequestException(message: '请求方法被禁止'.tr, code: errCode);
            case 500:
              return BadServiceException(message: '服务器内部错误'.tr, code: errCode);
            case 502:
              return BadServiceException(message: '无效的请求'.tr, code: errCode);
            case 503:
              return BadServiceException(message: '服务器挂了'.tr, code: errCode);
            case 505:
              return UnauthorisedException(
                  message: '不支持HTTP协议请求'.tr, code: errCode);
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
