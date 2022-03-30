import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ImboyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
        '>>> on ImboyInterceptor/REQUEST[${options.method}] => PATH: ${options.path}');
    options.headers['Accept'] = Headers.jsonContentType;
    options.headers['device-type'] = Platform.operatingSystem;
    options.headers['device-type-vsn'] = Platform.operatingSystemVersion;

    String tk = UserRepoLocal.to.accessToken;
    // debugPrint(">>>>>>> on ImboyInterceptor tk" + (tk == null ? "" : tk));
    if (strNoEmpty(tk)) {
      options.headers[Keys.tokenKey] = tk;
    }
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    debugPrint(">>> on ImboyInterceptor/onError: ${err.message.toString()}");
    return super.onError(err, handler);
  }
}
