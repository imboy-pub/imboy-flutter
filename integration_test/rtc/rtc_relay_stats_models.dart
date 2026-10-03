// integration_test/rtc/rtc_relay_stats_models.dart
//
// L4 SNI · TLS443 relay 证据判定——数据模型与解析层（纯 Dart，无 Flutter
// 依赖，可单测）。
//
// 本文件自 rtc_relay_stats_judge.dart 拆出（文件行数指导线 <800），
// 承载纯数据与解析部分：
//   - 判定结果常量（kVerdict* 等；判定与解析共用，judge 侧 re-export）；
//   - 解析后的 stats 快照数据结构（CandidateInfo / CandidatePairInfo /
//     TransportInfo / PcStatsSample / StatsPollFrame / RunMeta）；
//   - 原始 stats 报告 -> 快照的适配层（parseStatsReports）；
//   - TURN url 解析（TurnUrlParts / parseTurnUrl）。
// 判定逻辑（selected pair 绑定 / relay-only / TLS443 / 帧聚合）仍在
// rtc_relay_stats_judge.dart；该文件 import 并 re-export 本文件，
// 既有引用方的 import 保持不变。
//
// 事实边界（计划 Task 4，违反即 FAIL）中的取数约束：
//   - candidate 的 address/port 只记录实际值，绝不做 443 断言；
//   - 字段缺失进 missing 清单，绝不编造。
//
// 依据：https://www.w3.org/TR/webrtc-stats/#dom-rtcicecandidatestats
// candidateType 标准值：host / prflx / srflx / relay。

library;

/// 判定结果常量。
const String kVerdictPass = 'PASS';
const String kVerdictFail = 'FAIL';
const String kVerdictBlocked = 'BLOCKED_EVIDENCE';

/// ICE candidate pair 的成功态实际语义：
/// Chrome/Android native 报 `succeeded`，部分实现（Safari 风格）报
/// `connected`；其余（frozen/waiting/in-progress/failed）一律不算成功。
const Set<String> kPairSuccessStates = {'succeeded', 'connected'};

/// w3c 标准 candidateType 中的 relay 值（小写比较）。
const String kCandidateTypeRelay = 'relay';

/// TLS443 判定接受的 relayProtocol 实际值集合（小写比较）。
/// Chrome 对 TURN/TLS 通常报 `tcp`；个别实现报 `tls`。`udp` 不能证明 TLS。
const Set<String> kTlsRelayProtocols = {'tcp', 'tls'};

// ──────────────────────────────────────────────
// 采样数据结构（解析后的 stats 快照）
// ──────────────────────────────────────────────

/// 单个 ICE candidate 快照（local 或 remote 侧）。
class CandidateInfo {
  const CandidateInfo({
    required this.id,
    required this.isLocal,
    this.candidateType,
    this.address,
    this.port,
    this.url,
    this.relayProtocol,
    this.protocol,
    this.missing = const {},
  });

  final String id;
  final bool isLocal;

  /// w3c: host / prflx / srflx / relay（平台缺失时为 null）。
  final String? candidateType;

  /// candidate 实际地址/端口（仅记录实际值，绝不做 443 断言）。
  final String? address;
  final int? port;

  /// 分配该 candidate 的 TURN server url；仅 local 侧有语义。
  final String? url;

  /// relay 分配所用传输协议（tcp/udp/tls…）；仅 local relay 侧有语义。
  final String? relayProtocol;

  /// candidate 自身传输协议（部分平台提供）。
  final String? protocol;

  /// 缺失字段 -> 缺失原因（native stats 未提供 / 报告中不存在）。
  final Map<String, String> missing;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'side': isLocal ? 'local' : 'remote',
    if (candidateType != null) 'candidateType': candidateType,
    if (address != null) 'address': address,
    if (port != null) 'port': port,
    // url / relayProtocol 仅 local 侧有语义，remote 侧不输出。
    if (isLocal && url != null) 'url': url,
    if (isLocal && relayProtocol != null) 'relayProtocol': relayProtocol,
    if (protocol != null) 'protocol': protocol,
    if (missing.isNotEmpty) 'missing': missing,
  };
}

/// candidate pair 快照。
class CandidatePairInfo {
  const CandidatePairInfo({
    required this.id,
    this.localCandidateId,
    this.remoteCandidateId,
    this.state,
    this.nominated,
    this.selected,
  });

  final String id;
  final String? localCandidateId;
  final String? remoteCandidateId;

  /// frozen / waiting / in-progress / succeeded / failed（部分实现 connected）。
  final String? state;
  final bool? nominated;
  final bool? selected;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (localCandidateId != null) 'localCandidateId': localCandidateId,
    if (remoteCandidateId != null) 'remoteCandidateId': remoteCandidateId,
    if (state != null) 'state': state,
    if (nominated != null) 'nominated': nominated,
    if (selected != null) 'selected': selected,
  };
}

/// transport（RTCTransportStats）快照。
class TransportInfo {
  const TransportInfo({
    required this.id,
    this.selectedCandidatePairId,
    this.dtlsState,
  });

  /// stats 报告里的 transport id（如 "T1"）。
  final String id;

  /// 当前所选 candidate pair 的绑定依据（判定首选，缺此字段不可回退 nominated）。
  final String? selectedCandidatePairId;
  final String? dtlsState;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'selectedCandidatePairId': selectedCandidatePairId,
    if (dtlsState != null) 'dtlsState': dtlsState,
  };
}

/// 一条 PeerConnection（pc 角色：publisher / subscriber）的一轮 stats 快照。
class PcStatsSample {
  PcStatsSample({
    required this.pcRole,
    required this.sampledAt,
    this.transports = const [],
    this.candidatePairs = const [],
    this.candidates = const [],
    this.missing = const {},
  });

  /// pc 不可用（未建立 / pc 对象缺失）时的占位采样。
  PcStatsSample.unavailable({
    required String pcRole,
    required DateTime sampledAt,
    required String reason,
  }) : this(
         pcRole: pcRole,
         sampledAt: sampledAt,
         missing: <String, String>{'peer_connection': reason},
       );

  final String pcRole;
  final DateTime sampledAt;
  final List<TransportInfo> transports;
  final List<CandidatePairInfo> candidatePairs;
  final List<CandidateInfo> candidates;

  /// 采样级缺失（如整个 pc 不可用 / 无 transport 报告）及原因。
  final Map<String, String> missing;

  CandidateInfo? candidateById(String? id) =>
      id == null ? null : candidates.where((c) => c.id == id).firstOrNull;

  CandidatePairInfo? pairById(String? id) =>
      id == null ? null : candidatePairs.where((p) => p.id == id).firstOrNull;

  Map<String, Object?> toJson() => <String, Object?>{
    'pc_role': pcRole,
    'sampled_at': sampledAt.toIso8601String(),
    'sampled_at_epoch_ms': sampledAt.millisecondsSinceEpoch,
    'transports': [for (final t in transports) t.toJson()],
    'candidate_pairs': [for (final p in candidatePairs) p.toJson()],
    'candidates': [for (final c in candidates) c.toJson()],
    if (missing.isNotEmpty) 'missing': missing,
  };
}

/// 一轮轮询采到的全部 pc 快照。
class StatsPollFrame {
  StatsPollFrame({required this.collectedAt, required this.pcSamples});

  final DateTime collectedAt;
  final List<PcStatsSample> pcSamples;

  Map<String, Object?> toJson() => <String, Object?>{
    'collected_at': collectedAt.toIso8601String(),
    'collected_at_epoch_ms': collectedAt.millisecondsSinceEpoch,
    'pc_samples': [for (final s in pcSamples) s.toJson()],
  };
}

/// run 级元数据（随证据 NDJSON 输出；不含任何 secret/token）。
class RunMeta {
  RunMeta({
    required this.runId,
    required this.startedAt,
    required this.wsUrl,
    required this.strict,
    required this.requireTls,
    required this.expectTlsPort,
  });

  final String runId;
  final DateTime startedAt;

  /// LiveKit WS 接入地址（不含 token；token 只在连接时引用，绝不输出）。
  final String wsUrl;
  final bool strict;
  final bool requireTls;
  final int expectTlsPort;

  Map<String, Object?> toJson() => <String, Object?>{
    'run_id': runId,
    'started_at': startedAt.toIso8601String(),
    'ws_url': wsUrl,
    'strict': strict,
    'require_tls': requireTls,
    'expect_tls_port': expectTlsPort,
    // 事实边界声明：本探针不发布媒体，证据级别为连接级。
    'evidence_level':
        'connection-level (no media published; media-level proof '
        'requires the two-device publish/subscribe test)',
    'schema_version': 1,
  };
}

// ──────────────────────────────────────────────
// 原始 stats 报告 -> 快照（适配层）
// ──────────────────────────────────────────────

/// 把 flutter_webrtc `pc.getStats()` 的报告列表适配为 [PcStatsSample]。
///
/// 报告元素为 StatsReport-like 对象（`.id` / `.type` / `.values`）；
/// 字段名兼容驼峰（`candidateType`，Chrome/Android 风格）与
/// snake_case（`candidate_type`，部分 native 风格）。取不到的字段进
/// `missing`，不编造。
PcStatsSample parseStatsReports({
  required String pcRole,
  required Iterable<dynamic> reports,
  DateTime? sampledAt,
}) {
  final now = sampledAt ?? DateTime.now();
  final transports = <TransportInfo>[];
  final pairs = <CandidatePairInfo>[];
  final candidates = <CandidateInfo>[];
  for (final raw in reports) {
    final report = raw as dynamic;
    final type = report.type as String?;
    final id = report.id as String?;
    final values = report.values as Map<dynamic, dynamic>?;
    if (type == null || values == null) continue;
    switch (type) {
      case 'transport':
        transports.add(_parseTransport(id!, values));
      case 'candidate-pair':
      case 'selected-candidate-pair':
        pairs.add(_parsePair(id!, values));
      case 'local-candidate':
        candidates.add(_parseCandidate(id!, values, isLocal: true));
      case 'remote-candidate':
        candidates.add(_parseCandidate(id!, values, isLocal: false));
    }
  }
  return PcStatsSample(
    pcRole: pcRole,
    sampledAt: now,
    transports: transports,
    candidatePairs: pairs,
    candidates: candidates,
    missing: transports.isEmpty
        ? <String, String>{
            'transport': 'no transport stats report in this poll',
          }
        : const <String, String>{},
  );
}

TransportInfo _parseTransport(String id, Map<dynamic, dynamic> values) {
  return TransportInfo(
    id: id,
    selectedCandidatePairId: _readString(
      values,
      'selectedCandidatePairId',
      'selected_candidate_pair_id',
    ),
    dtlsState: _readString(values, 'dtlsState', 'dtls_state'),
  );
}

CandidatePairInfo _parsePair(String id, Map<dynamic, dynamic> values) {
  return CandidatePairInfo(
    id: id,
    localCandidateId: _readString(
      values,
      'localCandidateId',
      'local_candidate_id',
    ),
    remoteCandidateId: _readString(
      values,
      'remoteCandidateId',
      'remote_candidate_id',
    ),
    state: _readString(values, 'state', 'state'),
    nominated: _readBool(values, 'nominated', 'nominated'),
    selected: _readBool(values, 'selected', 'selected'),
  );
}

CandidateInfo _parseCandidate(
  String id,
  Map<dynamic, dynamic> values, {
  required bool isLocal,
}) {
  const reason = 'absent in native stats report (platform may not support it)';
  final candidateType = _readString(values, 'candidateType', 'candidate_type');
  final url = isLocal ? _readString(values, 'url', 'url') : null;
  final relayProtocol = isLocal
      ? _readString(values, 'relayProtocol', 'relay_protocol')
      : null;
  return CandidateInfo(
    id: id,
    isLocal: isLocal,
    candidateType: candidateType,
    address: _readString(values, 'address', 'ip'),
    port: _readInt(values, 'port', 'network_port'),
    url: url,
    relayProtocol: relayProtocol,
    protocol: _readString(values, 'protocol', 'protocol'),
    missing: <String, String>{
      if (candidateType == null) 'candidateType': reason,
      // url / relayProtocol 仅 local 侧有语义；缺失会阻碍 TLS443 判定，
      // 记入缺失清单供 BLOCKED_EVIDENCE 输出。
      if (isLocal && url == null) 'url': reason,
      if (isLocal && relayProtocol == null) 'relayProtocol': reason,
    },
  );
}

String? _readString(Map<dynamic, dynamic> values, String camel, String snake) {
  final v = values[camel] ?? values[snake];
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool? _readBool(Map<dynamic, dynamic> values, String camel, String snake) {
  final v = values[camel] ?? values[snake];
  return v is bool ? v : (v?.toString() == 'true' ? true : null);
}

int? _readInt(Map<dynamic, dynamic> values, String camel, String snake) {
  final v = values[camel] ?? values[snake];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return v == null ? null : int.tryParse(v.toString());
}

// ──────────────────────────────────────────────
// TURN url 解析
// ──────────────────────────────────────────────

/// TURN url 解析结果（scheme / host / port / query transport）。
class TurnUrlParts {
  const TurnUrlParts({
    required this.scheme,
    required this.host,
    this.port,
    this.transport,
  });

  final String scheme;
  final String host;
  final int? port;
  final String? transport;
}

/// 解析 `turn:host:3478?transport=udp` / `turns:host:443?transport=tcp` /
/// `turns:[2001:db8::1]:443?transport=tcp` 形式的 TURN url。
/// 无法可靠解析时返回 null（调用方记 BLOCKED_EVIDENCE，不猜测）。
TurnUrlParts? parseTurnUrl(String url) {
  final schemeMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):').firstMatch(url);
  if (schemeMatch == null) return null;
  final scheme = schemeMatch.group(1)!.toLowerCase();
  var rest = url.substring(schemeMatch.end);
  String? transport;
  final q = rest.indexOf('?');
  if (q >= 0) {
    final query = rest.substring(q + 1);
    rest = rest.substring(0, q);
    for (final kv in query.split('&')) {
      final eq = kv.indexOf('=');
      if (eq > 0 && kv.substring(0, eq) == 'transport') {
        transport = kv.substring(eq + 1).toLowerCase();
      }
    }
  }
  return _splitHostPort(scheme, rest, transport);
}

TurnUrlParts? _splitHostPort(
  String scheme,
  String hostPort,
  String? transport,
) {
  if (hostPort.isEmpty) return null;
  String host;
  int? port;
  if (hostPort.startsWith('[')) {
    // IPv6 literal: [::1]:443
    final close = hostPort.indexOf(']');
    if (close < 0) return null;
    host = hostPort.substring(1, close);
    if (close + 1 < hostPort.length) {
      if (!hostPort.startsWith(':', close + 1)) return null;
      port = int.tryParse(hostPort.substring(close + 2));
    }
  } else {
    final colon = hostPort.lastIndexOf(':');
    if (colon < 0) {
      host = hostPort;
    } else if (hostPort.indexOf(':') != colon) {
      // 多个冒号且未用 [] 包裹：无法可靠分割。
      return null;
    } else {
      host = hostPort.substring(0, colon);
      port = int.tryParse(hostPort.substring(colon + 1));
    }
  }
  if (host.isEmpty) return null;
  return TurnUrlParts(
    scheme: scheme,
    host: host,
    port: port,
    transport: transport,
  );
}
