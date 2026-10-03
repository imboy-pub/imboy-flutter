/// C17b — seeded 随机腐蚀 fuzz harness（AC-35 前置）
///
/// 方案出处：`imboy/docs/design/2026-10-03-e2ee-production-excellence/
/// privacy-profile.md` §4.3。Dart 生态无 AFL/libFuzzer 等价物
/// （进程级 coverage-instrumented entry 不可用），故采用手写 seeded
/// 随机腐蚀 harness：固定 seed 集合保证可重跑（AC-35 要求），CI 内
/// 确定性复现。
///
/// 覆盖四个 parser 域（corpus 均取自**真实构造**的合法字节流，与产线
/// roundtrip 测试同源）：
///
/// | 域 | oracle 入口 | corpus 来源 | 白名单异常 |
/// |---|---|---|---|
/// | PFv3 信封 | `ProtectedFrameV3.verifyOuterEnvelope` + `validateEnvelopeBounds` | `encodeOuterEnvelope`（真实 FrameContext） | `CborParseException` / `FrameBoundsException` / `FormatException` |
/// | attachment descriptor | `AttachmentDescriptor.fromCanonicalBytes` | 合法 descriptor（带 thumb）canonical CBOR | `AttachmentDescriptorException` |
/// | backup 下载体 | `E2EELocalBackupService.unpackBackupBytes` | `packBackupBytes` 真实导出（见下方 KDF 成本闸） | `ArgumentError` / `FormatException` / `StateError` |
/// | handshake/claim 响应 | `OlmApi.parseClaimPayload`（jsonDecode 之后） | 合法 claim 响应 JSON | `FormatException` / `olm claim_key: invalid payload` 前缀 Exception |
/// | get_identity 响应 | `OlmApi.parseIdentityPayload`（jsonDecode 之后；C17b 复审 gap 收口） | 合法 identity 响应 JSON | `FormatException` / `olm get_identity: invalid payload` 前缀 Exception |
///
/// 不变量：**任何输入只能抛域白名单内的异常**（fail-closed 契约）。
/// TypeError / RangeError / StackOverflowError 等非契约异常 = 测试失败
/// = parser 存在崩溃面。正常返回（含"拒收"语义的返回值）同样合法。
///
/// KDF 成本闸（backup 域）：`unpackBackupBytes` 的 PBKDF2 迭代数来自
/// 文件头偏移 12（攻击者可控，合法区间 [1, 1e6]）。随机腐蚀若把该字段
/// 打进 (64, 1e6] 会让单轮 fuzz 跑数十万次 PBKDF2，oracle 预算被 KDF
/// 吞掉。故腐蚀后该字段 **> 64 即钳回 17**——不只 (64, 1e6] 的合法昂贵
/// 区间，**越界值（> 1e6，如 0xFFFFFFFF）同样被钳**，seeded 腐蚀不会
/// 命中「区间校验拒绝」分支（该路径由下方「迭代数越界固定向量」组以
/// 零 KDF 成本覆盖）；<= 64 的值（含越界的 0）原样保留。迭代数越界的
/// 固定向量见 `backup 下载体固定恶意向量` 组（越界值在派生前即被拒，
/// 零 KDF 成本）。
///
/// 迭代规模：每域 5 seeds × 40 rounds = 200 次（AC-35 下限）。
/// 运行：`flutter test test/unit_test/service/e2ee/parser_fuzz_harness_test.dart`
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/store/api/olm_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// harness 基础设施：seed 集合 / 腐蚀算子 / 不变量检查
// ─────────────────────────────────────────────────────────────────────────────

/// 固定 seed 集合（AC-35：可重跑 corpus）。dart:math Random(seed) 在同一
/// Dart SDK 版本内确定性；换 SDK 版本序列可能漂移，但每轮输入由
/// (seed, round, op) 完全决定，失败信息会带出三者以便复现。
const List<int> fuzzSeeds = [20261003, 1017, 4242, 31337, 271828];

/// 每个种子下的腐蚀轮数。5 × 40 = 200 次/域。
const int roundsPerSeed = 40;

Uint8List _bytes(List<int> l) => Uint8List.fromList(l);

/// 单字节翻转（新值保证 ≠ 旧值）。
Uint8List _flipOne(Uint8List src, Random rng) {
  if (src.isEmpty) return Uint8List.fromList(src);
  final out = Uint8List.fromList(src);
  final i = rng.nextInt(src.length);
  var next = rng.nextInt(256);
  if (next == out[i]) next = (next + 1) & 0xFF;
  out[i] = next;
  return out;
}

/// 多字节翻转（1..8 个位置，含连续段——模拟局部突发误码）。
Uint8List _flipMany(Uint8List src, Random rng) {
  if (src.isEmpty) return Uint8List.fromList(src);
  final out = Uint8List.fromList(src);
  final count = 1 + rng.nextInt(8);
  for (var k = 0; k < count; k++) {
    final i = rng.nextInt(src.length);
    out[i] ^= 1 + rng.nextInt(255);
  }
  return out;
}

/// 随机位置插入 1..8 个随机字节（编码错位/注入）。
Uint8List _insert(Uint8List src, Random rng) {
  final out = BytesBuilder();
  final at = src.isEmpty ? 0 : rng.nextInt(src.length + 1);
  out.add(Uint8List.sublistView(src, 0, at));
  final n = 1 + rng.nextInt(8);
  for (var k = 0; k < n; k++) {
    out.addByte(rng.nextInt(256));
  }
  out.add(Uint8List.sublistView(src, at));
  return out.toBytes();
}

/// 边界截断：保留 0..len-1 前缀。
Uint8List _truncate(Uint8List src, Random rng) {
  if (src.isEmpty) return Uint8List.fromList(src);
  final keep = rng.nextInt(src.length);
  return Uint8List.fromList(Uint8List.sublistView(src, 0, keep));
}

/// 尾部扩展 1..64 字节随机数据。
Uint8List _extend(Uint8List src, Random rng) {
  final out = BytesBuilder()..add(src);
  final n = 1 + rng.nextInt(64);
  for (var k = 0; k < n; k++) {
    out.addByte(rng.nextInt(256));
  }
  return out.toBytes();
}

/// CBOR 头探测：把首个字节替换为随机 (majorType, additionalInfo) 组合，
/// 覆盖 indefinite-length / non-shortest / unsupported major type 分支。
Uint8List _cborHead(Uint8List src, Random rng) {
  if (src.isEmpty) return Uint8List.fromList(src);
  final out = Uint8List.fromList(src);
  out[0] = rng.nextInt(256);
  return out;
}

const List<String> opNames = [
  'flipOne',
  'flipMany',
  'insert',
  'truncate',
  'extend',
  'cborHead',
];

typedef MutateOp = Uint8List Function(Uint8List src, Random rng);

final List<MutateOp> _ops = [
  _flipOne,
  _flipMany,
  _insert,
  _truncate,
  _extend,
  _cborHead,
];

/// 执行一轮腐蚀：随机串 1..3 个算子。返回 (产物, 描述)。
(Uint8List, String) _mutate(Uint8List corpus, Random rng) {
  var cur = corpus;
  final steps = 1 + rng.nextInt(3);
  final desc = StringBuffer();
  for (var s = 0; s < steps; s++) {
    final idx = rng.nextInt(_ops.length);
    cur = _ops[idx](cur, rng);
    desc.write(opNames[idx]);
    if (s != steps - 1) desc.write('→');
  }
  return (cur, desc.toString());
}

/// 不变量检查：[body] 只允许抛 [allowed] 的异常（正常返回亦合法）。
/// 失败信息携带 (seed, round, ops) 供重放。
void _checkInvariant(
  String domain,
  int seed,
  int round,
  String ops,
  void Function() body,
  bool Function(Object e) allowed,
) {
  try {
    body();
  } on Object catch (e) {
    if (!allowed(e)) {
      fail(
        '[$domain] 非白名单异常 ${e.runtimeType}: $e\n'
        '重放: seed=$seed round=$round ops=$ops',
      );
    }
  }
}

/// async 版不变量检查：**必须** await oracle Future——async 函数体内的
/// 异常进 Future 而非同步抛出，不 await 会得到恒绿假结果。
Future<void> _checkInvariantAsync(
  String domain,
  int seed,
  int round,
  String ops,
  Future<void> Function() body,
  bool Function(Object e) allowed,
) async {
  try {
    await body();
  } on Object catch (e) {
    if (!allowed(e)) {
      fail(
        '[$domain] 非白名单异常 ${e.runtimeType}: $e\n'
        '重放: seed=$seed round=$round ops=$ops',
      );
    }
  }
}

/// 白名单辅助：按异常**运行时类型精确匹配**判定（本 harness 涉及的白名单
/// 异常均未被继承特化，精确匹配可避免误放行子类）。
bool Function(Object e) _allowTypes(Set<Type> types) =>
    (e) => types.contains(e.runtimeType);

// ─────────────────────────────────────────────────────────────────────────────
// corpus 构造（全部取自真实合法构造路径）
// ─────────────────────────────────────────────────────────────────────────────

/// PFv3 信封 corpus：真实 FrameContext + 96B 密文。
Map<String, dynamic> _buildEnvelopeCorpus() {
  const ctx = FrameContext(
    messageId: 'msg-fuzz-001',
    scope: FrameScope.c2c,
    conversationId: 'conv-1',
    senderUid: '100',
    senderDid: 'dev-a',
    destination: '200',
    messageType: 'text',
    action: 'message',
    createdAtMs: 1753500000000,
    protocol: 'olm',
    protocolVersion: 3,
    sessionRef: 'sess-fuzz',
    epochOrCounter: 7,
  );
  return ProtectedFrameV3.encodeOuterEnvelope(
    context: ctx,
    ciphertext: _bytes(List.generate(96, (i) => (i * 7) & 0xFF)),
    protocolMetadata: const {'session_id': 'sess-fuzz'},
  );
}

/// descriptor corpus：合法 map（带独立密钥 thumb），与
/// attachment_descriptor_test.dart 的正向锚点同构。
Uint8List _buildDescriptorCorpus() {
  Uint8List filled(int v, int len) =>
      _bytes(List<int>.filled(len, v, growable: false));
  String b64(int v, int len) => base64Url.encode(filled(v, len));
  final m = <String, dynamic>{
    'attachment_id': 'att-fuzz-0001',
    'object_key': 'u10086/2026/10/fuzz.bin',
    'content_key': b64(0x11, 32),
    'cipher': 'AES-256-GCM',
    'chunk_size': 32,
    'chunk_count': 4,
    'base_nonce': b64(0x22, 12),
    'plain_size': 100,
    'plain_sha256': b64(0x33, 32),
    'mime': 'application/octet-stream',
    'name': 'fuzz.bin',
    'thumb': <String, dynamic>{
      'attachment_id': 'att-fuzz-0001-thumb',
      'object_key': 'u10086/2026/10/fuzz-thumb.bin',
      'content_key': b64(0x44, 32),
      'cipher': 'AES-256-GCM',
      'chunk_size': 32,
      'chunk_count': 1,
      'base_nonce': b64(0x55, 12),
      'plain_size': 20,
      'plain_sha256': b64(0x66, 32),
      'mime': 'image/jpeg',
      'name': 'fuzz-thumb.jpg',
    },
  };
  return AttachmentDescriptor.fromMap(m).toCanonicalBytes();
}

/// claim 响应 corpus：字段类型/非空均合法（签名不要求密码学有效——
/// parse 层不验签，验签在 OlmSessionService 的 TOFU/签名层）。
Uint8List _buildClaimCorpus() {
  final claim = <String, dynamic>{
    'type': 'one_time',
    'key_id': 'otk-0042',
    'key_base64': base64Url.encode(
      _bytes(List.generate(32, (i) => (i * 3) & 0xFF)),
    ),
    'identity': <String, dynamic>{
      'ed25519_key': base64Url.encode(
        _bytes(List.generate(32, (i) => (i * 5) & 0xFF)),
      ),
      'curve25519_key': base64Url.encode(
        _bytes(List.generate(32, (i) => (i * 11) & 0xFF)),
      ),
      'signature': base64Url.encode(
        _bytes(List.generate(64, (i) => (i * 13) & 0xFF)),
      ),
    },
  };
  return _bytes(utf8.encode(jsonEncode(claim)));
}

/// megolm backup section corpus（云备份恢复路径的服务端可控 JSON 层）。
Map<String, dynamic> _buildMegolmSectionCorpus() {
  final grant = MegolmHistoryGrant(
    scope: '100',
    sessionId: 'session-fuzz',
    generationNo: 2,
    startSeq: 481,
    endSeq: 900,
  ).toJson();
  return <String, dynamic>{
    'format_version': kMegolmSectionFormatVersion,
    'sessions': [
      <String, dynamic>{
        'scope': '100',
        'session_id': 'session-fuzz',
        'exported_key': 'AgICAgICAgIC',
        'grant': grant,
      },
    ],
    'omitted_session_count': 0,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试入口
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final envelopeWhitelist = _allowTypes({
    CborParseException,
    FrameBoundsException,
    FormatException,
  });
  final descriptorWhitelist = _allowTypes({AttachmentDescriptorException});
  final backupWhitelist = _allowTypes({
    ArgumentError,
    FormatException,
    StateError,
  });

  group('fuzz: PFv3 信封（protected_header/信封字段腐蚀）', () {
    final corpus = _buildEnvelopeCorpus();
    // 腐蚀目标：protected_header 解码后的 canonical CBOR 字节。
    final headerBytes = base64Url.decode(corpus['protected_header'] as String);

    test(
      'seeded 腐蚀 ×200：verifyOuterEnvelope + validateEnvelopeBounds 只抛白名单',
      () {
        var mutations = 0;
        for (final seed in fuzzSeeds) {
          final rng = Random(seed);
          for (var round = 0; round < roundsPerSeed; round++) {
            final (mutated, ops) = _mutate(headerBytes, rng);
            final env = Map<String, dynamic>.from(corpus);
            env['protected_header'] = base64Url.encode(mutated);
            mutations++;
            _checkInvariant('PFv3 信封', seed, round, ops, () {
              ProtectedFrameV3.validateEnvelopeBounds(env);
              ProtectedFrameV3.verifyOuterEnvelope(env);
            }, envelopeWhitelist);
          }
        }
        expect(mutations, greaterThanOrEqualTo(200));
      },
    );

    test('seeded 腐蚀 ×200：base64 字符串层腐蚀（传输层形态）', () {
      final stringFields = ['protected_header', 'header_hash', 'ciphertext'];
      const scrambleChars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          'abcdefghijklmnopqrstuvwxyz0123456789-_=+/?#*';
      var mutations = 0;
      for (final seed in fuzzSeeds) {
        final rng = Random(seed ^ 0x5F3759DF);
        for (var round = 0; round < roundsPerSeed; round++) {
          final env = Map<String, dynamic>.from(corpus);
          final field = stringFields[rng.nextInt(stringFields.length)];
          final s = (corpus[field] as String);
          final chars = s.split('');
          final n = 1 + rng.nextInt(3);
          for (var k = 0; k < n && chars.isNotEmpty; k++) {
            final at = rng.nextInt(chars.length);
            chars[at] = scrambleChars[rng.nextInt(scrambleChars.length)];
          }
          env[field] = chars.join();
          // 交替把 meta_version 打成随机类型（服务端可控 JSON 字段）。
          if (rng.nextBool()) {
            env['meta_version'] = rng.nextInt(9) - 2;
          }
          mutations++;
          _checkInvariant('PFv3 信封.b64', seed, round, field, () {
            ProtectedFrameV3.validateEnvelopeBounds(env);
            ProtectedFrameV3.verifyOuterEnvelope(env);
          }, envelopeWhitelist);
        }
      }
      expect(mutations, greaterThanOrEqualTo(200));
    });
  });

  group('fuzz: attachment descriptor（canonical CBOR 腐蚀）', () {
    final corpus = _buildDescriptorCorpus();

    test(
      'seeded 腐蚀 ×200：fromCanonicalBytes 只抛 AttachmentDescriptorException',
      () {
        var mutations = 0;
        for (final seed in fuzzSeeds) {
          final rng = Random(seed ^ 0xC0FFEE);
          for (var round = 0; round < roundsPerSeed; round++) {
            final (mutated, ops) = _mutate(corpus, rng);
            mutations++;
            _checkInvariant('descriptor', seed, round, ops, () {
              AttachmentDescriptor.fromCanonicalBytes(mutated);
            }, descriptorWhitelist);
          }
        }
        expect(mutations, greaterThanOrEqualTo(200));
      },
    );

    test('合法 corpus 锚点：未腐蚀时必须可解析（防恒拒收假绿）', () {
      final d = AttachmentDescriptor.fromCanonicalBytes(corpus);
      expect(d.attachmentId, 'att-fuzz-0001');
      expect(d.thumb, isNotNull);
    });
  });

  group('fuzz: backup 下载体（.enc 容器腐蚀，KDF 成本闸见文件头注释）', () {
    const password = 'FuzzPass123!';
    late Uint8List corpus;

    setUpAll(() async {
      final packed = await E2EELocalBackupService.packBackupBytes(
        password: password,
        privateKey: 'test-private-key-pem',
        publicKey: 'test-public-key-pem',
        deviceId: 'dev-fuzz-1',
        keyId: 'kid-fuzz-1',
        secureEntriesForTest: const {},
      );
      // corpus 阶段即钳低迭代数：corpus 只需**结构合法**，无需可解密回
      // 明文（fuzz 的期望结果本就是拒收/白名单异常）。
      final head = ByteData.sublistView(packed);
      head.setUint32(12, 17);
      corpus = packed;
    });

    /// KDF 成本闸：腐蚀后若迭代数 > 64（含合法昂贵区间 (64, 1e6] 与越界
    /// 值 > 1e6），一律钳回 17——seeded 腐蚀不覆盖越界拒绝分支（该路径由
    /// 固定向量组覆盖）；<= 64（含越界的 0）原样保留。
    Uint8List kdfCostGuard(Uint8List b) {
      final view = ByteData.sublistView(b);
      if (b.length < 16) return b;
      final it = view.getUint32(12);
      if (it > 64) {
        final out = Uint8List.fromList(b);
        ByteData.sublistView(out).setUint32(12, 17);
        return out;
      }
      return b;
    }

    test('seeded 腐蚀 ×200：unpackBackupBytes 只抛白名单', () async {
      var mutations = 0;
      for (final seed in fuzzSeeds) {
        final rng = Random(seed ^ 0xBACC10);
        for (var round = 0; round < roundsPerSeed; round++) {
          final (mutated, ops) = _mutate(corpus, rng);
          final guarded = kdfCostGuard(mutated);
          mutations++;
          await _checkInvariantAsync('backup', seed, round, ops, () {
            return E2EELocalBackupService.unpackBackupBytes(
              bytes: guarded,
              password: password,
            );
          }, backupWhitelist);
        }
      }
      expect(mutations, greaterThanOrEqualTo(200));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('合法 corpus 锚点：结构完整（可走到 GCM 认证失败而非结构拒绝）', () async {
      // 迭代数被钳为 17 → 派生密钥必然与导出时（600k）不同 → GCM 认证
      // 失败 → ArgumentError。这证明 corpus 通过了全部结构校验。
      await expectLater(
        E2EELocalBackupService.unpackBackupBytes(
          bytes: corpus,
          password: password,
        ),
        throwsA(isA<ArgumentError>()),
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('迭代数越界固定向量：派生前确定性拒绝（零 KDF 成本）', () async {
      for (final bad in [0, 1000001, 0x7FFFFFFF, 0xFFFFFFFF]) {
        final bytes = Uint8List.fromList(corpus);
        ByteData.sublistView(bytes).setUint32(12, bad);
        await expectLater(
          E2EELocalBackupService.unpackBackupBytes(
            bytes: bytes,
            password: password,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'iterations=$bad 应在派生前被拒',
        );
      }
    });
  });

  group('fuzz: handshake/claim 响应（JSON 字节腐蚀）', () {
    final corpus = _buildClaimCorpus();

    /// claim 域白名单：FormatException（utf8/JSON）+ 带固定前缀的
    /// fail-closed 拒收 Exception（parseClaimPayload 契约）。
    bool claimWhitelist(Object e) =>
        e is FormatException ||
        (e is Exception &&
            e.toString().contains('olm claim_key: invalid payload'));

    test('seeded 腐蚀 ×200：jsonDecode + parseClaimPayload 只抛白名单', () {
      var mutations = 0;
      for (final seed in fuzzSeeds) {
        final rng = Random(seed ^ 0xC1A1F);
        for (var round = 0; round < roundsPerSeed; round++) {
          final (mutated, ops) = _mutate(corpus, rng);
          mutations++;
          _checkInvariant('claim', seed, round, ops, () {
            final decoded = jsonDecode(utf8.decode(mutated));
            OlmApi.parseClaimPayload(decoded);
          }, claimWhitelist);
        }
      }
      expect(mutations, greaterThanOrEqualTo(200));
      // 合法 corpus 锚点：未腐蚀时必须完整通过（防恒拒收假绿）。
      final ok = OlmApi.parseClaimPayload(jsonDecode(utf8.decode(corpus)));
      expect(ok['key_id'], 'otk-0042');
    });

    test('畸形 JSON 固定向量：全部 FormatException / 拒收', () {
      const vectors = [
        '',
        '{',
        '{"identity": ',
        '{"a":1,}',
        'garbage',
        'null',
        'true',
        '42',
        '"string"',
        '[]',
        '[{"identity":{}}]',
        '\x00\x01\x02',
        '{"type":"one_time","key_id":"k","key_base64":"AA","identity":{"ed25519_key":"AA","curve25519_key":"AA","signature":"AA"}},', // 尾逗号
      ];
      for (final v in vectors) {
        _checkInvariant('claim.畸形JSON', -1, -1, 'fixed', () {
          final decoded = jsonDecode(v);
          OlmApi.parseClaimPayload(decoded);
        }, claimWhitelist);
      }
    });

    test('类型混淆固定向量：fail-closed 拒收（TypeError=失败）', () {
      final identityValid = <String, dynamic>{
        'ed25519_key': 'AA',
        'curve25519_key': 'AA',
        'signature': 'AA',
      };
      final valid = <String, dynamic>{
        'type': 'one_time',
        'key_id': 'k',
        'key_base64': 'AA',
        'identity': identityValid,
      };

      final vectors = <dynamic>[
        'not a map',
        42,
        true,
        null,
        <dynamic>[],
        {...valid, 'identity': 'identity-as-string'},
        {...valid, 'identity': 42},
        {
          ...valid,
          'identity': <dynamic>[1, 2],
        },
        {...valid, 'identity': null},
        {...valid, 'key_base64': 123},
        {...valid, 'key_base64': null},
        {...valid, 'key_base64': <dynamic, dynamic>{}},
        {...valid, 'type': true},
        {...valid, 'type': 1},
        {...valid, 'key_id': <dynamic>[]},
        {
          ...valid,
          'identity': {...identityValid, 'ed25519_key': 32},
        },
        {
          ...valid,
          'identity': {...identityValid, 'curve25519_key': null},
        },
        {
          ...valid,
          'identity': {...identityValid, 'signature': <dynamic>[]},
        },
        {...valid, 'identity': <String, dynamic>{}},
        {...valid}..remove('key_base64'),
        {...valid}..remove('identity'),
        {...valid}..remove('type'),
        // C17b 复审 m2：非 String key 的 Map。生产 jsonDecode 不可达
        // （JSON 对象 key 恒为 String），但 oracle 契约要求显式拒收而非
        // `Map<String, dynamic>.from` 抛 TypeError 泄出。
        // 顶层混入 int key（spread + int key → Map<dynamic, dynamic>）。
        <dynamic, dynamic>{...valid, 42: 'x'},
        // identity 是 int-key map。
        <dynamic, dynamic>{
          ...valid,
          'identity': <dynamic, dynamic>{1: 'AA'},
        },
        // identity 混入 int key（合法 String key 也在）。
        <dynamic, dynamic>{
          ...valid,
          'identity': <dynamic, dynamic>{'ed25519_key': 'AA', 7: 'BB'},
        },
      ];

      for (var i = 0; i < vectors.length; i++) {
        // 顶层非 map 的直接抛白名单拒收；
        // 顶层是 map 的必须要么拒收、要么（理论不可能）结构合法。
        final raw = vectors[i];
        if (raw is Map) {
          expect(
            () => OlmApi.parseClaimPayload(raw),
            throwsA(
              predicate<Object>(
                (e) => e.toString().contains('olm claim_key: invalid payload'),
                'fail-closed 拒收（vector #$i: ${raw.keys.toList()}）',
              ),
            ),
            reason: '类型混淆 vector #$i 必须被 parseClaimPayload 拒收',
          );
        } else {
          _checkInvariant('claim.类型混淆', -1, i, 'fixed', () {
            OlmApi.parseClaimPayload(raw);
          }, claimWhitelist);
        }
      }
    });

    test('超长字段/深嵌套固定向量：解析不崩溃、深嵌套不栈溢出', () {
      final oneMb = 'A' * (1024 * 1024);
      final oversized = <String, dynamic>{
        'type': 'one_time',
        'key_id': oneMb.substring(0, 64 * 1024),
        'key_base64': oneMb,
        'identity': {
          'ed25519_key': oneMb,
          'curve25519_key': oneMb,
          'signature': oneMb,
        },
      };
      // parse 层只做类型/非空校验（长度上限属密码学消费层——
      // Curve25519PublicKey.fromBase64 会拒收非 32B 输入），此处断言
      // 不崩溃、不挂死、可判定。
      final r = OlmApi.parseClaimPayload(oversized);
      expect(r['key_base64'], hasLength(1024 * 1024));

      // 深嵌套（嵌在 identity 里）：jsonDecode + parse 均须可判定。
      // 实测 Dart jsonDecode 迭代实现可承受 200k 层（探针见 C17b 证据卡）。
      for (final depth in [100, 1000, 10000, 100000]) {
        final deep = '{"x": ${'[' * depth}${']' * depth}}';
        _checkInvariant('claim.深嵌套', -1, depth, 'fixed', () {
          final decoded = jsonDecode(deep);
          OlmApi.parseClaimPayload(decoded);
        }, claimWhitelist);
      }
    });
  });

  group('fuzz: get_identity 响应（C17b 复审 gap 收口）', () {
    /// 合法 identity corpus：与后端 `olm_identity_repo:find_identity` 的
    /// SELECT 列一致（device_id/ed25519_key/curve25519_key/signature，
    /// 密码学有效性不在 parse 层——验签在 OlmSessionService）。
    Uint8List buildIdentityCorpus() {
      final identity = <String, dynamic>{
        'device_id': 'dev-peer-1',
        'ed25519_key': base64Url.encode(
          _bytes(List.generate(32, (i) => (i * 5) & 0xFF)),
        ),
        'curve25519_key': base64Url.encode(
          _bytes(List.generate(32, (i) => (i * 11) & 0xFF)),
        ),
        'signature': base64Url.encode(
          _bytes(List.generate(64, (i) => (i * 13) & 0xFF)),
        ),
      };
      return _bytes(utf8.encode(jsonEncode(identity)));
    }

    bool identityWhitelist(Object e) =>
        e is FormatException ||
        (e is Exception &&
            e.toString().contains('olm get_identity: invalid payload'));

    test('seeded 腐蚀 ×200：jsonDecode + parseIdentityPayload 只抛白名单', () {
      final corpus = buildIdentityCorpus();
      var mutations = 0;
      for (final seed in fuzzSeeds) {
        final rng = Random(seed ^ 0x6E0);
        for (var round = 0; round < roundsPerSeed; round++) {
          final (mutated, ops) = _mutate(corpus, rng);
          mutations++;
          _checkInvariant('get_identity', seed, round, ops, () {
            final decoded = jsonDecode(utf8.decode(mutated));
            OlmApi.parseIdentityPayload(decoded);
          }, identityWhitelist);
        }
      }
      expect(mutations, greaterThanOrEqualTo(200));
      // 合法 corpus 锚点：未腐蚀时必须完整通过（防恒拒收假绿）。
      final ok = OlmApi.parseIdentityPayload(jsonDecode(utf8.decode(corpus)));
      expect(ok['device_id'], 'dev-peer-1');
    });

    test('类型混淆/非 String key 固定向量：fail-closed 拒收（TypeError=失败）', () {
      final valid = <String, dynamic>{
        'device_id': 'dev-peer-1',
        'ed25519_key': 'AA',
        'curve25519_key': 'AA',
        'signature': 'AA',
      };

      final vectors = <dynamic>[
        'not a map',
        42,
        true,
        null,
        <dynamic>[],
        {...valid, 'curve25519_key': 32},
        {...valid, 'curve25519_key': null},
        {...valid, 'ed25519_key': <dynamic>[]},
        {...valid, 'signature': <dynamic, dynamic>{}},
        {...valid, 'device_id': true},
        {...valid}..remove('device_id'),
        {...valid}..remove('ed25519_key'),
        {...valid}..remove('curve25519_key'),
        {...valid}..remove('signature'),
        // 非 String key（生产 jsonDecode 不可达，oracle 契约边角）：
        // 修复前 `Map<String, dynamic>.from` 在此处抛 TypeError。
        <dynamic, dynamic>{...valid, 1: 'x'},
        <dynamic, dynamic>{...valid, 'curve25519_key': 'AA', 9: null},
      ];

      for (var i = 0; i < vectors.length; i++) {
        final raw = vectors[i];
        if (raw is Map) {
          expect(
            () => OlmApi.parseIdentityPayload(raw),
            throwsA(
              predicate<Object>(
                (e) =>
                    e.toString().contains('olm get_identity: invalid payload'),
                'fail-closed 拒收（vector #$i: ${raw.keys.toList()}）',
              ),
            ),
            reason: '类型混淆 vector #$i 必须被 parseIdentityPayload 拒收',
          );
        } else {
          _checkInvariant('get_identity.类型混淆', -1, i, 'fixed', () {
            OlmApi.parseIdentityPayload(raw);
          }, identityWhitelist);
        }
      }
    });
  });

  group('fuzz: backup JSON 段（megolm section，云恢复路径）', () {
    final corpusJson = jsonEncode(_buildMegolmSectionCorpus());

    bool sectionWhitelist(Object e) => e is FormatException;

    test('seeded 腐蚀 ×200：parseMegolmSection 只抛 FormatException', () {
      final corpusBytes = _bytes(utf8.encode(corpusJson));
      var mutations = 0;
      for (final seed in fuzzSeeds) {
        final rng = Random(seed ^ 0xBE11);
        for (var round = 0; round < roundsPerSeed; round++) {
          final (mutated, ops) = _mutate(corpusBytes, rng);
          mutations++;
          _checkInvariant('megolm-section', seed, round, ops, () {
            final decoded = jsonDecode(utf8.decode(mutated));
            parseMegolmSection(decoded);
          }, sectionWhitelist);
        }
      }
      expect(mutations, greaterThanOrEqualTo(200));
    });
  });
}
