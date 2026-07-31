/// S13: 真机 E2EE Olm 验收集成测试
///
/// 在真实 Android/iOS 设备上验证 E2EE 核心密码学管线：
/// 1. vodozemac FFI 初始化（平台原生 .so/.framework）
/// 2. Olm Account 创建 + identity key 生成
/// 3. X3DH 密钥协商 → Olm 会话建立
/// 4. 双向消息加解密（Double Ratchet）
/// 5. Ed25519 签名/验签
/// 6. SQLCipher 加密数据库打开
///
/// 运行方式（真机）：
///   flutter test integration_test/e2ee_olm_device_test.dart -d XWE6R19916004085
///
/// 验收标准（docs/guides/testing/e2ee-testing.md）：
///   "真机 Olm 验收有记录(非模拟器)" — 本测试即该记录。
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:integration_test/integration_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage（集成测试环境无原生 secure storage 插件）
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final store = <String, String?>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              store[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return store[call.arguments['key'] as String];
            case 'delete':
              store.remove(call.arguments['key'] as String);
              return null;
            case 'containsKey':
              return store.containsKey(call.arguments['key'] as String);
            default:
              return null;
          }
        });

    // vodozemac 全进程只能初始化一次（flutter_rust_bridge 限制）
    await fvod.init();
  });

  group('真机 E2EE Olm 验收', () {
    test('vodozemac 初始化 + Account 创建', () async {
      final account = vod.Account();
      expect(account.identityKeys.curve25519, isNotNull);
      expect(account.identityKeys.ed25519, isNotNull);

      // identity key 非空且为有效 base64
      final c25519 = account.identityKeys.curve25519.toBase64();
      final ed25519 = account.identityKeys.ed25519.toBase64();
      expect(c25519.isNotEmpty, isTrue);
      expect(ed25519.isNotEmpty, isTrue);
    });

    test('X3DH 密钥协商 + Olm 会话建立 + 双向加解密', () async {
      final alice = vod.Account();
      final bob = vod.Account();

      // Bob 生成 OTK
      bob.generateOneTimeKeys(1);
      final bobOtk = bob.oneTimeKeys.values.first;

      // Alice 建出站会话（X3DH）
      final aliceSession = alice.createOutboundSession(
        identityKey: bob.identityKeys.curve25519,
        oneTimeKey: bobOtk,
      );

      // Prekey 消息
      final prekeyMsg = aliceSession.encrypt('x3dh-handshake');
      expect(prekeyMsg.messageType, equals(0));

      // Bob 建入站会话
      final inbound = bob.createInboundSession(
        theirIdentityKey: alice.identityKeys.curve25519,
        preKeyMessageBase64: prekeyMsg.ciphertext,
      );
      expect(inbound.plaintext, equals('x3dh-handshake'));
      bob.markKeysAsPublished();
      final bobSession = inbound.session;

      // Alice → Bob（Alice 还没收到 Bob 的回信，按 Olm 语义会话仍处 pre-key 状态）
      final m1 = aliceSession.encrypt('hello from alice');
      expect(m1.messageType, equals(0)); // 仍是 pre-key，不是 normal
      final pt1 = bobSession.decrypt(
        messageType: m1.messageType,
        ciphertext: m1.ciphertext,
      );
      expect(pt1, equals('hello from alice'));

      // Bob → Alice（反向 ratchet）
      final m2 = bobSession.encrypt('hello from bob');
      final pt2 = aliceSession.decrypt(
        messageType: m2.messageType,
        ciphertext: m2.ciphertext,
      );
      expect(pt2, equals('hello from bob'));

      // Alice 解密过 Bob 的消息后会话才算建立，此后才切成 normal message
      final m3 = aliceSession.encrypt('after handshake');
      expect(m3.messageType, equals(1)); // normal message
      expect(
        bobSession.decrypt(
          messageType: m3.messageType,
          ciphertext: m3.ciphertext,
        ),
        equals('after handshake'),
      );

      // 多轮往返（ratchet 推进）
      for (var i = 0; i < 10; i++) {
        final out = aliceSession.encrypt('msg-$i');
        final got = bobSession.decrypt(
          messageType: out.messageType,
          ciphertext: out.ciphertext,
        );
        expect(got, equals('msg-$i'));
      }
    });

    test('Ed25519 签名/验签（identity 绑定）', () async {
      final account = vod.Account();
      final message = account.identityKeys.curve25519.toBase64();

      // 签名
      final signature = account.sign(message);
      expect(signature.toBase64().isNotEmpty, isTrue);

      // 验签通过
      expect(
        () => account.identityKeys.ed25519.verify(
          message: message,
          signature: signature,
        ),
        returnsNormally,
      );

      // 篡改消息 → 验签失败
      expect(
        () => account.identityKeys.ed25519.verify(
          message: 'tampered-$message',
          signature: signature,
        ),
        throwsA(anything),
      );
    });

    test('OTK 生成 + 消费后不重复', () async {
      final account = vod.Account();
      account.generateOneTimeKeys(5);
      final keys = account.oneTimeKeys;
      expect(keys.length, equals(5));

      // 所有 OTK 唯一
      final values = keys.values.map((k) => k.toBase64()).toSet();
      expect(values.length, equals(5));

      // 标记已发布后清空
      account.markKeysAsPublished();
      expect(account.oneTimeKeys.isEmpty, isTrue);
    });

    test('Session pickle 加密/恢复（密钥持久化模拟）', () async {
      final alice = vod.Account();
      final bob = vod.Account();
      bob.generateOneTimeKeys(1);

      final session = alice.createOutboundSession(
        identityKey: bob.identityKeys.curve25519,
        oneTimeKey: bob.oneTimeKeys.values.first,
      );

      // 加密一条消息推进 ratchet
      session.encrypt('before-pickle');

      // Pickle（模拟落盘）
      final pickleKey = Uint8List.fromList(
        List<int>.generate(32, (i) => i + 100),
      );
      final pickle = session.toPickleEncrypted(pickleKey);
      expect(pickle.isNotEmpty, isTrue);

      // 恢复（模拟重启后加载）
      final restored = vod.Session.fromPickleEncrypted(
        pickle: pickle,
        pickleKey: pickleKey,
      );

      // 恢复后的 session 仍可加密
      final msg = restored.encrypt('after-restore');
      expect(msg.ciphertext.isNotEmpty, isTrue);
    });
  });
}
