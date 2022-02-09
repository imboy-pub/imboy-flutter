import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:webcrypto/webcrypto.dart';

// The "iv" stands for initialization vector (IV). To ensure the encryption’s strength,
// each encryption process must use a random and distinct IV.
// It’s included in the message so that the decryption procedure can use it.
final Uint8List iv = Uint8List.fromList('Initialization Vector'.codeUnits);

Future<String> encryptMessage(
  String message,
  List<int> deriveKey,
) async {
  // Importing cryptoKey
  final aesGcmSecretKey = await AesGcmSecretKey.importRawKey(deriveKey);

  // Converting message into bytes
  final messageBytes = Uint8List.fromList(message.codeUnits);

  // Encrypting the message
  final encryptedMessageBytes = await aesGcmSecretKey.encryptBytes(
    messageBytes,
    iv,
  );

  // Converting encrypted message into String
  final encryptedMessage = String.fromCharCodes(encryptedMessageBytes);
  return encryptedMessage;
}

Future<String> decryptMessage(
  String encryptedMessage,
  List<int> deriveKey,
) async {
  // Importing cryptoKey
  final aesGcmSecretKey = await AesGcmSecretKey.importRawKey(deriveKey);

  // Converting message into bytes
  final messageBytes = Uint8List.fromList(encryptedMessage.codeUnits);

  // Decrypting the message
  final decryptedMessageBytes = await aesGcmSecretKey.decryptBytes(
    messageBytes,
    iv,
  );

  // Converting decrypted message into String
  final decryptedMessage = String.fromCharCodes(decryptedMessageBytes);
  return decryptedMessage;
}

// Generating keyPair using the function defined in above steps
// final keyPair = generateKeys();
Future<JsonWebKeyPair> generateKeys() async {
  debugPrint(">>> on e2ee ${EllipticCurve.p256.toString()}");
  final keyPair = await EcdhPrivateKey.generateKey(EllipticCurve.p256);
  final publicKeyJwk = await keyPair.publicKey.exportJsonWebKey();
  final privateKeyJwk = await keyPair.privateKey.exportJsonWebKey();

  return JsonWebKeyPair(
    privateKey: json.encode(privateKeyJwk),
    publicKey: json.encode(publicKeyJwk),
  );
}

// Model class for storing keys
class JsonWebKeyPair {
  const JsonWebKeyPair({
    required this.privateKey,
    required this.publicKey,
  });

  final String privateKey;
  final String publicKey;
}

// SendersJwk -> sender.privateKey
//1. Alice's public key
// Map<String, dynamic> publicjwk = json.decode(
//      '{"kty": "EC", "crv": "P-256", "x": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "y": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}');
// ReceiverJwk -> receiver.publicKey
Future<List<int>> deriveKey(String senderJwk, String receiverJwk) async {
  // Sender's key
  final senderPrivateKey = json.decode(senderJwk);
  final senderEcdhKey = await EcdhPrivateKey.importJsonWebKey(
    senderPrivateKey,
    EllipticCurve.p256,
  );

  // Receiver's key
  final receiverPublicKey = json.decode(receiverJwk);
  final receiverEcdhKey = await EcdhPublicKey.importJsonWebKey(
    receiverPublicKey,
    EllipticCurve.p256,
  );

  // Generating CryptoKey
  final derivedBits = await senderEcdhKey.deriveBits(256, receiverEcdhKey);
  return derivedBits;
}
