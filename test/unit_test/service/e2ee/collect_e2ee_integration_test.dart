/// C8 —— E2EE 收藏客户端链集成测试（PLAN §16 可自动化部分）。
///
/// 覆盖：密钥链 bootstrap → seal → decode（§8.2 双核对）→ 编辑流 CAS
/// （成功/409 冲突重读）→ 同步检测（仅看 generation，重包裹不漏检）→
/// v1 协议核心（C3 批准前置/发送前重查/ACK 语义）。
/// 真机矩阵（A4/A6/A7）与抓包（A1/A3）不在本文件范围。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/collect_key_sync.dart';
import 'package:imboy/service/e2ee/collect_keychain.dart';
import 'package:imboy/service/e2ee/collect_sealed_service.dart';
import 'package:imboy/store/api/user_collect_api.dart';
import 'package:imboy/store/model/user_collect_model.dart';

/// fake API：模拟服务端单行状态机（generation CAS）。
class _FakeCollectApi extends UserCollectApi {
  _FakeCollectApi();

  // 服务端行状态
  int generation = 0;
  String infoSealed = '';
  int keyVersion = 0;
  List<String> attach = [];

  @override
  Future<CollectV1Result> updateV1({
    required String kindId,
    required int expectedGeneration,
    required int newGeneration,
    required String infoSealed,
    required int keyVersion,
    required List<String> attachHashes,
  }) async {
    if (generation != expectedGeneration) {
      // 幂等判定：同代同密文同版本同引用
      if (generation == newGeneration &&
          this.infoSealed == infoSealed &&
          this.keyVersion == keyVersion) {
        return CollectV1Result(
          ok: true,
          code: 0,
          msg: 'ok',
          generation: newGeneration,
          idempotent: true,
        );
      }
      return const CollectV1Result(ok: false, code: 5502, msg: 'conflict');
    }
    generation = newGeneration;
    this.infoSealed = infoSealed;
    this.keyVersion = keyVersion;
    attach = attachHashes;
    return CollectV1Result(
      ok: true,
      code: 0,
      msg: 'ok',
      generation: newGeneration,
    );
  }
}

/// 内存版 CollectKeychain（绕开 flutter_secure_storage 平台通道）。
class _MemKeychain implements CollectKeychain {
  _MemKeychain._();
  static _MemKeychain instance = _MemKeychain._();

  CollectKeychainState? state;

  @override
  Future<CollectKeychainState> load() async =>
      state ?? const CollectKeychainState(keys: []);

  @override
  Future<void> save(CollectKeychainState s) async {
    state = s;
  }

  @override
  Future<CollectKeychainState> ensureBootstrap() async {
    final s = await load();
    if (s.keys.isNotEmpty) return s;
    final bootstrapped = CollectKeychainLogic.bootstrap();
    await save(bootstrapped);
    return bootstrapped;
  }

  @override
  Future<CollectKeyVersion?> sealableKey() async {
    final s = await load();
    return CollectKeychainLogic.sealAllowed(s) ? s.activeKey : null;
  }
}

void main() {
  const userId = 100860;
  const kindId = 'cqi6od1pa9gjnlt3a5a0';
  const kind = 2;
  final hashes = <String>['aa' * 32, 'bb' * 32];

  Future<CollectKeychainState> boot() async {
    final kc = _MemKeychain.instance;
    kc.state = null;
    return kc.ensureBootstrap();
  }

  test('A4 自动化链：bootstrap → seal → decode → 编辑 CAS → 同步检测', () async {
    final kc = _MemKeychain.instance;
    final state = await boot();
    expect(state.activeVersion, 1);

    // seal（generation=1）
    final payload = {
      'remark': '备注',
      'source': 'chat',
      'attach_file_hash256': hashes,
    };
    final sealed = await CollectSealedService.sealPayload(
      key: state.activeKey!,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 1,
      payload: payload,
      attachHashes: hashes,
    );
    expect(sealed.isNotEmpty, isTrue);

    // decode（§8.2 双核对通过）
    final decoded = await CollectSealedService.decodeSealedRow(
      keychain: kc,
      userId: userId,
      row: {
        'kind': kind,
        'kind_id': kindId,
        'generation': 1,
        'key_version': 1,
        'info': sealed,
        'attach_file_hash256': hashes.join(','),
      },
    );
    expect(decoded.payload['remark'], '备注');
    expect(decoded.generation, 1);
    expect(decoded.sealGeneration, 1);

    // 编辑流 CAS（fake 服务端 gen: 1→2）
    final api = _FakeCollectApi()..generation = 1;
    final r1 = await CollectSealedService.editFlow(
      api: api,
      keychain: kc,
      userId: userId,
      kindId: kindId,
      kind: kind,
      expectedGeneration: 1,
      payload: {...payload, 'remark': '改'},
      attachHashes: hashes,
    );
    expect(r1.ok, isTrue);
    expect(r1.generation, 2);
    expect(api.generation, 2);

    // 陈旧基线 → 5502
    final r2 = await CollectSealedService.editFlow(
      api: api,
      keychain: kc,
      userId: userId,
      kindId: kindId,
      kind: kind,
      expectedGeneration: 1,
      payload: payload,
      attachHashes: hashes,
    );
    expect(r2.ok, isFalse);
    expect(r2.code, 5502);

    // 同步检测：重包裹推进 generation（服务端语义）→ 不漏检
    expect(CollectSealedService.needsResync(2, 3), isTrue);
    expect(CollectSealedService.needsResync(3, 3), isFalse);
  });

  test('decode 防串用：行引用列表被拼装 → 必败（§8.2②）', () async {
    final kc = _MemKeychain.instance;
    final state = await boot();
    final sealed = await CollectSealedService.sealPayload(
      key: state.activeKey!,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 1,
      payload: {'attach_file_hash256': hashes},
      attachHashes: hashes,
    );
    expect(
      () => CollectSealedService.decodeSealedRow(
        keychain: kc,
        userId: userId,
        row: {
          'kind': kind,
          'kind_id': kindId,
          'generation': 1,
          'key_version': 1,
          'info': sealed,
          // 服务端列表被拼装进第三个哈希
          'attach_file_hash256': [...hashes, 'cc' * 32].join(','),
        },
      ),
      throwsA(isA<CollectSealedException>()),
    );
  });

  test('C3 协议核心：批准前置三条件缺一不可；ACK 仅收讫；重试需重新批准', () {
    expect(
      CollectKeySyncProtocol.mayDeliverKey(
        userApproved: true,
        identityVerified: true,
        authorizedNow: true,
      ),
      isTrue,
    );
    for (final missing in [
      (false, true, true),
      (true, false, true),
      (true, true, false),
    ]) {
      expect(
        CollectKeySyncProtocol.mayDeliverKey(
          userApproved: missing.$1,
          identityVerified: missing.$2,
          authorizedNow: missing.$3,
        ),
        isFalse,
      );
    }
    final ack = CollectKeySyncProtocol.onAck(
      CollectKeySyncMessage.fromJson({'t': 'key_ack', 'did': 'dev-1'})!,
    );
    expect(ack.receivedOnly, isTrue);
    expect(CollectKeySyncProtocol.retryRequiresReapproval(), isTrue);

    // key_delivery 编解码 roundtrip（CK 只在协议层短暂存在即交传输层）
    final msg = CollectKeySyncProtocol.keyDelivery(
      targetDid: 'dev-2',
      keyVersion: 2,
      ckB64: base64.encode(Uint8List(32)),
      nonce: 'n-1',
    );
    final restored = CollectKeySyncMessage.fromJson(
      Map<String, dynamic>.from(
        (msg.toJson() as Map).map((k, v) => MapEntry(k.toString(), v)),
      ),
    )!;
    expect(restored.ckB64, msg.ckB64);
    expect(restored.keyVersion, 2);
  });

  test('C5 decryptModels：sealed 行就地解密回填（remark/source/tag 权威）', () async {
    final kc = _MemKeychain.instance;
    final state = await boot();
    final sealed = await CollectSealedService.sealPayload(
      key: state.activeKey!,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 1,
      payload: {
        'remark': '密内备注',
        'source': 'chat',
        'tag': 't1,',
        'attach_file_hash256': hashes,
      },
      attachHashes: hashes,
    );
    final item = UserCollectModel(
      userId: userId,
      kind: kind,
      kindId: kindId,
      source: '',
      remark: '',
      tag: '',
      updatedAt: 0,
      createdAt: 0,
      info: const {},
      generation: 1,
      keyVersion: 1,
      infoSealed: sealed,
      attachFileHash256: hashes.join(','),
    );
    await CollectSealedService.decryptModels(
      [item],
      userId: userId,
      keychain: kc,
    );
    expect(item.remark, '密内备注');
    expect(item.source, 'chat');
    expect(item.tag, 't1,');
    expect(item.info['attach_file_hash256'], isNotNull);
  });

  test('C5 decryptModels：解密失败保留占位（不抛出）', () async {
    final kc = _MemKeychain.instance;
    await boot();
    final item = UserCollectModel(
      userId: userId,
      kind: kind,
      kindId: kindId,
      source: '',
      remark: '',
      tag: '',
      updatedAt: 0,
      createdAt: 0,
      info: const {},
      generation: 1,
      keyVersion: 1,
      infoSealed: 'bm90LXZhbGlk', // 合法 base64，非法密文
      attachFileHash256: '',
    );
    await CollectSealedService.decryptModels(
      [item],
      userId: userId,
      keychain: kc,
    );
    expect(item.remark, '');
    expect(item.info, isEmpty);
  });

  test('C5 remark：sealed 行 editFlow 回写新密文；legacy 行走 change', () async {
    final kc = _MemKeychain.instance;
    final state = await boot();
    final sealed = await CollectSealedService.sealPayload(
      key: state.activeKey!,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 1,
      payload: {'remark': '旧'},
      attachHashes: const [],
    );
    final item = UserCollectModel(
      userId: userId,
      kind: kind,
      kindId: kindId,
      source: '',
      remark: '旧',
      tag: '',
      updatedAt: 0,
      createdAt: 0,
      info: {'remark': '旧'},
      generation: 1,
      keyVersion: 1,
      infoSealed: sealed,
      attachFileHash256: '',
    );
    final api = _FakeCollectApi()..generation = 1;
    final saved = <Map<String, dynamic>>[];
    final ok = await CollectSealedService.remark(
      kindId: kindId,
      remark: '新',
      sealedItem: item,
      userId: userId,
      nowSec: 100,
      api: api,
      keychain: kc,
      legacyChange: (_) async => false,
      onSaved: (row) async => saved.add(row),
    );
    expect(ok, isTrue);
    expect(api.generation, 2);
    expect(saved.single['generation'], 2);
    expect(saved.single['remark'], '新');
    // 新密文回写（非旧密文）
    expect(saved.single['info'], isNot(equals(sealed)));

    // legacy 分支
    final legacySaved = <Map<String, dynamic>>[];
    var legacyCalled = false;
    final okLegacy = await CollectSealedService.remark(
      kindId: 'legacy-kind',
      remark: 'r',
      sealedItem: null,
      userId: userId,
      nowSec: 100,
      api: api,
      keychain: kc,
      legacyChange: (_) async {
        legacyCalled = true;
        return true;
      },
      onSaved: (row) async => legacySaved.add(row),
    );
    expect(okLegacy, isTrue);
    expect(legacyCalled, isTrue);
    expect(legacySaved.single['remark'], 'r');
  });

  test('墓碑后密文仍可解（seal_generation < 行 generation，§8.1）', () async {
    final kc = _MemKeychain.instance;
    final state = await boot();
    final sealed = await CollectSealedService.sealPayload(
      key: state.activeKey!,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 2,
      payload: {'remark': 'r'},
      attachHashes: const [],
    );
    // 行经墓碑（gen 3）与复活（gen 4）——密文头仍是 2，可解且断言通过
    final decoded = await CollectSealedService.decodeSealedRow(
      keychain: kc,
      userId: userId,
      row: {
        'kind': kind,
        'kind_id': kindId,
        'generation': 4,
        'key_version': 1,
        'info': sealed,
        'attach_file_hash256': '',
      },
    );
    expect(decoded.sealGeneration, 2);
    expect(decoded.generation, 4);
  });
}
