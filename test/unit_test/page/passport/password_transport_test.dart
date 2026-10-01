import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as asn1;
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';

({pc.RSAPrivateKey privateKey, String pem}) _keys() {
  final random = Random.secure();
  final rng = pc.SecureRandom('Fortuna')
    ..seed(
      pc.KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      ),
    );
  final generator = pc.RSAKeyGenerator()
    ..init(
      pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        rng,
      ),
    );
  final pair = generator.generateKeyPair();
  final public = pair.publicKey;
  final algorithm = asn1.ASN1Sequence()
    ..add(asn1.ASN1ObjectIdentifier.fromName('rsaEncryption'))
    ..add(asn1.ASN1Null());
  final key = asn1.ASN1Sequence()
    ..add(asn1.ASN1Integer(public.modulus))
    ..add(asn1.ASN1Integer(public.exponent));
  final spki = asn1.ASN1Sequence()
    ..add(algorithm)
    ..add(asn1.ASN1BitString(stringValues: key.encode()));
  return (
    privateKey: pair.privateKey,
    pem:
        '-----BEGIN PUBLIC KEY-----\n${base64Encode(spki.encode())}\n'
        '-----END PUBLIC KEY-----',
  );
}

void main() {
  const password = 'Synthetic-password-42';
  final keys = _keys();

  test('RSA 兼容重试仍为密文，真实 OAEP 解密得到原始密码', () async {
    final config = {
      'login_pwd_rsa_encrypt': '1',
      'login_rsa_pub_key': keys.pem,
    };
    final first = await encodePassportPassword(password, config);
    final retry = await encodePassportPassword(
      password,
      config,
      prehash: false,
    );
    for (final request in [first, retry]) {
      expect(request['rsa_encrypt'], '1');
      expect(request['password'], isNot(password));
    }
    String decrypt(Map<String, dynamic> request) => utf8.decode(
      RSAService.rsaDecrypt(
        keys.privateKey,
        base64Decode(request['password'] as String),
      ),
    );
    expect(decrypt(first), EncrypterService.md5(password));
    expect(decrypt(retry), password);
    expect(config['login_pwd_rsa_encrypt'], '1');
  });

  test('未启用 RSA 时保留既有预哈希与原始密码重试协议', () async {
    final config = {'login_pwd_rsa_encrypt': '0'};
    final first = await encodePassportPassword(password, config);
    final retry = await encodePassportPassword(
      password,
      config,
      prehash: false,
    );
    expect(first['password'], EncrypterService.md5(password));
    expect(first['pwd_was_md5'], isTrue);
    expect(retry['password'], password);
    expect(retry['rsa_encrypt'], '0');
    expect(retry['pwd_was_md5'], isFalse);
  });

  test('RSA 公钥无效时重试失败，不能退化为原始密码传输', () async {
    await expectLater(
      encodePassportPassword(password, {
        'login_pwd_rsa_encrypt': '1',
        'login_rsa_pub_key': 'invalid-synthetic-key',
      }, prehash: false),
      throwsException,
    );
  });
}
