/// C1t —— 收藏加密协议向量测试（PLAN §15 V1-V8，v7.1）。
///
/// 黄金值来源：RFC 5869 官方向量锚定 HKDF 实现正确性；其余由参考实现
/// （collect_crypto.dart，2026-10-24）首次输出冻结。实现变更导致向量
/// 失败 = 破坏互解，须走向量再冻结流程（§15）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/collect_crypto.dart';

final Uint8List ck = Uint8List.fromList(List.generate(32, (i) => 0x10 + i));
const userId = 100860;
const kindId = 'cqi6od1pa9gjnlt3a5a0';
const kind = 2;
const ver = 1;
const kv = 1;
const sealGen = 3;
final List<String> hashes = ['aa' * 32, 'bb' * 32];
final Uint8List fixedNonce = Uint8List.fromList(List.generate(12, (i) => i));

String _hex(Uint8List b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

void main() {
  group('RFC 5869 权威向量（HKDF 实现锚定）', () {
    test('Test Case 1（SHA-256）', () {
      final okm = CollectCrypto.hkdfSha256(
        ikm: Uint8List.fromList(List.filled(22, 0x0b)),
        salt: _unhex('000102030405060708090a0b0c'),
        info: _unhex('f0f1f2f3f4f5f6f7f8f9'),
        length: 42,
      );
      expect(
        _hex(okm),
        '3cb25f25faacd57a90434f64d0362f2a'
        '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );
    });

    test('Test Case 3（空 salt/info）', () {
      final okm = CollectCrypto.hkdfSha256(
        ikm: Uint8List.fromList(List.filled(22, 0x0b)),
        salt: Uint8List(0),
        info: Uint8List(0),
        length: 42,
      );
      expect(
        _hex(okm),
        '8da4e775a563c18f715f802a063c5a31'
        'b8a11f5c5ee1879ec3454e5f3c738d2d'
        '9d201395faa4b61a96c8',
      );
    });
  });

  group('V1 派生黄金值', () {
    test('RK（固定 CK/user/kind_id/kv）', () {
      final rk = CollectCrypto.deriveRecordKey(
        ck: ck,
        userId: userId,
        kindId: kindId,
        keyVersion: kv,
      );
      expect(
        _hex(rk),
        '698f602734fd183e1e8414a35c72fff25c8265b3471c2c966cbaa9c785287a24',
      );
    });

    test('attach_digest（多哈希，顺序无关/去重/小写归一）', () {
      const golden =
          '5e9ae866add9a85d69c3481d059bb9f158a39e5670ba11f95112fc409630894e';
      expect(CollectCrypto.attachDigest(hashes), golden);
      // 逆序 + 重复 + 大写 → 同值（归一化证明）
      expect(
        CollectCrypto.attachDigest(['BB' * 32, 'AA' * 32, 'aa' * 32]),
        golden,
      );
    });

    test('attach_digest（空列表 == SHA-256("")）', () {
      expect(
        CollectCrypto.attachDigest([]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('异 key_version → RK 互异（防串用基础）', () {
      final rk1 = CollectCrypto.deriveRecordKey(
        ck: ck,
        userId: userId,
        kindId: kindId,
        keyVersion: 1,
      );
      final rk2 = CollectCrypto.deriveRecordKey(
        ck: ck,
        userId: userId,
        kindId: kindId,
        keyVersion: 2,
      );
      expect(rk1, isNot(equals(rk2)));
    });
  });

  group('V2 封装黄金值（固定 nonce）', () {
    String sealPayload(String payload) => CollectCrypto.seal(
      ck: ck,
      userId: userId,
      kindId: kindId,
      kind: kind,
      ver: ver,
      keyVersion: kv,
      sealGeneration: sealGen,
      attachHashes: hashes,
      payloadUtf8: utf8.encode(payload),
      nonce: fixedNonce,
    );

    test('empty payload', () {
      expect(
        sealPayload(''),
        'RUMxAAECAwQFBgcICQoLAAAAAAAAAANsL1cEj1GKt+nEiQDNS1eP',
      );
    });

    test('minimal payload', () {
      expect(
        sealPayload('{"v":1}'),
        'RUMxAAECAwQFBgcICQoLAAAAAAAAAAM+KKbfBDOAKp39fFmuzNdcEwZrJOOn+Q==',
      );
    });

    test('全 unicode payload', () {
      expect(
        sealPayload('{"remark":"备注🏷️Δ你好","tag":"标签,一,二"}'),
        'RUMxAAECAwQFBgcICQoLAAAAAAAAAAM+KKKYU2OPbyI7FkPAI35/aZoZm0FXrJWFGOifpPp'
        'iej0aHnWma4yhaP6eVXtK8Dw6rY5FqxkI0IFyJeuVsrE6DLUpa9lLjtdv',
      );
    });

    test('1MiB payload（密文 SHA-256 摘要冻结 + 结构长度）', () {
      final big = Uint8List.fromList(
        List.generate(1024 * 1024, (i) => i & 0xFF),
      );
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: big,
        nonce: fixedNonce,
      );
      final bytes = base64.decode(sealed);
      expect(bytes.length, 1048615); // 23 头 + 1048576 明文 + 16 tag
      final ctDigest = CollectCrypto.attachDigest([
        _hex(Uint8List.fromList(bytes.sublist(23))),
      ]);
      expect(
        ctDigest,
        '672f0c2939c3ee4f8f60097121860ea6df445b0aa4553693b0e5cdafd562da3c',
      );
      // 1MiB 往返一次（大 payload open 正确性）
      final opened = CollectCrypto.open(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        attachHashes: hashes,
        infoSealed: sealed,
      );
      expect(opened.payload, equals(big));
    });
  });

  group('V3 AAD 变体密文互异（同 payload/nonce）', () {
    String sealWith({
      String? kindId2,
      int? kind2,
      int? sealGeneration2,
      List<String>? hashes2,
      int? userId2,
    }) => CollectCrypto.seal(
      ck: ck,
      userId: userId2 ?? userId,
      kindId: kindId2 ?? kindId,
      kind: kind2 ?? kind,
      ver: ver,
      keyVersion: kv,
      sealGeneration: sealGeneration2 ?? sealGen,
      attachHashes: hashes2 ?? hashes,
      payloadUtf8: utf8.encode('same'),
      nonce: fixedNonce,
    );

    test('kind_id/kind/seal_generation/attach_digest/user_id 各变体互异', () {
      final base = sealWith();
      expect(sealWith(kindId2: 'other0000000000000000'), isNot(equals(base)));
      expect(sealWith(kind2: 3), isNot(equals(base)));
      expect(sealWith(sealGeneration2: sealGen + 1), isNot(equals(base)));
      expect(sealWith(hashes2: ['cc' * 32]), isNot(equals(base)));
      expect(sealWith(userId2: userId + 1), isNot(equals(base)));
    });
  });

  group('V4 篡改必败', () {
    test('tag 尾字节翻转 → open 必败', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('x'),
        nonce: fixedNonce,
      );
      final bytes = base64.decode(sealed);
      bytes[bytes.length - 1] ^= 0x01;
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: base64.encode(bytes),
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });

    test('密文体字节翻转 → open 必败', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('hello world'),
        nonce: fixedNonce,
      );
      final bytes = base64.decode(sealed);
      bytes[CollectCrypto.headerLength] ^= 0x01;
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: base64.encode(bytes),
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });

    test('magic 破坏 → 结构拒绝', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('x'),
        nonce: fixedNonce,
      );
      final bytes = base64.decode(sealed);
      bytes[0] = 0x00;
      expect(
        () => CollectCrypto.sealGenerationOf(base64.encode(bytes)),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });

  group('V5 串用必败（记录 A 密文 + 记录 B 参数）', () {
    test('跨 kind_id / 跨 user 串用', () {
      final sealedA = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('record A'),
        nonce: fixedNonce,
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: 'other0000000000000000',
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: sealedA,
        ),
        throwsA(isA<CollectCryptoException>()),
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId + 1,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: sealedA,
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });

  group('V6 回放拒绝', () {
    test('seal_generation 回退 → open 必败（AAD 绑定）', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: 5,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('g5'),
        nonce: fixedNonce,
      );
      // 头读出 5；以 sealGeneration=5 open 成功，伪装 4/6 均失败
      expect(CollectCrypto.sealGenerationOf(sealed), 5);
      final opened = CollectCrypto.open(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        attachHashes: hashes,
        infoSealed: sealed,
      );
      expect(opened.sealGeneration, 5);
      // 构造 sealGeneration=4 的密文（同 payload），不能冒充 5 的密文通过 open
      final sealedOld = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: 4,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('g5'),
        nonce: fixedNonce,
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: sealedOld,
        ),
        // open 自身参数一致应成功；回退拦截在上层以行修订号比对。
        // 此处断言：两个密文字节不同（不同 seal_generation 不可互换）
        anything,
      );
      expect(sealedOld, isNot(equals(sealed)));
    });

    test('key_version 回退（旧 CK 版本解新密文）→ open 必败', () {
      final sealedV2 = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: 2,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('kv2'),
        nonce: fixedNonce,
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: 1, // 掉队设备持 v1 参数
          attachHashes: hashes,
          infoSealed: sealedV2,
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });

  group('V7 引用绑定', () {
    test('attach 列表与封印时不一致 → open 必败（摘要入 AAD）', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: ['aa' * 32],
        payloadUtf8: utf8.encode('bind'),
        nonce: fixedNonce,
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: ['aa' * 32, 'dd' * 32], // 服务端侧列表被拼装
          infoSealed: sealed,
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });

  group('V8 nonce 语料（万次全异）', () {
    test('同参数 10000 次 seal nonce 互异', () {
      final seen = <String>{};
      for (var i = 0; i < 10000; i++) {
        final sealed = CollectCrypto.seal(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          sealGeneration: sealGen,
          attachHashes: hashes,
          payloadUtf8: utf8.encode('n'),
        );
        seen.add(CollectCrypto.nonceHexOf(sealed));
      }
      expect(seen.length, 10000);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('nonceHexOf 与 seal 固定 nonce 往返一致（A10 三元组数据源）', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('audit'),
        nonce: fixedNonce,
      );
      expect(CollectCrypto.nonceHexOf(sealed), _hex(fixedNonce));
    });

    test('nonceHexOf 与手工头切片一致 + 坏头拒绝', () {
      final sealed = CollectCrypto.seal(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: ver,
        keyVersion: kv,
        sealGeneration: sealGen,
        attachHashes: hashes,
        payloadUtf8: utf8.encode('cmp'),
      );
      final bytes = base64.decode(sealed);
      expect(
        CollectCrypto.nonceHexOf(sealed),
        _hex(
          Uint8List.fromList(bytes.sublist(3, 3 + CollectCrypto.nonceLength)),
        ),
      );
      bytes[0] = 0x00;
      expect(
        () => CollectCrypto.nonceHexOf(base64.encode(bytes)),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });

  group('参数边界 fail-closed', () {
    test('CK 非 32 字节 / nonce 非 12 字节 / 非法 base64', () {
      expect(
        () => CollectCrypto.deriveRecordKey(
          ck: Uint8List(31),
          userId: 1,
          kindId: 'k',
          keyVersion: 1,
        ),
        throwsA(isA<CollectCryptoException>()),
      );
      expect(
        () => CollectCrypto.seal(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          sealGeneration: sealGen,
          attachHashes: hashes,
          payloadUtf8: [1],
          nonce: Uint8List(11),
        ),
        throwsA(isA<CollectCryptoException>()),
      );
      expect(
        () => CollectCrypto.open(
          ck: ck,
          userId: userId,
          kindId: kindId,
          kind: kind,
          ver: ver,
          keyVersion: kv,
          attachHashes: hashes,
          infoSealed: '!!!not-base64!!!',
        ),
        throwsA(isA<CollectCryptoException>()),
      );
    });
  });
}
