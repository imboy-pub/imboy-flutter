/// L4 SNI Task 4：TLS443 relay 证据判定逻辑最小检查集（纯函数单测）。
///
/// 覆盖六类判定用例（计划 Task 4 验收要求）：
///   1. 健康 relay（local relay + turns:443 + tcp）→ PASS
///   2. remote-only relay（仅 remote 侧 relay）→ 不 PASS
///   3. 未成功 / nominated-only → 不 PASS
///   4. 错误 URL/协议（turn:3478/udp、turns:443+udp）→ 不 PASS 且给出原因
///   5. 缺字段（无 selectedCandidatePairId / url / relayProtocol）→
///      BLOCKED_EVIDENCE 而非异常
///   6. 延迟出现（首轮无、后续出现）→ 最终 PASS 并记录就绪等待时长
///
/// 事实边界回归：禁止 candidate.port=443 断言（candidate 端口只记录）、
/// remote relay 不能替代 local relay、nominated 单独不算 selected。
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/rtc/rtc_relay_stats_judge.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 2, 12, 0, 0);

PcStatsSample _sample({
  String pcRole = 'subscriber',
  DateTime? sampledAt,
  List<TransportInfo> transports = const [],
  List<CandidatePairInfo> pairs = const [],
  List<CandidateInfo> candidates = const [],
}) {
  return PcStatsSample(
    pcRole: pcRole,
    sampledAt: sampledAt ?? _t0,
    transports: transports,
    candidatePairs: pairs,
    candidates: candidates,
  );
}

/// 健康 TLS443 relay 样本：selected pair（transport 绑定 + succeeded）+
/// local relay candidate（turns:443?transport=tcp + relayProtocol=tcp）。
PcStatsSample _healthyTlsRelaySample({
  String pcRole = 'subscriber',
  DateTime? sampledAt,
}) {
  return _sample(
    pcRole: pcRole,
    sampledAt: sampledAt,
    transports: [
      TransportInfo(
        id: 'T1',
        selectedCandidatePairId: 'CP1',
        dtlsState: 'connected',
      ),
    ],
    pairs: [
      CandidatePairInfo(
        id: 'CP1',
        localCandidateId: 'L1',
        remoteCandidateId: 'R1',
        state: 'succeeded',
        nominated: true,
        selected: true,
      ),
    ],
    candidates: [
      CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        // candidate 地址端口是 relay 分配的实际值（非 443）——判定只记录，
        // 绝不据此断言。
        address: '203.0.113.7',
        port: 61000,
        url: 'turns:turn.example.com:443?transport=tcp',
        relayProtocol: 'tcp',
      ),
      const CandidateInfo(
        id: 'R1',
        isLocal: false,
        candidateType: 'relay',
        address: '198.51.100.9',
        port: 40000,
      ),
    ],
  );
}

/// remote-only relay 样本：local 是 host，remote 才是 relay。
PcStatsSample _remoteOnlyRelaySample() {
  return _sample(
    transports: const [TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1')],
    pairs: const [
      CandidatePairInfo(
        id: 'CP1',
        localCandidateId: 'L1',
        remoteCandidateId: 'R1',
        state: 'succeeded',
        nominated: true,
      ),
    ],
    candidates: const [
      CandidateInfo(id: 'L1', isLocal: true, candidateType: 'host'),
      CandidateInfo(
        id: 'R1',
        isLocal: false,
        candidateType: 'relay',
        address: '198.51.100.9',
        port: 40000,
      ),
    ],
  );
}

void main() {
  group('用例1：健康 relay（local relay + turns:443 + tcp）→ PASS', () {
    test('relay-only 与 TLS443 双判定 PASS', () {
      final sample = _healthyTlsRelaySample();
      final relay = judgeRelayOnly(sample);
      expect(relay.verdict, kVerdictPass, reason: relay.reasons.join('; '));

      final tls = judgeTls443(sample);
      expect(tls.verdict, kVerdictPass, reason: tls.reasons.join('; '));
      expect(tls.evidence['url'], 'turns:turn.example.com:443?transport=tcp');
      expect(tls.evidence['url_scheme'], 'turns');
      expect(tls.evidence['url_port'], 443);
      expect(tls.evidence['relayProtocol'], 'tcp');
    });

    test('candidate 实际端口非 443 不影响判定（禁止 port=443 断言）', () {
      // local relay candidate 分配端口 61000（非 443）；TLS443 由 url/协议证明。
      final tls = judgeTls443(_healthyTlsRelaySample());
      expect(tls.verdict, kVerdictPass);
      expect(tls.evidence['local_candidate_port'], 61000); // 仅记录实际值
    });

    test('relayProtocol=tls 亦可证明 TLS（按实际值）', () {
      final sample = _healthyTlsRelaySample();
      const tlsCandidate = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turns:turn.example.com:443?transport=tcp',
        relayProtocol: 'tls',
      );
      final patched = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'succeeded',
          ),
        ],
        candidates: [tlsCandidate, ...sample.candidates.skip(1)],
      );
      expect(judgeTls443(patched).verdict, kVerdictPass);
    });

    test('pair state=connected（部分平台语义）同样算成功', () {
      final sample = _healthyTlsRelaySample();
      final patched = _sample(
        transports: sample.transports,
        pairs: [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'connected',
            nominated: true,
          ),
        ],
        candidates: sample.candidates,
      );
      expect(judgeRelayOnly(patched).verdict, kVerdictPass);
    });
  });

  group('用例2：remote-only relay（仅 remote 侧 relay）→ 不 PASS', () {
    test('relay-only FAIL：所选 local 是 host', () {
      final verdict = judgeRelayOnly(_remoteOnlyRelaySample());
      expect(verdict.verdict, kVerdictFail);
      expect(verdict.reasons.join(' '), contains('is not relay'));
      // remote relay 不能替代 local relay。
      expect(verdict.evidence['remote_candidate_type'], 'relay');
      expect(verdict.evidence['local_candidate_type'], 'host');
    });

    test('TLS443 也 FAIL：local 未走 relay 路径', () {
      final verdict = judgeTls443(_remoteOnlyRelaySample());
      expect(verdict.verdict, kVerdictFail);
      expect(verdict.reasons.join(' '), contains('not relay'));
    });
  });

  group('用例3：未成功 / nominated-only → 不 PASS', () {
    test('pair state=in-progress（transport 已绑定）→ FAIL', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'in-progress',
            nominated: true,
          ),
        ],
        candidates: const [
          CandidateInfo(
            id: 'L1',
            isLocal: true,
            candidateType: 'relay',
            url: 'turns:turn.example.com:443?transport=tcp',
            relayProtocol: 'tcp',
          ),
        ],
      );
      final verdict = judgeRelayOnly(sample);
      expect(verdict.verdict, kVerdictFail);
      expect(verdict.reasons.join(' '), contains('in-progress'));
    });

    test('nominated-only（无 transport.selectedCandidatePairId）→ FAIL', () {
      final sample = _sample(
        transports: const [TransportInfo(id: 'T1')],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'succeeded',
            nominated: true, // 仅 nominated 标记
          ),
        ],
        candidates: _healthyTlsRelaySample().candidates,
      );
      final verdict = judgeRelayOnly(sample);
      expect(verdict.verdict, kVerdictFail);
      expect(
        verdict.reasons.join(' '),
        contains('nominated alone is not selection proof'),
      );
    });

    test('pair state=failed → FAIL', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(id: 'CP1', localCandidateId: 'L1', state: 'failed'),
        ],
        candidates: const [
          CandidateInfo(id: 'L1', isLocal: true, candidateType: 'relay'),
        ],
      );
      expect(judgeRelayOnly(sample).verdict, kVerdictFail);
    });
  });

  group('用例4：错误 URL/协议 → 不 PASS 且给出具体原因', () {
    PcStatsSample withLocalCandidate(CandidateInfo local) => _sample(
      transports: const [
        TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
      ],
      pairs: const [
        CandidatePairInfo(
          id: 'CP1',
          localCandidateId: 'L1',
          remoteCandidateId: 'R1',
          state: 'succeeded',
        ),
      ],
      candidates: [
        local,
        const CandidateInfo(id: 'R1', isLocal: false),
      ],
    );

    test('turn:3478/udp：relay-only PASS（不排除 TURN/UDP），TLS443 FAIL', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turn:turn.example.com:3478?transport=udp',
        relayProtocol: 'udp',
      );
      final sample = withLocalCandidate(local);
      final relay = judgeRelayOnly(sample);
      expect(relay.verdict, kVerdictPass, reason: 'relay-only 不排除 TURN/UDP');

      final tls = judgeTls443(sample);
      expect(tls.verdict, kVerdictFail);
      final reasons = tls.reasons.join(' ');
      expect(reasons, contains('scheme="turn"'));
      expect(reasons, contains('port=3478'));
      expect(reasons, contains('relayProtocol="udp"'));
    });

    test('turns:443 但 relayProtocol=udp → FAIL 且点明 udp 矛盾', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turns:turn.example.com:443?transport=tcp',
        relayProtocol: 'udp',
      );
      final tls = judgeTls443(withLocalCandidate(local));
      expect(tls.verdict, kVerdictFail);
      expect(
        tls.reasons.join(' '),
        contains('udp over turns url is contradictory'),
      );
    });

    test('turns:443 但端口非 443 → FAIL（url 端口与接入端口不符）', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turns:turn.example.com:8443?transport=tcp',
        relayProtocol: 'tcp',
      );
      final tls = judgeTls443(withLocalCandidate(local));
      expect(tls.verdict, kVerdictFail);
      expect(tls.reasons.join(' '), contains('port=8443'));
    });

    test('url 端口可按现场接入端口参数化', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turns:turn.example.com:8443?transport=tcp',
        relayProtocol: 'tcp',
      );
      final tls = judgeTls443(withLocalCandidate(local), expectPort: 8443);
      expect(tls.verdict, kVerdictPass);
    });
  });

  group('用例5：缺字段 → BLOCKED_EVIDENCE 而非异常', () {
    test('无 transport 报告 → BLOCKED（带缺失原因）', () {
      final verdict = judgeRelayOnly(_sample());
      expect(verdict.verdict, kVerdictBlocked);
      expect(
        verdict.reasons.join(' '),
        contains('no transport stats report sampled'),
      );
    });

    test('无 selectedCandidatePairId 且无 nominated pair → BLOCKED', () {
      final sample = _sample(
        transports: const [TransportInfo(id: 'T1')],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            state: 'succeeded',
          ),
        ],
        candidates: const [CandidateInfo(id: 'L1', isLocal: true)],
      );
      final verdict = judgeRelayOnly(sample);
      expect(verdict.verdict, kVerdictBlocked);
      expect(
        verdict.reasons.join(' '),
        contains('transport.selectedCandidatePairId absent'),
      );
    });

    test('selectedCandidatePairId 指向不存在的 pair → BLOCKED', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP-missing'),
        ],
        pairs: const [],
      );
      final verdict = judgeTls443(sample);
      expect(verdict.verdict, kVerdictBlocked);
      expect(verdict.reasons.join(' '), contains('not found in stats reports'));
    });

    test('pair 无 state 字段 → BLOCKED', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [CandidatePairInfo(id: 'CP1', localCandidateId: 'L1')],
        candidates: const [CandidateInfo(id: 'L1', isLocal: true)],
      );
      expect(judgeRelayOnly(sample).verdict, kVerdictBlocked);
    });

    test('local relay 无 url → TLS443 BLOCKED（url 仅 local 侧有语义）', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        relayProtocol: 'tcp',
      );
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'succeeded',
          ),
        ],
        candidates: [
          local,
          const CandidateInfo(id: 'R1', isLocal: false),
        ],
      );
      final relay = judgeRelayOnly(sample);
      expect(relay.verdict, kVerdictPass, reason: 'relay-only 不依赖 url');

      final tls = judgeTls443(sample);
      expect(tls.verdict, kVerdictBlocked);
      expect(tls.reasons.join(' '), contains('url absent'));
    });

    test('local relay 无 relayProtocol → TLS443 BLOCKED', () {
      const local = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turns:turn.example.com:443?transport=tcp',
      );
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            state: 'succeeded',
          ),
        ],
        candidates: const [local],
      );
      final tls = judgeTls443(sample);
      expect(tls.verdict, kVerdictBlocked);
      expect(tls.reasons.join(' '), contains('relayProtocol absent'));
    });

    test('local candidateType 缺失 → relay-only BLOCKED', () {
      const local = CandidateInfo(id: 'L1', isLocal: true);
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            state: 'succeeded',
          ),
        ],
        candidates: const [local],
      );
      final verdict = judgeRelayOnly(sample);
      expect(verdict.verdict, kVerdictBlocked);
      expect(verdict.reasons.join(' '), contains('candidateType absent'));
    });
  });

  group('用例6：延迟出现 → 最终 PASS 并记录就绪等待时长', () {
    test('首轮缺 selected pair，次轮健康 → PASS + readyWait', () {
      final f1 = StatsPollFrame(
        collectedAt: _t0,
        pcSamples: [
          PcStatsSample.unavailable(
            pcRole: 'subscriber',
            sampledAt: _t0,
            reason: 'transport not established yet',
          ),
        ],
      );
      final f2At = _t0.add(const Duration(milliseconds: 1500));
      final f2 = StatsPollFrame(
        collectedAt: f2At,
        pcSamples: [_healthyTlsRelaySample(sampledAt: f2At)],
      );
      final outcome = evaluatePollSequence([f1, f2]);
      expect(outcome.verdict, kVerdictPass, reason: outcome.reasons.join('; '));
      expect(outcome.rounds, 2);
      expect(outcome.readyWait.inMilliseconds, 1500);
    });

    test('全轮 BLOCKED → 超时语义 BLOCKED_EVIDENCE（不崩、不编造）', () {
      final frames = [
        for (var i = 0; i < 3; i++)
          StatsPollFrame(
            collectedAt: _t0.add(Duration(milliseconds: 500 * i)),
            pcSamples: [
              PcStatsSample.unavailable(
                pcRole: 'subscriber',
                sampledAt: _t0,
                reason: 'transport not established yet',
              ),
            ],
          ),
      ];
      final outcome = evaluatePollSequence(
        frames,
        timeout: const Duration(seconds: 2),
      );
      expect(outcome.verdict, kVerdictBlocked);
      expect(outcome.reasons.join(' '), contains('stats not ready within 2s'));
      expect(outcome.reasons.join(' '), contains('no transport stats report'));
    });

    test('末轮 FAIL → 超时语义 FAIL（有否定证据优先于 BLOCKED）', () {
      final bad = _remoteOnlyRelaySample();
      final frames = [
        StatsPollFrame(collectedAt: _t0, pcSamples: [bad]),
      ];
      final outcome = evaluatePollSequence(
        frames,
        timeout: const Duration(seconds: 1),
      );
      expect(outcome.verdict, kVerdictFail);
    });

    test('空帧序列 → BLOCKED', () {
      final outcome = evaluatePollSequence(const []);
      expect(outcome.verdict, kVerdictBlocked);
      expect(outcome.reasons.join(' '), contains('no poll frames'));
    });
  });

  group('帧聚合：任一路 pc 不完整不得宣称整体 PASS', () {
    test('subscriber PASS + publisher BLOCKED → aggregate BLOCKED', () {
      final frame = StatsPollFrame(
        collectedAt: _t0,
        pcSamples: [
          _healthyTlsRelaySample(pcRole: 'subscriber'),
          PcStatsSample.unavailable(
            pcRole: 'publisher',
            sampledAt: _t0,
            reason: 'transport not established yet',
          ),
        ],
      );
      final fv = evaluateFrame(frame);
      expect(fv.aggregateRelay, kVerdictBlocked);
      expect(fv.aggregateTls, kVerdictBlocked);
      expect(fv.isPass, isFalse, reason: '任一路命中不能替代另一路');
    });

    test('两路全 PASS → 帧判定 PASS', () {
      final frame = StatsPollFrame(
        collectedAt: _t0,
        pcSamples: [
          _healthyTlsRelaySample(pcRole: 'subscriber'),
          _healthyTlsRelaySample(pcRole: 'publisher'),
        ],
      );
      final fv = evaluateFrame(frame);
      expect(fv.isPass, isTrue, reason: fv.reasons.join('; '));
    });

    test('requireTls=false 时 relay-only 全 PASS 即帧 PASS', () {
      const turnUdp = CandidateInfo(
        id: 'L1',
        isLocal: true,
        candidateType: 'relay',
        url: 'turn:turn.example.com:3478?transport=udp',
        relayProtocol: 'udp',
      );
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            state: 'succeeded',
          ),
        ],
        candidates: const [turnUdp],
      );
      final fv = evaluateFrame(
        StatsPollFrame(collectedAt: _t0, pcSamples: [sample]),
        requireTls: false,
      );
      expect(fv.isPass, isTrue, reason: 'relay-only 场景不排除 TURN/UDP');
      expect(fv.aggregateTls, kVerdictFail, reason: 'TLS443 判定仍如实记录');
    });
  });

  group('parseStatsReports：原始报告适配（驼峰与 snake_case 兼容）', () {
    test('驼峰风格报告完整解析', () {
      final sample = parseStatsReports(
        pcRole: 'subscriber',
        sampledAt: _t0,
        reports: [
          _FakeReport('T1', 'transport', {
            'selectedCandidatePairId': 'CP1',
            'dtlsState': 'connected',
          }),
          _FakeReport('CP1', 'candidate-pair', {
            'localCandidateId': 'L1',
            'remoteCandidateId': 'R1',
            'state': 'succeeded',
            'nominated': true,
          }),
          _FakeReport('L1', 'local-candidate', {
            'candidateType': 'relay',
            'address': '203.0.113.7',
            'port': 61000,
            'url': 'turns:turn.example.com:443?transport=tcp',
            'relayProtocol': 'tcp',
          }),
          _FakeReport('R1', 'remote-candidate', {
            'candidateType': 'relay',
            'ip': '198.51.100.9',
            'port': 40000,
          }),
          _FakeReport('O1', 'outbound-rtp', {'bytesSent': 1}),
        ],
      );
      expect(sample.transports.single.selectedCandidatePairId, 'CP1');
      expect(sample.candidatePairs.single.state, 'succeeded');
      final local = sample.candidates.firstWhere((c) => c.isLocal);
      expect(local.candidateType, 'relay');
      expect(local.url, 'turns:turn.example.com:443?transport=tcp');
      expect(local.relayProtocol, 'tcp');
      expect(judgeTls443(sample).verdict, kVerdictPass);

      final remote = sample.candidates.firstWhere((c) => !c.isLocal);
      expect(remote.address, '198.51.100.9', reason: '旧键 ip 也应取到');
      expect(remote.url, isNull, reason: 'url 仅 local 侧有语义');
    });

    test('snake_case 风格报告兼容解析', () {
      final sample = parseStatsReports(
        pcRole: 'publisher',
        sampledAt: _t0,
        reports: [
          _FakeReport('T1', 'transport', {'selected_candidate_pair_id': 'CP1'}),
          _FakeReport('CP1', 'candidate-pair', {
            'local_candidate_id': 'L1',
            'state': 'succeeded',
          }),
          _FakeReport('L1', 'local-candidate', {
            'candidate_type': 'relay',
            'relay_protocol': 'tcp',
            'url': 'turns:turn.example.com:443?transport=tcp',
          }),
        ],
      );
      expect(sample.transports.single.selectedCandidatePairId, 'CP1');
      final verdict = judgeTls443(sample);
      expect(verdict.verdict, kVerdictPass, reason: verdict.reasons.join('; '));
    });

    test('local candidate 缺 url/relayProtocol 记入缺失清单', () {
      final sample = parseStatsReports(
        pcRole: 'subscriber',
        sampledAt: _t0,
        reports: [
          _FakeReport('T1', 'transport', {'selectedCandidatePairId': 'CP1'}),
          _FakeReport('CP1', 'candidate-pair', {
            'localCandidateId': 'L1',
            'state': 'succeeded',
          }),
          _FakeReport('L1', 'local-candidate', {'candidateType': 'relay'}),
        ],
      );
      final local = sample.candidates.single;
      expect(local.missing.containsKey('url'), isTrue);
      expect(local.missing.containsKey('relayProtocol'), isTrue);
      final json = local.toJson();
      expect(json['missing'], isNotNull, reason: '缺失原因必须随 JSON 输出');
    });

    test('无 transport 报告 → 采样级 missing 记录', () {
      final sample = parseStatsReports(
        pcRole: 'subscriber',
        sampledAt: _t0,
        reports: [
          _FakeReport('L1', 'local-candidate', {'candidateType': 'relay'}),
        ],
      );
      expect(sample.missing.containsKey('transport'), isTrue);
      expect(judgeRelayOnly(sample).verdict, kVerdictBlocked);
    });
  });

  group('parseTurnUrl', () {
    test('turns host:443?transport=tcp', () {
      final parts = parseTurnUrl('turns:turn.example.com:443?transport=tcp')!;
      expect(parts.scheme, 'turns');
      expect(parts.host, 'turn.example.com');
      expect(parts.port, 443);
      expect(parts.transport, 'tcp');
    });

    test('turn host:3478?transport=udp', () {
      final parts = parseTurnUrl('turn:turn.example.com:3478?transport=udp')!;
      expect(parts.scheme, 'turn');
      expect(parts.port, 3478);
      expect(parts.transport, 'udp');
    });

    test('IPv6 literal [2001:db8::1]:443', () {
      final parts = parseTurnUrl('turns:[2001:db8::1]:443?transport=tcp')!;
      expect(parts.host, '2001:db8::1');
      expect(parts.port, 443);
    });

    test('无端口 → port=null（判定记 BLOCKED 而非猜测）', () {
      final parts = parseTurnUrl('turns:turn.example.com')!;
      expect(parts.port, isNull);
    });

    test('坏 url → null', () {
      expect(parseTurnUrl('not-a-url'), isNull);
      expect(parseTurnUrl('turns:'), isNull);
    });
  });

  group('aggregateVerdict 优先级', () {
    test('FAIL > BLOCKED > PASS；空集 BLOCKED', () {
      expect(aggregateVerdict([kVerdictPass]), kVerdictPass);
      expect(
        aggregateVerdict([kVerdictPass, kVerdictBlocked]),
        kVerdictBlocked,
      );
      expect(
        aggregateVerdict([kVerdictPass, kVerdictBlocked, kVerdictFail]),
        kVerdictFail,
      );
      expect(aggregateVerdict([]), kVerdictBlocked);
    });
  });
  group('多 transport selectedCandidatePairId 消歧（NOTE-A0-2，拒绝首个命中猜测）', () {
    final relayLocal = CandidateInfo(
      id: 'L1',
      isLocal: true,
      candidateType: 'relay',
      address: '203.0.113.7',
      port: 61000,
      url: 'turns:turn.example.com:443?transport=tcp',
      relayProtocol: 'tcp',
    );
    final healthyPair = CandidatePairInfo(
      id: 'CP1',
      localCandidateId: 'L1',
      remoteCandidateId: 'R1',
      state: 'succeeded',
      nominated: true,
      selected: true,
    );

    test('双 transport 仅一个报 selected → 绑定它，正常判定', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
          TransportInfo(id: 'T2'),
        ],
        pairs: [healthyPair],
        candidates: [relayLocal],
      );
      expect(judgeTls443(sample).verdict, kVerdictPass);
    });

    test('双 transport 均报 succeeded 选择 → BLOCKED（ambiguous，拒绝猜测）', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
          TransportInfo(id: 'T2', selectedCandidatePairId: 'CP2'),
        ],
        pairs: [
          healthyPair,
          CandidatePairInfo(
            id: 'CP2',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'succeeded',
            nominated: true,
            selected: true,
          ),
        ],
        candidates: [relayLocal],
      );
      final verdict = judgeTls443(sample);
      expect(verdict.verdict, kVerdictBlocked);
      expect(verdict.reasons.single, contains('ambiguous'));
      expect(verdict.reasons.single, contains('T1=CP1'));
      expect(verdict.reasons.single, contains('T2=CP2'));
    });

    test('双 transport 报选择但仅一个 pair 成功 → 绑定成功侧，正常判定', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
          TransportInfo(id: 'T2', selectedCandidatePairId: 'CP2'),
        ],
        pairs: [
          healthyPair,
          const CandidatePairInfo(
            id: 'CP2',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'failed',
          ),
        ],
        candidates: [relayLocal],
      );
      expect(judgeTls443(sample).verdict, kVerdictPass);
    });

    test('双 transport 报选择但全部 pair 非成功 → BLOCKED（none resolves）', () {
      final sample = _sample(
        transports: const [
          TransportInfo(id: 'T1', selectedCandidatePairId: 'CP1'),
          TransportInfo(id: 'T2', selectedCandidatePairId: 'CP2'),
        ],
        pairs: const [
          CandidatePairInfo(
            id: 'CP1',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'in-progress',
          ),
          CandidatePairInfo(
            id: 'CP2',
            localCandidateId: 'L1',
            remoteCandidateId: 'R1',
            state: 'failed',
          ),
        ],
        candidates: [relayLocal],
      );
      final verdict = judgeTls443(sample);
      expect(verdict.verdict, kVerdictBlocked);
      expect(verdict.reasons.single, contains('none resolves'));
    });
  });
}

/// StatsReport-like 测试替身（.id / .type / .values）。
class _FakeReport {
  const _FakeReport(this.id, this.type, this.values);

  final String id;
  final String type;
  final Map<String, dynamic> values;
}
