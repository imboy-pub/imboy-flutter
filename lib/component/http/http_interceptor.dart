import 'package:dio/dio.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

class IMBoyInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = Headers.jsonContentType;
    options.headers['device-type'] = getOperatingSystem();
    options.headers['device-type-vsn'] = getSystemVersion();

    String tk = await UserRepoLocal.to.accessToken;
    if (strNoEmpty(tk)) {
      options.headers[Keys.tokenKey] = tk;
    }
    return super.onRequest(options, handler);
  }
}
