/// A2-b：实证 decrypt-on-read 路径（离线消息）的 v3 缺口。
///
/// ## 为什么存在两条解密路径
///
/// | 路径 | 存储状态 | 解密入口 |
/// |---|---|---|
/// | 实时 WS | 存**明文**（`_receiveMessage` 解密后再落库） | `message.dart::_handleE2EEMessage` → `decryptInboundV3` |
/// | 离线拉取 | 存**密文**（decrypt-on-read） | `message_model_mapper.dart::toTypeMessage()` → `decryptE2EEMessage` |
///
/// 离线消息经 `MessageOfflineService._processOfflineMessages` →
/// `MessageRepo.batchInsertOfflineMessages` 原样落库（密文），
/// 读取时才由 `toTypeMessage()` 解密。
///
/// 该路径**从未为 v3 接线**——与当初 `_handleE2EEMessage` 的缺口同型。
/// 本文件把这个判断从「文件级阅读」升格为「实证」。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;
import 'package:imboy/service/sqlite.dart';

const String _senderUid = '100';
const String _senderDid = 'dev-sender-01';
const String _sessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';
const String _myUid = '200';

/// 恒等协议：metadata 形状逐字段对照 `lib/service/e2ee/olm_protocol.dart:67-78`。
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
      'peer_uid': _senderUid,
      'peer_device_id': _senderDid,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);

    E2eeBootstrap.resetForTest();
    E2eeBootstrap.ensureRegistered();
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityOlmProtocol());
  });

  tearDown(() async {
    E2eeBootstrap.resetForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  const body = 'offline v3 body';

  /// 复刻 `_encryptC2COlmFanOut` 的产出：v3 信封 + 外层 payload 空串。
  Future<Map<String, dynamic>> buildV3Row() async {
    final encrypted = await E2eeOutboundRouter.encryptV3(
      suite: ProtocolSuite.olm,
      plaintext: jsonEncode({'msg_type': 'text', 'body': body}),
      recipients: [
        RecipientDevice(deviceId: deviceId, keyId: 'k1', publicKey: 'pk-1'),
      ],
      context: E2eeContext(
        peerUid: _myUid,
        peerDeviceId: deviceId,
        scope: 'c2c',
      ),
      messageId: 'offline-v3-001',
      senderUid: _senderUid,
      senderDid: _senderDid,
      destination: _myUid,
      messageType: 'text',
      action: 'message',
      sessionRef: _sessionId,
      createdAtMs: 1753500000000,
    );
    final envelope = Map<String, dynamic>.from(encrypted.metadata)
      ..remove('meta_version');

    return {
      'e2ee': {
        'meta_version': 3,
        'protocol': 'olm',
        'version': 1,
        'fan_out': 'per_device',
        'devices': {deviceId: envelope},
      },
      // 离线行落库时 payload 原样保留 = v3 恒为空串
      'payload': '',
    };
  }

  group('decrypt-on-read 路径的 v3 缺口（实证）', () {
    // toTypeMessage() 对 E2EE 分支恰好传这两个实参
    // （message_model_mapper.dart:39-43：ciphertext = payload，e2ee = e2ee!）。
    // 本用例证明：**用那两个实参根本解不出明文**。
    test('toTypeMessage 所用的 decryptE2EEMessage 无法解出 v3 明文', () async {
      final row = await buildV3Row();

      Object? thrown;
      String? out;
      try {
        out = await E2EEService.decryptE2EEMessage(
          ciphertext: row['payload'] as String,
          e2ee: row['e2ee'] as Map<String, dynamic>,
        );
      } on Object catch (e) {
        thrown = e;
      }

      // 缺口的本质与密码学无关，因此断言也不依赖具体协议行为：
      // toTypeMessage 传的 `ciphertext` 实参是**外层 payload**，而 v3 的
      // 外层 payload 恒为空串——真正的密文在 e2ee.devices[did].ciphertext 里。
      // 传错了输入，任何协议都不可能解出明文。
      final plaintext = jsonEncode({'msg_type': 'text', 'body': body});
      expect(
        out,
        isNot(equals(plaintext)),
        reason:
            'decryptE2EEMessage 若能解出 v3，本任务的前提就不成立，须停下重估。'
            '（本 harness 用恒等协议，故返回空串而非抛错；'
            '生产的真实 OlmProtocol 会在 olm_protocol.dart:87-90 '
            '因缺 peer_uid/peer_device_id 抛错，被 mapper 兜成 decrypt_failed。'
            '两者都读不出明文。）实际返回: $out / 异常: $thrown',
      );

      // 正面证明「传错了输入」：真密文确实在别处，且非空。
      final devices =
          (row['e2ee'] as Map<String, dynamic>)['devices']
              as Map<String, dynamic>;
      final realCiphertext =
          (devices[deviceId] as Map<String, dynamic>)['ciphertext'];
      expect(row['payload'], equals(''), reason: 'v3 外层 payload 恒为空串');
      expect(
        realCiphertext,
        isA<String>().having((s) => s.isNotEmpty, '非空', isTrue),
        reason: '真密文在 e2ee.devices[did].ciphertext —— 这才是应该被传进去的输入',
      );
    });

    // 对照组：同一 harness、同一行数据，改走生产 v3 入口必须成功。
    // 若这一项也红，说明是 harness 缺陷而非路径缺口，必须停下重估。
    test('对照组：同一行数据经 decryptInboundV3 必须可读', () async {
      final row = await buildV3Row();
      final frame = <String, dynamic>{
        'id': 'offline-v3-001',
        'type': 'C2C',
        'from': _senderUid,
        'to': _myUid,
        'msg_type': 'text',
        'e2ee': row['e2ee'],
        'payload': row['payload'],
        'sender_did': _senderDid,
      };

      final result = await E2EEService.decryptInboundV3(data: frame);
      expect(result, isNotNull);
      expect(
        result!['_e2ee_failed'],
        isNot(true),
        reason:
            '对照组失败 = harness 缺陷（假协议/信封构造/DB），'
            '不是路径缺口。失败原因: ${result['_e2ee_reason']}',
      );
      expect(result['body'], equals(body));
    });
  });

  // 结构守护：把「toTypeMessage 未为 v3 接线」这一事实钉在源码上。
  // 接线完成后本组必须同步改写（届时断言应反转为「必须调用 decryptInboundV3」）。
  group('decrypt-on-read 路径接线状态（结构级）', () {
    const mapperPath =
        'lib/modules/messaging/infrastructure/message_model_mapper.dart';

    test('toTypeMessage 目前只有 decryptE2EEMessage 一个解密入口', () {
      final source = File(mapperPath).readAsStringSync();
      expect(
        source.contains('E2EEService.decryptE2EEMessage'),
        isTrue,
        reason: '解密入口消失，本守护需重写',
      );
      expect(
        source.contains('decryptInboundV3'),
        isFalse,
        reason:
            'decrypt-on-read 已接线 v3 —— 这是好事，'
            '但本组断言必须反转，并把正向可用性用例补进来',
      );
      expect(
        source.contains('meta_version'),
        isFalse,
        reason: '出现 meta_version 分流 —— 同上，需反转断言',
      );
    });
  });
}
