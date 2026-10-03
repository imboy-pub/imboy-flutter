// integration_test/rtc/rtc_relay_stats_judge.dart
//
// L4 SNI · TLS443 relay 证据判定（纯 Dart，无 Flutter 依赖，可单测）。
//
// 事实边界（计划 Task 4，违反即 FAIL）：
//   1. TURN/TLS 接入端口 != relay candidate 端口。禁止断言 candidate.port=443；
//      candidate 的 address/port 只记录实际值。TLS443 由「客户端所选 local
//      relay candidate 的 TURN url（scheme=turns + url 端口）+ relayProtocol
//      （tcp/tls）」证明，remote 侧 relay 不能替代 local relay。
//   2. selected pair 绑定以 transport.selectedCandidatePairId 为准，
//      nominated 标记单独不能当 selected 证明。
//   3. relay-only 判定只排除 host/srflx（及 prflx），不排除 TURN/UDP：
//      candidateType=relay + url=turn:... + relayProtocol=udp 在 relay-only
//      判定为 PASS，在 TLS443 判定为 FAIL。
//   4. 字段缺失（无 selectedCandidatePairId / 无 url / 无 relayProtocol 等）
//      输出 BLOCKED_EVIDENCE + 缺失清单，绝不抛异常、绝不编造。
//
// 判定输入是解析后的 stats 结构（PcStatsSample），全部为纯函数；
// 原始报告适配见 [parseStatsReports]（接收 StatsReport-like 对象：
//   .id / .type / .values）。
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
// selected pair 绑定（判定前置）
// ──────────────────────────────────────────────

/// transport.selectedCandidatePairId 优先绑定结果。
class SelectedPairBinding {
  const SelectedPairBinding({
    required this.status,
    required this.problems,
    this.transport,
    this.pair,
    this.localCandidate,
    this.remoteCandidate,
    this.notes = const [],
  });

  /// 'ok'：绑定成功且 pair 状态成功；'fail'：有证据不满足；
  /// 'blocked'：证据不足以绑定。
  final String status;
  final List<String> problems;
  final TransportInfo? transport;
  final CandidatePairInfo? pair;
  final CandidateInfo? localCandidate;
  final CandidateInfo? remoteCandidate;
  final List<String> notes;
}

const String _bindOk = 'ok';
const String _bindFail = 'fail';
const String _bindBlocked = 'blocked';

/// 绑定当前所选 pair 并验证成功状态：
/// 1. 必须由 transport.selectedCandidatePairId 指定（nominated 单独不算）；
/// 2. pair 必须存在于 candidate-pair 报告；
/// 3. pair.state 必须是 succeeded/connected；
/// 4. local candidate 必须可解析（remote 缺失只记 note，不阻断——
///    remote relay 不能替代 local relay，判定只看 local 侧）。
SelectedPairBinding bindSelectedPair(PcStatsSample sample) {
  if (sample.transports.isEmpty) {
    return const SelectedPairBinding(
      status: _bindBlocked,
      problems: ['no transport stats report sampled for this pc'],
    );
  }
  TransportInfo? transport;
  for (final t in sample.transports) {
    final sel = t.selectedCandidatePairId;
    if (sel != null && sel.isNotEmpty) {
      transport = t;
      break;
    }
  }
  if (transport == null) {
    final nominated = sample.candidatePairs.where((p) => p.nominated == true);
    if (nominated.isNotEmpty) {
      return const SelectedPairBinding(
        status: _bindFail,
        problems: [
          'nominated alone is not selection proof: transport.selectedCandidatePairId '
              'absent while a nominated pair exists',
        ],
      );
    }
    return const SelectedPairBinding(
      status: _bindBlocked,
      problems: [
        'transport.selectedCandidatePairId absent and no nominated pair to inspect',
      ],
    );
  }
  return _bindPairById(sample, transport);
}

SelectedPairBinding _bindPairById(
  PcStatsSample sample,
  TransportInfo transport,
) {
  final pairId = transport.selectedCandidatePairId!;
  final pair = sample.pairById(pairId);
  if (pair == null) {
    return SelectedPairBinding(
      status: _bindBlocked,
      problems: [
        'selected candidate pair "$pairId" not found in stats reports',
      ],
    );
  }
  final state = pair.state?.toLowerCase();
  if (state == null) {
    return SelectedPairBinding(
      status: _bindBlocked,
      problems: ['candidate-pair "$pairId" state absent'],
      transport: transport,
      pair: pair,
    );
  }
  if (!kPairSuccessStates.contains(state)) {
    return SelectedPairBinding(
      status: _bindFail,
      problems: [
        'selected pair state="$state" is not succeeded/connected '
            '(pair not established)',
      ],
      transport: transport,
      pair: pair,
    );
  }
  return _bindLocalCandidate(sample, transport, pair);
}

SelectedPairBinding _bindLocalCandidate(
  PcStatsSample sample,
  TransportInfo transport,
  CandidatePairInfo pair,
) {
  if (pair.localCandidateId == null) {
    return SelectedPairBinding(
      status: _bindBlocked,
      problems: ['selected pair has no localCandidateId'],
      transport: transport,
      pair: pair,
    );
  }
  final local = sample.candidateById(pair.localCandidateId);
  if (local == null) {
    return SelectedPairBinding(
      status: _bindBlocked,
      problems: ['local candidate "${pair.localCandidateId}" not found'],
      transport: transport,
      pair: pair,
    );
  }
  final remote = sample.candidateById(pair.remoteCandidateId);
  return SelectedPairBinding(
    status: _bindOk,
    problems: const [],
    transport: transport,
    pair: pair,
    localCandidate: local,
    remoteCandidate: remote,
    notes: remote == null
        ? [
            'remote candidate not resolvable (recorded; remote never substitutes local)',
          ]
        : const [],
  );
}

// ──────────────────────────────────────────────
// 判定（纯函数）
// ──────────────────────────────────────────────

/// 单项判定结果。
class StatsVerdict {
  const StatsVerdict({
    required this.kind,
    required this.verdict,
    required this.reasons,
    this.evidence = const {},
  });

  /// 'relay_only' | 'tls443'。
  final String kind;
  final String verdict; // kVerdictPass / kVerdictFail / kVerdictBlocked
  final List<String> reasons;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'verdict': verdict,
    'reasons': reasons,
    'evidence': evidence,
  };
}

/// relay-only 判定：所选 **local** candidate 的 candidateType == relay。
/// 只排除 host/srflx（及 prflx）；TURN/UDP（candidateType=relay,
/// url=turn:..., relayProtocol=udp）在此判定为 PASS。
StatsVerdict judgeRelayOnly(PcStatsSample sample) {
  final binding = bindSelectedPair(sample);
  if (binding.status == _bindBlocked) {
    return StatsVerdict(
      kind: 'relay_only',
      verdict: kVerdictBlocked,
      reasons: List.of(binding.problems),
      evidence: _bindingEvidence(binding),
    );
  }
  if (binding.status == _bindFail) {
    return StatsVerdict(
      kind: 'relay_only',
      verdict: kVerdictFail,
      reasons: List.of(binding.problems),
      evidence: _bindingEvidence(binding),
    );
  }
  final local = binding.localCandidate!;
  final type = local.candidateType?.toLowerCase();
  if (type == null) {
    return StatsVerdict(
      kind: 'relay_only',
      verdict: kVerdictBlocked,
      reasons: ['selected local candidate candidateType absent (cannot judge)'],
      evidence: _bindingEvidence(binding),
    );
  }
  if (type == kCandidateTypeRelay) {
    return StatsVerdict(
      kind: 'relay_only',
      verdict: kVerdictPass,
      reasons: [
        'selected local candidate is relay (url=${local.url ?? "<absent>"}, '
            'relayProtocol=${local.relayProtocol ?? "<absent>"})',
      ],
      evidence: _bindingEvidence(binding),
    );
  }
  return StatsVerdict(
    kind: 'relay_only',
    verdict: kVerdictFail,
    reasons: [
      'selected local candidateType="$type" is not relay '
          '(host/srflx/prflx are excluded by relay-only policy)',
    ],
    evidence: _bindingEvidence(binding),
  );
}

/// TLS443 判定：所选 local relay candidate 的 url scheme（turns）+
/// url 端口（默认 443，可按现场接入端口参数化）+ relayProtocol（tcp/tls）
/// 的实际值组合。字段不支持时 BLOCKED_EVIDENCE + 缺失清单。
StatsVerdict judgeTls443(PcStatsSample sample, {int expectPort = 443}) {
  final binding = bindSelectedPair(sample);
  if (binding.status != _bindOk) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: binding.status == _bindFail ? kVerdictFail : kVerdictBlocked,
      reasons: List.of(binding.problems),
      evidence: _bindingEvidence(binding),
    );
  }
  final local = binding.localCandidate!;
  final type = local.candidateType?.toLowerCase();
  if (type != kCandidateTypeRelay) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: kVerdictFail,
      reasons: [
        'selected local candidateType="${type ?? "<absent>"}" is not relay; '
            'TLS443 relay path not in use',
      ],
      evidence: _bindingEvidence(binding),
    );
  }
  return _judgeTlsUrlAndProtocol(local, expectPort, _bindingEvidence(binding));
}

StatsVerdict _judgeTlsUrlAndProtocol(
  CandidateInfo local,
  int expectPort,
  Map<String, Object?> evidence,
) {
  final url = local.url;
  if (url == null) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: kVerdictBlocked,
      reasons: [
        'local relay candidate url absent (url is local-side only; '
            'cannot verify turns:$expectPort without it)',
      ],
      evidence: evidence,
    );
  }
  final parts = parseTurnUrl(url);
  if (parts == null) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: kVerdictBlocked,
      reasons: ['unparseable TURN url: "$url"'],
      evidence: evidence,
    );
  }
  final rp = local.relayProtocol?.toLowerCase();
  if (rp == null) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: kVerdictBlocked,
      reasons: [
        'local relay candidate relayProtocol absent (needed to prove TLS '
            'over TCP; url alone is insufficient)',
      ],
      evidence: evidence,
    );
  }
  return _judgeTlsCombination(parts, url, rp, expectPort, evidence);
}

StatsVerdict _judgeTlsCombination(
  TurnUrlParts parts,
  String url,
  String relayProtocol,
  int expectPort,
  Map<String, Object?> evidence,
) {
  final reasons = <String>[];
  if (parts.scheme != 'turns') {
    reasons.add('TURN url scheme="${parts.scheme}" (expected turns)');
  }
  if (parts.port == null) {
    reasons.add('TURN url has no port: "$url"');
  } else if (parts.port != expectPort) {
    reasons.add('TURN url port=${parts.port} (expected $expectPort)');
  }
  if (!kTlsRelayProtocols.contains(relayProtocol)) {
    reasons.add(
      'relayProtocol="$relayProtocol" cannot prove TLS '
      '(expected tcp/tls${relayProtocol == 'udp' ? '; udp over turns url is contradictory' : ''})',
    );
  }
  if (reasons.isNotEmpty) {
    return StatsVerdict(
      kind: 'tls443',
      verdict: kVerdictFail,
      reasons: reasons,
      evidence: {
        ...evidence,
        'url': url,
        'url_scheme': parts.scheme,
        'url_port': parts.port,
        'relayProtocol': relayProtocol,
      },
    );
  }
  return StatsVerdict(
    kind: 'tls443',
    verdict: kVerdictPass,
    reasons: [
      'selected local relay via $url (scheme=turns, port=$expectPort, '
          'relayProtocol=$relayProtocol)',
    ],
    evidence: {
      ...evidence,
      'url': url,
      'url_scheme': parts.scheme,
      'url_port': parts.port,
      'relayProtocol': relayProtocol,
    },
  );
}

Map<String, Object?> _bindingEvidence(SelectedPairBinding binding) {
  return <String, Object?>{
    'transport_id': binding.transport?.id,
    'selected_candidate_pair_id': binding.transport?.selectedCandidatePairId,
    'pair_state': binding.pair?.state,
    'pair_nominated': binding.pair?.nominated,
    'local_candidate_type': binding.localCandidate?.candidateType,
    // candidate 地址端口只记录实际值（事实边界：禁止 port=443 断言）。
    'local_candidate_address': binding.localCandidate?.address,
    'local_candidate_port': binding.localCandidate?.port,
    'local_candidate_url': binding.localCandidate?.url,
    'local_candidate_relay_protocol': binding.localCandidate?.relayProtocol,
    'remote_candidate_type': binding.remoteCandidate?.candidateType,
    if (binding.notes.isNotEmpty) 'notes': binding.notes,
  };
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

// ──────────────────────────────────────────────
// 帧判定与轮询聚合
// ──────────────────────────────────────────────

/// 一轮采样（可含 publisher/subscriber 多 pc）的判定结果。
class FrameVerdict {
  const FrameVerdict({
    required this.relayByPc,
    required this.tlsByPc,
    required this.aggregateRelay,
    required this.aggregateTls,
    required this.requireTls,
    required this.reasons,
  });

  final Map<String, StatsVerdict> relayByPc;
  final Map<String, StatsVerdict> tlsByPc;
  final String aggregateRelay;
  final String aggregateTls;
  final bool requireTls;
  final List<String> reasons;

  /// 连接级 PASS 门：所有采样 pc 的 relay 判定全 PASS，且（要求 TLS 时）
  /// TLS443 判定全 PASS。任一路命中不能宣称整体成功。
  bool get isPass =>
      aggregateRelay == kVerdictPass &&
      (!requireTls || aggregateTls == kVerdictPass);

  Map<String, Object?> toJson() => <String, Object?>{
    'relay_by_pc': {for (final e in relayByPc.entries) e.key: e.value.toJson()},
    'tls443_by_pc': {for (final e in tlsByPc.entries) e.key: e.value.toJson()},
    'aggregate_relay': aggregateRelay,
    'aggregate_tls443': aggregateTls,
    'require_tls': requireTls,
    'reasons': reasons,
  };
}

/// 判定一帧：逐 pc 判定 relay-only 与 TLS443，再聚合。
/// 聚合语义：任一 pc FAIL -> FAIL；否则任一 pc BLOCKED -> BLOCKED；
/// 全 PASS -> PASS；无 pc 证据 -> BLOCKED。
FrameVerdict evaluateFrame(
  StatsPollFrame frame, {
  int expectTlsPort = 443,
  bool requireTls = true,
}) {
  final relay = <String, StatsVerdict>{};
  final tls = <String, StatsVerdict>{};
  for (final sample in frame.pcSamples) {
    relay[sample.pcRole] = judgeRelayOnly(sample);
    tls[sample.pcRole] = judgeTls443(sample, expectPort: expectTlsPort);
  }
  final aggRelay = aggregateVerdict(relay.values.map((v) => v.verdict));
  final aggTls = aggregateVerdict(tls.values.map((v) => v.verdict));
  return FrameVerdict(
    relayByPc: relay,
    tlsByPc: tls,
    aggregateRelay: aggRelay,
    aggregateTls: aggTls,
    requireTls: requireTls,
    reasons: [
      for (final e in relay.entries)
        if (e.value.verdict != kVerdictPass)
          '[relay_only/${e.key}] ${e.value.verdict}: ${e.value.reasons.join('; ')}',
      for (final e in tls.entries)
        if (e.value.verdict != kVerdictPass)
          '[tls443/${e.key}] ${e.value.verdict}: ${e.value.reasons.join('; ')}',
    ],
  );
}

/// 多值聚合：FAIL 优先（有否定证据），其次 BLOCKED（证据不足），
/// 全 PASS 才 PASS，空集 BLOCKED。
String aggregateVerdict(Iterable<String> verdicts) {
  final list = verdicts.toList();
  if (list.isEmpty) return kVerdictBlocked;
  if (list.contains(kVerdictFail)) return kVerdictFail;
  if (list.contains(kVerdictBlocked)) return kVerdictBlocked;
  return kVerdictPass;
}

/// 整个轮询序列的最终结论。
class PollOutcome {
  const PollOutcome({
    required this.verdict,
    required this.rounds,
    required this.readyWait,
    required this.reasons,
  });

  final String verdict;
  final int rounds;

  /// 首帧到首个 PASS 帧的等待时长（延迟出现场景的就绪等待记录）。
  final Duration readyWait;
  final List<String> reasons;

  Map<String, Object?> toJson() => <String, Object?>{
    'verdict': verdict,
    'rounds': rounds,
    'ready_wait_ms': readyWait.inMilliseconds,
    'reasons': reasons,
  };
}

/// 对完整轮询历史做最终判定：
/// 任一帧达标即 PASS（记录就绪等待时长）；否则取最后一帧聚合状态并
/// 附「超时未就绪」语义（BLOCKED_EVIDENCE/FAIL 不崩、不编造）。
PollOutcome evaluatePollSequence(
  List<StatsPollFrame> frames, {
  int expectTlsPort = 443,
  bool requireTls = true,
  Duration timeout = const Duration(seconds: 30),
}) {
  if (frames.isEmpty) {
    return const PollOutcome(
      verdict: kVerdictBlocked,
      rounds: 0,
      readyWait: Duration.zero,
      reasons: ['no poll frames collected (stats sampling never ran)'],
    );
  }
  for (var i = 0; i < frames.length; i++) {
    final fv = evaluateFrame(
      frames[i],
      expectTlsPort: expectTlsPort,
      requireTls: requireTls,
    );
    if (fv.isPass) {
      return PollOutcome(
        verdict: kVerdictPass,
        rounds: i + 1,
        readyWait: frames[i].collectedAt.difference(frames.first.collectedAt),
        reasons: ['pass at frame ${i + 1}/${frames.length}'],
      );
    }
  }
  final last = evaluateFrame(
    frames.last,
    expectTlsPort: expectTlsPort,
    requireTls: requireTls,
  );
  final lastVerdict = aggregateVerdict([
    last.aggregateRelay,
    if (requireTls) last.aggregateTls,
  ]);
  return PollOutcome(
    verdict: lastVerdict,
    rounds: frames.length,
    readyWait: Duration.zero,
    reasons: [
      'stats not ready within ${timeout.inSeconds}s '
          '(${frames.length} frames polled)',
      ...last.reasons,
    ],
  );
}
