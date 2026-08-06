/// E2EE-030 — PFS（前向保密）穿过**生产持久化路径**的守护测试。
///
/// 与 `olm_ratchet_pfs_pcs_test.dart` 的区别：后者在裸 vodozemac 层证明**算法**
/// 具备 PFS；本文件证明 IMBoy 的**生产路径**（`OlmSessionService` + 事务性
/// `CryptoStore` 持久化 + 进程重启）不会把 PFS 破坏掉。
///
/// 对应不变量（ADR 14 §4.2）：
/// - 6：同一活跃发送 ratchet 不得在两处并行/回滚使用；
/// - 7：密码学状态更新要么原子提交，要么全部回滚——不得「密文已产出但 ratchet
///   状态未持久化」。
///
/// 威胁映射：ADR 14 §5.1 T5（单设备短期攻陷后恢复）、T9（崩溃/并发导致状态分叉）。
///
/// 测试全程使用真实 vodozemac（无 mock 密码学库）与真实 SQLite（ffi in-memory），
/// 只 mock `flutter_secure_storage` 平台通道（宿主机无 Keychain/Keystore）。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';

/// spike 已构建的 vodozemac 宿主动态库（同 olm_ratchet_pfs_pcs_test.dart）
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

const String _peerUid = '9001';
const String _peerDid = 'dev-alice';

/// 与 OlmSessionService `_pickleKeyStorageKey` 一致
const String _pickleKeyStorageKey = 'olm_pickle_key';

/// 与 OlmSessionService `_sessionPicklePrefix` 一致
const String _sessionPicklePrefix = 'olm_session_';

/// 测试用 pickle 主钥（32 字节，仅测试；预置进 mock secure storage 后
/// OlmSessionService 会读取同一把钥匙，从而能加载我们播种的 session）
final Uint8List _pickleKey = Uint8List.fromList(
  List<int>.generate(32, (i) => (i * 7 + 3) % 256),
);

bool _vodInited = false;
Future<void> _ensureVod() async {
  if (_vodInited) return;
  await vod.init(libraryPath: _spikeLibDir);
  _vodInited = true;
}

/// 对端（Alice）视角的会话句柄。本机（Bob）侧的会话由 OlmSessionService 持有。
class _Peer {
  _Peer(this.account, this.session);
  final vod.Account account;
  final vod.Session session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};

  late Database db;
  late CryptoStore store;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'write':
              if (key != null) secureStore[key] = args?['value'] as String?;
              return null;
            case 'read':
              return key == null ? null : secureStore[key];
            case 'delete':
              secureStore.remove(key);
              return null;
            case 'containsKey':
              return key != null && secureStore.containsKey(key);
            case 'readAll':
              return Map<String, String>.fromEntries(
                secureStore.entries
                    .where((e) => e.value != null)
                    .map((e) => MapEntry(e.key, e.value!)),
              );
            case 'deleteAll':
              secureStore.clear();
              return null;
            default:
              return null;
          }
        });

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await _ensureVod();
    // 生产路径的 fvod.init() 在宿主机无 Flutter plugin；已由 vod.init 完成初始化
    OlmSessionService.debugMarkVodReady();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  setUp(() async {
    secureStore
      ..clear()
      ..[_pickleKeyStorageKey] = base64.encode(_pickleKey);
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    OlmSessionService.to.resetForTest();
    store = CryptoStore(db);
    await store.ensureSchema();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    OlmSessionService.to.resetForTest();
    await db.close();
  });

  /// 建立 Alice(对端) ↔ Bob(本机) 的 Olm 会话，把 **Bob 侧 session pickle 播种进
  /// 生产 CryptoStore**，使 OlmSessionService 后续走真实加载/持久化路径
  /// （不触网：不需要 claim prekey / getIdentity）。
  ///
  /// 返回后双方均已可用 type=1 普通消息通信。
  Future<_Peer> seedEstablishedPair() async {
    final alice = vod.Account();
    final bobBootstrap = vod.Account();

    bobBootstrap.generateOneTimeKeys(1);
    final aliceSession = alice.createOutboundSession(
      identityKey: bobBootstrap.identityKeys.curve25519,
      oneTimeKey: bobBootstrap.oneTimeKeys.values.first,
    );

    final bootstrap = aliceSession.encrypt('bootstrap');
    expect(bootstrap.messageType, equals(0));
    final inbound = bobBootstrap.createInboundSession(
      theirIdentityKey: alice.identityKeys.curve25519,
      preKeyMessageBase64: bootstrap.ciphertext,
    );
    expect(inbound.plaintext, equals('bootstrap'));

    // 播种 Bob 侧 ratchet 状态到生产事务存储
    await store.persistSession(
      peerUid: _peerUid,
      peerDeviceId: _peerDid,
      pickle: inbound.session.toPickleEncrypted(_pickleKey),
    );

    final peer = _Peer(alice, aliceSession);

    // Bob 经生产路径回复一次 → Alice 侧会话确立，其后续消息为 type=1，
    // 从而入站解密不需要 `_lookupPeerIdentityKey`（不触网）。
    final reply = await OlmSessionService.to.encryptC2CMessage(
      peerUid: _peerUid,
      peerDeviceId: _peerDid,
      plaintext: 'bob-hello',
    );
    expect(
      peer.session.decrypt(
        messageType: reply.messageType,
        ciphertext: reply.ciphertext,
      ),
      equals('bob-hello'),
    );
    return peer;
  }

  Future<String> bobDecrypt(
    _Peer peer,
    String plaintext,
    String messageId,
  ) async {
    final m = peer.session.encrypt(plaintext);
    expect(
      m.messageType,
      equals(1),
      reason: '会话已确立后对端应发 normal message（type=1），否则会触发查身份网络请求',
    );
    return OlmSessionService.to.decryptC2CMessage(
      peerUid: _peerUid,
      peerDeviceId: _peerDid,
      messageType: m.messageType,
      ciphertext: m.ciphertext,
      messageId: messageId,
    );
  }

  // E2EE-025：`ensureSessionId` 是修复 `session_ref` 恒空的基石——
  // 它必须返回**随后 encrypt 实际使用的那个** session 的 id，否则写进
  // protected_header 的 session_ref 与 protocol_metadata.session_id 不符，
  // 接收侧 `_validateContextBinding` §7 会拒收整条消息。
  // 用真实 vodozemac + 真实 CryptoStore 守护该一致性。
  group('E2EE-025 ensureSessionId 与 encrypt 的会话一致性', () {
    test('ensureSessionId 返回值必须等于随后 encryptC2CMessage 的 sessionId', () async {
      await seedEstablishedPair();

      final ensured = await OlmSessionService.to.ensureSessionId(
        _peerUid,
        _peerDid,
      );
      expect(ensured, isNotEmpty, reason: 'ADR 15 §3.1: session_ref 必须非空');

      final encrypted = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'session-ref-consistency',
      );
      expect(
        encrypted.sessionId,
        equals(ensured),
        reason: '不一致会让每条消息被判 context_mismatch_session_id',
      );
    });

    test('连续多次 ensureSessionId 必须稳定返回同一 id（不得每次新建会话）', () async {
      await seedEstablishedPair();

      final first = await OlmSessionService.to.ensureSessionId(
        _peerUid,
        _peerDid,
      );
      final second = await OlmSessionService.to.ensureSessionId(
        _peerUid,
        _peerDid,
      );
      final third = await OlmSessionService.to.ensureSessionId(
        _peerUid,
        _peerDid,
      );

      expect(second, equals(first));
      expect(third, equals(first));
    });

    test('ensureSessionId 后 ratchet 仍可正常推进（未破坏会话状态）', () async {
      final peer = await seedEstablishedPair();

      await OlmSessionService.to.ensureSessionId(_peerUid, _peerDid);

      // 出站仍可用
      final out = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'after-ensure',
      );
      expect(
        peer.session.decrypt(
          messageType: out.messageType,
          ciphertext: out.ciphertext,
        ),
        equals('after-ensure'),
      );

      // 入站仍可用
      expect(
        await bobDecrypt(peer, 'inbound-after-ensure', 'mid-ensure'),
        equals('inbound-after-ensure'),
      );
    });
  });

  group('E2EE-030 PFS through production path (T5)', () {
    test('生产 CryptoStore 中的 at-rest ratchet 快照无法解密后续世代消息', () async {
      final peer = await seedEstablishedPair();

      // 攻陷点：攻击者拿到此刻生产存储里的 ratchet 状态（DB 被拖库/取证）
      final compromised = await store.loadSession(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
      );
      expect(compromised, isNotNull);

      // 生产路径继续推进（含 Bob 侧新的 DH ratchet 步）
      expect(await bobDecrypt(peer, 'a1', 'mid-a1'), equals('a1'));
      final r2 = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'bob-2',
      );
      peer.session.decrypt(
        messageType: r2.messageType,
        ciphertext: r2.ciphertext,
      );
      expect(await bobDecrypt(peer, 'a2', 'mid-a2'), equals('a2'));

      // 愈合后的新消息：当前生产会话可读
      final post = peer.session.encrypt('post-compromise-secret');
      expect(
        await OlmSessionService.to.decryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          messageType: post.messageType,
          ciphertext: post.ciphertext,
          messageId: 'mid-post',
        ),
        equals('post-compromise-secret'),
      );

      // 攻陷快照不可读 → 生产持久化路径未破坏 PFS
      final stale = vod.Session.fromPickleEncrypted(
        pickle: compromised!,
        pickleKey: _pickleKey,
      );
      expect(
        () => stale.decrypt(
          messageType: post.messageType,
          ciphertext: post.ciphertext,
        ),
        throwsA(anything),
        reason: '生产存储的旧 ratchet 快照不得解密后续 DH 世代消息',
      );
    });
  });

  group('E2EE-030 no ratchet rollback (ADR 14 §4.2 inv.6/7, T9)', () {
    test('CryptoStore 不可用时发送侧必须 fail-closed，不得只写 SecureStorage', () async {
      final peer = await seedEstablishedPair();
      final committed = await store.loadSession(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
      );
      expect(committed, isNotNull);

      // 事务存储不可用（SQLCipher 打不开 / 迁移中 / 磁盘故障）
      SqliteService.setDbForTest(null);
      OlmSessionService.to.resetForTest();

      await expectLater(
        OlmSessionService.to.encryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          plaintext: 'must-not-advance',
        ),
        throwsA(isA<OlmStateCommitException>()),
        reason: '无法原子提交 ratchet 时必须拒绝加密，不得静默降级到非事务存储',
      );

      // DB 恢复 + 进程重启
      SqliteService.setDbForTest(db);
      OlmSessionService.to.resetForTest();
      expect(
        await store.loadSession(peerUid: _peerUid, peerDeviceId: _peerDid),
        equals(committed),
        reason: '不可提交期间 ratchet 状态不得发生任何变化',
      );

      final after = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'after-outage',
      );
      expect(
        peer.session.decrypt(
          messageType: after.messageType,
          ciphertext: after.ciphertext,
        ),
        equals('after-outage'),
      );
    });

    test('DB 不可用窗口 + 进程重启不得回滚 ratchet 并重用已消费 message key', () async {
      final peer = await seedEstablishedPair();

      final m1 = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'm1',
      );
      expect(
        peer.session.decrypt(
          messageType: m1.messageType,
          ciphertext: m1.ciphertext,
        ),
        equals('m1'),
      );

      // DB 不可用窗口：若生产在此仍允许加密（fail-open），密文会被真实投递给对端，
      // 对端消费掉该 ratchet 索引的 message key，而状态只留在非事务存储。
      SqliteService.setDbForTest(null);
      OlmSessionService.to.resetForTest();
      try {
        final m2 = await OlmSessionService.to.encryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          plaintext: 'm2',
        );
        peer.session.decrypt(
          messageType: m2.messageType,
          ciphertext: m2.ciphertext,
        );
      } on OlmStateCommitException {
        // 期望路径：fail-closed，对端未消费任何 message key
      }

      // DB 恢复 + 进程重启（内存态清空，只能依赖持久化状态）
      SqliteService.setDbForTest(db);
      OlmSessionService.to.resetForTest();

      final m3 = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'm3',
      );
      expect(
        peer.session.decrypt(
          messageType: m3.messageType,
          ciphertext: m3.ciphertext,
        ),
        equals('m3'),
        reason: 'ratchet 回滚会用已消费的 message key 重新加密，对端将无法解密（key reuse）',
      );
    });

    test('CryptoStore 不可用时接收侧必须 fail-closed，消息恢复后仍可解密且只提交一次', () async {
      final peer = await seedEstablishedPair();
      final inbound = peer.session.encrypt('inbound-during-outage');
      expect(inbound.messageType, equals(1));

      SqliteService.setDbForTest(null);
      OlmSessionService.to.resetForTest();

      await expectLater(
        OlmSessionService.to.decryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          messageType: inbound.messageType,
          ciphertext: inbound.ciphertext,
          messageId: 'mid-outage',
        ),
        throwsA(isA<OlmStateCommitException>()),
        reason: '无法原子提交 dedupe + ratchet 时必须拒收，不得先展示后补状态',
      );

      // DB 恢复：同一条消息仍可解密（未丢失），且 dedupe 生效
      SqliteService.setDbForTest(db);
      OlmSessionService.to.resetForTest();
      expect(
        await OlmSessionService.to.decryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          messageType: inbound.messageType,
          ciphertext: inbound.ciphertext,
          messageId: 'mid-outage',
        ),
        equals('inbound-during-outage'),
      );
      await expectLater(
        OlmSessionService.to.decryptC2CMessage(
          peerUid: _peerUid,
          peerDeviceId: _peerDid,
          messageType: inbound.messageType,
          ciphertext: inbound.ciphertext,
          messageId: 'mid-outage',
        ),
        throwsA(isA<DuplicateMessageException>()),
      );
    });
  });

  group('E2EE-030 legacy SecureStorage session 只读导入', () {
    test('CryptoStore 无记录时导入 legacy pickle 并清除明面副本，不长期双写', () async {
      final alice = vod.Account();
      final bobBootstrap = vod.Account();
      bobBootstrap.generateOneTimeKeys(1);
      final aliceSession = alice.createOutboundSession(
        identityKey: bobBootstrap.identityKeys.curve25519,
        oneTimeKey: bobBootstrap.oneTimeKeys.values.first,
      );
      final bootstrap = aliceSession.encrypt('bootstrap');
      final inbound = bobBootstrap.createInboundSession(
        theirIdentityKey: alice.identityKeys.curve25519,
        preKeyMessageBase64: bootstrap.ciphertext,
      );

      // 仅存在 legacy SecureStorage 副本（升级前版本写入），CryptoStore 无记录
      final legacyKey = '$_sessionPicklePrefix$_peerUid:$_peerDid';
      secureStore[legacyKey] = inbound.session.toPickleEncrypted(_pickleKey);
      expect(
        await store.loadSession(peerUid: _peerUid, peerDeviceId: _peerDid),
        isNull,
      );

      final reply = await OlmSessionService.to.encryptC2CMessage(
        peerUid: _peerUid,
        peerDeviceId: _peerDid,
        plaintext: 'from-legacy-session',
      );
      expect(
        aliceSession.decrypt(
          messageType: reply.messageType,
          ciphertext: reply.ciphertext,
        ),
        equals('from-legacy-session'),
        reason: 'legacy 会话必须能被导入续用，升级不得丢会话',
      );

      expect(
        await store.loadSession(peerUid: _peerUid, peerDeviceId: _peerDid),
        isNotNull,
        reason: '导入后事务存储成为唯一权威副本',
      );
      expect(
        secureStore[legacyKey],
        isNull,
        reason: 'legacy 副本必须删除，否则 DB 与 SecureStorage 两份状态会分叉回滚',
      );
    });
  });
}
