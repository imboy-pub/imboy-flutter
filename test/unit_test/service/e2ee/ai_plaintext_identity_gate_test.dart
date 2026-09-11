// LT02-SEC-01（AI-ID=B）：AI 明文通道的共享身份门守护测试。
//
// 当前实现采用 AI-ID=B；当前决策包已建立但用户尚未选择，B 不代表已批准。
// B 语义：每个 AI 会话首次明文发送前用户显式确认；确认绑定五元组
// （deployment identity + 本机 owner uid + target uid + 对端指纹 + version）
// 本地持久化；身份或 version 变化后必须重新确认；昵称/头像/AI badge 不构成
// 确认；peerAccountType 只能用于 UI badge，不能单独授权明文。
//
// 本文件验证共享策略入口 AiPlaintextGate 的全部 fail-closed 负例与
// 有效确认正通道，以及生产谓词 shouldEncryptOutgoingPayload 经共享门的
// 接线语义。消息/附件/retry 三条出设备路径共用此唯一入口。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/ai_plaintext_gate.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 对端身份源 fake：可编程当前身份材料。
class _FakeIdentitySource implements AiPeerIdentitySource {
  _FakeIdentitySource(this.current);

  AiPeerIdentity? current;

  @override
  Future<AiPeerIdentity?> resolve(String targetUid) async => current;
}

/// 确认存储 fake：按 targetUid 存取，记录 save 次数。
class _FakeStore implements AiConfirmationStore {
  final Map<String, AiPlaintextConfirmation> byUid = {};
  int saveCount = 0;
  int deleteCount = 0;
  Future<void> Function()? onLoad;
  Future<void> Function()? onSave;

  @override
  Future<AiPlaintextConfirmation?> load({
    required String ownerUid,
    required String targetUid,
  }) async {
    await onLoad?.call();
    final rec = byUid[targetUid];
    return rec?.ownerUid == ownerUid ? rec : null;
  }

  @override
  Future<void> save(AiPlaintextConfirmation rec) async {
    byUid[rec.targetUid] = rec;
    saveCount++;
    await onSave?.call();
  }

  @override
  Future<void> delete({
    required String ownerUid,
    required String targetUid,
  }) async {
    if (byUid[targetUid]?.ownerUid == ownerUid) byUid.remove(targetUid);
    deleteCount++;
  }
}

AiPlaintextConfirmation _rec({
  String deploymentId = 'deploy-1',
  String ownerUid = 'user-1',
  String targetUid = '456',
  String fingerprint = 'fp-A',
  int version = 3,
  int confirmedAt = 1700000000000,
}) => AiPlaintextConfirmation(
  deploymentId: deploymentId,
  ownerUid: ownerUid,
  targetUid: targetUid,
  peerIdentityFingerprint: fingerprint,
  identityVersion: version,
  confirmedAt: confirmedAt,
);

void _wire({
  _FakeIdentitySource? source,
  _FakeStore? store,
  bool badge = true,
  Future<bool> Function(AiPlaintextPromptRequest req)? prompt,
}) {
  AiPlaintextGate.agentBadgeProbe = (String uid) async => badge;
  AiPlaintextGate.identitySource =
      source ??
      _FakeIdentitySource(
        const AiPeerIdentity(fingerprint: 'fp-A', version: 3),
      );
  AiPlaintextGate.confirmationStore = store ?? _FakeStore();
  AiPlaintextGate.deploymentIdResolver = () => 'deploy-1';
  AiPlaintextGate.currentUserIdResolver = () => 'user-1';
  AiPlaintextGate.promptHandler = prompt;
}

void main() {
  setUp(() {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
  });

  tearDown(() {
    AiPlaintextGate.debugReset();
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  group('AiPlaintextGate — fail-closed 负例矩阵（LT02-SEC-01 A03）', () {
    test('确认缺失 + agent 徽章 + 非交互 → fail-closed（不授权明文）', () async {
      _wire(store: _FakeStore());
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('uid 不匹配：记录属于其他 target → fail-closed', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(targetUid: '999');
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('version 回退（记录 4 > 当前 3）→ fail-closed，必须重新确认', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(version: 4);
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('version 前跳（记录 2 < 当前 3，身份已升级）→ fail-closed', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(version: 2);
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('指纹变化（对端身份更换）→ fail-closed', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(fingerprint: 'fp-old');
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('deployment identity 不匹配 → fail-closed', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(deploymentId: 'deploy-0');
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('任一 seam 显式 null（未接线）→ fail-closed', () async {
      // 真 null 分支覆盖（review CONCERN-b）：逐个 seam 置 null 验证
      // 门自身的未接线 fail-closed 判定，而非依赖 debugReset 的生产默认。
      AiPlaintextGate.agentBadgeProbe = (uid) async => true;
      AiPlaintextGate.identitySource = _FakeIdentitySource(
        const AiPeerIdentity(fingerprint: 'fp-A', version: 3),
      );
      AiPlaintextGate.confirmationStore = _FakeStore();
      AiPlaintextGate.deploymentIdResolver = () => 'deploy-1';
      AiPlaintextGate.currentUserIdResolver = () => 'user-1';

      AiPlaintextGate.confirmationStore = null;
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );

      AiPlaintextGate.confirmationStore = _FakeStore();
      AiPlaintextGate.identitySource = null;
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );

      AiPlaintextGate.identitySource = _FakeIdentitySource(
        const AiPeerIdentity(fingerprint: 'fp-A', version: 3),
      );
      AiPlaintextGate.deploymentIdResolver = null;
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );

      AiPlaintextGate.deploymentIdResolver = () => 'deploy-1';
      AiPlaintextGate.currentUserIdResolver = null;
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('debugReset 恢复生产默认接线：无确认记录 → fail-closed（非 null 语义）', () async {
      // review CONCERN-b 对齐：debugReset 恢复的是**生产默认接线**
      // （探针/身份源/存储/部署解析器），不是 null。本用例锁定该语义：
      // 生产接线下徽章探针因单测环境无 DB 而异常 → 门按无徽章 fail-closed。
      AiPlaintextGate.debugReset();
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('对端身份材料解析不到 → fail-closed', () async {
      _wire(source: _FakeIdentitySource(null));
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('非 agent 徽章（badge≠1）→ 一律 false（徽章只进 UI，不授权明文）', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(); // 即使存在完全匹配的记录
      _wire(store: store, badge: false);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('C2G 不适用 AI 明文门（群走独立 Megolm 强制门）', () async {
      final store = _FakeStore();
      store.byUid['g1'] = _rec(targetUid: 'g1');
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2G',
          toId: 'g1',
        ),
        isFalse,
      );
    });

    test('非交互语境（retry）即使注册了弹窗也不弹、不放行', () async {
      var promptCalls = 0;
      _wire(
        prompt: (req) async {
          promptCalls++;
          return true;
        },
      );
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: false,
        ),
        isFalse,
      );
      expect(promptCalls, 0);
    });
  });

  group('AiPlaintextGate — 有效确认正通道（LT02-SEC-01 A02）', () {
    test('五元组全部匹配 + agent 徽章 → 放行明文通道', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec();
      _wire(store: store);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isTrue,
      );
    });

    test('确认有效时不弹窗（昵称/头像/AI badge 变化不构成重新确认）', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec();
      var promptCalls = 0;
      _wire(
        store: store,
        prompt: (req) async {
          promptCalls++;
          return true;
        },
      );
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isTrue,
      );
      expect(promptCalls, 0);
    });

    test('已有确认读取期间本机账号变化 → fail-closed', () async {
      var ownerUid = 'user-1';
      final store = _FakeStore();
      store.byUid['456'] = _rec();
      store.onLoad = () async {
        ownerUid = 'user-2';
      };
      _wire(store: store);
      AiPlaintextGate.currentUserIdResolver = () => ownerUid;

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
    });

    test('交互式首次确认：用户确认 → 落库五元组并放行', () async {
      final store = _FakeStore();
      _wire(store: store, prompt: (req) async => true);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isTrue,
      );
      expect(store.saveCount, 1);
      final rec = store.byUid['456'];
      expect(rec, isNotNull);
      expect(rec!.deploymentId, 'deploy-1');
      expect(rec.ownerUid, 'user-1');
      expect(rec.targetUid, '456');
      expect(rec.peerIdentityFingerprint, 'fp-A');
      expect(rec.identityVersion, 3);
    });

    test('交互式首次确认：用户拒绝 → 不落库、不放行', () async {
      final store = _FakeStore();
      _wire(store: store, prompt: (req) async => false);
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 0);
    });

    test('确认弹窗期间 agent 徽章撤销 → 不落库、不放行', () async {
      final store = _FakeStore();
      var badge = true;
      _wire(
        store: store,
        prompt: (req) async {
          badge = false;
          return true;
        },
      );
      AiPlaintextGate.agentBadgeProbe = (uid) async => badge;

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 0);
    });

    test('确认弹窗期间 deployment 变化 → 不落库、不放行', () async {
      final store = _FakeStore();
      var deploymentId = 'deploy-1';
      _wire(
        store: store,
        prompt: (req) async {
          deploymentId = 'deploy-2';
          return true;
        },
      );
      AiPlaintextGate.deploymentIdResolver = () => deploymentId;

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 0);
    });

    test('确认弹窗期间本机账号变化 → 不落库、不放行', () async {
      final store = _FakeStore();
      var ownerUid = 'user-1';
      _wire(
        store: store,
        prompt: (req) async {
          ownerUid = 'user-2';
          return true;
        },
      );
      AiPlaintextGate.currentUserIdResolver = () => ownerUid;

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 0);
    });

    test('确认弹窗期间 identity 变化 → 不落库、不放行', () async {
      final store = _FakeStore();
      final source = _FakeIdentitySource(
        const AiPeerIdentity(fingerprint: 'fp-A', version: 3),
      );
      _wire(
        source: source,
        store: store,
        prompt: (req) async {
          source.current = const AiPeerIdentity(
            fingerprint: 'fp-B',
            version: 4,
          );
          return true;
        },
      );

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 0);
    });

    test('确认记录保存期间 identity 变化 → 撤销记录、不放行', () async {
      final source = _FakeIdentitySource(
        const AiPeerIdentity(fingerprint: 'fp-A', version: 3),
      );
      final store = _FakeStore();
      store.onSave = () async {
        source.current = const AiPeerIdentity(fingerprint: 'fp-B', version: 4);
      };
      _wire(source: source, store: store, prompt: (req) async => true);

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 1);
      expect(store.deleteCount, 1);
      expect(store.byUid['456'], isNull);
    });

    test('确认记录保存期间本机账号变化 → 撤销原账号记录、不放行', () async {
      final store = _FakeStore();
      var ownerUid = 'user-1';
      store.onSave = () async {
        ownerUid = 'user-2';
      };
      _wire(store: store, prompt: (req) async => true);
      AiPlaintextGate.currentUserIdResolver = () => ownerUid;

      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isFalse,
      );
      expect(store.saveCount, 1);
      expect(store.deleteCount, 1);
      expect(store.byUid['456'], isNull);
    });

    test('身份变化后必须重新确认：旧确认失效，重新确认绑定新指纹', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec(fingerprint: 'fp-old');
      _wire(
        store: store,
        prompt: (req) async {
          // 弹窗必须展示当前（新）指纹对应的请求
          expect(req.peerIdentityFingerprint, 'fp-A');
          return true;
        },
      );
      // 非交互：旧确认对新身份失效
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
        ),
        isFalse,
      );
      // 交互：重新确认后按新身份落库放行
      expect(
        await AiPlaintextGate.plaintextChannelAuthorized(
          chatType: 'C2C',
          toId: '456',
          interactive: true,
        ),
        isTrue,
      );
      expect(store.byUid['456']!.peerIdentityFingerprint, 'fp-A');
    });
  });

  group('生产谓词 shouldEncryptOutgoingPayload 经共享门（三路径单一来源）', () {
    test('strict + agent 徽章 + 无有效确认 → true（仍走 E2EE / 拒发）', () async {
      _wire(store: _FakeStore());
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
      );
    });

    test('strict + agent 徽章 + 有效确认 → false（明文通道放行）', () async {
      final store = _FakeStore();
      store.byUid['456'] = _rec();
      _wire(store: store);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isFalse,
      );
    });

    test('strict + 真人对端（badge=0）→ true（真人会话不受 AI 门影响）', () async {
      _wire(store: _FakeStore(), badge: false);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
      );
    });

    test('明文部署 + C2C（无 toId）→ false（部署级明文，与 AI 门无关）', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      expect(await E2EEService.shouldEncryptOutgoingPayload('C2C'), isFalse);
    });

    test(
      '策略未初始化 + C2C → 抛 policy_not_initialized（豁免不再先于 PolicyGate）',
      () async {
        EncryptionModeService.debugSet(
          mode: EncryptionMode.plaintext,
          initialized: false,
        );
        expect(
          () => E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
          throwsA(
            isA<E2eeSecurityException>().having(
              (e) => e.reason,
              'reason',
              'policy_not_initialized',
            ),
          ),
        );
      },
    );
  });

  group('SqliteAiPlaintextConfirmationStore — 本地持久化（schema 纪律）', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
    });

    tearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });

    test('ensureSchema 幂等建表；save/load 五元组往返一致', () async {
      final store = SqliteAiPlaintextConfirmationStore();
      await store.ensureSchema();
      await store.ensureSchema(); // 幂等

      await store.save(
        const AiPlaintextConfirmation(
          deploymentId: 'deploy-1',
          ownerUid: 'user-1',
          targetUid: '456',
          peerIdentityFingerprint: 'fp-A',
          identityVersion: 3,
          confirmedAt: 1700000000001,
        ),
      );
      final loaded = await store.load(ownerUid: 'user-1', targetUid: '456');
      expect(loaded, isNotNull);
      expect(loaded!.deploymentId, 'deploy-1');
      expect(loaded.targetUid, '456');
      expect(loaded.peerIdentityFingerprint, 'fp-A');
      expect(loaded.identityVersion, 3);
      expect(loaded.confirmedAt, 1700000000001);
    });

    test('load 其他 uid → null；save 覆盖旧记录（upsert）', () async {
      final store = SqliteAiPlaintextConfirmationStore();
      await store.ensureSchema();

      expect(await store.load(ownerUid: 'user-1', targetUid: 'nope'), isNull);

      await store.save(_rec(fingerprint: 'fp-1'));
      await store.save(_rec(fingerprint: 'fp-2'));
      final loaded = await store.load(ownerUid: 'user-1', targetUid: '456');
      expect(loaded!.peerIdentityFingerprint, 'fp-2');
    });

    test('delete 撤销当前账号的目标确认', () async {
      final store = SqliteAiPlaintextConfirmationStore();
      await store.save(_rec());

      await store.delete(ownerUid: 'user-1', targetUid: '456');

      expect(await store.load(ownerUid: 'user-1', targetUid: '456'), isNull);
    });

    test('C1 懒初始化：不经 ensureSchema，写入→重开 store→读回一致', () async {
      // review C1 回归证明：生产路径不（需要）有人先调 ensureSchema——
      // 首次 save/load 自动建表。两个全新实例模拟「写入后重开 store」。
      final writer = SqliteAiPlaintextConfirmationStore();
      await writer.save(_rec(confirmedAt: 1700000000002));

      final reopened = SqliteAiPlaintextConfirmationStore();
      final loaded = await reopened.load(ownerUid: 'user-1', targetUid: '456');
      expect(loaded, isNotNull);
      expect(loaded!.deploymentId, 'deploy-1');
      expect(loaded.targetUid, '456');
      expect(loaded.peerIdentityFingerprint, 'fp-A');
      expect(loaded.identityVersion, 3);
      expect(loaded.confirmedAt, 1700000000002);
    });
  });
}
