/// S16：Android/macOS 真实 ChatNetworkService C2C 外发帧验收。
///
/// 不登录、不连接后端、不创建好友或发送业务消息；预置一对真实
/// vodozemac Olm 会话后调用生产发送入口，验证 PFv3/Olm 信封、outbox
/// 提交和对端会话解密均成立。
library;

import 'dart:convert';

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
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

const _localUid = 'platform-c2c-sender-uid';
const _peerUid = 'platform-c2c-peer-uid';
const _localDid = 'platform-c2c-sender-did';
const _peerDid = 'platform-c2c-peer-did';
const _peerDid2 = 'platform-c2c-peer-did-2';
const _messageId = 'platform-c2c-e2ee-message';
const _plaintext = 'platform-c2c-secret-plaintext';
const _pickleKeyStorageKey = 'olm_pickle_key';

final Uint8List _pickleKey = Uint8List.fromList(
  List<int>.generate(32, (i) => (i * 11 + 5) % 256),
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

  test('ChatNetworkService C2C 双设备 fan-out 为 Olm PFv3 密文', () async {
    await StorageService.init();
    final previousUid = StorageService.to.getString(Keys.currentUid);
    final previousDeviceId = deviceId;
    await StorageService.to.setString(Keys.currentUid, _localUid);
    deviceId = _localDid;
    secureStore
      ..clear()
      ..[_pickleKeyStorageKey] = base64.encode(_pickleKey);
    // macOS 的集成测试进程可能在断言失败后留下同名 SQLCipher 文件；
    // 本测试使用固定 UID 便于断言，因此每次开始前只清理这个专用测试库，
    // 避免上一次的密钥不匹配污染本次结果。
    await SqliteService.to.close();
    await SqliteService.to.deleteDatabaseForUid(_localUid);
    final db = await SqliteService.to.db;
    if (db == null) {
      fail('平台 SQLCipher 数据库未能打开，拒绝把测试算作 E2EE 通过');
    }
    final store = CryptoStore(db);
    await store.ensureSchema();

    // Alice 是对端，Bob 是本机。把 Bob 的真实 inbound session 预置进
    // 生产 CryptoStore，发送路径随后会从该存储加载并推进 ratchet。
    final peerAccount = vod.Account();
    final localBootstrap = vod.Account()..generateOneTimeKeys(1);
    final peerSession = peerAccount.createOutboundSession(
      identityKey: localBootstrap.identityKeys.curve25519,
      oneTimeKey: localBootstrap.oneTimeKeys.values.first,
      config: legacyOlmSessionConfig(),
    );
    final handshake = peerSession.encrypt('platform-c2c-bootstrap');
    final localInbound = localBootstrap.createInboundSession(
      theirIdentityKey: peerAccount.identityKeys.curve25519,
      preKeyMessageBase64: handshake.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    expect(localInbound.plaintext, 'platform-c2c-bootstrap');
    await store.persistSession(
      peerUid: _peerUid,
      peerDeviceId: _peerDid,
      pickle: localInbound.session.toPickleEncrypted(_pickleKey),
    );

    final peerAccount2 = vod.Account();
    final localBootstrap2 = vod.Account()..generateOneTimeKeys(1);
    final peerSession2 = peerAccount2.createOutboundSession(
      identityKey: localBootstrap2.identityKeys.curve25519,
      oneTimeKey: localBootstrap2.oneTimeKeys.values.first,
      config: legacyOlmSessionConfig(),
    );
    final handshake2 = peerSession2.encrypt('platform-c2c-bootstrap-2');
    final localInbound2 = localBootstrap2.createInboundSession(
      theirIdentityKey: peerAccount2.identityKeys.curve25519,
      preKeyMessageBase64: handshake2.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    expect(localInbound2.plaintext, 'platform-c2c-bootstrap-2');
    await store.persistSession(
      peerUid: _peerUid,
      peerDeviceId: _peerDid2,
      pickle: localInbound2.session.toPickleEncrypted(_pickleKey),
    );

    final sent = <WebSocketMessageSendRequestEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(sent.add);
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    E2eeBootstrap.debugMarkReadyForTest(_localUid);
    E2EEService.setUserDeviceKeyCacheForTest(_peerUid, {
      _peerDid: 'peer-curve25519-placeholder',
      _peerDid2: 'peer-curve25519-placeholder-2',
    });

    try {
      final ok = await const ChatNetworkService().sendMessage({
        'id': _messageId,
        'type': 'C2C',
        'from': _localUid,
        'to': _peerUid,
        'msg_type': 'text',
        'action': '',
        'payload': <String, dynamic>{'msg_type': 'text', 'text': _plaintext},
      });
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(sent, hasLength(1));
      final frame = jsonDecode(sent.single.message) as Map<String, dynamic>;
      final e2ee = (frame['e2ee'] as Map).cast<String, dynamic>();
      final devices = (e2ee['devices'] as Map).cast<String, dynamic>();
      final envelope = (devices[_peerDid] as Map).cast<String, dynamic>();
      final protocolMetadata = (envelope['protocol_metadata'] as Map)
          .cast<String, dynamic>();

      expect(frame['id'], _messageId);
      expect(frame['type'], 'C2C');
      expect(frame['msg_type'], 'text');
      expect(frame['payload'], '');
      expect(frame['payload'], isNot(contains(_plaintext)));
      expect(e2ee['meta_version'], 3);
      expect(e2ee['protocol'], 'olm');
      expect(e2ee['version'], 1);
      expect(e2ee['fan_out'], 'per_device');
      expect(devices.keys, containsAll([_peerDid, _peerDid2]));
      // per-device envelope 在外层 fan-out 中不重复写 meta_version；接收侧
      // 提升为标准 v3 信封时补回该字段。
      expect(envelope.containsKey('meta_version'), isFalse);
      expect(envelope['protected_header'], isA<String>());
      expect(envelope['header_hash'], isA<String>());
      expect(protocolMetadata['e2ee_suite'], 'OLM.V1');
      expect(protocolMetadata['peer_uid'], _localUid);
      expect(protocolMetadata['peer_device_id'], _localDid);
      expect(protocolMetadata['session_id'], isNotEmpty);

      final verified = ProtectedFrameV3.verifyOuterEnvelope({
        'meta_version': 3,
        ...envelope,
      });
      expect(verified.isValid, isTrue);
      expect(verified.decodedHeader!['message_id'], _messageId);
      expect(verified.decodedHeader!['scope'], 'c2c');
      expect(verified.decodedHeader!['sender_uid'], _localUid);
      expect(verified.decodedHeader!['destination'], _peerUid);
      expect(verified.decodedHeader!['sender_did'], _localDid);

      final secondEnvelope = (devices[_peerDid2] as Map)
          .cast<String, dynamic>();
      final secondVerified = ProtectedFrameV3.verifyOuterEnvelope({
        'meta_version': 3,
        ...secondEnvelope,
      });
      expect(secondVerified.isValid, isTrue);
      expect(secondVerified.decodedHeader!['message_id'], _messageId);
      expect(secondVerified.decodedHeader!['destination'], _peerUid);

      // 把对端真实 Olm session 播种到生产存储，再走 App 的实际入站路由：
      // fan-out 选择 → PFv3 上下文绑定 → Olm Double Ratchet → inner payload。
      await store.persistSession(
        peerUid: _localUid,
        peerDeviceId: _localDid,
        pickle: peerSession.toPickleEncrypted(_pickleKey),
      );
      OlmSessionService.to.resetForTest();
      final senderDeviceId = deviceId;
      try {
        deviceId = _peerDid;
        // WS 服务端会从认证连接上下文回填可信 sender_did；捕获的是
        // 上行前客户端帧，因此在入站验收前只模拟这一个路由字段。
        final receivedFrame = <String, dynamic>{
          ...frame,
          'sender_did': _localDid,
        };
        final received = await E2EEService.decryptIncomingPayload(
          payload: receivedFrame,
        );
        expect(received['text'], _plaintext);
        expect(received['_e2ee_v3_verified'], isTrue);
      } finally {
        deviceId = senderDeviceId;
      }

      final outbox = await store.getOutboxEntry(_messageId);
      expect(outbox, isNotNull);
      expect(outbox!['status'], 'pending');
      expect(outbox['payload'], isNot(contains(_plaintext)));
      final outboxPayload = (jsonDecode(outbox['payload'] as String) as Map)
          .cast<String, dynamic>();
      expect(outboxPayload['payload'], '');
      final outboxE2ee = (outboxPayload['e2ee'] as Map).cast<String, dynamic>();
      expect(outboxE2ee['fan_out'], 'per_device');
      final outboxDevices = (outboxE2ee['devices'] as Map)
          .cast<String, dynamic>();
      expect(outboxDevices.keys, containsAll([_peerDid, _peerDid2]));
      final outboxEnvelope = (outboxDevices[_peerDid] as Map)
          .cast<String, dynamic>();
      final outboxVerified = ProtectedFrameV3.verifyOuterEnvelope({
        'meta_version': 3,
        ...outboxEnvelope,
      });
      expect(outboxVerified.isValid, isTrue);
      expect(outboxVerified.decodedHeader!['message_id'], _messageId);
    } finally {
      await subscription.cancel();
      MessageRetry.instance.clearRetryQueue();
      E2EEService.clearKeyCacheForTest();
      E2eeBootstrap.resetForTest();
      OlmSessionService.to.resetForTest();
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      await db.rawDelete('DELETE FROM crypto_outbox WHERE id = ?', [
        _messageId,
      ]);
      await db.rawDelete(
        'DELETE FROM crypto_olm_session WHERE peer_uid = ? AND peer_device_id = ?',
        [_peerUid, _peerDid],
      );
      await db.rawDelete(
        'DELETE FROM crypto_olm_session WHERE peer_uid = ? AND peer_device_id = ?',
        [_peerUid, _peerDid2],
      );
      await db.rawDelete(
        'DELETE FROM crypto_olm_session WHERE peer_uid = ? AND peer_device_id = ?',
        [_localUid, _localDid],
      );
      await SqliteService.to.close();
      await SqliteService.to.deleteDatabaseForUid(_localUid);
      deviceId = previousDeviceId;
      if (previousUid.isEmpty) {
        await StorageService.to.remove(Keys.currentUid);
      } else {
        await StorageService.to.setString(Keys.currentUid, previousUid);
      }
    }
  });
}
