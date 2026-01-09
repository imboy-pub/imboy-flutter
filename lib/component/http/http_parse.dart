// 成功回调
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/error_code.dart';

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
    if (int.tryParse(response.data['code']) == ErrorCode.TOO_MANY_REQUESTS) {
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
            case ErrorCode.BAD_REQUEST:
              // 请求语法错误
              return BadRequestException(
                message: 'errorRequestSyntax'.tr,
                code: errCode,
              );
            case ErrorCode.UNAUTHORIZED:
              // 没有权限
              return UnauthorisedException(
                message: 'noPermission'.tr,
                code: errCode,
              );
            case ErrorCode.FORBIDDEN:
              // 服务器拒绝执行
              return BadRequestException(
                message: 'errorServerRefused'.tr,
                code: errCode,
              );
            case ErrorCode.NOT_FOUND:
              // 无法连接服务器
              return BadRequestException(
                message: 'errorFailedConnectServer'.tr,
                code: errCode,
              );
            case ErrorCode.METHOD_NOT_ALLOWED:
              // 请求方法被禁止
              return BadRequestException(
                message: 'errorRequestForbidden'.tr,
                code: errCode,
              );
            case ErrorCode.TOO_MANY_REQUESTS:
              return BadRequestException(
                message: 'errorManyRequest'.tr,
                code: errCode,
              );

            case ErrorCode.INTERNAL_SERVER_ERROR:
              // 服务器内部错误
              return BadServiceException(
                message: 'errorInternalServer'.tr,
                code: errCode,
              );
            case ErrorCode.BAD_GATEWAY:
              // 无效的请求
              return BadServiceException(
                message: 'errorInvalidRequest'.tr,
                code: errCode,
              );
            case ErrorCode.SERVICE_UNAVAILABLE:
              // 服务器挂了
              return BadServiceException(
                message: 'errorServerDown'.tr,
                code: errCode,
              );
            case 505:
              // 不支持HTTP协议请求
              return UnauthorisedException(
                message: 'errorHttpNotSupported'.tr,
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
