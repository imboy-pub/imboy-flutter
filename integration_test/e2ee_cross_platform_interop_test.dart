/// Android/macOS 跨平台 E2EE 互操作验收（无后端、无业务写入）。
///
/// 运行编排由 scripts/run_cross_platform_e2ee_interop.sh 完成：
/// 1. Android sender 用真实 ChatNetworkService 生成 Olm/PFv3 密文；
/// 2. macOS receiver 导入 Android 导出的会话状态，走真实入站解密并回发；
/// 3. Android final 端导入 sender 会话状态，解密 macOS 的回复。
///
/// 这里导出的 pickle 只存在进程间命令参数中，是临时测试密钥材料；测试
/// 使用固定的合成 UID/DID，不登录、不连接 WebSocket、不接触生产数据。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:integration_test/integration_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

const _senderUid = 'interop-android-uid';
const _senderDid = 'interop-android-did';
const _receiverUid = 'interop-macos-uid';
const _receiverDid = 'interop-macos-did';
const _messageId = 'interop-c2c-android-to-macos';
const _replyMessageId = 'interop-c2c-macos-to-android';
const _messageText = 'android-to-macos-e2ee-secret';
const _replyText = 'macos-to-android-e2ee-reply';
const _pickleKeyStorageKey = 'olm_pickle_key';

const _role = String.fromEnvironment(
  'TEST_INTEROP_ROLE',
  defaultValue: 'sender',
);
const _vectorBase64 = String.fromEnvironment(
  'TEST_INTEROP_VECTOR_B64',
  defaultValue: '',
);

final Uint8List _pickleKey = Uint8List.fromList(
  List<int>.generate(32, (index) => (index * 19 + 7) % 256),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'write':
              if (key != null) secureStore[key] = args?['value'] as String?;
              return null;
            case 'read':
              return key == null ? null : secureStore[key];
            case 'delete':
              if (key != null) secureStore.remove(key);
              return null;
            case 'containsKey':
              return key != null && secureStore.containsKey(key);
            case 'readAll':
              return Map<String, String>.fromEntries(
                secureStore.entries
                    .where((entry) => entry.value != null)
                    .map((entry) => MapEntry(entry.key, entry.value!)),
              );
            case 'deleteAll':
              secureStore.clear();
              return null;
            default:
              return null;
          }
        });
    await fvod.init();
    OlmSessionService.debugMarkVodReady();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('Android/macOS C2C Olm/PFv3 双向互解', () async {
    switch (_role) {
      case 'sender':
        await _runSender(secureStore);
      case 'receiver':
        await _runReceiverAndReply(secureStore);
      case 'final':
        await _runFinalReceiver(secureStore);
      default:
        fail('TEST_INTEROP_ROLE 必须是 sender、receiver 或 final');
    }
  });
}

Future<void> _runSender(Map<String, String?> secureStore) async {
  await _prepareLocalState(secureStore, uid: _senderUid, did: _senderDid);
  final db = await SqliteService.to.db;
  if (db == null) fail('Android sender SQLCipher 数据库未打开');
  final store = CryptoStore(db);
  await store.ensureSchema();

  final senderAccount = vod.Account();
  final receiverBootstrap = vod.Account()..generateOneTimeKeys(1);
  final senderSession = senderAccount.createOutboundSession(
    identityKey: receiverBootstrap.identityKeys.curve25519,
    oneTimeKey: receiverBootstrap.oneTimeKeys.values.first,
    config: legacyOlmSessionConfig(),
  );
  final bootstrap = senderSession.encrypt('interop-bootstrap');
  final receiverInbound = receiverBootstrap.createInboundSession(
    theirIdentityKey: senderAccount.identityKeys.curve25519,
    preKeyMessageBase64: bootstrap.ciphertext,
    config: legacyOlmSessionConfig(),
  );
  expect(receiverInbound.plaintext, 'interop-bootstrap');

  // 预先完成一次合成 X3DH 握手后，sender 使用入站端的同一双向会话
  // 发送 normal message；macOS 导入 outbound 端状态接收。这样不依赖
  // 远端 claim API，同时仍覆盖生产 ChatNetworkService/PFv3 路径。
  await store.persistSession(
    peerUid: _receiverUid,
    peerDeviceId: _receiverDid,
    pickle: receiverInbound.session.toPickleEncrypted(_pickleKey),
  );
  _markStrictReady(_senderUid, _receiverUid, _receiverDid);

  final sent = <WebSocketMessageSendRequestEvent>[];
  final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
      .listen(sent.add);
  final retry = MessageRetry.instance;
  try {
    final ok = await const ChatNetworkService().sendMessage({
      'id': _messageId,
      'type': 'C2C',
      'from': _senderUid,
      'to': _receiverUid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': _messageText},
    });
    retry.removeFromRetryQueue(_messageId);
    await Future<void>.delayed(Duration.zero);

    expect(ok, isTrue);
    expect(sent, hasLength(1));
    final frame = _decodeFrame(sent.single.message);
    _assertEncryptedC2cFrame(frame, _messageId, _messageText);

    final senderAfter = await store.loadSession(
      peerUid: _receiverUid,
      peerDeviceId: _receiverDid,
    );
    expect(senderAfter, isNotNull);
    final receiverBefore = senderSession.toPickleEncrypted(_pickleKey);
    _printVector({
      'frame': frame,
      'receiver_session_before': receiverBefore,
      'sender_session_after': senderAfter,
    });
  } finally {
    await subscription.cancel();
    await retry.debugWaitForIdle();
    retry.dispose();
    await _cleanupLocalState(secureStore, uid: _senderUid);
  }
}

Future<void> _runReceiverAndReply(Map<String, String?> secureStore) async {
  final vector = _readVector();
  final frame = _map(vector['frame']);
  await _prepareLocalState(secureStore, uid: _receiverUid, did: _receiverDid);
  final db = await SqliteService.to.db;
  if (db == null) fail('macOS receiver SQLCipher 数据库未打开');
  final store = CryptoStore(db);
  await store.ensureSchema();
  await store.persistSession(
    peerUid: _senderUid,
    peerDeviceId: _senderDid,
    pickle: vector['receiver_session_before'] as String,
  );
  _markStrictReady(_receiverUid, _senderUid, _senderDid);

  final received = await E2EEService.decryptIncomingPayload(
    payload: {...frame, 'sender_did': _senderDid},
  );
  if (received['_e2ee_failed'] == true) {
    fail('macOS E2EE 解密失败: ${received['_e2ee_reason']}');
  }
  expect(received['text'], _messageText, reason: 'macOS 解密结果: $received');
  expect(received['_e2ee_v3_verified'], isTrue);

  final sent = <WebSocketMessageSendRequestEvent>[];
  final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
      .listen(sent.add);
  final retry = MessageRetry.instance;
  try {
    final ok = await const ChatNetworkService().sendMessage({
      'id': _replyMessageId,
      'type': 'C2C',
      'from': _receiverUid,
      'to': _senderUid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': _replyText},
    });
    retry.removeFromRetryQueue(_replyMessageId);
    await Future<void>.delayed(Duration.zero);

    expect(ok, isTrue);
    expect(sent, hasLength(1));
    final reply = _decodeFrame(sent.single.message);
    _assertEncryptedC2cFrame(reply, _replyMessageId, _replyText);
    _printVector({
      'frame': reply,
      'sender_session_after': vector['sender_session_after'],
    });
  } finally {
    await subscription.cancel();
    await retry.debugWaitForIdle();
    retry.dispose();
    await _cleanupLocalState(secureStore, uid: _receiverUid);
  }
}

Future<void> _runFinalReceiver(Map<String, String?> secureStore) async {
  final vector = _readVector();
  final frame = _map(vector['frame']);
  await _prepareLocalState(secureStore, uid: _senderUid, did: _senderDid);
  final db = await SqliteService.to.db;
  if (db == null) fail('Android final SQLCipher 数据库未打开');
  final store = CryptoStore(db);
  await store.ensureSchema();
  await store.persistSession(
    peerUid: _receiverUid,
    peerDeviceId: _receiverDid,
    pickle: vector['sender_session_after'] as String,
  );
  _markStrictReady(_senderUid, _receiverUid, _receiverDid);

  try {
    final received = await E2EEService.decryptIncomingPayload(
      payload: {...frame, 'sender_did': _receiverDid},
    );
    if (received['_e2ee_failed'] == true) {
      fail('Android E2EE 解密回复失败: ${received['_e2ee_reason']}');
    }
    expect(received['text'], _replyText, reason: 'Android 解密回复结果: $received');
    expect(received['_e2ee_v3_verified'], isTrue);
    debugPrintSynchronously('E2EE_INTEROP_PASS: Android/macOS C2C Olm 双向互解');
  } finally {
    await _cleanupLocalState(secureStore, uid: _senderUid);
  }
}

Future<void> _prepareLocalState(
  Map<String, String?> secureStore, {
  required String uid,
  required String did,
}) async {
  await StorageService.init();
  await StorageService.to.setString(Keys.currentUid, uid);
  secureStore
    ..clear()
    ..[_pickleKeyStorageKey] = base64.encode(_pickleKey);
  await SqliteService.to.close();
  await SqliteService.to.deleteDatabaseForUid(uid);
  deviceId = did;
  OlmSessionService.to.resetForTest();
}

Future<void> _cleanupLocalState(
  Map<String, String?> secureStore, {
  required String uid,
}) async {
  E2EEService.clearKeyCacheForTest();
  E2eeBootstrap.resetForTest();
  OlmSessionService.to.resetForTest();
  EncryptionModeService.debugSet(
    mode: EncryptionMode.plaintext,
    initialized: false,
  );
  await SqliteService.to.close();
  await SqliteService.to.deleteDatabaseForUid(uid);
  secureStore.clear();
}

void _markStrictReady(String uid, String peerUid, String peerDid) {
  EncryptionModeService.debugSet(
    mode: EncryptionMode.strictE2ee,
    initialized: true,
  );
  E2eeBootstrap.debugMarkReadyForTest(uid);
  E2EEService.setUserDeviceKeyCacheForTest(peerUid, {
    peerDid: 'interop-public-key-$peerDid',
  });
}

Map<String, dynamic> _decodeFrame(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) fail('WebSocket 外发帧不是 JSON map');
  return Map<String, dynamic>.from(decoded);
}

void _assertEncryptedC2cFrame(
  Map<String, dynamic> frame,
  String messageId,
  String plaintext,
) {
  expect(frame['id'], messageId);
  expect(frame['type'], 'C2C');
  expect(frame['payload'], '');
  expect('$frame', isNot(contains(plaintext)));
  final e2ee = _map(frame['e2ee']);
  expect(e2ee['meta_version'], 3);
  expect(e2ee['protocol'], 'olm');
  expect(e2ee['fan_out'], 'per_device');
  final devices = _map(e2ee['devices']);
  final did = devices.keys.single;
  final envelope = _map(devices[did]);
  final verified = ProtectedFrameV3.verifyOuterEnvelope({
    'meta_version': 3,
    ...envelope,
  });
  expect(verified.isValid, isTrue);
  expect(verified.decodedHeader!['message_id'], messageId);
  expect(envelope['ciphertext'], isNotEmpty);
}

Map<String, dynamic> _readVector() {
  if (_vectorBase64.isEmpty) fail('TEST_INTEROP_VECTOR_B64 不能为空');
  try {
    final decoded = jsonDecode(utf8.decode(base64Url.decode(_vectorBase64)));
    return _map(decoded);
  } catch (error) {
    fail('跨平台 E2EE vector 解码失败: $error');
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  fail('预期 JSON map，实际为 ${value.runtimeType}');
}

void _printVector(Map<String, dynamic> vector) {
  final encoded = base64Url.encode(utf8.encode(jsonEncode(vector)));
  debugPrintSynchronously('E2EE_INTEROP_VECTOR_B64:$encoded');
}
