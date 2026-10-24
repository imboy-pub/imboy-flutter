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

  // add_v1 服务端状态（语义与 2026-10-24 本地 HTTP 冒烟实测一致）
  int addCalls = 0;
  bool legacyRow = false;
  int tombstoneGen = 0; // >0 = sealed 墓碑行

  @override
  Future<CollectV1Result> addV1({
    required int kind,
    required String kindId,
    required String infoSealed,
    required int keyVersion,
    required List<String> attachHashes,
  }) async {
    addCalls++;
    if (legacyRow) {
      return const CollectV1Result(ok: false, code: 5506, msg: 'legacy row');
    }
    if (generation == 0 && tombstoneGen == 0) {
      generation = 1;
      this.infoSealed = infoSealed;
      this.keyVersion = keyVersion;
      attach = attachHashes;
      return CollectV1Result(ok: true, code: 0, msg: 'ok', generation: 1);
    }
    if (this.infoSealed == infoSealed && this.keyVersion == keyVersion) {
      return CollectV1Result(
        ok: true,
        code: 0,
        msg: 'ok',
        generation: tombstoneGen > 0 ? tombstoneGen : generation,
        idempotent: true,
      );
    }
    if (tombstoneGen > 0) {
      // 复活：复用原行，G+1
      generation = tombstoneGen + 1;
      tombstoneGen = 0;
      this.infoSealed = infoSealed;
      this.keyVersion = keyVersion;
      attach = attachHashes;
      return CollectV1Result(
        ok: true,
        code: 0,
        msg: 'ok',
        generation: generation,
      );
    }
    return const CollectV1Result(ok: false, code: 5502, msg: 'conflict');
  }

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

  @override
  void clearCache() => state = null;
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

  group('collectSealed 创建流（§5 能力1 / §9 兼容矩阵）', () {
    const uid = 100860;
    const kid = 'cs-create-0001';

    Future<CollectCreateOutcome> run(
      _FakeCollectApi api,
      _MemKeychain kc, {
      required bool capability,
      required Map<String, dynamic> info,
      UserCollectModel? local,
      String kindId = kid,
      int kind = 1,
    }) async {
      return CollectSealedService.collectSealed(
        api: api,
        keychain: kc,
        capability: () => capability,
        msgUnsupported: 'unsup-tip',
        msgRotating: 'rot-tip',
        userId: uid,
        kind: kind,
        kindId: kindId,
        source: 'tester',
        info: info,
        findLocal: (_) async => local,
        onSaved: (_) async {},
      );
    }

    setUp(() {
      _MemKeychain.instance.state = null;
    });

    test('能力未协商 → 拒绝+升级提示；不发请求、不 bootstrap（无明文回退）', () async {
      final api = _FakeCollectApi();
      final out = await run(
        api,
        _MemKeychain.instance,
        capability: false,
        info: {},
      );
      expect(out.status, CollectCreateStatus.refused);
      expect(out.tip, 'unsup-tip');
      expect(api.addCalls, 0);
      expect(_MemKeychain.instance.state, isNull);
    });

    test('密钥轮换进行中 → 拒绝；不发请求', () async {
      final api = _FakeCollectApi();
      final kc = _MemKeychain.instance;
      await kc.ensureBootstrap();
      kc.state = kc.state!.copyWith(phase: CollectRotationPhase.rewrapRunning);
      final out = await run(api, kc, capability: true, info: {});
      expect(out.status, CollectCreateStatus.refused);
      expect(out.tip, 'rot-tip');
      expect(api.addCalls, 0);
    });

    test('文本收藏：seal→addV1(gen1)→onSaved 密文行；可 decode 往返（§8.2 声明嵌入）', () async {
      final api = _FakeCollectApi();
      final kc = _MemKeychain.instance;
      final info = {
        'msg_type': 'text',
        'payload': {'text': '你好收藏'},
      };
      final savedRows = <Map<String, dynamic>>[];
      final out = await CollectSealedService.collectSealed(
        api: api,
        keychain: kc,
        capability: () => true,
        msgUnsupported: 'u',
        msgRotating: 'r',
        userId: uid,
        kind: 1,
        kindId: kid,
        source: 'tester',
        info: info,
        findLocal: (_) async => null,
        onSaved: (row) async => savedRows.add(row),
      );
      expect(out.status, CollectCreateStatus.ok);
      expect(out.generation, 1);
      expect(api.addCalls, 1);
      expect(api.keyVersion, 1);
      expect(api.attach, isEmpty);

      final row = savedRows.single;
      expect(row['generation'], 1);
      expect(row['key_version'], 1);
      expect(row['info'], isNot(equals(jsonEncode(info)))); // 密文非明文

      // 自家客户端能解：行可见列表 == payload 内嵌声明（§8.2 双核对②）
      final decoded = await CollectSealedService.decodeSealedRow(
        keychain: kc,
        userId: uid,
        row: {
          'kind': 1,
          'kind_id': kid,
          'generation': 1,
          'key_version': 1,
          'info': row['info'],
          'attach_file_hash256': '',
        },
      );
      expect(decoded.payload['payload']['text'], '你好收藏');
      expect(decoded.sealGeneration, 1);
    });

    test('视频收藏：thumb+video 双哈希声明（服务端 kind4 [Attach1,Attach2] 同口径）', () async {
      final api = _FakeCollectApi();
      final info = {
        'msg_type': 'video',
        'payload': {
          'thumb': {'file_hash256': 'h-thumb'},
          'video': {'md5': 'm-video'},
        },
      };
      final out = await run(
        api,
        _MemKeychain.instance,
        capability: true,
        info: info,
        kind: 4,
      );
      expect(out.status, CollectCreateStatus.ok);
      expect(api.attach, ['h-thumb', 'm-video']);
    });

    test('多图提取：file_hash256/md5 双读、无效项跳过、去重', () {
      final hashes = CollectSealedService.extractAttachHashes({
        'payload': {
          'images': [
            {'file_hash256': 'h1'},
            {'md5': 'm2'},
            {'uri': 'u'}, // 无哈希 → 跳过
            {'file_hash256': 'h1'}, // 重复 → 去重
            'not-a-map',
          ],
        },
      });
      expect(hashes, ['h1', 'm2']);
      // 无多图 → 回退 payload 顶层单附件
      expect(
        CollectSealedService.extractAttachHashes({
          'payload': {'file_hash256': 'single-h'},
        }),
        ['single-h'],
      );
      // 纯文本 → 空
      expect(
        CollectSealedService.extractAttachHashes({
          'payload': {'text': 'hi'},
        }),
        isEmpty,
      );
    });

    test('服务端 5502 冲突 → conflict，tip=服务端消息，不落本地', () async {
      final api = _FakeCollectApi()
        ..generation = 3
        ..infoSealed = 'other-device-cipher'
        ..keyVersion = 1;
      var saved = 0;
      final out = await CollectSealedService.collectSealed(
        api: api,
        keychain: _MemKeychain.instance,
        capability: () => true,
        msgUnsupported: 'u',
        msgRotating: 'r',
        userId: uid,
        kind: 1,
        kindId: kid,
        source: 's',
        info: {
          'payload': {'text': 'x'},
        },
        findLocal: (_) async => null,
        onSaved: (_) async => saved++,
      );
      expect(out.status, CollectCreateStatus.conflict);
      expect(out.tip, 'conflict');
      expect(api.addCalls, 1);
      expect(saved, 0);
    });

    test('本地已有活动 sealed 行 → already 短接（不发请求、不产新密文）', () async {
      final api = _FakeCollectApi();
      final local = UserCollectModel.fromJson({
        'kind': 1,
        'kind_id': kid,
        'generation': 2,
        'key_version': 1,
        'info': 'RUNPT0w=',
        'attach_file_hash256': '',
      });
      final out = run(
        api,
        _MemKeychain.instance,
        capability: true,
        info: {},
        local: local,
      );
      expect((await out).status, CollectCreateStatus.already);
      expect(api.addCalls, 0);
    });
  });
}
