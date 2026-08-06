/// E2EE-025 —— `session_ref` 契约与选项 C 接收侧语义的守护测试。
///
/// **事故背景**：`chat_network_service.dart` 曾写 `sessionRef: ''`，注释称
/// 「OlmProtocol 内部填充 session_id」——该填充并不存在。真实
/// `OlmProtocol.encrypt`（`olm_protocol.dart:77`）只把 `session_id` 写进
/// `protocol_metadata`，从不回填 protected_header。而
/// `E2eeService._validateContextBinding` §7 硬比对两者相等，
/// 于是**每一条生产 C2C Olm v3 消息都被判 `context_mismatch_session_id`**。
///
/// 既有 `protected_frame_v3_roundtrip_test.dart` 之所以全绿，是因为它把
/// `sessionRef: 'test-session'` 与假协议的 `session_id: 'test-session'`
/// **人为对齐**了——生产不会对齐。
///
/// 本文件的假协议只替换密码学实现，metadata 形状与真实 `OlmProtocol`
/// 逐字段一致（对照 `olm_protocol.dart:65-78`）；被测对象是 wiring 契约。
/// 真实 Olm（vodozemac）下 `ensureSessionId` 与 encrypt 的会话一致性，
/// 另见 `olm_pfs_production_path_test.dart` 的
/// 「E2EE-025 ensureSessionId 与 encrypt 的会话一致性」组。
///
/// 对应提案 25 §6 的 RC-01 / RC-02 / RC-04。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;

/// 真实 Olm 会话 id 的形状：非空、由协议内部产生，调用方在 encrypt 返回前无从得知。
const String _realOlmSessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';

/// 与 `OlmProtocol` metadata 形状一致的假协议（只替换密码学，不替换 wiring）。
class _OlmShapedProtocol implements E2eeSessionProtocol {
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
    // 字段集对照 olm_protocol.dart:65-78
    return E2eeCiphertext(plaintext, {
      'protocol': suite.protocol,
      'version': suite.version,
      'e2ee_suite': suite.legacyWire,
      'peer_uid': '100',
      'peer_device_id': 'dev-sender',
      'message_type': 1,
      'session_id': _realOlmSessionId,
    });
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(sqfliteFfiInit);

  // 逐用例独立 DB：dedupe / sequence 都是跨消息状态，共享 DB 会让结果依赖执行顺序。
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_OlmShapedProtocol());
  });

  tearDown(() async {
    E2eeProtocolRegistry.resetForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  const originalPayload = {
    'msg_type': 'text',
    'body': 'hello world',
    'ts': 1753500000000,
  };

  Future<E2eeCiphertext> encryptWith({
    required String sessionRef,
    String messageId = 'msg-025',
    String messageType = 'text',
    int epochOrCounter = 0,
  }) {
    return E2eeOutboundRouter.encryptV3(
      suite: ProtocolSuite.olm,
      plaintext: jsonEncode(originalPayload),
      recipients: const [
        RecipientDevice(deviceId: 'dev-peer', keyId: 'k1', publicKey: 'pk-1'),
      ],
      context: const E2eeContext(
        peerUid: '200',
        peerDeviceId: 'dev-peer',
        scope: 'c2c',
      ),
      messageId: messageId,
      senderUid: '100',
      senderDid: 'dev-sender',
      destination: '200',
      messageType: messageType,
      action: 'message',
      sessionRef: sessionRef,
      epochOrCounter: epochOrCounter,
      createdAtMs: 1753500000000,
    );
  }

  Map<String, dynamic> wrapAsIncoming(
    E2eeCiphertext result, {
    String messageId = 'msg-025',
    String messageType = 'text',
  }) {
    return {
      'id': messageId,
      'type': 'C2C',
      'from': '100',
      'to': '200',
      'msg_type': messageType,
      'e2ee': result.metadata,
      'payload': result.ciphertext,
      'sender_did': 'dev-sender',
      'sender_dtype': 'ios',
    };
  }

  group('E2EE-025 session_ref 契约', () {
    // RC-01a：空 session_ref 必须在构造处 fail-closed，而不是产出废密文。
    // 守卫放在 buildProtectedHeader，任何调用点漏传都会炸。
    test('RC-01a 空 sessionRef 必须抛错（ADR 15 §3.1 冻结字段：1..256 字节）', () async {
      expect(
        () => encryptWith(sessionRef: ''),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'name',
            equals('sessionRef'),
          ),
        ),
      );
    });

    // RC-01b：header.session_ref 必须等于协议实际会话标识
    test(
      'RC-01b header.session_ref 非空且等于 protocol_metadata.session_id',
      () async {
        final result = await encryptWith(sessionRef: _realOlmSessionId);
        final envelope = result.metadata;

        final verification = ProtectedFrameV3.verifyOuterEnvelope(envelope);
        expect(verification.isValid, isTrue, reason: verification.reason ?? '');
        final header = verification.decodedHeader!;

        final metaSessionId =
            (envelope['protocol_metadata'] as Map)['session_id']?.toString() ??
            '';
        expect(metaSessionId, equals(_realOlmSessionId));
        expect(header['session_ref'], isNotEmpty);
        expect(header['session_ref'], equals(metaSessionId));
      },
    );
  });

  // E2EE-012/024 复核：`_validateContextBinding` 的另外两项在生产上同样不对齐。
  //
  // 代码事实（`chat_network_service.dart`）：
  //   - 外层 WS 消息用 `'id': obj.id` 与真实 `'msg_type': msgType`；
  //   - 而 `_encryptC2COlmFanOut` 内部 `final msgId = Xid().toString();`
  //     **新生成**一个与 obj.id 无关的 id，并把 `messageType: 'text'` **硬编码**
  //     写进 protected_header。
  // 下面两个用例证明：只要这两对值不等，消息就会被整条拒收——
  // 与生产的代码事实相叠，即每条消息必被拒（非文本消息还会多命中一项）。
  group('E2EE-012/024 复核：其余 context binding 项的生产后果', () {
    test('header.message_id 与外层 payload.id 不等 → context_mismatch_id', () async {
      final result = await encryptWith(
        sessionRef: _realOlmSessionId,
        messageId: 'header-generated-xid', // 模拟 fan-out 内部新生成的 Xid
      );
      // 外层用业务真实 id（obj.id），与 header 内的不是同一个
      final incoming = wrapAsIncoming(result, messageId: 'business-msg-id');

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );
      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], equals('context_mismatch_id'));
    });

    test(
      'header.message_type 恒 text 而外层是 image → context_mismatch_msg_type',
      () async {
        final result = await encryptWith(sessionRef: _realOlmSessionId);
        final incoming = wrapAsIncoming(result)..['msg_type'] = 'image';

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: incoming,
        );
        expect(decrypted['_e2ee_failed'], isTrue);
        expect(decrypted['_e2ee_reason'], equals('context_mismatch_msg_type'));
      },
    );
  });

  // 正向可用性门 —— 这正是 E2EE-012/024 验收中**缺失**的那一类用例。
  // 它们只验「篡改能否拒收」，于是一个把所有消息都拒收的实现也能拿满分。
  // 凡收紧 context binding，必须同时有「生产发送路径产物能被接收侧接受」的正向用例。
  group('E2EE-012/024 复核：正向可用性门（修复后必须绿）', () {
    test('业务 id 与外层一致时必须被接受（message_id 不再自造）', () async {
      const businessId = 'business-msg-id-001';
      final result = await encryptWith(
        sessionRef: _realOlmSessionId,
        messageId: businessId,
      );
      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: wrapAsIncoming(result, messageId: businessId),
      );

      expect(
        decrypted['_e2ee_failed'],
        isNot(true),
        reason: '失败原因: ${decrypted['_e2ee_reason']}',
      );
      expect(decrypted['_e2ee_v3_verified'], isTrue);
    });

    test('非文本消息（image/video/audio/file）与外层一致时必须被接受', () async {
      for (final type in ['image', 'video', 'audio', 'file']) {
        final id = 'msg-$type';
        final result = await encryptWith(
          sessionRef: _realOlmSessionId,
          messageId: id,
          messageType: type,
        );
        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: wrapAsIncoming(result, messageId: id, messageType: type),
        );

        expect(
          decrypted['_e2ee_failed'],
          isNot(true),
          reason: '$type 被拒，原因: ${decrypted['_e2ee_reason']}',
        );
        expect(decrypted['_e2ee_v3_verified'], isTrue);
      }
    });
  });

  group('E2EE-025 选项 C 接收侧语义', () {
    // RC-02（可用性回归门）：首条合法消息必须被接受。
    // 这是提案 25 §1.2 的 P2：session_ref 填上后，若仍保留严格单调序列检查，
    // counter 恒 0 会让 `0 <= 0` 成立，首条消息即被误判 replay，C2C 全线不可读。
    test('RC-02 首条合法消息必须被接受（counter=0 不得被误判 replay）', () async {
      final result = await encryptWith(sessionRef: _realOlmSessionId);
      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: wrapAsIncoming(result),
      );

      expect(
        decrypted['_e2ee_failed'],
        isNot(true),
        reason: '失败原因: ${decrypted['_e2ee_reason']}',
      );
      expect(decrypted['_e2ee_v3_verified'], isTrue);
      expect(decrypted['body'], equals('hello world'));
    });

    // RC-04（可用性回归门）：离线批量 + 乱序投递必须全部可读。
    // 选项 C 下 Olm/Megolm 不做序列检查，counter 恒 0，乱序不构成拒收理由。
    test('RC-04 同一会话内 counter 恒 0 的多条消息全部可读，0 误判 replay', () async {
      const total = 50;
      final messages = <Map<String, dynamic>>[];
      for (var i = 0; i < total; i++) {
        final id = 'msg-batch-$i';
        messages.add(
          wrapAsIncoming(
            await encryptWith(sessionRef: _realOlmSessionId, messageId: id),
            messageId: id,
          ),
        );
      }
      // 乱序投递
      final shuffled = messages.reversed.toList();

      var ok = 0;
      for (final m in shuffled) {
        final r = await E2EEService.decryptIncomingPayload(payload: m);
        expect(
          r['_e2ee_reason'],
          isNot(equals('replay_detected')),
          reason: '选项 C 下 Olm 不做序列检查，不得出现 replay 误判',
        );
        if (r['_e2ee_failed'] != true) ok++;
      }
      expect(ok, equals(total));
    });

    // RC-04b：乱序的 epoch_or_counter（递减）同样不得被拒。
    test('RC-04b 递减的 epoch_or_counter 不得被判 replay', () async {
      final high = wrapAsIncoming(
        await encryptWith(
          sessionRef: _realOlmSessionId,
          messageId: 'msg-hi',
          epochOrCounter: 10,
        ),
        messageId: 'msg-hi',
      );
      final low = wrapAsIncoming(
        await encryptWith(
          sessionRef: _realOlmSessionId,
          messageId: 'msg-lo',
          epochOrCounter: 5,
        ),
        messageId: 'msg-lo',
      );

      final r1 = await E2EEService.decryptIncomingPayload(payload: high);
      expect(r1['_e2ee_failed'], isNot(true));

      final r2 = await E2EEService.decryptIncomingPayload(payload: low);
      expect(
        r2['_e2ee_reason'],
        isNot(equals('replay_detected')),
        reason: 'ADR 15 §7.2 的滑动窗口已收敛为仅 MLS 适用；Olm 乱序是常态',
      );
      expect(r2['_e2ee_failed'], isNot(true));
    });
  });
}
