/// PFv3 接收侧接线验收 —— 以 `E2EEService.decryptInboundV3` 为可测边界。
///
/// ## 背景：为什么这个文件存在
///
/// 此前 PFv3 的全部验收（E2EE-012 / 023 / 024 / 025 / 029）都以
/// `E2EEService.decryptIncomingPayload` 为起点，而 `rg` 全仓证明
/// **生产 WS 接收路径从不调用该方法**——它只有定义处自身与收藏列表两个调用方。
/// 生产走 `MessageService.processMessage` → `_receiveMessage` →
/// `_handleE2EEMessage` → `decryptE2EEMessage`。
///
/// 更糟的是两条路各支持一半：
/// - `decryptIncomingPayload`：支持 v1(keys) 与 v3，**不支持 v2**（扁平
///   Olm/Megolm 元数据会撞 `invalid_keys`）；
/// - `decryptE2EEMessage`（生产走这条）：支持 v1/v2，**不认识 v3**。
///
/// 结果：v3 消息因外层 payload 恒为空串，在 `_receiveMessage` 的
/// `if (payloadRaw.isEmpty) return;` 处被**静默丢弃**，连 `_e2ee_failed`
/// 占位都不产生（UI 上消息凭空消失）。
///
/// ## 本次接线
///
/// 新增 `E2EEService.decryptInboundV3` 作为 v3 的唯一进入点，并在
/// `_receiveMessage` / `_handleE2EEMessage` 两处对 v3 放行 + 分流。当前入口会
/// 使用 SQLCipher 暂存密文及可恢复解密结果，但不触发事件或 provider。
///
/// ## 为什么以纯函数为边界而不是 processMessage
///
/// 尝试过从 `processMessage` 端到端验证，失败了：`_receiveMessage` 耦合了
/// contact 仓储、会话 provider 等大量**与 E2EE 无关**的依赖，
/// 单测宿主里连对照组（v2）都跑不通（`contact.account_type` 缺列——
/// 内嵌基线 DDL 是 v16 而当前 schema 是 v24）。
/// 详见 `evidence/E2EE-v3-receive-path-not-wired.md`。
///
/// 因此当前可独立验证的密码接收边界是 `decryptInboundV3`。它与此前被测的
/// `decryptIncomingPayload` 有本质区别：**它是生产路径实际调用的入口**
/// （`message.dart::_handleE2EEMessage` 第 0 步直接调用它），
/// 而不是一条生产不走的旁路。
///
/// ⚠️ 残留：「`_handleE2EEMessage` 确实委托给本函数」目前靠代码审查保证，
/// 尚无自动化断言。真正的端到端门仍待建（需先解决测试 schema 或把解密
/// 从 `_receiveMessage` 的副作用链中进一步解耦）。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/olm_session_service.dart'
    show DuplicateMessageException;
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/config/init.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const String _sessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';

/// 恒等协议：只替换密码学，不替换 wiring。
/// metadata 形状对照真实 `OlmProtocol.encrypt`（olm_protocol.dart:65-78）。
class _IdentityOlmProtocol implements E2eeSessionProtocol {
  bool rejectDuplicate = false;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late _IdentityMegolmProtocol groupProtocol;
  late _IdentityOlmProtocol olmProtocol;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 32);
    SqliteService.setDbForTest(db);

    // 顺序要紧：先让 bootstrap 完成一次真实注册（把内部 _registered 置 true），
    // 再清空 registry 换入恒等协议。否则解密时 ensureRegistered() 会再注册
    // 真实 OlmProtocol，与恒等协议撞 'already registered: olm'。
    E2eeBootstrap.resetForTest();
    E2eeBootstrap.ensureRegistered();
    E2eeProtocolRegistry.resetForTest();
    olmProtocol = _IdentityOlmProtocol();
    E2eeProtocolRegistry.register(olmProtocol);
    groupProtocol = _IdentityMegolmProtocol();
    E2eeProtocolRegistry.register(groupProtocol);
  });

  tearDown(() async {
    E2eeBootstrap.resetForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

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

  group('PFv3 接收侧接线', () {
    test('协议去重异常不能作为编辑已完成确认', () async {
      final data = await buildV3Message(
        'edit-duplicate',
        action: 'message_edit',
      );
      data['action'] = 'message_edit';
      olmProtocol.rejectDuplicate = true;
      try {
        expect(await MessageService.to.persistInboundMessage(data), isFalse);
      } finally {
        MessageService.to.dispose();
        MessageRetry.instance.dispose();
      }
    });

    test('编辑密文身份冲突时接收入口不得确认', () async {
      final data = await buildV3Message(
        'edit-conflict',
        action: 'message_edit',
      );
      data['action'] = 'message_edit';
      expect(
        (await E2EEService.decryptInboundV3(data: data))?['_e2ee_failed'],
        isNot(true),
      );
      final devices = (data['e2ee'] as Map)['devices'] as Map;
      final envelope = devices[deviceId] as Map;
      envelope['ciphertext'] = '${envelope['ciphertext']}A';
      try {
        expect(await MessageService.to.persistInboundMessage(data), isFalse);
      } finally {
        MessageService.to.dispose();
        MessageRetry.instance.dispose();
      }
    });

    test('离线编辑路由提示必须与认证头一致', () async {
      final edit = await buildV3Message('offline-edit', action: 'message_edit');
      (edit['e2ee'] as Map)['relay_action'] = 'message_edit';
      final normalized = MessageOfflineService.normalizeForReceive(edit, 'C2C');
      expect(normalized['action'], 'message_edit');
      expect(
        (await E2EEService.decryptInboundV3(data: normalized))?['_e2ee_failed'],
        isNot(true),
      );

      final forged = await buildV3Message('offline-forged');
      (forged['e2ee'] as Map)['relay_action'] = 'message_edit';
      final forgedNormalized = MessageOfflineService.normalizeForReceive(
        forged,
        'C2C',
      );
      expect(
        (await E2EEService.decryptInboundV3(
          data: forgedNormalized,
        ))?['_e2ee_reason'],
        'context_mismatch_action',
      );
    });

    test('群聊协议元数据的 gid 必须与认证头一致', () async {
      final encrypted = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.megolm,
        plaintext: jsonEncode({'text': 'synthetic'}),
        recipients: const [],
        context: E2eeContext(gid: 'group-1', scope: 'c2g'),
        messageId: 'group-metadata-gid',
        senderUid: '100',
        senderDid: 'dev-sender',
        destination: 'group-1',
        messageType: 'text',
        action: 'message',
        sessionRef: _sessionId,
        createdAtMs: 1753500000000,
      );
      final envelope = Map<String, dynamic>.from(encrypted.metadata);
      final metadata = Map<String, dynamic>.from(
        envelope['protocol_metadata'] as Map,
      );
      envelope['protocol_metadata'] = metadata;
      final data = <String, dynamic>{
        'id': 'group-metadata-gid',
        'type': 'C2G',
        'from': '100',
        'to': 'group-1',
        'msg_type': 'text',
        'sender_did': 'dev-sender',
        'payload': encrypted.ciphertext,
        'e2ee': envelope,
      };
      metadata['gid'] = 'other-group';
      expect(
        (await E2EEService.decryptInboundV3(data: data))?['_e2ee_reason'],
        'context_mismatch_gid',
      );
      expect(groupProtocol.decryptMetadata, isEmpty);
      metadata.remove('gid');
      expect(
        (await E2EEService.decryptInboundV3(data: data))?['_e2ee_reason'],
        'context_mismatch_gid',
      );
      metadata['gid'] = 'group-1';
      expect(
        (await E2EEService.decryptInboundV3(data: data))?['_e2ee_failed'],
        isNot(true),
      );
    });

    test('群聊恢复缓存仍需满足历史授权', () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const grant = MegolmHistoryGrant(
        scope: 'group-1',
        sessionId: _sessionId,
        generationNo: 2,
        startSeq: 481,
        endSeq: 500,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'read' ? jsonEncode(grant.toJson()) : null,
          );
      GroupSessionService.to.clearMemory();
      try {
        final encrypted = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.megolm,
          plaintext: jsonEncode({'text': 'synthetic'}),
          recipients: const [],
          context: E2eeContext(gid: 'group-1', scope: 'c2g'),
          messageId: 'group-cached-grant',
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: 'group-1',
          messageType: 'text',
          action: 'message',
          sessionRef: _sessionId,
          createdAtMs: 1753500000000,
        );
        final data = <String, dynamic>{
          'id': 'group-cached-grant',
          'type': 'C2G',
          'from': '100',
          'to': 'group-1',
          'msg_type': 'text',
          'sender_did': 'dev-sender',
          'conv_seq': 481,
          'payload': encrypted.ciphertext,
          'e2ee': encrypted.metadata,
        };
        expect(
          (await E2EEService.decryptInboundV3(data: data))?['_e2ee_failed'],
          isNot(true),
        );
        final staged = (await db.query(
          'crypto_inbox_staging',
          where: 'message_id = ?',
          whereArgs: ['group-cached-grant'],
        )).single;
        expect(
          await CryptoStore(db).commitInboundResult(
            messageId: 'group-cached-grant',
            scope: staged['scope'] as String,
            ciphertextDigest: staged['ciphertext_digest'] as String,
            decryptedPayload: utf8.decode(
              base64Url.decode(encrypted.metadata['ciphertext'] as String),
            ),
          ),
          isTrue,
        );
        data['conv_seq'] = 480;
        expect(
          (await E2EEService.decryptInboundV3(data: data))?['_e2ee_reason'],
          'historical_room_key_scope_denied',
        );
        final protocolMetadata = <String, dynamic>{
          'gid': 'group-1',
          'session_id': _sessionId,
          'message_id': 'group-cached-grant',
          'inbox_scope': staged['scope'],
          'ciphertext_digest': staged['ciphertext_digest'],
          'history_conv_seq': 480,
        };
        await expectLater(
          MegolmProtocol().decrypt(ciphertext: '', metadata: protocolMetadata),
          throwsA(
            isA<E2eeDecryptException>().having(
              (error) => error.reason,
              'reason',
              'historical_room_key_scope_denied',
            ),
          ),
        );
        protocolMetadata['history_conv_seq'] = 481;
        expect(
          await MegolmProtocol().decrypt(
            ciphertext: '',
            metadata: protocolMetadata,
          ),
          utf8.decode(
            base64Url.decode(encrypted.metadata['ciphertext'] as String),
          ),
        );
        data['conv_seq'] = 481;
        expect(
          (await E2EEService.decryptInboundV3(data: data))?['_e2ee_failed'],
          isNot(true),
        );
        expect(groupProtocol.decryptMetadata.length, 1);
      } finally {
        GroupSessionService.to.clearMemory();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    });

    test('群聊 v3 历史序号仅来自可信外层或归档参数', () async {
      for (final source in ['outer', 'archive', 'missing']) {
        final encrypted = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.megolm,
          plaintext: jsonEncode({'text': 'synthetic'}),
          recipients: const [],
          context: E2eeContext(gid: 'group-1', scope: 'c2g'),
          messageId: 'group-sequence-$source',
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: 'group-1',
          messageType: 'text',
          action: 'message',
          sessionRef: _sessionId,
          createdAtMs: 1753500000000,
        );
        final envelope = Map<String, dynamic>.from(encrypted.metadata);
        envelope['protocol_metadata'] = {
          ...envelope['protocol_metadata'] as Map<String, dynamic>,
          'history_conv_seq': 1,
        };
        final result = await E2EEService.decryptInboundV3(
          data: {
            'id': 'group-sequence-$source',
            'type': 'C2G',
            'from': '100',
            'to': 'group-1',
            'msg_type': 'text',
            'sender_did': 'dev-sender',
            if (source == 'outer') 'conv_seq': 485,
            'payload': encrypted.ciphertext,
            'e2ee': envelope,
          },
          trustedArchiveConvSeq: source == 'missing' ? null : 480,
        );
        expect(result?['_e2ee_failed'], isNot(true));
        final metadata = groupProtocol.decryptMetadata.last;
        if (source == 'missing') {
          expect(metadata.containsKey('history_conv_seq'), isFalse);
        } else {
          expect(metadata['history_conv_seq'], source == 'outer' ? 485 : 480);
        }
      }
    });

    test('群聊编辑操作与受认证头绑定', () async {
      final encrypted = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.megolm,
        plaintext: jsonEncode({
          'original_msg_id': 'group-original',
          'content': 'edited text',
        }),
        recipients: const [],
        context: E2eeContext(gid: 'group-1', scope: 'c2g'),
        messageId: 'group-edit-binding',
        senderUid: '100',
        senderDid: 'dev-sender',
        destination: 'group-1',
        messageType: 'text',
        action: 'message_edit',
        sessionRef: _sessionId,
        createdAtMs: 1753500000000,
      );
      final data = <String, dynamic>{
        'id': 'group-edit-binding',
        'type': 'C2G',
        'from': '100',
        'to': 'group-1',
        'msg_type': 'text',
        'sender_did': 'dev-sender',
        'action': 'message',
        'payload': encrypted.ciphertext,
        'e2ee': {...encrypted.metadata, 'protocol': 'megolm', 'gid': 'group-1'},
      };
      final forged = await E2EEService.decryptInboundV3(data: data);
      expect(forged?['_e2ee_reason'], 'context_mismatch_action');

      data['action'] = 'message_edit';
      final valid = await E2EEService.decryptInboundV3(data: data);
      expect(valid?['_e2ee_failed'], isNot(true));
      expect(valid?['original_msg_id'], 'group-original');
      expect(valid?['content'], 'edited text');
    });

    test('编辑操作必须与受认证头一致', () async {
      final forgedEdit = await buildV3Message('v3-forged-edit');
      forgedEdit['action'] = 'message_edit';
      final forgedResult = await E2EEService.decryptInboundV3(data: forgedEdit);
      expect(forgedResult?['_e2ee_reason'], 'context_mismatch_action');

      final missingEdit = await buildV3Message(
        'v3-missing-edit',
        action: 'message_edit',
      );
      final missingResult = await E2EEService.decryptInboundV3(
        data: missingEdit,
      );
      expect(missingResult?['_e2ee_reason'], 'context_mismatch_action');

      missingEdit['action'] = 'message_edit';
      final validResult = await E2EEService.decryptInboundV3(data: missingEdit);
      expect(validResult?['_e2ee_failed'], isNot(true));
    });

    test('发送设备不在 fan-out 时不能解密服务端回显', () async {
      final data = await buildV3Message('inbound-v3-no-sender-envelope');
      final metadata = data['e2ee'] as Map<String, dynamic>;
      final devices = metadata['devices'] as Map<String, dynamic>;
      devices['other-device'] = devices.remove(deviceId);

      final result = await E2EEService.decryptInboundV3(data: data);
      expect(result?['_e2ee_failed'], isTrue);
      expect(result?['_e2ee_reason'], 'no_device_envelope');
    });

    test('v3 fan-out 消息必须被识别并解出明文', () async {
      final data = await buildV3Message('inbound-v3-001');
      final result = await E2EEService.decryptInboundV3(data: data);

      expect(
        result,
        isNotNull,
        reason: 'v3 信封必须被 decryptInboundV3 认领，而不是落到 v1/v2 路径',
      );
      expect(
        result!['_e2ee_failed'],
        isNot(true),
        reason: '失败原因: ${result['_e2ee_reason']}',
      );
      expect(result['_e2ee_v3_verified'], isTrue);
      expect(result['body'], equals(plainBody));
    });

    test('已完成同帧可幂等确认，同 ID 篡改密文必须拒绝', () async {
      const msgId = 'inbound-v3-retry-001';
      final data = await buildV3Message(msgId);
      final first = await E2EEService.decryptInboundV3(data: data);
      expect(first?['_e2ee_failed'], isNot(true));

      // 恒等协议替代了真实 OlmProtocol，因此测试需显式复刻协议层的
      // digest + 解密结果原子提交，再进入最终消息已持久化后的 complete。
      final staged = (await db.query(
        'crypto_inbox_staging',
        where: 'message_id = ?',
        whereArgs: [msgId],
      )).single;
      final e2eeBeforeTamper = data['e2ee'] as Map;
      final devicesBeforeTamper = e2eeBeforeTamper['devices'] as Map;
      final envelopeBeforeTamper = devicesBeforeTamper[deviceId] as Map;
      final innerFrame = utf8.decode(
        base64Url.decode(envelopeBeforeTamper['ciphertext'] as String),
      );
      final store = CryptoStore(db);
      expect(
        await store.commitInboundResult(
          messageId: msgId,
          scope: staged['scope'] as String,
          ciphertextDigest: staged['ciphertext_digest'] as String,
          decryptedPayload: innerFrame,
        ),
        isTrue,
      );
      await store.completeInbound(msgId);
      final retry = await E2EEService.decryptInboundV3(data: data);
      expect(retry?['_e2ee_reason'], 'already_processed');

      final e2ee = Map<String, dynamic>.from(data['e2ee'] as Map);
      final devices = Map<String, dynamic>.from(e2ee['devices'] as Map);
      final envelope = Map<String, dynamic>.from(devices[deviceId] as Map);
      envelope['ciphertext'] = '${envelope['ciphertext']}A';
      devices[deviceId] = envelope;
      e2ee['devices'] = devices;
      data['e2ee'] = e2ee;

      final tampered = await E2EEService.decryptInboundV3(data: data);
      expect(tampered?['_e2ee_reason'], 'inbound_identity_conflict');
    });

    test('非 v3 信封必须返回 null，交回 v1/v2 路径处理', () async {
      final v2 = {
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

      expect(
        await E2EEService.decryptInboundV3(data: v2),
        isNull,
        reason: 'v2 必须交回既有路径，不得被 v3 分支拦截（否则撞 invalid_keys）',
      );
    });

    test('无 e2ee 的明文消息必须返回 null', () async {
      expect(
        await E2EEService.decryptInboundV3(
          data: {'id': 'plain-001', 'type': 'C2C', 'payload': 'hi'},
        ),
        isNull,
      );
    });

    // 接线后 v3 失败必须有明确分类，不得回到「静默丢弃」
    test('v3 信封损坏时必须返回失败分类，而不是 null 或静默丢弃', () async {
      final data = await buildV3Message('inbound-v3-broken');
      final e2ee = Map<String, dynamic>.from(data['e2ee'] as Map);
      e2ee['devices'] = <String, dynamic>{}; // 抹掉本机信封
      data['e2ee'] = e2ee;

      final result = await E2EEService.decryptInboundV3(data: data);
      expect(result, isNotNull);
      expect(result!['_e2ee_failed'], isTrue);
      expect(result['_e2ee_reason'], equals('no_device_envelope'));
    });

    test('C2G Megolm v2 扁平 metadata 必须走 Megolm 入站路由', () async {
      final result = await E2EEService.decryptIncomingPayload(
        payload: {
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
        },
      );
      expect(result['_e2ee_failed'], isNot(true));
      expect(result['_e2ee_megolm_verified'], isTrue);
      expect(result['body'], plainBody);
    });
  });

  group('PFv3 失败行自愈重试', () {
    test('含 _e2ee_raw 的 v3 失败行重试必须解出明文（修复前恒跳过）', () async {
      final data = await buildV3Message('retry-v3-001');
      // 生产落库形状：_handleE2EEMessage v3 失败分支透传 _e2ee_raw，
      // 落库侧 identical() 补偿替换为 {payload, e2ee} 浅拷贝
      final failed = {
        '_e2ee_failed': true,
        '_e2ee_reason': 'decrypt_error',
        // 生产落库形状：落库侧 identical() 补偿的 8 键浅拷贝
        // （上下文绑定验证要求 id/from/to/type/msg_type/sender_did）
        '_e2ee_raw': {
          'id': data['id'],
          'from': data['from'],
          'to': data['to'],
          'type': data['type'],
          'msg_type': data['msg_type'],
          'sender_did': data['sender_did'],
          'payload': data['payload'],
          'e2ee': data['e2ee'],
        },
      };

      final result = await E2EEService.retryDecryptFailedMessage(failed);

      expect(
        result['_e2ee_failed'],
        isNot(true),
        reason: 'v3 重试必须解出明文而不是保持失败占位',
      );
      expect(result['body'], equals(plainBody));
    });

    test('密文损坏时 v3 重试必须保持失败占位（幂等失败语义）', () async {
      final data = await buildV3Message('retry-v3-broken');
      final e2ee = Map<String, dynamic>.from(data['e2ee'] as Map);
      e2ee['devices'] = <String, dynamic>{}; // 抹掉本机信封
      final failed = {
        '_e2ee_failed': true,
        '_e2ee_reason': 'decrypt_error',
        '_e2ee_raw': {
          'id': data['id'],
          'from': data['from'],
          'to': data['to'],
          'type': data['type'],
          'msg_type': data['msg_type'],
          'sender_did': data['sender_did'],
          'payload': data['payload'],
          'e2ee': e2ee,
        },
      };

      final result = await E2EEService.retryDecryptFailedMessage(failed);

      expect(result['_e2ee_failed'], isTrue);
      expect(result['_e2ee_reason'], isNotNull);
    });
  });
}
