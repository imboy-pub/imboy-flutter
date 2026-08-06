import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// E2EE-062：**`forgetFallbackKey()` 与 fallback key 留存期的特征测试**。
///
/// == 为什么需要它 ==
///
/// 周期轮换那一刀把「`forgetFallbackKey()` 从未被调用」列为残留，但**没有调它**，
/// 理由是语义不清：Dart 侧文档写的是 "Forget the **current** fallback key"，
/// 与 vodozemac Rust 侧的常见描述（丢弃**上一把**）矛盾。**误调会丢在途消息**，
/// 所以在钉死语义前不能动手。
///
/// 本文件用真 vodozemac 把语义与留存期一次性钉死，**不改任何生产代码**。
///
/// == 结论预告（详见 imboy evidence）==
///
/// Dart 文档是错的：丢的是**上一把**，当前那把保留。
/// 而且轮换本身就会挤掉"上上把"，因此每把 key 的留存期**已经**被周期轮换
/// 界定在约两个周期内——显式调用 `forgetFallbackKey()` 收益有限、丢消息风险真实。
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

/// 用 Bob 的某把 fallback key 建出站会话并加密一条，返回密文。
String _encryptTo(
  vod.Account alice,
  vod.Account bob,
  vod.Curve25519PublicKey fbKey,
  String text,
) {
  final s = alice.createOutboundSession(
    identityKey: bob.identityKeys.curve25519,
    oneTimeKey: fbKey,
  );
  return s.encrypt(text).ciphertext;
}

bool _canDecrypt(vod.Account bob, vod.Account alice, String ciphertext) {
  try {
    final inbound = bob.createInboundSession(
      theirIdentityKey: alice.identityKeys.curve25519,
      preKeyMessageBase64: ciphertext,
    );
    return inbound.plaintext.isNotEmpty;
  } on Object {
    return false;
  }
}

/// 生成一把 fallback key 并标记已发布，返回该公钥。
vod.Curve25519PublicKey _rotate(vod.Account acc) {
  acc.generateFallbackKey();
  final k = acc.fallbackKey.values.single;
  acc.markKeysAsPublished();
  return k;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await vod.init(libraryPath: _spikeLibDir);
  });

  group('forgetFallbackKey 的实际语义', () {
    test('对照组：全新账号（无 fallback key）→ 返回 false', () {
      final acc = vod.Account();
      expect(
        acc.forgetFallbackKey(),
        isFalse,
        reason: '对照组红说明我对这个 API 的基本理解就不对，后面几条都不必看',
      );
    });

    test('只有一把（从未轮换）→ 返回 false，且**该 key 仍可解密**', () {
      final bob = vod.Account();
      final only = _rotate(bob);
      final alice = vod.Account();
      final ct = _encryptTo(alice, bob, only, 'via-only');

      expect(bob.forgetFallbackKey(), isFalse);
      expect(
        _canDecrypt(bob, alice, ct),
        isTrue,
        reason:
            'Dart 文档写的是 "Forget the **current** fallback key"——'
            '若属实，这里应当解不开。实测解得开，**文档是错的**',
      );
    });

    test('轮换过一次 → 返回 true；丢的是**上一把**，当前那把保留', () {
      final bob = vod.Account();
      final old = _rotate(bob);
      final cur = _rotate(bob);

      final aliceOld = vod.Account();
      final ctOld = _encryptTo(aliceOld, bob, old, 'via-old');
      final aliceCur = vod.Account();
      final ctCur = _encryptTo(aliceCur, bob, cur, 'via-cur');

      expect(bob.forgetFallbackKey(), isTrue);
      expect(
        _canDecrypt(bob, aliceOld, ctOld),
        isFalse,
        reason: '上一把被丢弃——这正是"提前调用会丢在途消息"的机制',
      );
      expect(
        _canDecrypt(bob, aliceCur, ctCur),
        isTrue,
        reason: '当前那把必须保留，否则轮换后立刻无人能与本设备建会话',
      );
    });
  });

  group('留存期：轮换本身就会挤掉"上上把"', () {
    test('连续轮换两次后，第一把已不可用（最多只保留 current + previous）', () {
      final bob = vod.Account();
      final k1 = _rotate(bob);
      final alice1 = vod.Account();
      final ct1 = _encryptTo(alice1, bob, k1, 'via-k1');

      final k2 = _rotate(bob);
      final alice2 = vod.Account();
      final ct2 = _encryptTo(alice2, bob, k2, 'via-k2');

      // 此刻 current=k2、previous=k1，两把都应可用
      expect(_canDecrypt(bob, alice1, ct1), isTrue);
      expect(_canDecrypt(bob, alice2, ct2), isTrue);

      // 再轮换一次：k1 应被自动挤掉
      final k3 = _rotate(bob);
      final alice3 = vod.Account();
      final ct3 = _encryptTo(alice3, bob, k3, 'via-k3');

      expect(
        _canDecrypt(bob, alice1, ct1),
        isFalse,
        reason:
            '这条是"无需显式 forget"结论的直接依据：'
            '每把 key 的留存期已被轮换周期界定在约两个周期内',
      );
      expect(_canDecrypt(bob, alice2, ct2), isTrue, reason: 'k2 现在是 previous');
      expect(_canDecrypt(bob, alice3, ct3), isTrue, reason: 'k3 是 current');
    });
  });
}
