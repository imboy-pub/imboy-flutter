import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/src/platform_check/platform_check.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

class RSAService {
  static const BEGIN_PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----';
  static const END_PRIVATE_KEY = '-----END PRIVATE KEY-----';

  static const BEGIN_PUBLIC_KEY = '-----BEGIN PUBLIC KEY-----';
  static const END_PUBLIC_KEY = '-----END PUBLIC KEY-----';

  // === 内存缓存 ===
  static String? _cachedPublicKey;
  static String? _cachedPrivateKey;

  static Future<String> publicKey() async {
    if (strNoEmpty(_cachedPublicKey)) {
      return _cachedPublicKey!;
    }
    String? k = await StorageSecureService().read(key: Keys.publicKey);
    if (strNoEmpty(k)) {
      _cachedPublicKey = k;
      return k!;
    }
    await _init();
    k = await StorageSecureService().read(key: Keys.publicKey);
    if (strNoEmpty(k)) {
      _cachedPublicKey = k;
    }
    return k!;
  }

  static Future<String?> privateKey() async {
    if (strNoEmpty(_cachedPrivateKey)) {
      return _cachedPrivateKey;
    }
    String? k = await StorageSecureService().read(key: Keys.privateKey);
    if (strNoEmpty(k)) {
      _cachedPrivateKey = k;
      return k;
    }
    await _init();
    k = await StorageSecureService().read(key: Keys.privateKey);
    if (strNoEmpty(k)) {
      _cachedPrivateKey = k;
    }
    return k;
  }

  static Future<void> _init() async {
    AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> p = generateRSAKeyPair();
    final publicPem = encodeRSAPublicKeyToPem(p.publicKey);
    final privatePem = encodeRSAPrivateKeyToPem(p.privateKey);

    await StorageSecureService().write(key: Keys.publicKey, value: publicPem);
    await StorageSecureService().write(key: Keys.privateKey, value: privatePem);

    _cachedPublicKey = publicPem;
    _cachedPrivateKey = privatePem;
  }

  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair(
      {int bitLength = 2048}) {
    final entropySource = Platform.instance.platformEntropySource();

    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(entropySource.getBytes(32)));

    final keyGen = RSAKeyGenerator();

    keyGen.init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom));

    final pair = keyGen.generateKeyPair();

    final myPublic = pair.publicKey as RSAPublicKey;
    final myPrivate = pair.privateKey as RSAPrivateKey;

    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(myPublic, myPrivate);
  }

  Uint8List rsaSign(RSAPrivateKey privateKey, Uint8List dataToSign) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');

    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final sig = signer.generateSignature(dataToSign);

    return sig.bytes;
  }

  bool rsaVerify(
      RSAPublicKey publicKey,
      Uint8List signedData,
      Uint8List signature,
      ) {
    final sig = RSASignature(signature);

    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');

    verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    try {
      return verifier.verifySignature(signedData, sig);
    } on ArgumentError {
      return false;
    }
  }

  Uint8List rsaEncrypt(RSAPublicKey myPublic, Uint8List dataToEncrypt) {
    final encryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(myPublic)); // true=encrypt

    return _processInBlocks(encryptor, dataToEncrypt);
  }

  Uint8List rsaDecrypt(RSAPrivateKey myPrivate, Uint8List cipherText) {
    final decryptor = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(myPrivate)); // false=decrypt

    return _processInBlocks(decryptor, cipherText);
  }

  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks = input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final output = Uint8List(numBlocks * engine.outputBlockSize);

    var inputOffset = 0;
    var outputOffset = 0;
    while (inputOffset < input.length) {
      final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - inputOffset;

      outputOffset += engine.processBlock(
          input, inputOffset, chunkSize, output, outputOffset);

      inputOffset += chunkSize;
    }

    return (output.length == outputOffset)
        ? output
        : output.sublist(0, outputOffset);
  }

  static Uint8List getBytesFromPEMString(String pem,
      {bool checkHeader = true}) {
    var lines = LineSplitter.split(pem)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    String base64;
    if (checkHeader) {
      if (lines.length < 2 ||
          !lines.first.startsWith('-----BEGIN') ||
          !lines.last.startsWith('-----END')) {
        throw ArgumentError('The given string does not have the correct '
            'begin/end markers expected in a PEM file.');
      }
      base64 = lines.sublist(1, lines.length - 1).join('');
    } else {
      base64 = lines.join('');
    }

    return Uint8List.fromList(base64Decode(base64));
  }

  static String encodeRSAPrivateKeyToPem(RSAPrivateKey rsaPrivateKey) {
    var version = ASN1Integer(BigInt.from(0));

    var algorithmSeq = ASN1Sequence();
    var algorithmAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList(
        [0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    var privateKeySeq = ASN1Sequence();
    var modulus = ASN1Integer(rsaPrivateKey.n);
    var publicExponent = ASN1Integer(BigInt.parse('65537'));
    var privateExponent = ASN1Integer(rsaPrivateKey.privateExponent);
    var p = ASN1Integer(rsaPrivateKey.p);
    var q = ASN1Integer(rsaPrivateKey.q);
    var dP = rsaPrivateKey.privateExponent! % (rsaPrivateKey.p! - BigInt.from(1));
    var exp1 = ASN1Integer(dP);
    var dQ = rsaPrivateKey.privateExponent! % (rsaPrivateKey.q! - BigInt.from(1));
    var exp2 = ASN1Integer(dQ);
    var iQ = rsaPrivateKey.q!.modInverse(rsaPrivateKey.p!);
    var co = ASN1Integer(iQ);

    privateKeySeq.add(version);
    privateKeySeq.add(modulus);
    privateKeySeq.add(publicExponent);
    privateKeySeq.add(privateExponent);
    privateKeySeq.add(p);
    privateKeySeq.add(q);
    privateKeySeq.add(exp1);
    privateKeySeq.add(exp2);
    privateKeySeq.add(co);
    var publicKeySeqOctetString =
    ASN1OctetString(octets: Uint8List.fromList(privateKeySeq.encode()));

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(version);
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqOctetString);
    var dataBase64 = base64.encode(topLevelSeq.encode());
    var chunks = StringHelper.chunk(dataBase64, 64);
    return '$BEGIN_PRIVATE_KEY\n${chunks.join('\n')}\n$END_PRIVATE_KEY';
  }

  static String encodeRSAPublicKeyToPem(RSAPublicKey publicKey) {
    var algorithmSeq = ASN1Sequence();
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
    algorithmSeq.add(paramsAsn1Obj);

    var publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus));
    publicKeySeq.add(ASN1Integer(publicKey.exponent));
    var publicKeySeqBitString =
    ASN1BitString(stringValues: Uint8List.fromList(publicKeySeq.encode()));

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);
    var dataBase64 = base64.encode(topLevelSeq.encode());
    var chunks = StringHelper.chunk(dataBase64, 64);

    return '$BEGIN_PUBLIC_KEY\n${chunks.join('\n')}\n$END_PUBLIC_KEY';
  }
}
