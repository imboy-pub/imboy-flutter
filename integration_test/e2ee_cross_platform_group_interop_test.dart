/// Android/macOS C2G Megolm + room-key-over-Olm 跨进程互操作验收。
///
/// 不登录、不连接后端、不写业务消息；只用合成的双设备 Olm 会话，
/// 调用真实 ChatNetworkService、GroupSessionService 和入站解密路由。
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
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

const _role = String.fromEnvironment('TEST_INTEROP_ROLE', defaultValue: '');
const _vectorBase64 = String.fromEnvironment(
  'TEST_INTEROP_VECTOR_B64',
  defaultValue: '',
);
const _gid = 'interop-group-gid';
const _senderUid = 'interop-android-uid';
const _senderDid = 'interop-android-did';
const _receiverUid = 'interop-macos-uid';
const _receiverDid = 'interop-macos-did';
const _messageId = 'interop-c2g-android-to-macos';
const _replyMessageId = 'interop-c2g-macos-to-android';
const _messageText = 'interop-c2g-android-secret';
const _replyText = 'interop-c2g-macos-secret';
const _pickleKeyStorageKey = 'olm_pickle_key';

final _pickleKey = Uint8List.fromList(
  List<int>.generate(32, (i) => (i * 17 + 3) % 256),
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
    GroupSessionService.debugMarkVodReady();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('Android/macOS C2G Megolm + Olm 双向互解', () async {
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

Future<vod.Session> _seedOlmPair({
  required CryptoStore store,
  required String peerUid,
  required String peerDid,
}) async {
  final senderAccount = vod.Account();
  final receiverAccount = vod.Account()..generateOneTimeKeys(1);
  final senderSession = senderAccount.createOutboundSession(
    identityKey: receiverAccount.identityKeys.curve25519,
    oneTimeKey: receiverAccount.oneTimeKeys.values.first,
    config: legacyOlmSessionConfig(),
  );
  final bootstrap = senderSession.encrypt('interop-group-olm-bootstrap');
  final receiverInbound = receiverAccount.createInboundSession(
    theirIdentityKey: senderAccount.identityKeys.curve25519,
    preKeyMessageBase64: bootstrap.ciphertext,
    config: legacyOlmSessionConfig(),
  );
  expect(receiverInbound.plaintext, 'interop-group-olm-bootstrap');
  // 与生产会话方向一致：发送端持久化握手后的 inbound 侧 session，
  // room-key 从 normal Olm message(type=1) 开始；向量导出 outbound
  // 侧 session，供另一端解包。这样不需要身份查询接口。
  await store.persistSession(
    peerUid: peerUid,
    peerDeviceId: peerDid,
    pickle: receiverInbound.session.toPickleEncrypted(_pickleKey),
  );
  return senderSession;
}

Future<void> _runSender(Map<String, String?> secureStore) async {
  await _prepareLocalState(secureStore, uid: _senderUid, did: _senderDid);
  final db = await SqliteService.to.db;
  if (db == null) fail('Android sender SQLCipher 数据库未打开');
  final store = CryptoStore(db);
  await store.ensureSchema();
  final receiverInbound = await _seedOlmPair(
    store: store,
    peerUid: 'uid_$_receiverDid',
    peerDid: _receiverDid,
  );
  _markStrictReady(_senderUid);
  E2EEService.setGroupDeviceKeyCacheForTest(_gid, {
    _senderDid: 'sender-public-key',
    _receiverDid: 'receiver-public-key',
  });

  Map<String, dynamic>? roomKey;
  final sent = <WebSocketMessageSendRequestEvent>[];
  final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
      .listen(sent.add);
  final retry = MessageRetry.instance;
  GroupSessionService.to.debugRoomKeySender = (chatType, to, payload) {
    expect(chatType, 'C2G');
    expect(to, _gid);
    roomKey = payload;
  };
  GroupSessionService.to.debugOlmWrap = (did, exportedKey) async {
    final result = await OlmSessionService.to.wrapRoomKey(
      peerUid: 'uid_$did',
      peerDeviceId: did,
      exportedKey: exportedKey,
    );
    if (result == null) fail('Android sender room-key Olm 包裹失败: $did');
    return result;
  };
  try {
    final ok = await const ChatNetworkService().sendMessage({
      'id': _messageId,
      'type': 'C2G',
      'from': _senderUid,
      'to': _gid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': _messageText},
    });
    retry.removeFromRetryQueue(_messageId);
    await Future<void>.delayed(Duration.zero);
    expect(ok, isTrue);
    expect(sent, hasLength(1));
    expect(roomKey, isNotNull);
    final frame = _decodeFrame(sent.single.message);
    _assertEncryptedGroupFrame(frame, _messageId, _messageText);
    expect(roomKey!['meta_version'], 3);
    expect(roomKey!['session_id'], _map(frame['e2ee'])['session_id']);
    final keys = roomKey!['keys'] as List;
    expect(keys, hasLength(1));
    final olm = _map(_map(keys.single)['olm']);
    expect(olm['v'], 'OLM.V1');
    expect(olm['sid'], _senderDid);

    final senderAfter = await store.loadSession(
      peerUid: 'uid_$_receiverDid',
      peerDeviceId: _receiverDid,
    );
    expect(senderAfter, isNotNull);
    _printVector({
      'frame': frame,
      'room_key': roomKey,
      'receiver_session_before': receiverInbound.toPickleEncrypted(_pickleKey),
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
  final incoming = _map(vector['frame']);
  final incomingRoomKey = _map(vector['room_key']);
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
  _markStrictReady(_receiverUid);
  await GroupSessionService.to.handleRoomKeyMessage({
    'type': 'C2G',
    'from': _senderUid,
    'to': _gid,
    'payload': incomingRoomKey,
  });
  final received = await E2EEService.decryptIncomingPayload(
    payload: {...incoming, 'gid': _gid, 'sender_did': _senderDid},
  );
  if (received['_e2ee_failed'] == true) {
    fail('macOS 群聊 E2EE 解密失败: ${received['_e2ee_reason']}');
  }
  expect(received['text'], _messageText);
  expect(received['_e2ee_megolm_verified'], isTrue);

  E2EEService.setGroupDeviceKeyCacheForTest(_gid, {
    _senderDid: 'sender-public-key',
    _receiverDid: 'receiver-public-key',
  });
  Map<String, dynamic>? replyRoomKey;
  GroupSessionService.to.debugRoomKeySender = (chatType, to, payload) {
    expect(chatType, 'C2G');
    expect(to, _gid);
    replyRoomKey = payload;
  };
  GroupSessionService.to.debugOlmWrap = (did, exportedKey) async {
    final result = await OlmSessionService.to.wrapRoomKey(
      peerUid: _senderUid,
      peerDeviceId: did,
      exportedKey: exportedKey,
    );
    if (result == null) fail('macOS receiver room-key Olm 包裹失败: $did');
    return result;
  };
  final sent = <WebSocketMessageSendRequestEvent>[];
  final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
      .listen(sent.add);
  final retry = MessageRetry.instance;
  try {
    final ok = await const ChatNetworkService().sendMessage({
      'id': _replyMessageId,
      'type': 'C2G',
      'from': _receiverUid,
      'to': _gid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': _replyText},
    });
    retry.removeFromRetryQueue(_replyMessageId);
    await Future<void>.delayed(Duration.zero);
    expect(ok, isTrue);
    expect(sent, hasLength(1));
    expect(replyRoomKey, isNotNull);
    final reply = _decodeFrame(sent.single.message);
    _assertEncryptedGroupFrame(reply, _replyMessageId, _replyText);
    _printVector({
      'frame': reply,
      'room_key': replyRoomKey,
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
  final incoming = _map(vector['frame']);
  final incomingRoomKey = _map(vector['room_key']);
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
  _markStrictReady(_senderUid);
  await GroupSessionService.to.handleRoomKeyMessage({
    'type': 'C2G',
    'from': _receiverUid,
    'to': _gid,
    'payload': incomingRoomKey,
  });
  final received = await E2EEService.decryptIncomingPayload(
    payload: {...incoming, 'gid': _gid, 'sender_did': _receiverDid},
  );
  if (received['_e2ee_failed'] == true) {
    fail('Android 群聊 E2EE 回复解密失败: ${received['_e2ee_reason']}');
  }
  expect(received['text'], _replyText);
  expect(received['_e2ee_megolm_verified'], isTrue);
  debugPrintSynchronously('E2EE_GROUP_INTEROP_PASS: Android/macOS C2G 双向互解');
  await _cleanupLocalState(secureStore, uid: _senderUid);
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
  GroupSessionService.to.clearMemory();
  OlmSessionService.to.resetForTest();
}

Future<void> _cleanupLocalState(
  Map<String, String?> secureStore, {
  required String uid,
}) async {
  GroupSessionService.to.clearMemory();
  GroupSessionService.to.debugRoomKeySender = null;
  GroupSessionService.to.debugOlmWrap = null;
  GroupSessionService.to.debugOlmUnwrap = null;
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

void _markStrictReady(String uid) {
  EncryptionModeService.debugSet(
    mode: EncryptionMode.strictE2ee,
    initialized: true,
  );
  E2eeBootstrap.debugMarkReadyForTest(uid);
}

Map<String, dynamic> _decodeFrame(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) fail('C2G 外发帧不是 JSON map');
  return Map<String, dynamic>.from(decoded);
}

void _assertEncryptedGroupFrame(
  Map<String, dynamic> frame,
  String messageId,
  String plaintext,
) {
  expect(frame['id'], messageId);
  expect(frame['type'], 'C2G');
  expect(frame['payload'], isA<String>());
  expect('$frame', isNot(contains(plaintext)));
  final e2ee = _map(frame['e2ee']);
  expect(e2ee['protocol'], 'megolm');
  expect(e2ee['e2ee_suite'], 'MEGOLM.V1');
  expect(e2ee['meta_version'], 2);
  expect(e2ee['gid'], _gid);
  expect(e2ee['session_id'], isNotEmpty);
}

Map<String, dynamic> _readVector() {
  if (_vectorBase64.isEmpty) fail('TEST_INTEROP_VECTOR_B64 不能为空');
  try {
    return _map(jsonDecode(utf8.decode(base64Url.decode(_vectorBase64))));
  } catch (error) {
    fail('C2G 跨平台 vector 解码失败: $error');
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  fail('预期 JSON map，实际为 ${value.runtimeType}');
}

void _printVector(Map<String, dynamic> vector) {
  debugPrintSynchronously(
    'E2EE_INTEROP_VECTOR_B64:${base64Url.encode(utf8.encode(jsonEncode(vector)))}',
  );
}
