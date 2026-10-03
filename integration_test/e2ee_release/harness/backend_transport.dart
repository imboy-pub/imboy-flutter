/// C11 真实旅程传输抽象。
///
/// 两层实现：
/// - [InMemoryReleaseTransport]：冒烟层（本地嵌入式服务器替身），完全离线，
///   只用于 harness 自检，**不构成 AC-22/AC-23 证据**。
/// - [RealBackendTransport]：默认入口拒绝运行；registered 入口提供注册
///   身份的 C2C 接线，完整运行仍依赖后端/设备授权及 C07/C08/C10。
///   群组、真实密钥目录及真机旅程尚未验收。
library;

import 'registered_group_binding.dart';

import 'dart:convert';

import '../fixture_contract.dart';
import 'registered_backend_transport.dart';

/// 线上传输帧（WS 外层 JSON 的替身抽象：发送方 uid/did + 收件设备 + 帧内容）。
class WireFrame {
  const WireFrame({
    required this.messageId,
    required this.senderUid,
    required this.senderDid,
    required this.recipientUid,
    required this.recipientDid,
    required this.body,
    this.wireSeq = 0,
  });

  final String messageId;
  final String senderUid;
  final String senderDid;
  final String recipientUid;
  final String recipientDid;

  /// 帧内容（PFv3 外层信封 JSON 等）。传输层原样搬运、从不解读。
  final Map<String, dynamic> body;

  /// 服务端投递序（乱序/重放攻击注入的观测锚点）。
  final int wireSeq;

  WireFrame copyWith({String? messageId, int? wireSeq}) => WireFrame(
    messageId: messageId ?? this.messageId,
    senderUid: senderUid,
    senderDid: senderDid,
    recipientUid: recipientUid,
    recipientDid: recipientDid,
    body: body,
    wireSeq: wireSeq ?? this.wireSeq,
  );
}

/// 投递回执。
enum DeliveryReceipt { accepted, recipientOffline, rejected }

/// 真实旅程传输合同。设备以合成 fixture 的 deviceId 标识。
abstract class ReleaseTransport {
  /// 层标识：冒烟（内存替身）或真实后端。
  String get layerId;

  Future<void> start();
  Future<void> dispose();

  Future<void> connectDevice(SynthDevice device);
  Future<void> disconnectDevice(SynthDevice device);
  bool isDeviceConnected(String deviceId);

  /// 发送一帧到服务端；服务端按收件人在线状态存储/投递。
  Future<DeliveryReceipt> send(WireFrame frame);

  /// 拉取该设备当前待投递帧（冒烟层轮询语义；真实层为 WS 推送）。
  List<WireFrame> drainInbox(String deviceId);
}

/// 服务端持久化的一条密文消息（DB 消息表行的替身）。
class StoredServerMessage {
  const StoredServerMessage({
    required this.messageId,
    required this.senderUid,
    required this.senderDid,
    required this.recipientUid,
    required this.recipientDid,
    required this.bodyJson,
    required this.storedAtMs,
  });

  final String messageId;
  final String senderUid;
  final String senderDid;
  final String recipientUid;
  final String recipientDid;
  final String bodyJson;
  final int storedAtMs;
}

/// ---------------------------------------------------------------------------
/// 冒烟层：本地嵌入式服务器替身（内存消息总线 + 密文存储 + 离线 backlog）。
/// ---------------------------------------------------------------------------
class InMemoryReleaseTransport implements ReleaseTransport {
  @override
  final String layerId = 'in-memory-smoke';

  final Set<String> _connected = <String>{};
  final List<StoredServerMessage> _durableStore = <StoredServerMessage>[];
  final List<String> _deliveryLog = <String>[];
  final Map<String, List<WireFrame>> _pendingInboxes =
      <String, List<WireFrame>>{};
  final JsonCodec _json = const JsonCodec();
  int _wireSeq = 0;

  /// 服务端密文存储面 oracle：模拟 DB 消息表/归档行的全部持久化内容。
  List<StoredServerMessage> get durableStore =>
      List.unmodifiable(_durableStore);

  /// 服务端日志面 oracle：投递事件日志（只允许 message_id 等元数据）。
  List<String> get deliveryLog => List.unmodifiable(_deliveryLog);

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {
    _connected.clear();
    _pendingInboxes.clear();
  }

  @override
  Future<void> connectDevice(SynthDevice device) async {
    _connected.add(device.deviceId);
  }

  @override
  Future<void> disconnectDevice(SynthDevice device) async {
    _connected.remove(device.deviceId);
  }

  @override
  bool isDeviceConnected(String deviceId) => _connected.contains(deviceId);

  @override
  Future<DeliveryReceipt> send(WireFrame frame) async {
    // 服务端不解读帧内容，原样持久化（密文行）+ 日志只记元数据。
    _durableStore.add(
      StoredServerMessage(
        messageId: frame.messageId,
        senderUid: frame.senderUid,
        senderDid: frame.senderDid,
        recipientUid: frame.recipientUid,
        recipientDid: frame.recipientDid,
        bodyJson: _json.encode(frame.body),
        storedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!isDeviceConnected(frame.recipientDid)) {
      _deliveryLog.add('store-only ${frame.messageId} recipient-offline');
      return DeliveryReceipt.recipientOffline;
    }
    _deliver(frame);
    _deliveryLog.add('delivered ${frame.messageId}');
    return DeliveryReceipt.accepted;
  }

  void _deliver(WireFrame frame) {
    _pendingInboxes
        .putIfAbsent(frame.recipientDid, () => <WireFrame>[])
        .add(frame.copyWith(wireSeq: ++_wireSeq));
  }

  @override
  List<WireFrame> drainInbox(String deviceId) {
    final pending = _pendingInboxes[deviceId];
    if (pending == null || pending.isEmpty) return const <WireFrame>[];
    // 先快照再清空：List.unmodifiable(pending..clear()) 会包装已清空的列表。
    final drained = List<WireFrame>.unmodifiable(pending);
    pending.clear();
    return drained;
  }

  /// 离线重连：把离线期间存储、尚未投递的消息按持久化顺序补投。
  /// 返回补投帧数（AC22-S04 冒烟口径）。
  int flushBacklogFor(String deviceId) {
    var flushed = 0;
    for (final stored in List<StoredServerMessage>.from(_durableStore)) {
      if (stored.recipientDid != deviceId) continue;
      final alreadyDelivered = _deliveryLog.any(
        (line) =>
            line.startsWith('delivered ${stored.messageId}') ||
            line.startsWith('backlog-flushed ${stored.messageId}'),
      );
      if (alreadyDelivered) continue;
      _deliver(
        WireFrame(
          messageId: stored.messageId,
          senderUid: stored.senderUid,
          senderDid: stored.senderDid,
          recipientUid: stored.recipientUid,
          recipientDid: stored.recipientDid,
          body: _json.decode(stored.bodyJson) as Map<String, dynamic>,
        ),
      );
      _deliveryLog.add('backlog-flushed ${stored.messageId}');
      flushed++;
    }
    return flushed;
  }

  /// canary 明文全表面扫描（服务端密文 oracle 的替身实现）：
  /// 持久化存储 + 投递日志两面上都不应出现明文 canary。
  /// 返回命中描述列表；空列表 = PASS。
  List<String> scanPlaintextSurfaces(String canary) {
    final hits = <String>[];
    for (final stored in _durableStore) {
      if (stored.bodyJson.contains(canary)) {
        hits.add('durable-store 明文命中: ${stored.messageId}');
      }
    }
    for (final line in _deliveryLog) {
      if (line.contains(canary)) {
        hits.add('delivery-log 明文命中: $line');
      }
    }
    return hits;
  }
}

/// ---------------------------------------------------------------------------
/// 真实后端层 stub —— 本轮不实现。
///
/// REQUIRES_AUTHORIZED_BACKEND（attack-matrix.md §9 前置依赖清单）：
///  1. 授权隔离后端/PG/对象存储（`AUTHORIZED_ISOLATED_BACKEND` 等占位由用户确认）；
///  2. C07（多设备身份/生产接线）、C08（群成员/room-key/历史授权）、C10（KT）完成；
///  3. 合成账号按 fixture contract 在授权后端注册，凭据经本地环境注入；
///  4. 真机设备清单授权（Android/iOS/macOS 支持矩阵，禁模拟器与脚本默认设备）；
///  5. 本地可控 MITM 代理授权（W1–W4 注入点，attack-matrix.md §4.1）；
///  6. 服务端 DB/日志/备份/对象/Push 五面只读查询授权（与 C13 同一授权窗口）。
///
/// 实现时应连接真实 WS/REST（设备登录、发送、拉取），并为每个 attack-matrix
/// 场景提供设备显示 oracle（真机 Patrol 断言）与服务端密文 oracle（授权查询）。
/// ---------------------------------------------------------------------------
class RealBackendTransport implements ReleaseTransport {
  RealBackendTransport() : _transport = null {
    throw UnsupportedError(
      'REQUIRES_AUTHORIZED_BACKEND: 默认入口没有注册夹具或授权后端；'
      '真实旅程依赖 C07/C08/C10 完成与后端/设备授权'
      '（见 attack-matrix.md §9 前置依赖清单）。',
    );
  }

  /// Explicit registered composition; prerequisites and resources still need
  /// independent qualification. This does not authorize network execution.
  RealBackendTransport.registered(RegisteredBackendTransport transport)
    : _transport = transport;
  final RegisteredBackendTransport? _transport;
  RegisteredBackendTransport get _registered =>
      _transport ?? (throw UnsupportedError(_stubMessage));

  /// Registered C2G send only; not a recipient delivery or authorization oracle.
  Future<DeliveryReceipt> sendGroup({
    required String messageId,
    required String senderAlias,
    required String groupAlias,
    required Map<String, dynamic> body,
  }) => _registered.sendGroup(
    messageId: messageId,
    senderAlias: senderAlias,
    groupAlias: groupAlias,
    body: body,
  );

  List<RegisteredGroupFrame> drainGroupInbox(String alias) =>
      _registered.drainGroupInbox(alias);

  Future<void> acknowledgeGroupReceived(RegisteredGroupFrame frame) =>
      _registered.acknowledgeGroupReceived(frame);

  Future<void> acknowledgeReceived(WireFrame frame) =>
      _registered.acknowledgeReceived(frame);

  @override
  String get layerId => 'real-backend';

  @override
  Future<void> start() => _registered.start();

  @override
  Future<void> dispose() => _registered.dispose();

  @override
  Future<void> connectDevice(SynthDevice device) =>
      _registered.connectDevice(device);

  @override
  Future<void> disconnectDevice(SynthDevice device) =>
      _registered.disconnectDevice(device);

  @override
  bool isDeviceConnected(String deviceId) =>
      _registered.isDeviceConnected(deviceId);

  @override
  Future<DeliveryReceipt> send(WireFrame frame) => _registered.send(frame);

  @override
  List<WireFrame> drainInbox(String deviceId) =>
      _registered.drainInbox(deviceId);

  static const String _stubMessage = 'REQUIRES_AUTHORIZED_BACKEND: 未配置注册后端传输层';
}

/// REQUIRES_AUTHORIZED_BACKEND 标记常量：真实层代码/文档统一引用此串，
/// 便于验收检索与防伪扫描。
const String requiresAuthorizedBackendTag = 'REQUIRES_AUTHORIZED_BACKEND';
