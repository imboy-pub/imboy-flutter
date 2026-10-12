/// OA SSO 签发 API 客户端（EPGZ-06 W3 / plan §7.2；2026-10-12 定位修订 M3）。
///
/// `POST /api/v1/oa/sso/code`（Human JWT 走既有认证基建——HttpClient
/// 默认注入 token/refresh/401 重登录链路，本模块零额外认证代码）。
///
/// 响应解析与错误映射为纯函数（[parseOaSsoIssueResponse] /
/// [oaSsoIssueFailureFromCode]），网络壳仅做转发——测试可脱离 HTTP
/// 直测映射矩阵，也可经 [HttpClient.adapterForTest] 捕获真实请求。
///
/// 秘密边界：请求体只有 application_key（应用标识，非 secret）、
/// redirect_uri、nonce；一次性 code 只在内存中流转，不落盘。
/// 定位修订（organization 是业务对象，非租户）：application_key 实例内
/// 全局唯一，请求不再携带 organization_id（服务端兼容期容忍并忽略）。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_exceptions.dart'
    show NetworkException;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';

/// 签发端点（模块自有路径，A5 合同冻结）。
const String oaSsoCodePath = '/api/v1/oa/sso/code';

/// 解析签发响应（纯函数）。
///
/// 成功（resp.ok 且 payload 含非空 code）→ [OaSsoCodeIssued]；
/// redirect_uri 缺失时回退请求值（服务端合同必回显，回退仅容错）；
/// expires_in 缺失/非法回退合同恒值 60。
OaSsoIssueResult parseOaSsoIssueResponse(
  IMBoyHttpResponse resp, {
  required String fallbackRedirectUri,
}) {
  if (!resp.ok) {
    return OaSsoIssueFailed(oaSsoIssueFailureFromCode(resp));
  }
  final Map<String, dynamic> payload = IMBoyHttpResponse.payloadAsMap(
    resp.payload,
  );
  final String? code = IMBoyHttpResponse.payloadStr(payload, 'code');
  if (code == null || code.isEmpty) {
    // 200 但缺 code：服务端违约，按服务端错误处理（不可重试性未知，
    // 归 error 态由用户重试）。
    return const OaSsoIssueFailed(OaSsoIssueFailureKind.server);
  }
  final String? echoedRedirect = IMBoyHttpResponse.payloadStr(
    payload,
    'redirect_uri',
  );
  final int? expiresIn = IMBoyHttpResponse.payloadInt(payload, 'expires_in');
  return OaSsoCodeIssued(
    code: code,
    redirectUri: echoedRedirect == null || echoedRedirect.isEmpty
        ? fallbackRedirectUri
        : echoedRedirect,
    expiresInSeconds: expiresIn == null || expiresIn <= 0
        ? oaSsoCodeExpiresInSeconds
        : expiresIn,
  );
}

/// 失败响应 → 类别（纯函数）。
///
/// 判定序：网络异常（HttpClient 已把断网/超时归一为 NetworkException）
/// → HTTP/信封码（401/403/404/400/5xx）→ 其余 unknown。
OaSsoIssueFailureKind oaSsoIssueFailureFromCode(IMBoyHttpResponse resp) {
  if (resp.error is NetworkException) {
    return OaSsoIssueFailureKind.network;
  }
  switch (resp.code) {
    case 400:
      return OaSsoIssueFailureKind.badRequest;
    case 401:
      return OaSsoIssueFailureKind.unauthorized;
    case 403:
      return OaSsoIssueFailureKind.forbidden;
    case 404:
      return OaSsoIssueFailureKind.notFound;
    case 500:
    case 502:
    case 503:
    case 504:
      return OaSsoIssueFailureKind.server;
    default:
      return OaSsoIssueFailureKind.unknown;
  }
}

/// OA SSO 签发 API。
class OaSsoApi extends HttpClient {
  /// 换取 60 秒一次性 code（Human JWT 由既有认证基建注入）。
  Future<OaSsoIssueResult> issueCode({
    required String applicationKey,
    required String redirectUri,
    required String nonce,
  }) async {
    final resp = await post(
      oaSsoCodePath,
      data: {
        'application_key': applicationKey,
        'redirect_uri': redirectUri,
        'nonce': nonce,
      },
    );
    return parseOaSsoIssueResponse(resp, fallbackRedirectUri: redirectUri);
  }
}
