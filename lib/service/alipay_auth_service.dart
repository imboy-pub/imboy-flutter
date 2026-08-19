import 'package:tobias/tobias.dart';

/// 支付宝授权结果（sealed，调用方 exhaustive switch）
sealed class AlipayAuthResult {
  const AlipayAuthResult();
}

/// 授权成功，拿到 auth_code（回传服务端换登录态）
final class AlipayAuthSuccess extends AlipayAuthResult {
  const AlipayAuthSuccess(this.authCode);
  final String authCode;
}

/// 用户取消授权（resultStatus=6001），静默处理，不视为错误
final class AlipayAuthCancelled extends AlipayAuthResult {
  const AlipayAuthCancelled();
}

/// 授权失败（网络/系统异常/结果缺字段）
final class AlipayAuthFailure extends AlipayAuthResult {
  const AlipayAuthFailure(this.message);
  final String message;
}

/// 支付宝授权能力契约（隔离 tobias SDK，widget/单元测试可替换）
abstract interface class AlipayAuthGateway {
  /// authInfo 为服务端签名的授权串（GET /api/v1/passport/alipay_authinfo）
  Future<AlipayAuthResult> auth(String authInfo);
}

/// tobias（支付宝官方 SDK）实现
class TobiasAlipayAuthGateway implements AlipayAuthGateway {
  @override
  Future<AlipayAuthResult> auth(String authInfo) async {
    final Map<dynamic, dynamic> res = await Tobias().auth(authInfo);
    return parseAlipayAuthResponse(res);
  }
}

/// 解析支付宝 SDK 授权回调（纯函数，可单测）。
///
/// resultStatus: 9000 成功 / 6001 用户取消 / 6002 网络错误 / 其他失败。
/// result 形态两平台不一致：Android 为 query-string
/// （success=true&result_code=200&auth_code=xxx&...），iOS 可能直接是 Map。
AlipayAuthResult parseAlipayAuthResponse(Map<dynamic, dynamic> res) {
  final status = res['resultStatus']?.toString() ?? '';
  final raw = res['result'];
  switch (status) {
    case '9000':
      final code = _extractAuthCode(raw);
      if (code != null && code.isNotEmpty) {
        return AlipayAuthSuccess(code);
      }
      return const AlipayAuthFailure('授权结果缺少 auth_code');
    case '6001':
      return const AlipayAuthCancelled();
    case '6002':
      return const AlipayAuthFailure('网络连接出错，请稍后再试');
    default:
      final memo = res['memo']?.toString();
      return AlipayAuthFailure(
        (memo != null && memo.isNotEmpty) ? memo : '支付宝授权失败($status)',
      );
  }
}

String? _extractAuthCode(dynamic raw) {
  if (raw is Map) {
    return raw['auth_code']?.toString();
  }
  if (raw is String && raw.isNotEmpty) {
    return Uri.splitQueryString(raw)['auth_code'];
  }
  return null;
}
