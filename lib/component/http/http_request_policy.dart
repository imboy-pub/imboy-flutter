import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/web_writer_gate.dart';

const httpNoAutoRetry = 'http_no_auto_retry';
const httpSuppressErrorToast = 'http_suppress_error_toast';
const httpRequestGuard = 'http_request_guard';
const webFeatureSnapshotPath = '/api/v1/app/features';
const webSelfRegionSelectionPath = '/api/v1/web/user/region-selection';

const _webHumanMethods = <String, String>{
  'bootstrap': 'GET',
  'passport/login': 'POST',
  'refreshtoken': 'POST',
  'passport/qr_login/create': 'POST',
  'passport/qr_login/status': 'GET',
  'passport/qr_login/cancel': 'POST',
  'passport/qr_login/subscribe': 'GET',
  'msg/offline': 'GET',
  'msg/offline_ack': 'POST',
  'msg/history': 'GET',
  'msg': 'GET',
  'msg/result': 'GET',
  'e2ee/user_keys': 'GET',
  'e2ee/report_device_key': 'POST',
  'e2ee/devices': 'GET',
  'e2ee/olm/identity': 'POST',
  'e2ee/olm/prekeys': 'POST',
  'e2ee/olm/fallback_key': 'POST',
  'e2ee/olm/get_identity': 'GET',
  'e2ee/olm/prekey_count': 'GET',
  'e2ee/olm/claim': 'POST',
  'personal-history/status': 'GET',
  'personal-history/opt-in': 'POST',
  'personal-history/upload': 'POST',
  'personal-history/changes': 'GET',
  'personal-history/ack-cursor': 'POST',
  'personal-history/page': 'GET',
  'personal-history/key-package': 'POST',
  'personal-history/disable': 'POST',
  'personal-history/delete-status': 'GET',
  'conversation/mine': 'GET',
  'conversation/pin': 'POST',
  'conversation/unpin': 'POST',
  'conversation/delete': 'POST',
  'conversation/restore': 'POST',
  'conversation/pinned': 'GET',
  'conversation/manual_pending': 'POST',
  'conversation/manual_pending/list': 'GET',
  'friend/list': 'GET',
  'friend/add': 'POST',
  'friend/confirm': 'POST',
  'user/show': 'GET',
  'user/me': 'GET',
  'user/setting': 'POST',
  'fts/recently_user': 'GET',
  'user_device/delete': 'POST',
  'group/page': 'GET',
  'group/detail': 'GET',
  // JNY-06 web 建群族：与 backend web_human_routes/1 四别名一一对应
  // （ceedba693）。缺项时 webHumanRequestUri 本地抛出，请求不出网——
  // web 面建群四路径全败的客户端侧根因（R3b 证据）。
  'group/add': 'POST',
  'group/face2face': 'GET',
  'group/face2face_save': 'POST',
  'group_member/join': 'POST',
  'group_member/page': 'GET',
  'group_notice/page': 'GET',
  'attachment/direct/register': 'POST',
  'attachment/direct/declare': 'POST',
  'attachment/direct/grant': 'POST',
  'attachment/direct/renew': 'POST',
  'attachment/direct/finalize': 'POST',
  'attachment/direct/status': 'GET',
  'attachment/view_url': 'GET',
  'organizations/mine': 'GET',
  'workspaces/mine': 'GET',
  'channels/subscribed': 'GET',
  'channels/unread/summary': 'GET',
};

const _webPublicAppConfigPaths = <String>{
  webFeatureSnapshotPath,
  '/api/v1/app/manifest',
  '/api/v1/app/policy',
};

const webHumanPublicPaths = <String>{
  '/api/v1/init',
  '/api/v1/passport/login',
  '/api/v1/passport/qr_login/create',
  '/api/v1/passport/qr_login/status',
  '/api/v1/passport/qr_login/cancel',
  '/api/v1/passport/qr_login/subscribe',
  '/api/v1/web/bootstrap',
  '/api/v1/web/passport/login',
  '/api/v1/web/passport/qr_login/create',
  '/api/v1/web/passport/qr_login/status',
  '/api/v1/web/passport/qr_login/cancel',
  '/api/v1/web/passport/qr_login/subscribe',
  ..._webPublicAppConfigPaths,
};

/// Metadata allowed by Web Human CORS; credentials are added per request.
const webHumanMetadataHeaders = <String>{
  'content-type',
  'accept',
  'did',
  'dname',
  'vsn',
  'pkg',
  'terminology-profile',
  'tz_offset',
};

/// Explicit control aliases only. Resource/capability URLs use bare transports.
Uri webHumanRequestUri(String method, Uri input, Uri apiRoot) {
  const rejected = FormatException('Unsupported Web Human request');
  try {
    if (!{'http', 'https'}.contains(apiRoot.scheme) ||
        apiRoot.host.isEmpty ||
        apiRoot.userInfo.isNotEmpty ||
        !{'', '/'}.contains(apiRoot.path) ||
        apiRoot.hasQuery ||
        apiRoot.hasFragment) {
      throw rejected;
    }
    // Check before Dio's uri getter normalizes dot segments and double slashes.
    final rawUri = input.toString();
    final rawPath = rawUri.split(RegExp(r'[?#]')).first;
    if (rawPath.contains(RegExp(r'[%\\]')) ||
        rawPath.contains(RegExp(r'(^|/)\.{1,2}(/|$)'))) {
      throw rejected;
    }
    if (input.userInfo.isNotEmpty ||
        input.hasFragment ||
        (!input.hasScheme &&
            (!rawUri.startsWith('/') || rawUri.startsWith('//')))) {
      throw rejected;
    }
    final uri = apiRoot.resolveUri(input);
    if (uri.origin != apiRoot.origin ||
        uri.path.contains('//') ||
        uri.normalizePath().path != uri.path ||
        uri.queryParametersAll.keys.any(
          (key) => const {
            'tk',
            'rtk',
            'token',
            'refreshtoken',
            'authorization',
            'imboy-refreshtoken',
          }.contains(key.toLowerCase()),
        )) {
      throw rejected;
    }
    final verb = method.toUpperCase();
    if (_webPublicAppConfigPaths.contains(uri.path) && verb == 'GET') {
      return uri;
    }
    if (uri.path == webSelfRegionSelectionPath) {
      if (verb != 'POST' ||
          uri.hasQuery ||
          !const {'localhost', '127.0.0.1', '::1'}.contains(apiRoot.host)) {
        throw rejected;
      }
      return uri;
    }
    final web = uri.path.startsWith('/api/v1/web/');
    final prefix = web ? '/api/v1/web/' : '/api/v1/';
    if (!uri.path.startsWith(prefix)) throw rejected;
    final original = uri.path.substring(prefix.length);
    final suffix = !web && original == 'init' ? 'bootstrap' : original;
    if ((!web && suffix == 'bootstrap' && original != 'init') ||
        (suffix == 'msg' &&
            uri.queryParametersAll['action'] != null &&
            (uri.queryParametersAll['action']!.length != 1 ||
                uri.queryParameters['action'] != 'history_backfill'))) {
      throw rejected;
    }
    final dynamicRead = RegExp(
      r'^(workspaces/[1-9][0-9]*(/(branding|channels|groups))?|channel/[1-9][0-9]*(/messages)?)$',
    ).hasMatch(suffix);
    final readAllowed =
        verb == 'GET' &&
        (dynamicRead || suffix == 'personal-history/key-package');
    if (_webHumanMethods[suffix] != verb && !readAllowed) {
      throw rejected;
    }
    return uri.replace(path: '/api/v1/web/$suffix');
  } catch (_) {
    // Parsing errors must not echo raw URLs or capability/token values.
    throw rejected;
  }
}

/// Diagnostic URLs never include credentials, query values or fragments.
String safeHttpUri(Object uri) {
  final parsed = Uri.tryParse('$uri');
  if (parsed == null) return '[invalid-url]';
  return parsed
      .replace(
        userInfo: '',
        fragment: '',
        queryParameters: parsed.hasQuery
            ? {
                for (final key in parsed.queryParametersAll.keys)
                  key: '[REDACTED]',
              }
            : null,
      )
      .toString();
}

/// Runs last in the request chain, after asynchronous configuration/signing.
class HttpRequestGuardInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      requireWebWriter();
      final guard = options.extra[httpRequestGuard];
      if (guard != null) (guard as void Function())();
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Request guard rejected',
        ),
      );
    }
  }
}

/// Do not delegate to Dio's logger: it serializes full URLs and exceptions.
class SafeHttpLogInterceptor extends Interceptor {
  SafeHttpLogInterceptor({void Function(String)? log})
    : log = log ?? debugPrint;
  final void Function(String) log;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('HTTP ${options.method} ${safeHttpUri(options.uri)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log(
      'HTTP ${response.statusCode} ${safeHttpUri(response.requestOptions.uri)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('HTTP ${err.type.name} ${safeHttpUri(err.requestOptions.uri)}');
    handler.next(err);
  }
}
