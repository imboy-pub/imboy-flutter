/// link: https://www.jianshu.com/p/245a3b6b4037
///
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/api/passport_api.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/store/repository/user_repository.dart';

class Method {
  static final String get = "GET";
  static final String post = "POST";
  static final String put = "PUT";
  static final String head = "HEAD";
  static final String delete = "DELETE";
  static final String patch = "PATCH";
}

class DioUtil {
  static final DioUtil _instance = DioUtil._init();
  static Dio _dio;
  Map<String, dynamic> headers;

  factory DioUtil() {
    return _instance;
  }

  DioUtil._init() {
    if (this.headers == null) {
      this.headers = {};
    }
    this.headers['Accept'] = Headers.jsonContentType;
    this.headers['device-type'] = Platform.operatingSystem;
    this.headers['device-type-vsn'] = Platform.operatingSystemVersion;

    this.headers[Keys.tokenKey] = UserRepository.accessToken();
    _dio = new Dio();
  }

  Future<Map<String, dynamic>> get(String path,
      {pathParams, data, headers, Function errorCallback}) async {
    debugPrint(">>> get path {$path}");
    return request(path,
        method: Method.get,
        pathParams: pathParams,
        data: data,
        headers: headers,
        errorCallback: errorCallback);
  }

  Future<Map<String, dynamic>> post(String path,
      {pathParams, data, headers, Function errorCallback}) async {
    return request(path,
        method: Method.post,
        pathParams: pathParams,
        data: data,
        headers: headers,
        errorCallback: errorCallback);
  }

  Future<Map<String, dynamic>> request(String path,
      {String method,
      Map pathParams,
      data,
      Map<String, dynamic> headers,
      Function errorCallback}) async {
    ///restful请求处理
    if (pathParams != null) {
      pathParams.forEach((key, value) {
        if (path.indexOf(key) != -1) {
          path = path.replaceAll(":$key", value.toString());
        }
      });
    }
    this.headers[Keys.tokenKey] = UserRepository.accessToken();

    if (headers != null && headers.length > 0) {
      this.headers.addAll(headers);
    }
    // debugPrint(">>>>>>>> on token ${token}");
    var response = await _dio.request(
      path,
      data: data,
      options: Options(
          method: method,
          contentType: Headers.formUrlEncodedContentType,
          headers: this.headers),
    );
    debugPrint(">>>>>>>> on ${response.statusCode} ${response.toString()}");
    if (response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.created) {
      try {
        Map<String, dynamic> resp = response.data is Map
            ? response.data
            : json.decode(response.data.toString());
        int code = resp['code'] ?? 99999;
        debugPrint(">>>>>>>> on resp code >>> {$code}");
        switch (code) {
          case 705: // 刷新token
            {
              await refreshtoken();
              return request(path,
                  method: method,
                  pathParams: pathParams,
                  data: data,
                  headers: headers,
                  errorCallback: errorCallback);
            }
            break;
          case 706: // token无效，需要重新登录
            {
              Get.to(() => LoginPage());
            }
            break;
        }
        return resp;
      } catch (e) {
        return null;
      }
    } else {
      _handleHttpError(response.statusCode);
      if (errorCallback != null) {
        errorCallback(response.statusCode);
      }
      return null;
    }
  }

  ///处理Http错误码
  void _handleHttpError(int errorCode) {}
}
