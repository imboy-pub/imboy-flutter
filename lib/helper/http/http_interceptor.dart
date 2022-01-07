import 'dart:io';

import 'package:dio/dio.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ImboyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('REQUEST[${options.method}] => PATH: ${options.path}');
    options.headers['Accept'] = Headers.jsonContentType;
    options.headers['device-type'] = Platform.operatingSystem;
    options.headers['device-type-vsn'] = Platform.operatingSystemVersion;

    String tk = UserRepoLocal.user.accessToken;
    // debugPrint(">>>>>>> on ImboyInterceptor tk" + (tk == null ? "" : tk));
    if (strNoEmpty(tk)) {
      options.headers[Keys.tokenKey] = tk;
    }

    // if (options.headers['refreshToken'] == null) {
    //   DioUtil.instance.dio.lock();
    //   Dio _tokenDio = Dio();
    //   _tokenDio..get("http://localhost:8080/getRefreshToken").then((d) {
    //     options.headers['refreshToken'] = d.data['data']['token'];
    //     handler.next(options);
    //   }).catchError((error, stackTrace) {
    //     handler.reject(error, true);
    //   }) .whenComplete(() {
    //     DioUtil.instance.dio.unlock();
    //   }); // unlock the dio
    // } else {
    //   options.headers['refreshToken'] = options.headers['refreshToken'];
    //   handler.next(options);
    // }

    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    return super.onError(err, handler);
  }
}
