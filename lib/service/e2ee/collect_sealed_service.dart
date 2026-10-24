/// E2EE 收藏 sealed 行客户端服务（PLAN 2026-10-24-e2ee-collect §7.3/§8.2）
///
/// 职责（纯逻辑 + keychain/api 组装，UI 接线在 provider/detail 页）：
/// - [decodeSealedRow]：服务端 sealed 行 → 解密 payload + §8.2 双核对
///   （attach_digest 重算比对 + payload 声明 == 行可见列表）+
///   seal_generation ≤ 行 generation 断言（§8.1 墓碑后密文仍可解）；
/// - [editFlow]：D1 编辑流——本地改 payload → generation+1 → 重 seal →
///   CAS 上传；409 冲突重读（以服务端 generation 为基重编辑或放弃）；
/// - [needsResync]：同步检测=仅看 generation 变化（重包裹亦推进，
///   key_version 变化不漏检，§7.3）。
///
/// 旧端读 sealed 行为失败占位（§9），本服务只服务 sealed 协议新端。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/service/e2ee/collect_crypto.dart';
import 'package:imboy/service/e2ee/collect_keychain.dart';
import 'package:imboy/store/api/user_collect_api.dart';

/// sealed 行的解码失败分类（不区分底层原因粒度，防 oracle）。
class CollectSealedException implements Exception {
  final String message;
  CollectSealedException(this.message);
  @override
  String toString() => 'CollectSealedException: $message';
}

/// 解码成功的 sealed 行。
class DecodedCollect {
  const DecodedCollect({
    required this.payload,
    required this.generation,
    required this.keyVersion,
    required this.sealGeneration,
  });

  /// 解密后的完整 payload（含 source/remark/tag/附件声明，D1）。
  final Map<String, dynamic> payload;

  /// 行当前修订号（服务端权威）。
  final int generation;

  final int keyVersion;

  /// 密文头声明的封印时修订号（≤ generation；§8.1）。
  final int sealGeneration;
}

class CollectSealedService {
  /// 服务端 page 行 → 解密。
  ///
  /// [row] 需含 kind/kind_id/generation/key_version/info（sealed base64）。
  /// [attachHashes] = 行可见引用列表（服务端 attach_file_hash256 逗号拆分）。
  static Future<DecodedCollect> decodeSealedRow({
    required Map<String, dynamic> row,
    required int userId,
    required CollectKeychain keychain,
  }) async {
    final kindId = row['kind_id'] as String? ?? '';
    final kind = row['kind'] is int ? row['kind'] as int : 0;
    final generation = row['generation'] is int ? row['generation'] as int : 0;
    final keyVersion = row['key_version'] is int
        ? row['key_version'] as int
        : 0;
    if (keyVersion <= 0) {
      throw CollectSealedException('not a sealed row');
    }
    final infoSealed = row['info'] as String? ?? '';
    final attachRaw = row['attach_file_hash256'] as String? ?? '';
    final attachHashes = attachRaw.isEmpty
        ? <String>[]
        : attachRaw.split(',').where((h) => h.isNotEmpty).toList();

    final state = await keychain.load();
    final key = state.keys
        .where((k) => k.version == keyVersion)
        .cast<CollectKeyVersion?>()
        .firstWhere((_) => true, orElse: () => null);
    if (key == null) {
      // 掉队设备：本地无该版本 CK——须先走密钥同步（§6.2），不解密不降级
      throw CollectSealedException('key version missing locally');
    }
    final ck = Uint8List.fromList(base64.decode(key.ckB64));

    final OpenedCollect opened;
    try {
      opened = CollectCrypto.open(
        ck: ck,
        userId: userId,
        kindId: kindId,
        kind: kind,
        ver: 1,
        keyVersion: keyVersion,
        attachHashes: attachHashes,
        infoSealed: infoSealed,
      );
    } on CollectCryptoException {
      throw CollectSealedException('open failed');
    }

    // §8.1：seal_generation ≤ 行 generation（墓碑/复活推进后旧密文仍可解）
    if (opened.sealGeneration > generation) {
      throw CollectSealedException('seal_generation ahead of row');
    }
    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(utf8.decode(opened.payload));
      if (decoded is! Map) {
        throw CollectSealedException('payload not json map');
      }
      payload = Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (e is CollectSealedException) rethrow;
      throw CollectSealedException('payload not json');
    }
    // §8.2 双核对 ②：payload 声明列表 == 行可见列表（①已由 AAD 绑定）
    final declared = _declaredHashes(payload);
    if (declared.length != attachHashes.length ||
        !declared.every(attachHashes.contains)) {
      throw CollectSealedException('attach list mismatch');
    }
    return DecodedCollect(
      payload: payload,
      generation: generation,
      keyVersion: keyVersion,
      sealGeneration: opened.sealGeneration,
    );
  }

  /// 同步检测（§7.3）：仅比 generation——重包裹亦推进，key_version 变化不漏检。
  static bool needsResync(int localGeneration, int serverGeneration) =>
      serverGeneration > localGeneration;

  /// seal 当前编辑内容（generation=sealGeneration；复活=墓碑G+1，§7.3）。
  static Future<String> sealPayload({
    required CollectKeyVersion key,
    required int userId,
    required String kindId,
    required int kind,
    required int sealGeneration,
    required Map<String, dynamic> payload,
    required List<String> attachHashes,
  }) async {
    final ck = Uint8List.fromList(base64.decode(key.ckB64));
    return CollectCrypto.seal(
      ck: ck,
      userId: userId,
      kindId: kindId,
      kind: kind,
      ver: 1,
      keyVersion: key.version,
      sealGeneration: sealGeneration,
      attachHashes: attachHashes,
      payloadUtf8: utf8.encode(jsonEncode(payload)),
    );
  }

  /// D1 编辑流（CAS）：成功或冲突（上层决定重读/放弃）。
  static Future<CollectV1Result> editFlow({
    required UserCollectApi api,
    required CollectKeychain keychain,
    required int userId,
    required String kindId,
    required int kind,
    required int expectedGeneration,
    required Map<String, dynamic> payload,
    required List<String> attachHashes,
  }) async {
    final state = await keychain.load();
    if (!CollectKeychainLogic.sealAllowed(state)) {
      throw CollectSealedException('rotation in progress');
    }
    final key = state.activeKey!;
    final newGen = expectedGeneration + 1;
    final infoSealed = await sealPayload(
      key: key,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: newGen,
      payload: payload,
      attachHashes: attachHashes,
    );
    return api.updateV1(
      kindId: kindId,
      expectedGeneration: expectedGeneration,
      newGeneration: newGen,
      infoSealed: infoSealed,
      keyVersion: key.version,
      attachHashes: attachHashes,
    );
  }

  static List<String> _declaredHashes(Map<String, dynamic> payload) {
    final raw = payload['attach_file_hash256'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((h) => h.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').where((h) => h.isNotEmpty).toList();
    }
    return const [];
  }
}
