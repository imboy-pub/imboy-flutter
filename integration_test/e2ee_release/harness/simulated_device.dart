/// C11 冒烟层模拟设备：真实 vodozemac Olm 加解密 + PFv3 外层信封。
///
/// 这是「双端模拟设备」冒烟层的端侧替身：
/// - 身份与 OTK 来自真实 `vodo.Account`；
/// - 会话用真实 Olm 双棘轮（合成 X3DH 握手，与
///   `integration_test/e2ee_cross_platform_interop_test.dart` 同模式）；
/// - 外层信封用生产 `ProtectedFrameV3`（canonical CBOR header + SHA-256）；
/// - 收件侧带 message_id 去重（replay 防御观测）与 fail-closed 失败分类。
///
/// 设备显示 oracle：[displayInbox] 即「设备 UI 实际渲染内容」的替身；
/// 冒烟层不构成 AC-22/AC-23 证据（见 attack-matrix.md §7 防伪声明）。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';

import '../fixture_contract.dart';
import 'backend_transport.dart';

/// 设备 UI 上的一条显示条目（显示 oracle 的替身）。
class DeviceDisplayEntry {
  const DeviceDisplayEntry({
    required this.messageId,
    required this.text,
    required this.verified,
    this.failedReason,
  });

  /// 正常条目：解密成功且 PFv3 外层校验通过。
  factory DeviceDisplayEntry.decrypted(String messageId, String text) =>
      DeviceDisplayEntry(messageId: messageId, text: text, verified: true);

  /// 失败条目：fail-closed 占位（不显示乱码、不静默丢弃）。
  factory DeviceDisplayEntry.failed(String messageId, String reason) =>
      DeviceDisplayEntry(
        messageId: messageId,
        text: '[e2ee-failed]',
        verified: false,
        failedReason: reason,
      );

  final String messageId;
  final String text;
  final bool verified;
  final String? failedReason;
}

/// 收帧结果。
enum ReceiveStatus { ok, duplicate, rejected }

class ReceiveOutcome {
  const ReceiveOutcome(this.status, {this.reason, this.plaintext});

  final ReceiveStatus status;
  final String? reason;
  final String? plaintext;
}

/// 双端握手产物：两侧各持有配对的 Olm 会话。
class HandshakeResult {
  const HandshakeResult({required this.initiator, required this.responder});

  final SimulatedDevice initiator;
  final SimulatedDevice responder;
}

/// 模拟设备。
class SimulatedDevice {
  SimulatedDevice({
    required this.account,
    required this.device,
    vod.Account? vodAccount,
  }) : _vod = vodAccount ?? vod.Account();

  final SynthAccount account;
  final SynthDevice device;
  final vod.Account _vod;

  /// peer deviceId -> Olm 会话（发送/接收共用同一 ratchet）。
  final Map<String, vod.Session> _sessions = <String, vod.Session>{};

  /// replay 去重账本。
  final Set<String> _seenMessageIds = <String>{};

  /// 发送侧单调计数（epoch_or_counter）。
  int _sendCounter = 0;

  /// 设备显示 oracle。
  final List<DeviceDisplayEntry> displayInbox = <DeviceDisplayEntry>[];

  /// 每设备 pickle 密钥（冒烟层随机；真实层由 CryptoStore/SQLCipher 管理）。
  static Uint8List newPickleKey() =>
      Uint8List.fromList(List<int>.generate(32, (_) => _rng.nextInt(256)));

  String get uid => account.uid;
  String get deviceId => device.deviceId;
  String get identityCurve25519 => _vod.identityKeys.curve25519.toBase64();

  /// 目录握手材料：生成并暴露一个 OTK（真实层走 /keys/claim 目录端点，
  /// 恶意代理的 W2 注入点即改写这里的应答，见 malicious_proxy.dart）。
  String claimOneTimeKey() {
    _vod.generateOneTimeKeys(1);
    return _vod.oneTimeKeys.values.first.toBase64();
  }

  /// 合成 X3DH 握手：initiator 用 responder 目录材料建 outbound session，
  /// responder 用 pre-key message 建 inbound session；两侧登记配对会话。
  static HandshakeResult establishSession(
    SimulatedDevice initiator,
    SimulatedDevice responder, {

    /// W2 注入点：可选改写 initiator 看到的 responder 身份/OTK 材料。
    String Function(String realKey)? directoryIdentityOverride,
    String Function(String realKey)? directoryOtkOverride,
  }) {
    final claimedOtk = responder.claimOneTimeKey();
    final responderIdentity =
        directoryIdentityOverride?.call(responder.identityCurve25519) ??
        responder.identityCurve25519;
    final responderOtk = directoryOtkOverride?.call(claimedOtk) ?? claimedOtk;

    final outbound = initiator._vod.createOutboundSession(
      identityKey: vod.Curve25519PublicKey.fromBase64(responderIdentity),
      oneTimeKey: vod.Curve25519PublicKey.fromBase64(responderOtk),
      config: legacyOlmSessionConfig(),
    );
    final preKey = outbound.encrypt('c11-handshake-${initiator.deviceId}');
    final inbound = responder._vod.createInboundSession(
      theirIdentityKey: vod.Curve25519PublicKey.fromBase64(
        initiator.identityCurve25519,
      ),
      preKeyMessageBase64: preKey.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    if (inbound.plaintext != 'c11-handshake-${initiator.deviceId}') {
      throw StateError('握手 pre-key 消息校验失败（目录材料可能被替换）');
    }
    initiator._sessions[responder.deviceId] = outbound;
    responder._sessions[initiator.deviceId] = inbound.session;
    return HandshakeResult(initiator: initiator, responder: responder);
  }

  /// 是否已与对端设备建立会话。
  bool hasSessionWith(String peerDeviceId) =>
      _sessions.containsKey(peerDeviceId);

  /// 发送一条受保护文本：真实 Olm 加密 + 生产 PFv3 外层信封。
  /// 返回可直接交传输层的帧（帧内不出现明文）。
  WireFrame sendProtectedText({
    required String messageId,
    required String plaintext,
    required SimulatedDevice peer,
  }) {
    final session = _sessions[peer.deviceId];
    if (session == null) {
      throw StateError('未与 ${peer.deviceId} 建立会话，拒绝发送（fail-closed）');
    }
    final encrypted = session.encrypt(plaintext);
    final context = FrameContext(
      messageId: messageId,
      scope: FrameScope.c2c,
      conversationId: peer.uid,
      senderUid: uid,
      senderDid: deviceId,
      destination: peer.deviceId,
      messageType: 'text',
      action: '',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      protocol: 'olm',
      protocolVersion: 3,
      sessionRef: session.sessionId,
      epochOrCounter: ++_sendCounter,
    );
    final envelope = ProtectedFrameV3.encodeOuterEnvelope(
      context: context,
      // vodozemac 密文是 base64 字符串；以 utf8 字节无损进入信封，
      // 避免标准/URL-safe base64 字母表在二次编解码时引入歧义。
      ciphertext: Uint8List.fromList(utf8.encode(encrypted.ciphertext)),
      protocolMetadata: <String, dynamic>{
        'olm_message_type': encrypted.messageType,
      },
    );
    return WireFrame(
      messageId: messageId,
      senderUid: uid,
      senderDid: deviceId,
      recipientUid: peer.uid,
      recipientDid: peer.deviceId,
      body: <String, dynamic>{
        'id': messageId,
        'type': 'C2C',
        'payload': '',
        'e2ee': <String, dynamic>{
          'meta_version': 3,
          'protocol': 'olm',
          'fan_out': 'per_device',
          'devices': <String, dynamic>{peer.deviceId: envelope},
        },
      },
    );
  }

  /// 接收一帧：PFv3 外层校验 -> 去重 -> Olm 解密；全程 fail-closed。
  ReceiveOutcome receiveFrame(WireFrame frame) {
    if (_seenMessageIds.contains(frame.messageId)) {
      // replay/重复投递：不重复推进 UI（设备显示 oracle 不变）。
      return const ReceiveOutcome(
        ReceiveStatus.duplicate,
        reason: 'duplicate_message_id',
      );
    }
    _seenMessageIds.add(frame.messageId);

    final envelope = _extractEnvelope(frame);
    if (envelope == null) {
      displayInbox.add(
        DeviceDisplayEntry.failed(frame.messageId, 'no_envelope'),
      );
      return const ReceiveOutcome(
        ReceiveStatus.rejected,
        reason: 'no_envelope',
      );
    }
    final verification = ProtectedFrameV3.verifyOuterEnvelope(envelope);
    if (!verification.isValid) {
      displayInbox.add(
        DeviceDisplayEntry.failed(
          frame.messageId,
          'envelope:${verification.reason}',
        ),
      );
      return ReceiveOutcome(
        ReceiveStatus.rejected,
        reason: verification.reason,
      );
    }

    final session = _sessions[frame.senderDid];
    if (session == null) {
      displayInbox.add(
        DeviceDisplayEntry.failed(frame.messageId, 'no_session'),
      );
      return const ReceiveOutcome(ReceiveStatus.rejected, reason: 'no_session');
    }
    final olmMessageType =
        (envelope['protocol_metadata']
            as Map<String, dynamic>?)?['olm_message_type'];
    if (olmMessageType is! int) {
      displayInbox.add(
        DeviceDisplayEntry.failed(frame.messageId, 'missing_olm_message_type'),
      );
      return const ReceiveOutcome(
        ReceiveStatus.rejected,
        reason: 'missing_olm_message_type',
      );
    }
    try {
      final ciphertextString = utf8.decode(
        base64Url.decode(envelope['ciphertext'] as String),
      );
      final plaintext = session.decrypt(
        messageType: olmMessageType,
        ciphertext: ciphertextString,
      );
      displayInbox.add(
        DeviceDisplayEntry.decrypted(frame.messageId, plaintext),
      );
      return ReceiveOutcome(ReceiveStatus.ok, plaintext: plaintext);
    } catch (error) {
      // Olm 认证失败（密文被篡改/错会话）必须显式失败，不得乱码上屏。
      displayInbox.add(
        DeviceDisplayEntry.failed(frame.messageId, 'olm_decrypt:$error'),
      );
      return ReceiveOutcome(
        ReceiveStatus.rejected,
        reason: 'olm_decrypt_failed',
      );
    }
  }

  Map<String, dynamic>? _extractEnvelope(WireFrame frame) {
    final e2ee = frame.body['e2ee'];
    if (e2ee is! Map<String, dynamic>) return null;
    final devices = e2ee['devices'];
    if (devices is! Map<String, dynamic>) return null;
    final envelope = devices[deviceId];
    if (envelope is! Map<String, dynamic>) return null;
    return envelope;
  }
}

// pickle key 用 dart:math 的安全随机（冒烟层仅在进程内使用，不落盘）。
final Random _rng = Random.secure();
