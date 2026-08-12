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
/// 新增 `E2EEService.decryptInboundV3`（纯函数，无 DB/事件/provider 副作用）
/// 作为 v3 的唯一进入点，并在 `_receiveMessage` / `_handleE2EEMessage`
/// 两处对 v3 放行 + 分流。
///
/// ## 为什么以纯函数为边界而不是 processMessage
///
/// 尝试过从 `processMessage` 端到端验证，失败了：`_receiveMessage` 耦合了
/// contact 仓储、会话 provider 等大量**与 E2EE 无关**的依赖，
/// 单测宿主里连对照组（v2）都跑不通（`contact.account_type` 缺列——
/// 内嵌基线 DDL 是 v16 而当前 schema 是 v24）。
/// 详见 `evidence/E2EE-v3-receive-path-not-wired.md`。
///
/// 因此当前的可验证边界是 `decryptInboundV3`。它与此前被测的
/// `decryptIncomingPayload` 有本质区别：**它是生产路径实际调用的入口**
/// （`message.dart::_handleE2EEMessage` 第 0 步直接调用它），
/// 而不是一条生产不走的旁路。
///
/// ⚠️ 残留：「`_handleE2EEMessage` 确实委托给本函数」目前靠代码审查保证，
/// 尚无自动化断言。真正的端到端门仍待建（需先解决测试 schema 或把解密
/// 从 `_receiveMessage` 的副作用链中进一步解耦）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;
import 'package:imboy/config/init.dart';

const String _sessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';

/// 恒等协议：只替换密码学，不替换 wiring。
/// metadata 形状对照真实 `OlmProtocol.encrypt`（olm_protocol.dart:65-78）。
class _IdentityOlmProtocol implements E2eeSessionProtocol {
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
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

class _IdentityMegolmProtocol implements E2eeSessionProtocol {
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
  }) async => ciphertext;

  @override
  Future<void> clearAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);

    // 顺序要紧：先让 bootstrap 完成一次真实注册（把内部 _registered 置 true），
    // 再清空 registry 换入恒等协议。否则解密时 ensureRegistered() 会再注册
    // 真实 OlmProtocol，与恒等协议撞 'already registered: olm'。
    E2eeBootstrap.resetForTest();
    E2eeBootstrap.ensureRegistered();
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityOlmProtocol());
    E2eeProtocolRegistry.register(_IdentityMegolmProtocol());
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
  Future<Map<String, dynamic>> buildV3Message(String msgId) async {
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
      action: 'message',
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
}
