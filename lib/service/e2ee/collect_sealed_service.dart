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

import 'package:flutter/foundation.dart';

import 'package:imboy/service/e2ee/collect_crypto.dart';
import 'package:imboy/service/e2ee/collect_keychain.dart';
import 'package:imboy/store/api/user_collect_api.dart';
import 'package:imboy/store/model/user_collect_model.dart';

/// legacy e2ee 字段 payload 解密回调（provider 注入 E2EEService 适配）。
typedef E2eePayloadDecryptor = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

/// sealed 行的解码失败分类（不区分底层原因粒度，防 oracle）。
class CollectSealedException implements Exception {
  final String message;
  CollectSealedException(this.message);
  @override
  String toString() => 'CollectSealedException: $message';
}

/// v1 密封收藏创建结果（PLAN §5 能力 1 / §9 兼容矩阵）。
enum CollectCreateStatus {
  /// 已创建（服务端 generation 落定）。
  ok,

  /// 本地已有活动 sealed 行——已收藏短接（不产新密文、不发请求）。
  already,

  /// 拒绝：能力未协商（旧后端）或密钥轮换中；均不回退明文（§9）。
  refused,

  /// 服务端 5502：他设备已改，需刷新后重试。
  conflict,

  failed,
}

class CollectCreateOutcome {
  const CollectCreateOutcome(this.status, {this.generation = 0, this.tip});

  final CollectCreateStatus status;

  /// ok 时的服务端修订号（本地 CAS 基准）。
  final int generation;

  /// 非 ok 时的用户提示文案（已收藏短接无提示）。
  final String? tip;
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

  /// v1 密封收藏创建流（收藏入口唯一委托点，§9 兼容矩阵）：
  /// - 能力门：manifest 无 `e2ee_collect` → 拒绝创建 + 升级提示
  ///   （无明文静默回退——落旧后端会丢 GC 引用与防复活保护）；
  /// - seal 门：轮换进行中拒绝（同样不回退明文）；
  /// - 本地已有活动 sealed 行 → 已收藏短接；
  /// - attach 哈希提取与后端 collect_image_attaches 同口径
  ///   （payload.images[].file_hash256 ?? md5；无多图时取单图字段）；
  /// - addV1 成功 → onSaved 回写密文行（含 generation 供后续 CAS）。
  ///
  /// seal_generation 恒取 1：创建场景本地无从知晓墓碑 G（remove 已删本地行），
  /// §8.1 头部断言为 ≤（复活后 G+1 仍成立）；内容时效由服务端字节幂等/CAS
  /// 拦截，不存在旧密文重放（每次都全新 seal）。
  static Future<CollectCreateOutcome> collectSealed({
    required UserCollectApi api,
    required CollectKeychain keychain,
    required bool Function() capability,
    required String msgUnsupported,
    required String msgRotating,
    required int userId,
    required int kind,
    required String kindId,
    required String source,
    required Map<String, dynamic> info,
    required Future<UserCollectModel?> Function(String kindId) findLocal,
    required Future<void> Function(Map<String, dynamic> row) onSaved,
  }) async {
    if (!capability()) {
      return CollectCreateOutcome(
        CollectCreateStatus.refused,
        tip: msgUnsupported,
      );
    }
    final bootstrapped = await keychain.ensureBootstrap();
    if (!CollectKeychainLogic.sealAllowed(bootstrapped)) {
      return CollectCreateOutcome(
        CollectCreateStatus.refused,
        tip: msgRotating,
      );
    }
    final key = bootstrapped.activeKey!;
    final local = await findLocal(kindId);
    if (local != null && local.sealed) {
      return const CollectCreateOutcome(CollectCreateStatus.already);
    }
    final attach = extractAttachHashes(info);
    // §8.2 双核对②数据源：被密封 payload 自带可见引用声明，
    // decodeSealedRow 据此与行可见列表交叉核对（缺此键非文本收藏不可解）。
    final payloadToSeal = <String, dynamic>{
      ...info,
      'attach_file_hash256': attach,
    };
    final infoSealed = await sealPayload(
      key: key,
      userId: userId,
      kindId: kindId,
      kind: kind,
      sealGeneration: 1,
      payload: payloadToSeal,
      attachHashes: attach,
    );
    final res = await api.addV1(
      kind: kind,
      kindId: kindId,
      infoSealed: infoSealed,
      keyVersion: key.version,
      attachHashes: attach,
    );
    if (res.ok && res.generation != null) {
      await onSaved({
        'user_id': userId,
        'kind': kind,
        'kind_id': kindId,
        'source': source,
        'generation': res.generation,
        'key_version': key.version,
        'info': infoSealed,
        'attach_file_hash256': attach.join(','),
      });
      return CollectCreateOutcome(
        CollectCreateStatus.ok,
        generation: res.generation!,
      );
    }
    return CollectCreateOutcome(
      res.code == 5502
          ? CollectCreateStatus.conflict
          : CollectCreateStatus.failed,
      tip: res.msg,
    );
  }

  /// 行可见引用哈希提取（与服务端 add_legacy 各 kind 同口径）：
  /// - 多图（kind 2 imageMulti）：payload.images[] 每项 file_hash256 ?? md5；
  /// - 视频（kind 4）：payload.thumb + payload.video 双对象（服务端 [Attach1,
  ///   Attach2] 同款）；漏报会丢 GC 保留引用（A2/A8）；
  /// - 其余单附件 kind：payload 顶层 file_hash256 ?? md5。
  /// 去重后返回（与服务端 attach_file_hash256 逗号列表语义一致）。
  static List<String> extractAttachHashes(Map<String, dynamic> info) {
    final payload = info['payload'];
    final map = payload is Map ? payload : const <String, dynamic>{};
    final hashes = <String>{};
    void collectFrom(Map<dynamic, dynamic> m) {
      final h = _hashOf(m);
      if (h != null) hashes.add(h);
    }

    final images = map['images'];
    if (images is List) {
      for (final item in images) {
        if (item is Map) collectFrom(item);
      }
    }
    for (final key in ['thumb', 'video']) {
      final sub = map[key];
      if (sub is Map) collectFrom(sub);
    }
    if (hashes.isEmpty) {
      collectFrom(map);
    }
    return hashes.toList();
  }

  static String? _hashOf(Map<dynamic, dynamic> map) {
    final h = map['file_hash256'] ?? map['md5'];
    return h is String && h.isNotEmpty ? h : null;
  }

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

  /// provider 列表解密钩子（sealed + e2ee 双分支）：
  /// sealed 行（keyVersion>0）就地解密——payload 回填 info，remark/source/tag
  /// 覆盖列值（D1：密文内字段为权威）；解密失败（掉队设备/坏行）保留
  /// 原样，渲染层按空信息占位（A6 行为）。
  static Future<void> decryptModels(
    List<UserCollectModel> list, {
    required int userId,
    required CollectKeychain keychain,
    E2eePayloadDecryptor? e2eeDecryptor,
  }) async {
    for (final item in list) {
      if (item.sealed && item.infoSealed != null) {
        try {
          final decoded = await decodeSealedRow(
            keychain: keychain,
            userId: userId,
            row: {
              'kind': item.kind,
              'kind_id': item.kindId,
              'generation': item.generation,
              'key_version': item.keyVersion,
              'info': item.infoSealed,
              'attach_file_hash256': item.attachFileHash256,
            },
          );
          item.info = decoded.payload;
          final remark = decoded.payload['remark'];
          final source = decoded.payload['source'];
          final tag = decoded.payload['tag'];
          if (remark is String && remark.isNotEmpty) item.remark = remark;
          if (source is String && source.isNotEmpty) item.source = source;
          if (tag is String && tag.isNotEmpty) item.tag = tag;
        } on CollectSealedException {
          if (kDebugMode) {
            debugPrint('collect sealed decode failed: kindId=\${item.kindId}');
          }
        }
        continue;
      }
      // legacy e2ee 字段分支（原 provider 逻辑迁移至此）
      final decryptor = e2eeDecryptor;
      if (decryptor == null) continue;
      try {
        final e2ee = item.info['e2ee'];
        if (e2ee == null || e2ee == '') continue;
        final decrypted = await decryptor(item.info);
        if (!identical(decrypted, item.info)) {
          item.info = Map<String, dynamic>.from(decrypted);
        }
      } on Exception {
        if (kDebugMode) {}
      }
    }
  }

  /// D1 remark 编辑流（sealed 行）：payload 内 remark 更新 → 重 seal → CAS；
  /// 成功后回写本地缓存（新密文 + generation + remark 明文缓存供检索）。
  static Future<bool> editRemark({
    required UserCollectApi api,
    required CollectKeychain keychain,
    required UserCollectModel item,
    required String remark,
    required int userId,
    required Future<void> Function(Map<String, dynamic> row) onSaved,
  }) async {
    final state = await keychain.load();
    if (!CollectKeychainLogic.sealAllowed(state)) {
      // 轮换中不产新密文；上层提示稍后重试
      return false;
    }
    final key = state.activeKey!;
    final payload = {...item.info, 'remark': remark};
    final attach = item.attachFileHash256.isEmpty
        ? <String>[]
        : item.attachFileHash256.split(',').where((h) => h.isNotEmpty).toList();
    final newGen = item.generation + 1;
    final infoSealed = await sealPayload(
      key: key,
      userId: userId,
      kindId: item.kindId,
      kind: item.kind,
      sealGeneration: newGen,
      payload: payload,
      attachHashes: attach,
    );
    final res = await api.updateV1(
      kindId: item.kindId,
      expectedGeneration: item.generation,
      newGeneration: newGen,
      infoSealed: infoSealed,
      keyVersion: key.version,
      attachHashes: attach,
    );
    if (!res.ok || res.generation == null) return false;
    await onSaved({
      'user_id': userId,
      'kind': item.kind,
      'kind_id': item.kindId,
      'generation': res.generation,
      'key_version': key.version,
      'info': infoSealed,
      'remark': remark,
      'attach_file_hash256': item.attachFileHash256,
    });
    return true;
  }

  /// provider.remark 全量委托：sealed 行走 v1 编辑流（D1，密文内字段），
  /// legacy 行走原 change 接口 + 本地回写；回调注入避免依赖 UI 层。
  static Future<bool> remark({
    required String kindId,
    required String remark,
    required UserCollectModel? sealedItem,
    required int userId,
    required int nowSec,
    required UserCollectApi api,
    required CollectKeychain keychain,
    required Future<bool> Function(Map<String, dynamic> data) legacyChange,
    required Future<void> Function(Map<String, dynamic> row) onSaved,
  }) async {
    if (sealedItem != null && sealedItem.sealed) {
      return editRemark(
        api: api,
        keychain: keychain,
        item: sealedItem,
        remark: remark,
        userId: userId,
        onSaved: onSaved,
      );
    }
    final res = await legacyChange({
      'action': 'remark',
      'kind_id': kindId,
      'remark': remark,
    });
    if (res) {
      // legacy 回写行（user_collect 表列名，repo.save 直接可存）
      await onSaved({
        'user_id': userId,
        'kind_id': kindId,
        'remark': remark,
        'updated_at': nowSec,
      });
    }
    return res;
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
