part of 'passport_notifier.dart';

String formatJverifyLoginError(int? code, String? message) {
  final detail = message?.trim() ?? '';
  final codeText = code?.toString() ?? 'unknown';
  return detail.isEmpty
      ? '一键登录失败（错误码 $codeText）'
      : '一键登录失败（错误码 $codeText）：$detail';
}

/// 兼容重试只切换密码预哈希，保留服务端要求的 RSA 传输。
Future<Map<String, dynamic>> encodePassportPassword(
  String password,
  Map<String, dynamic> config, {
  bool prehash = true,
}) async {
  final value = prehash ? EncrypterService.md5(password) : password;
  final rsaEncrypt = config['login_pwd_rsa_encrypt'].toString();
  return {
    'password': rsaEncrypt == '1'
        ? await RSAService.rsaEncryptWithPointyCastleAsync(
            value,
            config['login_rsa_pub_key'].toString(),
          )
        : value,
    'rsa_encrypt': rsaEncrypt,
    'pwd_was_md5': prehash && rsaEncrypt != '1',
  };
}
