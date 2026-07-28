/// 生产投递形状的 PFv3 接收门 —— 输入是**后端真实投递帧**，不是手工 fixture。
///
/// ## 为什么需要这个文件（任务 A：按新边界重新验收 012/023/024/025/029）
///
/// `evidence/E2EE-012-024-review.md` 指出的方法论缺陷是：
/// 「收紧校验 → 既有测试变红 → 改测试 fixture 去迁就 → 宣布 PASS」。
/// 该 review §3 把 `_validateContextBinding` 的 7 项逐一列表，其中
/// **#2 `sender_uid` 与 #6 `sender_did` 标为「⚠️ 未实证」**，并写明：
///
/// > 静态看应当相等，但本次复核的教训正是「静态看起来对齐 ≠ 生产对齐」。
///
/// 而 `v3_receive_path_e2e_test.dart::buildV3Message` 在构造入站帧时
/// **手工补了顶层 `'sender_did': 'dev-sender'`**，恰好把 #6 抹平了 ——
/// 同一个「改 fixture 去迁就」的模式又重复了一次。
///
/// 本文件把入站帧改为后端**实际产出**的形状。首次运行时 7 项正向用例
/// 全部红，失败原因一律 `context_mismatch_sender_did`，暴露出接线之后仍然
/// 存在的第 4 个断点：
///
/// | 修复前事实 | 出处 |
/// |---|---|
/// | 投递帧字段集 = ver/id/type/from/to/msg_type/action/e2ee/payload/server_ts | `imboy/src/ds/message_ds.erl` `assemble_msg/8` |
/// | `sender_did` 注入的是 **payload 内部**，不是帧顶层 | `imboy/src/ds/message_ds.erl` `inject_sender_device/2` |
/// | 注入只在 payload 是 map 或可 JSON 解码的 binary 时发生 | 同上 |
/// | v3 外层 payload 恒为空串 | `lib/service/e2ee/e2ee_outbound_router.dart:183` |
///
/// 两条事实相叠：v3 的 payload 是空串 → `inject_sender_device` 走 binary
/// 分支、`jsone:decode(<<>>)` 失败 → **原样返回，什么都没注入** →
/// 接收侧 `data['sender_did']` 恒为 null → context binding #6 必然失配 →
/// **每条生产 C2C v3 消息不可读**。
///
/// ## 修复
///
/// 后端新增 `message_ds:stamp_sender_device/2`，把已认证 WS State 的
/// did/dtype 盖在**信封顶层**（payload 层对 E2EE 消息不可用），
/// 并由 `message_ds:with_sender_device/2` 带进投递帧。
/// 服务端侧守护见 `imboy/test/ds/e2ee_sender_device_envelope_tests.erl`。
///
/// ## 本文件的三组门
///
/// 1. **正向可用性门** —— 修复后的真实投递帧必须可读。这正是 E2EE-012/024
///    验收中缺失的那一类用例（原验收只验「篡改能否拒收」，该指标在一个
///    拒绝所有消息的实现上恒成立）。
/// 2. **接线守护** —— 结构级断言 `_handleE2EEMessage` 委托给 `decryptInboundV3`。
/// 3. **fail-closed 负向门** —— 服务端不提供 / 伪造 `sender_did` 时必须拒收。
///    它同时充当原 RED 的回归证据：把第 3 组改绿的唯一办法是放行，而放行
///    正是被禁止的 fail-open。
///
/// ⚠️ 首次跑本文件时第 3 组（当时叫「对照组」，仅手工补 sender_did）是唯一
/// 的绿，正是它隔离出断点在 `sender_did` 而非 harness 缺陷。对照组红时必须
/// 停下重估，见 `evidence/E2EE-v3-receive-path-not-wired.md` §6。
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

/// 发送者身份（对端）。接收侧比对的 header.sender_uid / sender_did 都是这两个值。
const String _senderUid = '100';
const String _senderDid = 'dev-sender-01';
const String _sessionId = 'kR8pQmXv2TnL7yFwZ0aBcDeGhIjKlMnOpQrStUvWxYz';

/// 恒等协议：只替换密码学，不替换 wiring。
///
/// metadata 形状逐字段对照真实实现 `lib/service/e2ee/olm_protocol.dart:67-78`：
/// protocol / version / e2ee_suite / peer_uid / peer_device_id /
/// message_type / session_id 共 7 键，一个不多一个不少。
/// `peer_uid` / `peer_device_id` 按真实实现填**发送方自身身份**
/// （olm_protocol.dart:73-75 注释：「peer 视角：填发送方自身身份」）。
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
    // 逐用例新建库：跨消息状态（outbox / dedupe）会让结果依赖执行顺序。
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);

    // 顺序要紧：先让 bootstrap 完成一次真实注册（把内部 _registered 置 true），
    // 再清空 registry 换入恒等协议。否则解密时 ensureRegistered() 会再注册
    // 真实 OlmProtocol，撞 'already registered: olm'。
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

  const myUid = '200';

  /// 复刻 `chat_network_service._encryptC2COlmFanOut` 的逐设备加密。
  ///
  /// [extraDids] 用于模拟对端多设备 fan-out：除本机 did 外再挂若干设备信封，
  /// 接收侧必须只取本机那一个（E2EE-029 接收侧）。
  Future<Map<String, dynamic>> buildFanOutE2ee({
    required String msgId,
    required String messageType,
    required String plaintextBody,
    List<String> extraDids = const [],
  }) async {
    final devices = <String, dynamic>{};

    for (final targetDid in [deviceId, ...extraDids]) {
      final encrypted = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode({
          'msg_type': messageType,
          // 每个设备信封放可区分的正文，才能断言「取的是本机那一个」
          'body': targetDid == deviceId ? plaintextBody : 'WRONG-DEVICE-BODY',
        }),
        recipients: [
          RecipientDevice(deviceId: targetDid, keyId: 'k1', publicKey: 'pk-1'),
        ],
        context: E2eeContext(
          peerUid: myUid,
          peerDeviceId: targetDid,
          scope: 'c2c',
        ),
        messageId: msgId,
        senderUid: _senderUid,
        senderDid: _senderDid,
        destination: myUid,
        messageType: messageType,
        action: 'message',
        sessionRef: _sessionId,
        createdAtMs: 1753500000000,
      );

      final envelope = Map<String, dynamic>.from(encrypted.metadata);
      envelope.remove('meta_version'); // 由外层统一标注
      devices[targetDid] = envelope;
    }

    return {
      'meta_version': 3,
      'protocol': 'olm',
      'version': 1,
      'fan_out': 'per_device',
      'devices': devices,
    };
  }

  /// 后端 C2C 实时投递帧的实际产出：
  /// `message_ds:assemble_msg/8`（message_ds.erl:201-216）
  /// + `message_ds:with_sender_device/2`（本轮修复新增，msg_c2c_logic.erl:365）。
  ///
  /// `sender_did` / `sender_dtype` 由 `websocket_logic:stamp_sender_device/2`
  /// 从已认证的 WS State 盖在**信封顶层**——payload 层对 E2EE 消息不可用
  /// （v3 payload 恒为空串），服务端侧的实证见
  /// `imboy/test/ds/e2ee_sender_device_envelope_tests.erl`。
  ///
  /// [fromWireValue] 用于覆盖 `from` 的线上表示：后端 `From = CurrentUid`
  /// 是 Erlang 整数（msg_c2c_logic.erl:156），JSON 编码后是数字；
  /// 但 message_ds.erl:203 注释又要求「所有 ID 必须转为 binary 字符串」。
  /// 两种表示都必须被接受（context binding #2），故参数化。
  ///
  /// [withSenderDevice] = false 复刻**修复前**的帧（顶层无设备标识），
  /// 用于 fail-closed 负向门：服务端不提供时必须拒收，不得放行。
  Map<String, dynamic> serverDeliveredFrame({
    required String msgId,
    required String messageType,
    required Map<String, dynamic> e2ee,
    required Object fromWireValue,
    bool withSenderDevice = true,
  }) {
    return {
      'ver': 2,
      'id': msgId,
      'type': 'C2C',
      'from': fromWireValue,
      'to': myUid,
      'msg_type': messageType,
      'action': 'message',
      'e2ee': e2ee,
      'payload': '', // v3：密文在信封内，外层恒为空串
      'server_ts': 1753500000123,
      if (withSenderDevice) 'sender_did': _senderDid,
      if (withSenderDevice) 'sender_dtype': 'ios',
    };
  }

  group('生产投递形状的 v3 正向可用性门', () {
    test('后端实际投递帧必须能解出明文', () async {
      const body = 'production shaped inbound body';
      final frame = serverDeliveredFrame(
        msgId: 'prod-frame-001',
        messageType: 'text',
        e2ee: await buildFanOutE2ee(
          msgId: 'prod-frame-001',
          messageType: 'text',
          plaintextBody: body,
        ),
        fromWireValue: int.parse(_senderUid), // 后端 From 是整数
      );

      final result = await E2EEService.decryptInboundV3(data: frame);

      expect(result, isNotNull, reason: 'v3 帧必须被 decryptInboundV3 认领');
      expect(
        result!['_e2ee_failed'],
        isNot(true),
        reason:
            '后端真实投递帧必须可读。失败原因: ${result['_e2ee_reason']}\n'
            'context_mismatch_sender_did 意味着 context binding #6 '
            '拿服务端从未提供的字段做硬比对（见本文件头部事实表）。',
      );
      expect(result['body'], equals(body));
      expect(result['_e2ee_v3_verified'], isTrue);
    });

    test('from 为字符串表示时同样必须可读（context binding #2）', () async {
      const body = 'string uid body';
      final frame = serverDeliveredFrame(
        msgId: 'prod-frame-002',
        messageType: 'text',
        e2ee: await buildFanOutE2ee(
          msgId: 'prod-frame-002',
          messageType: 'text',
          plaintextBody: body,
        ),
        fromWireValue: _senderUid, // 字符串表示
      );

      final result = await E2EEService.decryptInboundV3(data: frame);
      expect(result, isNotNull);
      expect(
        result!['_e2ee_failed'],
        isNot(true),
        reason: '失败原因: ${result['_e2ee_reason']}',
      );
      expect(result['body'], equals(body));
    });

    // E2EE-024 的「100% Mutation Rejection Rate」在一个拒绝所有消息的实现上
    // 恒成立。非文本类型是 review §3 #5 指出的第二个生产不对齐项，必须有正向用例。
    for (final messageType in ['image', 'video', 'audio', 'file']) {
      test('非文本消息 msg_type=$messageType 在生产投递形状下必须可读', () async {
        final msgId = 'prod-frame-$messageType';
        final frame = serverDeliveredFrame(
          msgId: msgId,
          messageType: messageType,
          e2ee: await buildFanOutE2ee(
            msgId: msgId,
            messageType: messageType,
            plaintextBody: 'body-$messageType',
          ),
          fromWireValue: int.parse(_senderUid),
        );

        final result = await E2EEService.decryptInboundV3(data: frame);
        expect(result, isNotNull);
        expect(
          result!['_e2ee_failed'],
          isNot(true),
          reason: '失败原因: ${result['_e2ee_reason']}',
        );
        expect(result['msg_type'], equals(messageType));
        expect(result['body'], equals('body-$messageType'));
      });
    }

    // E2EE-029 接收侧：per-device fan-out 必须按本机 deviceId 取信封。
    test('对端多设备 fan-out 时必须只采用本机信封', () async {
      const body = 'my device only';
      final frame = serverDeliveredFrame(
        msgId: 'prod-frame-fanout',
        messageType: 'text',
        e2ee: await buildFanOutE2ee(
          msgId: 'prod-frame-fanout',
          messageType: 'text',
          plaintextBody: body,
          extraDids: const ['other-device-a', 'other-device-b'],
        ),
        fromWireValue: int.parse(_senderUid),
      );

      final result = await E2EEService.decryptInboundV3(data: frame);
      expect(result, isNotNull);
      expect(
        result!['_e2ee_failed'],
        isNot(true),
        reason: '失败原因: ${result['_e2ee_reason']}',
      );
      expect(
        result['body'],
        equals(body),
        reason: '必须取 devices[本机 deviceId]，不得取他机信封',
      );
    });
  });

  // `evidence/E2EE-v3-receive-path-not-wired.md` §7.4.1 残留项：
  // 「`_handleE2EEMessage` 确实委托给 `decryptInboundV3`」此前只靠代码审查保证。
  // `_handleE2EEMessage` 是私有方法，且 `_receiveMessage` 耦合了 contact 仓储 /
  // 会话 provider（端到端 harness 尝试失败见同文件 §7.5），行为级断言暂不可得。
  // 这里退而求其次做**结构守护**：委托一旦被删除，测试立刻红。
  // 它不是行为证明，但能防止「接线被悄悄改回去」这一类回归——
  // 而这正是耗掉三轮才发现的那个缺口。
  group('接线守护（结构级，非行为级）', () {
    test('_handleE2EEMessage 必须在 v1/v2 路径之前委托给 decryptInboundV3', () {
      final source = File('lib/service/message.dart').readAsStringSync();

      final handlerIdx = source.indexOf('_handleE2EEMessage({');
      expect(handlerIdx, greaterThan(-1), reason: '_handleE2EEMessage 定义不存在');

      final delegateIdx = source.indexOf(
        'E2EEService.decryptInboundV3',
        handlerIdx,
      );
      expect(
        delegateIdx,
        greaterThan(-1),
        reason: '_handleE2EEMessage 不再调用 decryptInboundV3 —— v3 接线被移除',
      );

      // v1/v2 路径的第一步是取外层密文字符串；v3 分流必须排在它之前，
      // 否则 v3 的空串 payload 会先撞 empty_payload（历史上的静默丢弃）。
      final legacyIdx = source.indexOf(
        "data['payload']?.toString()",
        handlerIdx,
      );
      expect(legacyIdx, greaterThan(-1), reason: 'v1/v2 取密文的锚点消失，守护需重写');
      expect(
        delegateIdx,
        lessThan(legacyIdx),
        reason: 'v3 分流必须在 v1/v2 密文形状检查之前，否则 v3 会被判 empty_payload',
      );
    });

    test('_receiveMessage 的空 payload early-return 必须对 v3 放行', () {
      final source = File('lib/service/message.dart').readAsStringSync();
      expect(
        source.contains("final isV3 = e2ee['meta_version'] == 3;"),
        isTrue,
        reason: 'v3 判定消失：空串 payload 的 early return 会重新静默丢弃 v3 消息',
      );
    });
  });

  group('fail-closed 负向门：服务端不提供设备标识时必须拒收', () {
    // 修复前的帧形状（顶层无 sender_did）。当初 7 项正向用例全部因此判
    // context_mismatch_sender_did，是本任务的 RED 证据。
    //
    // 修复后这条路径**必须继续被拒**：绑定的价值就在于服务端那一份不可伪造，
    // 缺失时放行等于把 #6 降级成可选项（fail-open），属明令禁止。
    test('缺顶层 sender_did 的帧必须判 context_mismatch_sender_did', () async {
      final frame = serverDeliveredFrame(
        msgId: 'failclosed-001',
        messageType: 'text',
        e2ee: await buildFanOutE2ee(
          msgId: 'failclosed-001',
          messageType: 'text',
          plaintextBody: 'must not be readable',
        ),
        fromWireValue: int.parse(_senderUid),
        withSenderDevice: false,
      );

      final result = await E2EEService.decryptInboundV3(data: frame);
      expect(result, isNotNull, reason: '必须返回失败分类，不得静默丢弃');
      expect(
        result!['_e2ee_failed'],
        isTrue,
        reason: '服务端未提供设备标识时放行 = context binding #6 降级为 fail-open',
      );
      expect(result['_e2ee_reason'], equals('context_mismatch_sender_did'));
    });

    test('伪造的 sender_did 与受认证 header 不符时必须拒收', () async {
      final frame = serverDeliveredFrame(
        msgId: 'failclosed-002',
        messageType: 'text',
        e2ee: await buildFanOutE2ee(
          msgId: 'failclosed-002',
          messageType: 'text',
          plaintextBody: 'must not be readable',
        ),
        fromWireValue: int.parse(_senderUid),
      );
      frame['sender_did'] = 'attacker-device';

      final result = await E2EEService.decryptInboundV3(data: frame);
      expect(result!['_e2ee_failed'], isTrue);
      expect(result['_e2ee_reason'], equals('context_mismatch_sender_did'));
    });
  });
}
