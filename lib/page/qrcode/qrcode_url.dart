import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/encrypter.dart';

/// 二维码数据 URL 构造（三处共用，防拼接漂移）。
///
/// 2026-08-08 修复：原实现漏 `/api/v1` 段（apiBaseUrl 为裸域名），
/// 扫出的码 GET `/user/qrcode` 等裸路径 404，扫码报「错误」。
/// 服务端路由统一 `/api/v1/*` 前缀（imboy_router.erl）。
///
/// [baseUrl] 仅测试注入用，生产走 [Env.apiBaseUrl]。
String buildUserQrcodeUrl(String uid, {String? baseUrl}) {
  final host = baseUrl ?? Env().apiBaseUrl;
  return '$host/api/v1/user/qrcode?id=$uid&$qrcodeDataSuffix';
}

/// Legacy compatibility checksum only: it grants no channel subscription,
/// invitation or payment rights. The server enforces those separately.
String buildChannelQrcodeUrl({
  required String channelId,
  required int expiredAt,
  String? baseUrl,
}) {
  final host = baseUrl ?? Env().apiBaseUrl;
  final tk = EncrypterService.md5('${expiredAt}_${Env().solidifiedKey}');
  return '$host/api/v1/channel/qrcode?id=$channelId&exp=$expiredAt&tk=$tk'
      '&$qrcodeDataSuffix';
}

/// Formats a server-issued, group-bound invitation. Never signs with app keys.
String buildGroupQrcodeUrl({
  required Object groupId,
  required int expiredAt,
  required String token,
  String? baseUrl,
}) {
  if (token.isEmpty) throw ArgumentError.value(token, 'token', 'required');
  final host = baseUrl ?? Env().apiBaseUrl;
  return '$host/api/v1/group/qrcode?id=${Uri.encodeQueryComponent('$groupId')}'
      '&exp=$expiredAt&tk=${Uri.encodeQueryComponent(token)}&$qrcodeDataSuffix';
}
