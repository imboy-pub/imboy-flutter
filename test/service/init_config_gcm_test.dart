import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encrypter.dart';

/// `/api/v1/init` 配置下发的 GCM 互操作契约
///
/// 背景（#94）：原来是 AES-256-CBC + 固定 IV（`solidified_key_iv`）且**无认证
/// 标签**，客户端无法分辨密文是否被篡改，攻击者可重定向 ws_url / upload_url /
/// login_rsa_pub_key。后端新增 `res_v2` 走 `elib_cipher:aes_gcm_encrypt/2`。
///
/// 下面的密文**不是手写的**，是用后端真实实现跑出来的：
///   escript: elib_cipher:aes_gcm_encrypt(Json, <<32 个 "k">>)
/// 跨仓格式对不上是这类改动最容易翻车的地方，必须拿真实产物当测试向量。
///
/// 后端自包含布局：base64( Salt(16) ‖ IV(12) ‖ Ciphertext ‖ Tag(16) )，AAD = Salt。
void main() {
  // 32 字节密钥；生产里是 utf8(md5hex(signKey))，同样 32 字节
  final Uint8List key = Uint8List.fromList(utf8.encode('k' * 32));

  const String backendCiphertext =
      'GVyDUrG2cMcU1qG0OoSjORdAYNOu2JYzB6VYBSNDlX/O38v1ZJR5vpa3ez2uXUnu'
      'eVF5Q0S/oCP3tlpawBMg5z+EgALx9KTCWJdJhpMZd19ZHHoDTJc=';

  test('能解开后端 elib_cipher:aes_gcm_encrypt/2 的真实产物', () {
    final plain = utf8.decode(
      EncrypterService.aesGcmDecryptSelfContained(backendCiphertext, key),
    );
    expect(jsonDecode(plain), {'ws_url': 'wss://pro.imboy.pub/api/v1/ws'});
  });

  test('tag 区被篡改必须抛异常，不得静默解出脏数据', () {
    final chars = backendCiphertext.split('');
    final int i = chars.length - 3;
    chars[i] = chars[i] == 'A' ? 'B' : 'A';
    expect(
      () => EncrypterService.aesGcmDecryptSelfContained(chars.join(), key),
      throwsA(anything),
      reason: 'GCM 的认证标签就是用来挡这个的；CBC 版本会静默解出脏数据',
    );
  });

  test('密文正文被篡改同样必须抛异常', () {
    final chars = backendCiphertext.split('');
    // 挑一个正文区（跳过 salt/iv 对应的前 38 个 base64 字符）的字符改掉
    chars[45] = chars[45] == 'A' ? 'B' : 'A';
    expect(
      () => EncrypterService.aesGcmDecryptSelfContained(chars.join(), key),
      throwsA(anything),
    );
  });

  test('错误密钥必须抛异常', () {
    final wrongKey = Uint8List.fromList(utf8.encode('x' * 32));
    expect(
      () => EncrypterService.aesGcmDecryptSelfContained(
        backendCiphertext,
        wrongKey,
      ),
      throwsA(anything),
    );
  });

  test('长度不足 salt+iv+tag 的密文判非法', () {
    expect(
      () => EncrypterService.aesGcmDecryptSelfContained(
        base64.encode(List<int>.filled(20, 0)),
        key,
      ),
      throwsArgumentError,
    );
  });
}
