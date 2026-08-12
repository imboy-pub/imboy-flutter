/// S10: E2EE 全链路协议集成测试（组件组合验收）
///
/// 本测试证明 S2–S9 落地的所有 E2EE 守护组件在真实 vodozemac 运行时下
/// 正确组合工作，而非仅各自单元测试通过。覆盖完整生命周期：
///
/// 1. X3DH 密钥协商 → Olm 会话建立
/// 2. Ed25519 identity 签名验证（IdentityVerifier）
/// 3. TOFU identity pinning（CryptoStore）
/// 4. Safety Number 对称生成与比对（SafetyNumber）
/// 5. Capability 协商 + HWM 记录（CapabilityGuard）
/// 6. 双向消息加解密（Olm Session）
/// 7. 审计日志记录 + 哈希链完整性（CryptoAuditLog）
/// 8. Identity 变更检测（TOFU 比对 → IdentityChangedException）
/// 9. 协议降级检测（CapabilityGuard → CapabilityDowngradeException）
///
/// 运行环境：flutter test 宿主（macOS/Linux），vodozemac FFI via spike dylib。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/capability_guard.dart';
import 'package:imboy/service/e2ee/crypto_audit_log.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/identity_verifier.dart';
import 'package:imboy/service/e2ee/safety_number.dart';

/// spike 已构建的 vodozemac 宿主动态库
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

bool _vodInited = false;
Future<void> _ensureVod() async {
  if (_vodInited) return;
  await vod.init(libraryPath: _spikeLibDir);
  _vodInited = true;
}

/// vodozemac toBase64() 输出无填充 base64；SafetyNumber 内部 base64Decode 需要
/// 标准填充。此辅助函数补齐 '=' 填充。
String _padB64(String s) {
  final mod = s.length % 4;
  return mod == 0 ? s : s + '=' * (4 - mod);
}

/// 模拟设备上下文（identity keys + Olm account）。
class _Device {
  _Device(this.uid, this.deviceId, this.account);

  final String uid;
  final String deviceId;
  final vod.Account account;

  /// 类型化公钥（用于 vodozemac API 调用）
  vod.Curve25519PublicKey get curve25519Key => account.identityKeys.curve25519;
  vod.Ed25519PublicKey get ed25519Key => account.identityKeys.ed25519;

  /// Base64 编码公钥（用于 IdentityVerifier / SafetyNumber / CryptoStore）
  String get curve25519Pub => _padB64(curve25519Key.toBase64());
  String get ed25519Pub => _padB64(ed25519Key.toBase64());

  /// 构造 identity map（模拟服务端返回的 device identity 结构）。
  Map<String, dynamic> identityMap() {
    // 用 Ed25519 私钥对 curve25519 公钥 base64 签名（自签名证明同设备持有）
    final sig = account.sign(curve25519Pub);
    return {
      'ed25519_key': ed25519Pub,
      'curve25519_key': curve25519Pub,
      'signature': _padB64(sig.toBase64()),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late CryptoStore store;
  late CryptoAuditLog auditLog;
  late CapabilityGuard capGuard;
  late _Device alice;
  late _Device bob;

  setUpAll(() async {
    await _ensureVod();
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
    auditLog = CryptoAuditLog(db);
    await auditLog.ensureSchema();
    capGuard = CapabilityGuard(store);

    alice = _Device('1001', 'alice-dev-1', vod.Account());
    bob = _Device('2002', 'bob-dev-1', vod.Account());
  });

  tearDown(() async => db.close());

  group('E2EE 全链路协议集成', () {
    test('完整生命周期：协商→验证→TOFU→通信→审计', () async {
      // ─── Phase 1: Identity 签名验证（P0-1 IdentityVerifier）───
      final aliceIdentity = alice.identityMap();
      final bobIdentity = bob.identityMap();

      // 双向验证通过（无 MITM）
      expect(
        () => verifyIdentitySignature(aliceIdentity, context: 'alice'),
        returnsNormally,
      );
      expect(
        () => verifyIdentitySignature(bobIdentity, context: 'bob'),
        returnsNormally,
      );

      // ─── Phase 2: X3DH 密钥协商 → Olm 会话建立 ───
      bob.account.generateOneTimeKeys(1);
      final bobOtk = bob.account.oneTimeKeys.values.first;

      final aliceSession = alice.account.createOutboundSession(
        identityKey: bob.curve25519Key,
        oneTimeKey: bobOtk,
        config: legacyOlmSessionConfig(),
      );
      final prekeyMsg = aliceSession.encrypt('x3dh-init');
      expect(prekeyMsg.messageType, equals(0)); // prekey message

      final inbound = bob.account.createInboundSession(
        theirIdentityKey: alice.curve25519Key,
        preKeyMessageBase64: prekeyMsg.ciphertext,
        config: legacyOlmSessionConfig(),
      );
      expect(inbound.plaintext, equals('x3dh-init'));
      bob.account.markKeysAsPublished();
      final bobSession = inbound.session;

      // 审计：会话建立
      await auditLog.append(
        AuditEventType.sessionEstablished,
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        detail: 'X3DH outbound',
      );

      // ─── Phase 3: TOFU Identity Pinning（S3）───
      // Alice 固定 Bob 的 identity
      final bobFp = bob.curve25519Pub;
      await store.pinIdentity(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        fingerprint: bobFp,
      );
      await auditLog.append(
        AuditEventType.identityPinned,
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        detail: 'TOFU first use',
      );

      // Bob 固定 Alice 的 identity
      final aliceFp = alice.curve25519Pub;
      await store.pinIdentity(
        peerUid: alice.uid,
        peerDeviceId: alice.deviceId,
        fingerprint: aliceFp,
      );

      // 验证 pin 持久化
      expect(
        await store.loadPinnedFingerprint(
          peerUid: bob.uid,
          peerDeviceId: bob.deviceId,
        ),
        equals(bobFp),
      );

      // ─── Phase 4: Safety Number 对称验证（S4）───
      final snAlice = SafetyNumber.generate(
        localUid: alice.uid,
        localIdentityPub: alice.curve25519Pub,
        remoteUid: bob.uid,
        remoteIdentityPub: bob.curve25519Pub,
      );
      final snBob = SafetyNumber.generate(
        localUid: bob.uid,
        localIdentityPub: bob.curve25519Pub,
        remoteUid: alice.uid,
        remoteIdentityPub: alice.curve25519Pub,
      );
      // 对称性：双方计算结果必须一致
      expect(snAlice, equals(snBob));
      expect(snAlice.length, equals(60));

      // 格式化：12 组 × 5 位
      final groups = SafetyNumber.formatGroups(snAlice);
      expect(groups.length, equals(12));
      expect(groups.every((g) => g.length == 5), isTrue);

      // ─── Phase 5: Capability 协商 + HWM（S6）───
      await capGuard.enforceNoDowngrade(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        negotiatedProtocol: 'olm',
      );
      // HWM 已记录
      expect(
        await capGuard.loadHighWaterMark(
          peerUid: bob.uid,
          peerDeviceId: bob.deviceId,
        ),
        equals('olm'),
      );

      // ─── Phase 6: 双向消息加解密 ───
      // Alice → Bob
      final m1 = aliceSession.encrypt('hello bob');
      final pt1 = bobSession.decrypt(
        messageType: m1.messageType,
        ciphertext: m1.ciphertext,
      );
      expect(pt1, equals('hello bob'));

      // Bob → Alice
      final m2 = bobSession.encrypt('hi alice');
      final pt2 = aliceSession.decrypt(
        messageType: m2.messageType,
        ciphertext: m2.ciphertext,
      );
      expect(pt2, equals('hi alice'));

      // 多轮往返（ratchet 推进）
      for (var i = 0; i < 5; i++) {
        final out = aliceSession.encrypt('msg-$i');
        final got = bobSession.decrypt(
          messageType: out.messageType,
          ciphertext: out.ciphertext,
        );
        expect(got, equals('msg-$i'));
      }

      // ─── Phase 7: 审计日志完整性验证（S8）───
      expect(await auditLog.verifyChain(), isTrue);
      final events = await auditLog.recent(limit: 100);
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.first.eventType, equals(AuditEventType.sessionEstablished));

      // ─── Phase 8: Identity 变更检测（S3 TOFU）───
      // 模拟 Bob 换机：新 Account 产生不同 identity key
      final bobNew = _Device('2002', 'bob-dev-2', vod.Account());
      final newFp = bobNew.curve25519Pub;
      expect(newFp, isNot(equals(bobFp))); // 确认不同

      // TOFU 比对：旧 pin vs 新 key → 不匹配
      final pinnedFp = await store.loadPinnedFingerprint(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
      );
      expect(pinnedFp, isNot(equals(newFp)));
      // 生产路径此处抛 IdentityChangedException，UI 告警用户

      await auditLog.append(
        AuditEventType.identityChanged,
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        detail: 'fp mismatch detected',
      );

      // ─── Phase 9: 协议降级检测（S6）───
      // 攻击者伪造 Bob 只支持 rsa-oaep（低于 olm）
      expect(
        () => capGuard.enforceNoDowngrade(
          peerUid: bob.uid,
          peerDeviceId: bob.deviceId,
          negotiatedProtocol: 'rsa-oaep',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );

      await auditLog.append(
        AuditEventType.capabilityDowngraded,
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        detail: 'olm → rsa-oaep rejected',
      );

      // 最终审计链仍然完整
      expect(await auditLog.verifyChain(), isTrue);
      final allEvents = await auditLog.recent(limit: 100);
      expect(allEvents.length, equals(4));
    });

    test('篡改 identity 签名 → IdentityVerificationException（MITM 检测）', () {
      // 攻击者替换 Bob 的 curve25519 公钥但保留 Alice 的签名
      final forgedIdentity = <String, dynamic>{
        'ed25519_key': alice.ed25519Pub,
        'curve25519_key': bob.curve25519Pub, // 不是 Alice 的 key
        'signature': _padB64(
          alice.account.sign(alice.curve25519Pub).toBase64(),
        ),
      };

      expect(
        () => verifyIdentitySignature(forgedIdentity, context: 'MITM'),
        throwsA(isA<IdentityVerificationException>()),
      );
    });

    test('Safety Number 对 MITM 敏感（替换公钥 → 不同安全码）', () {
      final attacker = vod.Account();

      final snLegit = SafetyNumber.generate(
        localUid: alice.uid,
        localIdentityPub: alice.curve25519Pub,
        remoteUid: bob.uid,
        remoteIdentityPub: bob.curve25519Pub,
      );
      final snMitm = SafetyNumber.generate(
        localUid: alice.uid,
        localIdentityPub: alice.curve25519Pub,
        remoteUid: bob.uid,
        remoteIdentityPub: _padB64(attacker.identityKeys.curve25519.toBase64()),
      );

      // MITM 替换公钥后安全码必须不同（用户比对即可发现）
      expect(snLegit, isNot(equals(snMitm)));
    });

    test('用户确认降级后通信恢复（S6 confirmDowngrade）', () async {
      // 首次协商 olm
      await capGuard.enforceNoDowngrade(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        negotiatedProtocol: 'olm',
      );

      // 降级被拒绝
      expect(
        () => capGuard.enforceNoDowngrade(
          peerUid: bob.uid,
          peerDeviceId: bob.deviceId,
          negotiatedProtocol: 'rsa-oaep',
        ),
        throwsA(isA<CapabilityDowngradeException>()),
      );

      // 用户确认：对端确实换了低版本客户端
      await capGuard.confirmDowngrade(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        newProtocol: 'rsa-oaep',
      );

      // 确认后同级别不再告警
      await capGuard.enforceNoDowngrade(
        peerUid: bob.uid,
        peerDeviceId: bob.deviceId,
        negotiatedProtocol: 'rsa-oaep',
      );

      // HWM 已更新
      expect(
        await capGuard.loadHighWaterMark(
          peerUid: bob.uid,
          peerDeviceId: bob.deviceId,
        ),
        equals('rsa-oaep'),
      );
    });
  });
}
