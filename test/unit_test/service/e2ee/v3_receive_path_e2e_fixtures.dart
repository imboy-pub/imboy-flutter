part of 'v3_receive_path_e2e_test.dart';

const String _sessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';

/// 恒等协议：只替换密码学，不替换 wiring。
/// metadata 形状对照真实 `OlmProtocol.encrypt`（olm_protocol.dart:65-78）。
class _IdentityOlmProtocol implements E2eeSessionProtocol {
  bool rejectDuplicate = false;
  bool commitInbound = false;
  Future<void> Function()? beforeDecrypt;
  @override
  ProtocolSuite get suite => ProtocolSuite.olm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    return E2eeCiphertext(plaintext, {
      'protocol': suite.protocol,
      'version': suite.version,
      'e2ee_suite': suite.legacyWire,
      'peer_uid': '100',
      'peer_device_id': 'dev-sender',
      'message_type': 1,
      'session_id': _sessionId,
    });
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    if (rejectDuplicate) throw DuplicateMessageException('test');
    if (commitInbound) {
      final store = await OlmSessionService.to.cryptoStore;
      await store!.commitInboundResult(
        messageId: metadata['message_id'] as String,
        scope: metadata['inbox_scope'] as String,
        ciphertextDigest: metadata['ciphertext_digest'] as String,
        decryptedPayload: ciphertext,
      );
    }
    await beforeDecrypt?.call();
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

class _IdentityMegolmProtocol implements E2eeSessionProtocol {
  final List<Map<String, dynamic>> decryptMetadata = [];

  @override
  ProtocolSuite get suite => ProtocolSuite.megolm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async => E2eeCiphertext(plaintext, {
    'protocol': suite.protocol,
    'version': suite.version,
    'e2ee_suite': suite.legacyWire,
    'gid': 'group-1',
    'session_id': _sessionId,
  });

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    decryptMetadata.add(Map<String, dynamic>.from(metadata));
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

const plainBody = 'inbound v3 body';

/// 复刻 `chat_network_service._encryptC2COlmFanOut` 的实际产出形状：
/// e2ee 为 fan_out/devices 结构，**外层 payload 为空串**（密文在信封内）。
/// 信封挂在本机 deviceId 下，与生产接收侧按 deviceId 取信封一致。
Future<Map<String, dynamic>> buildV3Message(
  String msgId, {
  String action = 'message',
}) async {
  final myDid = deviceId;
  final encrypted = await E2eeOutboundRouter.encryptV3(
    suite: ProtocolSuite.olm,
    plaintext: jsonEncode({'msg_type': 'text', 'body': plainBody}),
    recipients: [
      RecipientDevice(deviceId: myDid, keyId: 'k1', publicKey: 'pk-1'),
    ],
    context: E2eeContext(peerUid: '200', peerDeviceId: myDid, scope: 'c2c'),
    messageId: msgId,
    senderUid: '100',
    senderDid: 'dev-sender',
    destination: '200',
    messageType: 'text',
    action: action,
    sessionRef: _sessionId,
    createdAtMs: 1753500000000,
  );

  final envelope = Map<String, dynamic>.from(encrypted.metadata);
  envelope.remove('meta_version');

  return {
    'id': msgId,
    'type': 'C2C',
    'from': '100',
    'to': '200',
    'msg_type': 'text',
    'e2ee': {
      'meta_version': 3,
      'protocol': 'olm',
      'version': 1,
      'fan_out': 'per_device',
      'devices': {myDid: envelope},
    },
    'payload': encrypted.ciphertext, // v3: 恒为空串
    'created_at': 1753500000000,
    'sender_did': 'dev-sender',
    'sender_dtype': 'ios',
  };
}

Future<void> seedExisting(
  Database db,
  Map<String, dynamic> frame,
  Object payload, {
  int status = 20,
}) => db
    .insert('msg_c2c', {
      'id': frame['id'],
      'type': frame['type'],
      'from_id': frame['from'],
      'to_id': frame['to'],
      'msg_type': frame['msg_type'],
      'sender_did': frame['sender_did'],
      'created_at': frame['created_at'],
      'e2ee': jsonEncode(frame['e2ee']),
      'payload': payload is String ? payload : jsonEncode(payload),
      'status': status,
      'is_author': 0,
      'topic_id': 0,
      'conversation_uk3': 'C2C_200_100',
    })
    .then((_) {});

(_IdentityOlmProtocol, _IdentityMegolmProtocol) _registerV3ReceiveProtocols() {
  // 顺序要紧：先让 bootstrap 完成一次真实注册（把内部 _registered 置 true），
  // 再清空 registry 换入恒等协议。否则解密时 ensureRegistered() 会再注册
  // 真实 OlmProtocol，与恒等协议撞 'already registered: olm'。
  E2eeBootstrap.resetForTest();
  E2eeBootstrap.ensureRegistered();
  E2eeProtocolRegistry.resetForTest();
  final olmProtocol = _IdentityOlmProtocol();
  E2eeProtocolRegistry.register(olmProtocol);
  final groupProtocol = _IdentityMegolmProtocol();
  E2eeProtocolRegistry.register(groupProtocol);
  return (olmProtocol, groupProtocol);
}

Future<void> _tearDownV3ReceiveFixture(Database db) async {
  MessageService.to.dispose();
  MessageRetry.instance.dispose();
  await MessageRetry.instance.debugWaitForIdle();
  E2eeBootstrap.resetForTest();
  SqliteService.setDbForTest(null);
  await db.close();
}

Map<String, dynamic> _v2OlmMessage() => {
  'id': 'inbound-v2-001',
  'type': 'C2C',
  'from': '100',
  'to': '200',
  'msg_type': 'text',
  'e2ee': {
    'protocol': 'olm',
    'version': 1,
    'e2ee_suite': 'OLM.V1',
    'session_id': _sessionId,
  },
  'payload': jsonEncode({'msg_type': 'text', 'body': plainBody}),
  'created_at': 1753500000000,
};

Map<String, dynamic> _v2MegolmMessage() => {
  'id': 'inbound-c2g-001',
  'type': 'C2G',
  'from': '100',
  'to': 'group-1',
  'msg_type': 'text',
  'e2ee': {
    'protocol': 'megolm',
    'version': 1,
    'e2ee_suite': 'MEGOLM.V1',
    'meta_version': 2,
    'gid': 'group-1',
    'session_id': _sessionId,
  },
  'payload': jsonEncode({'msg_type': 'text', 'body': plainBody}),
};
