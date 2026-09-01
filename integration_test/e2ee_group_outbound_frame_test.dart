/// S15：Android/macOS 真实 ChatNetworkService C2G 外发帧验收。
///
/// 不登录、不连接后端、不创建群、不写业务消息；只调用生产发送入口，
/// 捕获准备发送到 WebSocket 的事件，验证群级 Megolm 密文和 room-key
/// 分发编排在真实平台原生库上成立。
library;

import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:integration_test/integration_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart'
    show ProtectedFrameV3;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

const _gid = '700001';
const _senderUid = '100001';
const _senderDid = 'platform-sender-did';
const _peerDid = 'platform-peer-did';
const _messageId = 'platform-c2g-e2ee-message';
const _plaintext = 'platform-c2g-secret-plaintext';
const _pickleKeyStorageKey = 'olm_pickle_key';

final _pickleKey = Uint8List.fromList(
  List<int>.generate(32, (i) => (i * 17 + 3) % 256),
);

Future<vod.Session> _seedPeerOlmSession({
  required CryptoStore store,
  required String peerUid,
  required String peerDid,
}) async {
  final senderAccount = vod.Account();
  final peerAccount = vod.Account()..generateOneTimeKeys(1);
  final senderSession = senderAccount.createOutboundSession(
    identityKey: peerAccount.identityKeys.curve25519,
    oneTimeKey: peerAccount.oneTimeKeys.values.first,
    config: legacyOlmSessionConfig(),
  );
  final handshake = senderSession.encrypt('group-room-key-bootstrap');
  final peerInbound = peerAccount.createInboundSession(
    theirIdentityKey: senderAccount.identityKeys.curve25519,
    preKeyMessageBase64: handshake.ciphertext,
    config: legacyOlmSessionConfig(),
  );
  expect(peerInbound.plaintext, 'group-room-key-bootstrap');
  await store.persistSession(
    peerUid: peerUid,
    peerDeviceId: peerDid,
    pickle: senderSession.toPickleEncrypted(_pickleKey),
  );
  return peerInbound.session;
}

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

  test('ChatNetworkService C2G 外发帧为 Megolm 密文', () async {
    await StorageService.init();
    final previousUid = StorageService.to.getString(Keys.currentUid);
    final previousUser = StorageService.getMap(Keys.currentUser);
    await StorageService.to.setString(Keys.currentUid, _senderUid);
    if (previousUser.isEmpty) {
      await StorageService.setMap(Keys.currentUser, {
        'user_id': _senderUid,
        'account': 'platform-e2ee-test',
        'nickname': 'platform-e2ee-test',
      });
    }
    final previousDeviceId = deviceId;
    deviceId = _senderDid;
    secureStore
      ..clear()
      ..[_pickleKeyStorageKey] = base64.encode(_pickleKey);
    await SqliteService.to.close();
    await SqliteService.to.deleteDatabaseForUid(_senderUid);
    final db = await SqliteService.to.db;
    if (db == null) {
      fail('平台 SQLCipher 数据库未能打开，拒绝把群聊测试算作通过');
    }
    final store = CryptoStore(db);
    await store.ensureSchema();
    OlmSessionService.to.resetForTest();
    final peerInbound = await _seedPeerOlmSession(
      store: store,
      peerUid: 'uid_$_peerDid',
      peerDid: _peerDid,
    );
    final peerDid2 = 'platform-peer-did-2';
    final peerInbound2 = await _seedPeerOlmSession(
      store: store,
      peerUid: 'uid_$peerDid2',
      peerDid: peerDid2,
    );
    final sent = <WebSocketMessageSendRequestEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(sent.add);
    final retry = MessageRetry.instance;
    Map<String, dynamic>? roomKey;

    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    E2eeBootstrap.debugMarkReadyForTest(_senderUid);
    E2EEService.setGroupDeviceKeyCacheForTest(_gid, {
      _senderDid: 'sender-pem-placeholder',
      _peerDid: 'peer-pem-placeholder',
      peerDid2: 'peer-pem-placeholder-2',
    });
    GroupSessionService.to.debugRoomKeySender = (chatType, to, payload) {
      expect(chatType, 'C2G');
      expect(to, _gid);
      roomKey = payload;
    };

    try {
      final ok = await const ChatNetworkService().sendMessage({
        'id': _messageId,
        'type': 'C2G',
        'from': _senderUid,
        'to': _gid,
        'msg_type': 'text',
        'action': '',
        'payload': <String, dynamic>{'msg_type': 'text', 'text': _plaintext},
      });
      // 该验收不连接 WebSocket；sendMessage 会按生产路径把消息加入
      // MessageRetry。测试后续会清理专用数据库，必须先移出队列，避免
      // 5 秒重试扫描在清理阶段异步调用 toTypeMessage，读取已恢复的
      // currentUid 而形成竞态失败。
      retry.removeFromRetryQueue(_messageId);
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(sent, hasLength(1));
      final frame = jsonDecode(sent.single.message) as Map<String, dynamic>;
      final e2ee = (frame['e2ee'] as Map).cast<String, dynamic>();
      expect(frame['id'], _messageId);
      expect(frame['type'], 'C2G');
      expect(frame['msg_type'], 'text');
      // PFv3（E2EE-025）：外层 payload 恒为空串，密文在信封内
      expect(frame['payload'], '');
      // v3 外层信封结构——C2G 已从 v2 扁平 metadata 统一升级为 PFv3 信封
      expect(e2ee['meta_version'], 3);
      final protocolMetadata = (e2ee['protocol_metadata'] as Map)
          .cast<String, dynamic>();
      expect(protocolMetadata['protocol'], 'megolm');
      expect(protocolMetadata['version'], 1);
      expect(protocolMetadata['e2ee_suite'], 'MEGOLM.V1');
      expect(protocolMetadata['gid'], _gid);
      final sessionId = protocolMetadata['session_id'] as String;
      expect(sessionId, isNotEmpty);
      final verified = ProtectedFrameV3.verifyOuterEnvelope(e2ee);
      expect(verified.isValid, isTrue);
      expect(verified.decodedHeader!['message_id'], _messageId);
      // Megolm 密文 = base64url(utf8(innerFrameB64))
      final megolmCiphertext = utf8.decode(
        base64Url.decode(e2ee['ciphertext'] as String),
      );
      expect(megolmCiphertext, isNot(contains(_plaintext)));

      // 生产入站路径验收（v3 信封 → Megolm → inner frame payload）。
      // WS 服务端会从认证连接上下文回填可信 sender_did；捕获的是上行前
      // 客户端帧，入站验收前模拟这一个路由字段（与 C2C 验收同款）。
      final received = await E2EEService.decryptIncomingPayload(
        payload: {...frame, 'sender_did': _senderDid},
      );
      expect(
        received['_e2ee_failed'],
        isNull,
        reason: 'v3 解密失败 reason=${received['_e2ee_reason']}',
      );
      expect(received['text'], _plaintext);
      expect(received['_e2ee_v3_verified'], isTrue);

      // 模拟重进会话：清掉内存会话后，接收侧必须从安全存储恢复 inbound。
      GroupSessionService.to.clearMemory();
      final recovered = await E2EEService.decryptIncomingPayload(
        payload: {...frame, 'sender_did': _senderDid},
      );
      expect(recovered['_e2ee_failed'], isNull);
      expect(recovered['text'], _plaintext);

      // 同一真实 Megolm 密文再走生产离线/历史消息映射入口，确认 UI 层
      // 不是只在 GroupSessionService 直调时能解密。
      final mapped = await MessageModel(
        frame['id'] as String,
        autoId: 1,
        type: 'C2G',
        status: IMBoyMessageStatus.delivered,
        fromId: int.parse(_senderUid),
        toId: int.parse(_gid),
        payload: frame['payload'] as String,
        isAuthor: 0,
        conversationUk3: 'C2G_$_gid',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        msgType: 'text',
        action: '',
        e2ee: e2ee,
        senderDid: _senderDid,
      ).toTypeMessage();
      expect(mapped, isA<TextMessage>());
      expect((mapped as TextMessage).text, _plaintext);

      expect(roomKey, isNotNull);
      expect(roomKey!['gid'], _gid);
      expect(roomKey!['session_id'], sessionId);
      final keys = roomKey!['keys'] as List;
      expect(keys, hasLength(2));
      expect(
        keys.map((entry) => (entry as Map)['did']),
        containsAll([_peerDid, peerDid2]),
      );
      expect(keys.any((entry) => (entry as Map)['did'] == _senderDid), isFalse);

      // 不再替换生产 Olm 包裹器：两台接收设备的 inbound session 用真实
      // vodozemac 解开 room key，再导入 Megolm 验证群消息可解密。
      for (final (did, inbound) in <(String, vod.Session)>[
        (_peerDid, peerInbound),
        (peerDid2, peerInbound2),
      ]) {
        final entry =
            (keys.singleWhere((item) => (item as Map)['did'] == did) as Map)
                .cast<String, dynamic>();
        final olm = (entry['olm'] as Map).cast<String, dynamic>();
        expect(olm['v'], 'OLM.V1');
        expect(olm['sid'], _senderDid);
        final exported = inbound.decrypt(
          ciphertext: olm['body'] as String,
          messageType: olm['type'] as int,
        );
        final peerGroupInbound = vod.InboundGroupSession.import(exported);
        expect(peerGroupInbound.sessionId, sessionId);
        // PFv3 下 Megolm 原文是 inner frame 的 base64url CBOR（非裸 JSON）；
        // CBOR/明文还原已由上面生产入站路径段覆盖，这里验证对端设备
        // 能用 room key 导入的会话解出非空原文即可。
        final peerPlaintext = peerGroupInbound
            .decrypt(megolmCiphertext)
            .plaintext;
        expect(peerPlaintext, isNotEmpty);
      }
    } finally {
      await subscription.cancel();
      // ChatNetworkService 会把提交帧加入重试队列；先停掉重试扫描，再关闭
      // 专用 SQLCipher，避免后台扫描与测试清库并发产生假错误日志。
      await retry.debugWaitForIdle();
      retry.dispose();
      GroupSessionService.to.clearMemory();
      GroupSessionService.to.debugRoomKeySender = null;
      GroupSessionService.to.debugOlmWrap = null;
      E2EEService.clearKeyCacheForTest();
      E2eeBootstrap.resetForTest();
      OlmSessionService.to.resetForTest();
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      await db.rawDelete(
        'DELETE FROM crypto_olm_session WHERE peer_uid IN (?, ?)',
        ['uid_$_peerDid', 'uid_platform-peer-did-2'],
      );
      await SqliteService.to.close();
      await SqliteService.to.deleteDatabaseForUid(_senderUid);
      deviceId = previousDeviceId;
      if (previousUid.isEmpty) {
        await StorageService.to.remove(Keys.currentUid);
      } else {
        await StorageService.to.setString(Keys.currentUid, previousUid);
      }
      if (previousUser.isEmpty) {
        await StorageService.to.remove(Keys.currentUser);
      } else {
        await StorageService.setMap(Keys.currentUser, previousUser);
      }
    }
  });
}
