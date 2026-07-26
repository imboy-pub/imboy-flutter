/// S9: Olm Double Ratchet PFS/PCS 守护（ADR 08 T5）— TDD 测试
///
/// 用原生 vodozemac 双 Account 建立真实 Olm 会话，验证：
/// - **PFS（前向保密）**：旧（已被攻陷/快照）的 session 状态无法解密后续 ratchet
///   世代的消息——DH 私钥随 ratchet 推进被销毁。
/// - **PCS（崩溃后安全）**：会话状态被攻陷后，一旦发生一次新的 DH ratchet 步骤
///   （引入攻陷者没有的新熵），攻陷者即失去读取后续消息的能力。
///
/// 这两项此前标记 `skip: 真机/vodozemac 运行时`。本文件证明 vodozemac FFI 在
/// `flutter test` 宿主运行时即可驱动 Olm 会话，故落地为可在 CI 跑的守护测试。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// spike 已构建的 vodozemac 宿主动态库（同 group_session_service_test.dart）
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

/// vod.init 全进程只能调一次（RustLib 重复初始化会抛错）
bool _vodInited = false;
Future<void> _ensureVod() async {
  if (_vodInited) return;
  await vod.init(libraryPath: _spikeLibDir);
  _vodInited = true;
}

/// 测试用 pickle 加密密钥（32 字节，仅测试）。
final _pickleKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

/// 一对已建立会话的双端 Olm 上下文。
class _Pair {
  _Pair(this.alice, this.bob, this.aliceSession, this.bobSession);
  final vod.Account alice;
  final vod.Account bob;
  vod.Session aliceSession;
  vod.Session bobSession;
}

/// 建立 Alice→Bob 的 Olm 会话，并完成首次 prekey 消息往返。
_Pair _establish() {
  final alice = vod.Account();
  final bob = vod.Account();

  // Bob 生成一次性 prekey
  bob.generateOneTimeKeys(1);
  final bobOtk = bob.oneTimeKeys.values.first;
  final bobIdentity = bob.identityKeys.curve25519;

  // Alice 用 Bob identity + OTK 建出站会话
  final aliceSession = alice.createOutboundSession(
    identityKey: bobIdentity,
    oneTimeKey: bobOtk,
  );

  // Alice 加密首条 prekey 消息（messageType=0）
  final first = aliceSession.encrypt('hello-bob');
  expect(first.messageType, equals(0));

  // Bob 用 Alice 的 prekey 密文建入站会话
  final inbound = bob.createInboundSession(
    theirIdentityKey: alice.identityKeys.curve25519,
    preKeyMessageBase64: first.ciphertext,
  );
  expect(inbound.plaintext, equals('hello-bob'));
  bob.markKeysAsPublished();

  return _Pair(alice, bob, aliceSession, inbound.session);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _ensureVod();
  });

  group('vodozemac Olm 运行时可用性', () {
    test('双 Account 可建立会话并往返加解密', () {
      final p = _establish();

      // 正常往返：Alice→Bob
      final m = p.aliceSession.encrypt('msg-1');
      final pt = p.bobSession.decrypt(
        messageType: m.messageType,
        ciphertext: m.ciphertext,
      );
      expect(pt, equals('msg-1'));
    });
  });

  group('olm_pfs_old_session_cannot_decrypt (T5)', () {
    test('旧 session 快照无法解密后续 DH ratchet 世代消息', () {
      final p = _establish();

      // Alice→Bob 一条，推进对称链
      var m = p.aliceSession.encrypt('m1');
      p.bobSession.decrypt(
        messageType: m.messageType,
        ciphertext: m.ciphertext,
      );

      // 快照当前 Bob 状态（攻陷点）——此时 Bob 持有初始 DH 密钥对
      final oldPickle = p.bobSession.toPickleEncrypted(_pickleKey);

      // 关键：Bob 回复 → 触发 Bob 侧新 DH ratchet 步骤（生成新 DH 密钥对）
      final reply = p.bobSession.encrypt('bob-reply');
      p.aliceSession.decrypt(
        messageType: reply.messageType,
        ciphertext: reply.ciphertext,
      );

      // Alice 收到回复后再发 → Alice 也生成新 DH 密钥对，进入新 ratchet 世代
      // 新 root key = KDF(old_root, DH(alice_new_priv, bob_new_pub))
      // 旧快照只有 bob_old_priv，无法计算此 root key
      final newMsg = p.aliceSession.encrypt('secret-after-compromise');

      // 验证当前 Bob 可正常解密（sanity check）
      final ok = p.bobSession.decrypt(
        messageType: newMsg.messageType,
        ciphertext: newMsg.ciphertext,
      );
      expect(ok, equals('secret-after-compromise'));

      // 用旧快照 S_old 尝试解密新世代消息 → 必须失败（前向保密）
      final oldSession = vod.Session.fromPickleEncrypted(
        pickle: oldPickle,
        pickleKey: _pickleKey,
      );
      expect(
        () => oldSession.decrypt(
          messageType: newMsg.messageType,
          ciphertext: newMsg.ciphertext,
        ),
        throwsA(anything),
        reason: '旧 session 状态不得解密后续 DH ratchet 世代消息',
      );
    });
  });

  group('olm_pcs_recovery (T5)', () {
    test('攻陷后一次新 DH ratchet 即愈合，攻陷者失去后续读取能力', () {
      final p = _establish();

      // 攻陷者快照 Bob 当前状态
      final compromisedPickle = p.bobSession.toPickleEncrypted(_pickleKey);

      // 愈合：Alice 发新消息触发 Bob 新 DH ratchet 步骤（引入攻陷者没有的熵）
      final heal1 = p.aliceSession.encrypt('heal-1');
      p.bobSession.decrypt(
        messageType: heal1.messageType,
        ciphertext: heal1.ciphertext,
      );
      // Bob 回复 → Alice 侧也 ratchet，双向愈合
      final reply = p.bobSession.encrypt('heal-reply');
      p.aliceSession.decrypt(
        messageType: reply.messageType,
        ciphertext: reply.ciphertext,
      );
      // 再来一轮 Alice→Bob，确保进入攻陷者无法到达的 ratchet 世代
      final heal2 = p.aliceSession.encrypt('heal-2');
      p.bobSession.decrypt(
        messageType: heal2.messageType,
        ciphertext: heal2.ciphertext,
      );

      // 愈合后的新消息
      final futureMsg = p.aliceSession.encrypt('future-secret');

      // 攻陷者用旧快照尝试解密愈合后的消息 → 必须失败（PCS）
      final compromised = vod.Session.fromPickleEncrypted(
        pickle: compromisedPickle,
        pickleKey: _pickleKey,
      );
      expect(
        () => compromised.decrypt(
          messageType: futureMsg.messageType,
          ciphertext: futureMsg.ciphertext,
        ),
        throwsA(anything),
        reason: '攻陷状态在新 DH ratchet 后不得读取后续消息',
      );
    });
  });
}
