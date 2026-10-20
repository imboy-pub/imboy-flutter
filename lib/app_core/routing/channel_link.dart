import 'package:imboy/config/const.dart';

/// 资源定位符不包含访问凭证，读取仍由服务端鉴权。
String channelLink(String channelId, {String? messageId, String? baseUrl}) {
  final base = Uri.parse(baseUrl ?? webBaseUrl);
  if (base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      (base.path.isNotEmpty && base.path != '/')) {
    throw StateError('WEB_BASE_URL must be an HTTPS origin');
  }
  return base
      .replace(
        pathSegments: [
          ...base.pathSegments.where((part) => part.isNotEmpty),
          'channel',
          channelId,
          if (messageId != null) ...['article', messageId],
        ],
        query: null,
        fragment: null,
      )
      .toString();
}

/// 仅识别本站频道链接，避免把任意扫码地址交给带认证的请求客户端。
String? channelLinkLocation(String value, {String? baseUrl}) {
  final uri = Uri.tryParse(value);
  final base = Uri.parse(baseUrl ?? webBaseUrl);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.hasQuery) {
    return null;
  }
  final trustedWeb =
      uri.scheme == base.scheme &&
      uri.host == base.host &&
      uri.port == base.port;
  final trustedApp =
      uri.scheme == 'imboy' && uri.host == base.host && !uri.hasPort;
  if (!trustedWeb && !trustedApp) return null;
  final parts = uri.pathSegments;
  if (parts.length != 2 && parts.length != 4) return null;
  if (parts.first != 'channel' || !_id(parts[1])) return null;
  if (parts.length == 4 && (parts[2] != 'article' || !_id(parts[3]))) {
    return null;
  }
  return '/${parts.join('/')}';
}

bool _id(String value) =>
    RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value) &&
    BigInt.parse(value) <= BigInt.parse('9223372036854775807');
