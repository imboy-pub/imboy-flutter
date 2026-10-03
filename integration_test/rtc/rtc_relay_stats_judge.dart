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
// 本文件承载判定逻辑（selected pair 绑定 / relay-only / TLS443 / 帧判定
// 与轮询聚合）；数据模型与解析层（数据类、parseStatsReports、parseTurnUrl
// 及 kVerdict* 常量）拆至 rtc_relay_stats_models.dart。本文件 import 并
// re-export 该文件，既有引用方（realdevice 测试与单测）无需改 import。
//
// 依据：https://www.w3.org/TR/webrtc-stats/#dom-rtcicecandidatestats
// candidateType 标准值：host / prflx / srflx / relay。

library;

import 'rtc_relay_stats_models.dart';

export 'rtc_relay_stats_models.dart';

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
/// 2. 多个 transport 同时报 selectedCandidatePairId 时不取"首个"：恰好一个
///    能解析到 succeeded/connected pair 时绑定它，否则 BLOCKED（拒绝猜测哪条
///    pc 路径承载当前选择——选错会把 TLS443 证据记到未承载媒体的路径上）；
/// 3. pair 必须存在于 candidate-pair 报告；
/// 4. pair.state 必须是 succeeded/connected；
/// 5. local candidate 必须可解析（remote 缺失只记 note，不阻断——
///    remote relay 不能替代 local relay，判定只看 local 侧）。
SelectedPairBinding bindSelectedPair(PcStatsSample sample) {
  if (sample.transports.isEmpty) {
    return const SelectedPairBinding(
      status: _bindBlocked,
      problems: ['no transport stats report sampled for this pc'],
    );
  }
  final candidates = <TransportInfo>[
    for (final t in sample.transports)
      if (t.selectedCandidatePairId != null &&
          t.selectedCandidatePairId!.isNotEmpty)
        t,
  ];
  if (candidates.isEmpty) {
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
  if (candidates.length == 1) {
    return _bindPairById(sample, candidates.first);
  }
  final valid = <TransportInfo>[];
  for (final t in candidates) {
    final pair = sample.pairById(t.selectedCandidatePairId!);
    final state = pair?.state?.toLowerCase();
    if (pair != null && state != null && kPairSuccessStates.contains(state)) {
      valid.add(t);
    }
  }
  final summary =
      'multiple transports report a selected candidate pair '
      '(${candidates.map((t) => '${t.id}=${t.selectedCandidatePairId}').join(', ')})';
  if (valid.length == 1) {
    return _bindPairById(sample, valid.first);
  }
  return SelectedPairBinding(
    status: _bindBlocked,
    problems: [
      if (valid.isEmpty)
        '$summary but none resolves to a succeeded/connected pair '
            '(ambiguous selection)'
      else
        '$summary with ${valid.length} in succeeded/connected state '
            '(ambiguous selection); refusing to guess which one carries it',
    ],
  );
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
