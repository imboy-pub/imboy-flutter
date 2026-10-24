/// E2EE 收藏记录加密（方案 `docs/design/2026-10-24-e2ee-collect/PLAN.md` §8.1，v7.1）
///
/// 收藏记录层（M1）：`info_sealed` = b64(header || AES-256-GCM(RK, N, payload, AAD))。
/// 服务端只存储密文与少量明文路由字段；source/remark/tag 全部在 payload 内（D1）。
///
/// ## 密钥与绑定
/// - `RK = HKDF-SHA256(salt=常量, IKM=CKvN, info=TLV(...), L=32)`：每记录每次
///   key_version 派生一个 RK——nonce 唯一性只需在单 RK 域内成立（§8.3）。
/// - AAD 覆盖全部解析相关字段 + attach_digest；防串用/防篡改在 GCM 认证性内完成。
/// - `attach_digest = SHA-256(hex 小写哈希字典序升序 join("\n"))`：绑定可见引用
///   列表；open 成功后上层还要做 payload 声明列表 == 请求列表的二次核对（§8.2）。
///
/// ## seal_generation（v7.1，解墓碑-AAD 脱节）
/// 墓碑（取消收藏）推进行修订号 generation 但**不重封**——服务端无密钥。因此
/// AAD 绑定的是**封印时刻的修订号** `seal_generation`（密文头明文携带），而非行
/// 当前 generation。open 断言 `seal_generation <= 行generation` 由上层负责（本
/// 模块返回解出的 seal_generation 供其校验）。
///
/// ## fail-closed
/// 任何参数越界、tag 校验失败、头结构不合法都抛 [CollectCryptoException]，
/// 不区分对外失败原因粒度（不成为 oracle）；本模块不做 IO、不管密钥存储。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/api.dart' as api;
import 'package:pointycastle/export.dart';

/// 收藏封装违规：参数非法 / 头结构不合法 / tag 校验失败。
class CollectCryptoException implements Exception {
  final String message;
  CollectCryptoException(this.message);
  @override
  String toString() => 'CollectCryptoException: $message';
}

/// 域分隔常量（§8.1 冻结值；改动即破坏互解，须走向量再冻结流程）。
class CollectCrypto {
  static const String domain = 'e2ee-collect/v1';
  static const String hkdfSalt = 'imboy/e2ee-collect/hkdf/v1';
  static const int hkdfLength = 32;
  static const int nonceLength = 12; // GCM 标准 96 bit
  static const int tagLength = 16; // GCM 推荐 128 bit
  static const int sealGenerationBytes = 8; // uint64BE
  static const List<int> headerMagic = [0x45, 0x43, 0x31]; // "EC1"
  static const int headerLength =
      3 + nonceLength + sealGenerationBytes; // 23 字节定长头

  static final Random _rng = Random.secure();

  // ---------------------------------------------------------------------
  // TLV 编码（§8.1：字符串=u16BE 长度前缀+utf8；整数=固定宽度 BE）
  // ---------------------------------------------------------------------

  /// 域分隔字符串（定界符）。TLV 输入的第一段，防跨上下文重用。
  static Uint8List tlvDomain(String value) => tlvString(value);

  static Uint8List tlvString(String value) {
    final bytes = utf8.encode(value);
    if (bytes.length > 0xFFFF) {
      throw CollectCryptoException('TLV 字符串超长: ${bytes.length}');
    }
    final out = BytesBuilder();
    out.add(_u16(bytes.length));
    out.add(bytes);
    return out.toBytes();
  }

  static Uint8List tlvUint8(int value) => _fixedWidth(value, 1);

  static Uint8List tlvUint32(int value) => _fixedWidth(value, 4);

  static Uint8List tlvUint64(int value) => _fixedWidth(value, 8);

  static Uint8List _u16(int value) => _fixedWidth(value, 2);

  static Uint8List _fixedWidth(int value, int width) {
    // u64 上限用 int64 最大值（Dart 无 u64；TSID/修订号均为正整数，足够）
    final limit = width == 8 ? 0x7FFFFFFFFFFFFFFF : (1 << (8 * width)) - 1;
    if (value < 0 || value > limit) {
      throw CollectCryptoException('整数超出 u${width * 8} 范围: $value');
    }
    final out = Uint8List(width);
    for (var i = width - 1; i >= 0; i--) {
      out[i] = value & 0xFF;
      value >>= 8;
    }
    return out;
  }

  /// 顺序拼接 TLV 段。
  static Uint8List tlvConcat(List<Uint8List> parts) {
    final out = BytesBuilder();
    for (final p in parts) {
      out.add(p);
    }
    return out.toBytes();
  }

  // ---------------------------------------------------------------------
  // attach_digest（§8.1：绑定可见引用列表）
  // ---------------------------------------------------------------------

  /// `SHA-256(hex 小写哈希字典序升序 join("\n"))` 的 ascii hex。
  ///
  /// 输入为原始 hex 哈希列表（大小写归一小写；去重后排序，顺序无关）。
  /// 空列表同样可计算（无附件的文本收藏），"无引用"本身是被绑定的状态。
  static String attachDigest(List<String> hashes) {
    final normalized = hashes.map((h) => h.toLowerCase()).toSet().toList()
      ..sort();
    final joined = normalized.join('\n');
    return crypto.sha256.convert(utf8.encode(joined)).toString();
  }

  // ---------------------------------------------------------------------
  // HKDF-SHA256（RFC 5869；手写以精确对齐向量，crypto 包无 HKDF）
  // ---------------------------------------------------------------------

  static Uint8List _hmacSha256(Uint8List key, Uint8List data) {
    final h = crypto.Hmac(crypto.sha256, key);
    return Uint8List.fromList(h.convert(data).bytes);
  }

  /// RFC 5869 HKDF：extract(salt, ikm) → expand(prk, info, l)。
  static Uint8List hkdfSha256({
    required Uint8List ikm,
    required Uint8List salt,
    required Uint8List info,
    required int length,
  }) {
    if (length <= 0 || length > 255 * 32) {
      throw CollectCryptoException('HKDF 输出长度非法: $length');
    }
    final prk = _hmacSha256(salt, ikm);
    final out = BytesBuilder();
    var t = Uint8List(0);
    var counter = 1;
    while (out.length < length) {
      final input = BytesBuilder();
      input.add(t);
      input.add(info);
      input.add([counter]);
      t = _hmacSha256(prk, input.toBytes());
      out.add(t);
      counter++;
    }
    final result = out.toBytes();
    return Uint8List.sublistView(result, 0, length);
  }

  /// 记录密钥派生：`RK = HKDF-SHA256(salt=hkdfSalt, IKM=CK, info, L=32)`。
  static Uint8List deriveRecordKey({
    required Uint8List ck,
    required int userId,
    required String kindId,
    required int keyVersion,
  }) {
    if (ck.length != 32) {
      throw CollectCryptoException('CK 必须为 32 字节: ${ck.length}');
    }
    final info = tlvConcat([
      tlvDomain(domain),
      tlvUint64(userId),
      tlvString(kindId),
      tlvUint32(keyVersion),
    ]);
    return hkdfSha256(
      ikm: ck,
      salt: Uint8List.fromList(utf8.encode(hkdfSalt)),
      info: info,
      length: hkdfLength,
    );
  }

  // ---------------------------------------------------------------------
  // AAD（§8.1：全部解析相关字段 + attach_digest）
  // ---------------------------------------------------------------------

  static Uint8List buildAad({
    required int ver,
    required int keyVersion,
    required int userId,
    required String kindId,
    required int kind,
    required int sealGeneration,
    required String attachDigestHex,
  }) {
    return tlvConcat([
      tlvDomain(domain),
      tlvUint8(ver),
      tlvUint32(keyVersion),
      tlvUint64(userId),
      tlvString(kindId),
      tlvUint8(kind),
      tlvUint64(sealGeneration),
      tlvString(attachDigestHex),
    ]);
  }

  // ---------------------------------------------------------------------
  // seal / open
  // ---------------------------------------------------------------------

  /// [CollectCrypto.seal] 的产物。
  static String seal({
    required Uint8List ck,
    required int userId,
    required String kindId,
    required int kind,
    required int ver,
    required int keyVersion,
    required int sealGeneration,
    required List<String> attachHashes,
    required List<int> payloadUtf8,
    Uint8List? nonce,
  }) {
    final n = nonce ?? randomNonce();
    if (n.length != nonceLength) {
      throw CollectCryptoException('nonce 必须为 $nonceLength 字节: ${n.length}');
    }
    if (payloadUtf8.length > 16 * 1024 * 1024) {
      throw CollectCryptoException('payload 超 16MiB 上限');
    }
    final rk = deriveRecordKey(
      ck: ck,
      userId: userId,
      kindId: kindId,
      keyVersion: keyVersion,
    );
    final aad = buildAad(
      ver: ver,
      keyVersion: keyVersion,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: sealGeneration,
      attachDigestHex: attachDigest(attachHashes),
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, api.AEADParameters(KeyParameter(rk), tagLength * 8, n, aad));
    final ct = cipher.process(Uint8List.fromList(payloadUtf8));
    final header = BytesBuilder();
    header.add(headerMagic);
    header.add(n);
    header.add(tlvUint64(sealGeneration));
    final sealed = BytesBuilder();
    sealed.add(header.toBytes());
    sealed.add(ct);
    return base64.encode(sealed.toBytes());
  }

  /// [CollectCrypto.open] 的产物。
  static OpenedCollect open({
    required Uint8List ck,
    required int userId,
    required String kindId,
    required int kind,
    required int ver,
    required int keyVersion,
    required List<String> attachHashes,
    required String infoSealed,
  }) {
    final sealed = _decodeB64(infoSealed);
    if (sealed.length <= headerLength + tagLength) {
      throw CollectCryptoException('密文过短');
    }
    if (!_hasPrefix(sealed, headerMagic)) {
      throw CollectCryptoException('密文头 magic 不符');
    }
    final nonce = Uint8List.sublistView(sealed, 3, 3 + nonceLength);
    var sealGeneration = 0;
    for (var i = 0; i < sealGenerationBytes; i++) {
      sealGeneration = (sealGeneration << 8) | sealed[3 + nonceLength + i];
    }
    final body = Uint8List.sublistView(sealed, headerLength);
    final rk = deriveRecordKey(
      ck: ck,
      userId: userId,
      kindId: kindId,
      keyVersion: keyVersion,
    );
    final aad = buildAad(
      ver: ver,
      keyVersion: keyVersion,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: sealGeneration,
      attachDigestHex: attachDigest(attachHashes),
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        api.AEADParameters(KeyParameter(rk), tagLength * 8, nonce, aad),
      );
    // tag 校验失败在此抛出（fail-closed；转译为统一异常面，不区分原因粒度）
    final Uint8List payload;
    try {
      payload = cipher.process(body);
    } on InvalidCipherTextException {
      throw CollectCryptoException('密文校验失败');
    }
    return OpenedCollect(
      payload: payload,
      sealGeneration: sealGeneration,
      attachDigestHex: attachDigest(attachHashes),
    );
  }

  /// 从密文头读出 seal_generation（不解密；供同步层先比行修订号再决定是否 open）。
  static int sealGenerationOf(String infoSealed) {
    final sealed = _decodeB64(infoSealed);
    if (sealed.length <= headerLength + tagLength ||
        !_hasPrefix(sealed, headerMagic)) {
      throw CollectCryptoException('密文头结构不合法');
    }
    var value = 0;
    for (var i = 0; i < sealGenerationBytes; i++) {
      value = (value << 8) | sealed[3 + nonceLength + i];
    }
    return value;
  }

  /// 从密文头读出 nonce 的 hex（不解密；A10 审计三元组 kind_id/key_version/nonce
  /// 的数据源，§8.3 密钥域内唯一性事后核对用）。
  static String nonceHexOf(String infoSealed) {
    final sealed = _decodeB64(infoSealed);
    if (sealed.length <= headerLength + tagLength ||
        !_hasPrefix(sealed, headerMagic)) {
      throw CollectCryptoException('密文头结构不合法');
    }
    final nonce = Uint8List.sublistView(sealed, 3, 3 + nonceLength);
    return nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List randomNonce() =>
      Uint8List.fromList(List.generate(nonceLength, (_) => _rng.nextInt(256)));

  static Uint8List _decodeB64(String value) {
    try {
      return base64.decode(value);
    } catch (_) {
      throw CollectCryptoException('info_sealed 非合法 base64');
    }
  }

  static bool _hasPrefix(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }
}

/// open 成功的产物。
class OpenedCollect {
  /// 解密后的 payload utf8 字节（上层再做 JSON 解析与 §8.2 双核对）。
  final Uint8List payload;

  /// 密文头声明的封印时修订号；上层断言 `sealGeneration <= 行generation`。
  final int sealGeneration;

  /// open 时使用的 attach_digest（== 请求侧可见列表摘要；AAD 已绑定）。
  final String attachDigestHex;

  const OpenedCollect({
    required this.payload,
    required this.sealGeneration,
    required this.attachDigestHex,
  });
}
