import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

/// 请求是否发往公开/预签名 Garage 存储 host（如 s3.imboy.pub）。
///
/// 这类请求**禁止**携带 App 的 JWT `Authorization` 头：否则经 nginx 反代时
/// `if ($http_authorization != "")` 会把它路由到 S3 API(3900)，Garage 把 JWT
/// 当 SigV4 解析 → 400 "Authorization field too short"。公开读应匿名走 website
/// 端(3902)，私有读应只带 presigned 的 X-Amz 查询签名（见 resource-access-control.md §9）。
@visibleForTesting
bool isPublicStorageRequest(Uri requestUri, String publicBaseUrl) {
  final String host = Uri.tryParse(publicBaseUrl)?.host ?? '';
  return host.isNotEmpty && requestUri.host == host;
}

class IMBoyInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = Headers.jsonContentType;
    options.headers['device-type'] = getOperatingSystem();
    options.headers['device-type-vsn'] = getSystemVersion();

    // 公开/预签名 Garage 资源不注入 App JWT（避免被 nginx 误判为 S3 API 请求
    // 而 400，且不向存储/CDN 泄露用户 token）。
    if (!isPublicStorageRequest(options.uri, Env.publicBaseUrl)) {
      String tk = await UserRepoLocal.to.accessToken;
      if (strNoEmpty(tk)) {
        options.headers[Keys.tokenKey] = tk;
      }
    }
    return super.onRequest(options, handler);
  }
}
