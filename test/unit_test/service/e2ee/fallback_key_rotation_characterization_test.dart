import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// E2EE-062：**fallback key 轮换语义的特征测试**（characterization test）。
///
/// == 为什么需要它 ==
///
/// 上一刀顺带实证：`generateFallbackKey()` 全仓只在 `publishIdentityAndPrekeys`
/// 出现一次，即**只在登录时轮换**，且全仓**没有** `forgetFallbackKey()` 调用。
/// 要判断这是不是前向保密缺口，必须先确定 vodozemac 的实际语义：
///
/// 1. `fallbackKey` 文档写的是「current **unpublished** fallback key」——
///    那么 `markKeysAsPublished()` 之后它还剩什么？这直接决定第二次登录时
///    我们的上传逻辑（`if (fbKey.isNotEmpty)`）到底还会不会执行；
/// 2. `generateFallbackKey()` 是否真的换出新 keyid（真轮换，而非幂等空操作）？
/// 3. 轮换之后，**用旧 fallback key 建立的 inbound 会话还能不能解密**？
///    这决定 `forgetFallbackKey()` 是"必须调"还是"调了会丢消息"。
///
/// **读文档只能形成假设**（本项目已多次被实证推翻），故用真 vodozemac 账号实测。
/// 本文件**不改任何生产代码**，只把库行为钉死，供轮换设计引用。
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await vod.init(libraryPath: _spikeLibDir);
  });

  test('对照组：新账号 generateFallbackKey 后能取到一把 key', () {
    final acc = vod.Account();
    expect(
      acc.fallbackKey,
      isEmpty,
      reason: '未生成前不该有 fallback key；若这里非空说明测试根本没在测轮换',
    );
    acc.generateFallbackKey();
    expect(acc.fallbackKey.length, 1);
  });

  test('markKeysAsPublished 之后 fallbackKey 变空（"unpublished" 的字面含义）', () {
    final acc = vod.Account();
    acc.generateFallbackKey();
    expect(acc.fallbackKey.length, 1);
    acc.markKeysAsPublished();
    expect(
      acc.fallbackKey,
      isEmpty,
      reason: '生产代码 `if (fbKey.isNotEmpty)` 的分支条件依赖这个语义',
    );
  });

  test('再次 generateFallbackKey 换出**新** keyid（确实是轮换，不是幂等空操作）', () {
    final acc = vod.Account();
    acc.generateFallbackKey();
    final first = acc.fallbackKey.keys.single;
    acc.markKeysAsPublished();

    acc.generateFallbackKey();
    final second = acc.fallbackKey.keys.single;

    expect(second, isNot(first), reason: '若 keyid 不变，则"每次登录轮换"根本没有发生');
  });

  test('轮换一次后，用**旧** fallback key 建的会话仍可解密（旧私钥被保留）', () async {
    final bob = vod.Account();
    bob.generateFallbackKey();
    final oldFbId = bob.fallbackKey.keys.single;
    final oldFb = bob.fallbackKey.values.single;
    bob.markKeysAsPublished();

    // Alice 用 Bob 的**旧** fallback key 建出站会话并加密一条
    final alice = vod.Account();
    final aliceSession = alice.createOutboundSession(
      identityKey: bob.identityKeys.curve25519,
      oneTimeKey: oldFb,
      config: legacyOlmSessionConfig(),
    );
    final msg = aliceSession.encrypt('hello-via-old-fallback');

    // Bob 轮换 fallback key（模拟下一次登录）
    bob.generateFallbackKey();
    final newFbId = bob.fallbackKey.keys.single;
    expect(newFbId, isNot(oldFbId));

    // 轮换之后，旧 key 建的 pre-key 消息仍应能解开
    final inbound = bob.createInboundSession(
      theirIdentityKey: alice.identityKeys.curve25519,
      preKeyMessageBase64: msg.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    expect(
      inbound.plaintext,
      'hello-via-old-fallback',
      reason:
          '旧 fallback 私钥被保留，正是"轮换后仍能收在途消息"的机制；'
          '这也说明 forgetFallbackKey() 不调的话旧私钥会一直留在 pickle 里',
    );
  });
}
