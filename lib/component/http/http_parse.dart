// 成功回调
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart';

import 'http_exceptions.dart';
import 'http_response.dart';
import 'http_transformer.dart';

IMBoyHttpResponse handleResponse(Response? response,
    {required String uri, HttpTransformer? httpTransformer}) {
  httpTransformer ??= DefaultHttpTransformer.getInstance();

  // 返回值异常
  if (response == null) {
    return IMBoyHttpResponse.failureFromError();
  }

  // 接口调用成功
  if (_isRequestSuccess(response.statusCode)) {
    return httpTransformer.parse(response, uri);
  } else {
    iPrint("handleResponse_response $uri : ${response.toString()==''} ${response.toString()}; ");
    if (response.toString()=='') {
      return IMBoyHttpResponse.failureFromError();
    }
    if (int.tryParse(response.data['code']) == 429) {
      EasyLoading.showError(response.data['msg']);
    }
    // 接口调用失败
    return IMBoyHttpResponse.failure(
      errMsg: response.data['msg'],
      errCode: response.data['code'],
      payload: response.data['payload'],
    );
  }
}

IMBoyHttpResponse handleException(String uri, Exception exception) {
  var parseException = _parseException(exception);
  debugPrint("> on handleException $uri: ${parseException.message.toString()}");
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
              // 请求语法错误
              return BadRequestException(
                message: 'error_request_syntax'.tr,
                code: errCode,
              );
            case 401:
              // 没有权限
              return UnauthorisedException(
                message: 'no_permission'.tr,
                code: errCode,
              );
            case 403:
              // 服务器拒绝执行
              return BadRequestException(
                message: 'error_server_refused'.tr,
                code: errCode,
              );
            case 404:
              // 无法连接服务器
              return BadRequestException(
                message: 'error_failed_connect_server'.tr,
                code: errCode,
              );
            case 405:
              // 请求方法被禁止
              return BadRequestException(
                message: 'error_request_forbidden'.tr,
                code: errCode,
              );
            case 429:
              return BadRequestException(
                message: 'Too Many Requests'.tr,
                code: errCode,
              );

            case 500:
              // 服务器内部错误
              return BadServiceException(
                message: 'error_internal_server'.tr,
                code: errCode,
              );
            case 502:
              // 无效的请求
              return BadServiceException(
                message: 'error_invalid_request'.tr,
                code: errCode,
              );
            case 503:
              // 服务器挂了
              return BadServiceException(
                message: 'error_server_down'.tr,
                code: errCode,
              );
            case 505:
              // 不支持HTTP协议请求
              return UnauthorisedException(
                message: 'error_http_not_supported'.tr,
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
