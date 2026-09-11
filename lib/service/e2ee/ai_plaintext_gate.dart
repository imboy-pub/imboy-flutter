/// LT02-SEC-01（AI-ID=B）：AI 明文通道的**共享身份门**。
///
/// 当前实现采用 AI-ID=B：每个 AI 会话首次明文发送前用户显式确认。
/// 源码曾引用不存在的 `RR/decisions/AI-ID-2026-09-09.md`；当前决策包为
/// `imboy/docs/planning/ai-id-plaintext-channel-decision-brief-2026-09-11.md`。
/// “B”只描述已实现的变体，用户尚未选择，不代表批准或风险接受。
/// 确认绑定五元组并本地持久化：
///
/// 1. **deployment identity** — 部署身份（默认取 API base 指纹，换部署即失效）；
/// 2. **本机 owner uid** — 发起确认的本地账号（切换账号即失效）；
/// 3. **稳定 target uid** — 对端账号 ID（与可被污染的 contact 昵称/头像无关）；
/// 4. **对端身份公钥/指纹** — 确认时观察到的对端身份材料指纹，变化即失效；
/// 5. **当前 version** — 对端身份 version，回退/前跳均视为身份变化即失效。
///
/// == 为什么需要它 ==
///
/// 旧实现：`e2ee_service.shouldEncryptOutgoingPayload` 里
/// `chatType == 'C2C' && peerAccountType == 1` 直接短路返回「不加密」。
/// 输入是**未签名、可污染**的裸 int（contact.account_type 列，来源为免鉴权
/// `user/show` 响应回吐）——任何人向设备投递一条伪造响应即可让消息/附件/
/// 重试三条出设备路径全部明文豁免，且豁免先于 PolicyGate，没有 second
/// opinion。finding LT02-SEC-01 HIGH/OPEN。
///
/// AI-ID=B 修复：徽章（account_type）只允许渲染 UI；**授权明文**必须存在
/// 一条与当前五元组完全匹配的用户确认记录。确认弹窗明示「本会话消息和附件
/// 不是端到端加密」。身份或 version 变化后旧确认失效、必须重新确认；
/// 昵称/头像/AI badge 变化不构成确认，也不触发重新确认。
///
/// == 单一入口 ==
///
/// 消息（`chat_network_service`）、附件（`attachment_handler`）、重试
/// （`message_retry`）三条出设备路径都经由
/// `E2EEService.shouldEncryptOutgoingPayload(chatType, toId: ...)` 汇流到
/// [AiPlaintextGate.plaintextChannelAuthorized]——禁止在 caller 各写一份
/// guard。`peerAccountType` 只能用于 UI badge，**不能单独授权明文**。
///
/// == 边界 ==
///
/// - 后端 `ai_agent_ds:is_agent/1` 仍是落库/触发/计费前的服务端权威二道门，
///   行为不变；它不能替代本客户端 pre-send 门，但对「客户端被污染误判」兜底。
/// - B 不防御恶意服务端（确认绑定的材料由部署下发）；在用户批准 AI-ID=B
///   并明确接受该剩余风险前，不得把本实现视为风险接受或替代 AI-ID-A 信任锚。
/// - 任何未知/缺失/不一致状态一律 fail-closed：走真人 E2EE 或拒发。
/// - 本地 DB `account_type=1` 无有效确认 → 仍走 E2EE（agent 无设备密钥时
///   发送端加密失败 → 拒发），绝不静默明文出网。
///
/// == schema 纪律 ==
///
/// 确认表 [SqliteAiPlaintextConfirmationStore] 遵循仓内 CryptoStore/
/// CryptoAuditLog 先例：服务自有幂等 `ensureSchema()`（CREATE TABLE IF
/// NOT EXISTS，位于同一 SQLCipher 库、继承静态加密），不占用全局迁移版本号
/// （避免与并行任务的迁移号冲突）；schema_contract 的 invariant 只校验必需
/// 表，不拒绝服务自有表。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
// visibleForTesting 由 foundation 再导出（仓内不直接依赖 meta 包）。
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:imboy/config/env.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 对端身份材料（确认五元组的后两维来源）。
class AiPeerIdentity {
  const AiPeerIdentity({required this.fingerprint, required this.version});

  /// 对端身份材料指纹（SHA-256 hex）。变化 = 对端身份变化 → 旧确认失效。
  final String fingerprint;

  /// 对端身份 version。回退/前跳都视为身份变化 → 旧确认失效。
  ///
  /// 当前部署未发布 agent 身份 version，生产源恒为 0；服务端未来下发
  /// version 后在本源升级，旧确认（version=0）随即失效、强制重新确认
  /// （fail-closed 方向）。单测经 [AiPlaintextGate.identitySource] 注入
  /// 任意 version 验证门逻辑。
  final int version;
}

/// 一条用户确认记录（不可变五元组 + 审计时间戳）。
class AiPlaintextConfirmation {
  const AiPlaintextConfirmation({
    required this.deploymentId,
    required this.ownerUid,
    required this.targetUid,
    required this.peerIdentityFingerprint,
    required this.identityVersion,
    required this.confirmedAt,
  });

  final String deploymentId;
  final String ownerUid;
  final String targetUid;
  final String peerIdentityFingerprint;
  final int identityVersion;
  final int confirmedAt;
}

/// 确认弹窗请求（弹窗实现据此组织文案；不含任何密钥/明文）。
class AiPlaintextPromptRequest {
  const AiPlaintextPromptRequest({
    required this.targetUid,
    required this.peerIdentityFingerprint,
    required this.identityVersion,
  });

  final String targetUid;
  final String peerIdentityFingerprint;
  final int identityVersion;
}

/// UI 确认处理器：返回 true 表示用户显式确认。
typedef AiPlaintextPromptHandler =
    Future<bool> Function(AiPlaintextPromptRequest request);

/// 对端身份材料源 seam。
abstract class AiPeerIdentitySource {
  Future<AiPeerIdentity?> resolve(String targetUid);
}

/// 确认记录存储 seam。
abstract class AiConfirmationStore {
  Future<AiPlaintextConfirmation?> load({
    required String ownerUid,
    required String targetUid,
  });
  Future<void> save(AiPlaintextConfirmation rec);
  Future<void> delete({required String ownerUid, required String targetUid});
}

/// 生产身份源：部署作用域的对端身份投影。
///
/// 指纹 = SHA-256(`imboy.ai-peer.v1` | deploymentId | targetUid)：
/// 同一 uid 在不同部署下指纹不同（deployment 绑定），uid 是部署内稳定键。
/// 服务端未来发布 agent 身份公钥/version 时在此升级，旧确认自动失效。
class DeploymentScopedPeerIdentitySource implements AiPeerIdentitySource {
  const DeploymentScopedPeerIdentitySource();

  @override
  Future<AiPeerIdentity?> resolve(String targetUid) async {
    final deploymentId = AiPlaintextGate.deploymentIdResolver?.call() ?? '';
    if (deploymentId.isEmpty || targetUid.isEmpty) return null;
    final fingerprint = sha256
        .convert(utf8.encode('imboy.ai-peer.v1|$deploymentId|$targetUid'))
        .toString();
    return AiPeerIdentity(fingerprint: fingerprint, version: 0);
  }
}

/// 生产确认存储：SQLCipher 库内服务自有表（懒初始化幂等建表）。
///
/// 独立于 contact 表（污染列隔离）：`user/show` / friend/list 同步只写
/// contact，永远碰不到本表；主键 (user_id, target_uid) 同时隔离本机多账号。
///
/// C1（review 条件，2026-09-09）：schema 采用**懒初始化**——首次
/// load/save 自动 `ensureSchema()` 并缓存（失败不缓存、下次重试），
/// 不依赖任何调用方先记得建表。否则生产首次 load 会因表不存在抛异常、
/// 被共享门 catch 吞掉 → 确认弹窗永不出现，正通道生产不可达。
class SqliteAiPlaintextConfirmationStore implements AiConfirmationStore {
  static const String tableName = 'ai_plaintext_confirmation';

  final SqliteService _db = SqliteService.to;

  /// 懒初始化缓存：null = 尚未建表（或上次失败已清空，待重试）。
  Future<void>? _schemaReady;

  /// 幂等建表。懒初始化自动触发；也可显式调用预热（测试/引导路径）。
  Future<void> ensureSchema() async {
    final db = (await _db.db)!;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        user_id TEXT NOT NULL,
        target_uid TEXT NOT NULL,
        deployment_id TEXT NOT NULL,
        peer_identity_fingerprint TEXT NOT NULL,
        identity_version INTEGER NOT NULL,
        confirmed_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, target_uid)
      )
    ''');
  }

  /// 懒初始化入口：首次访问建表，失败不缓存（下次 load/save 重试）。
  Future<void> _schemaReadyOnce() {
    final existing = _schemaReady;
    if (existing != null) return existing;
    final f = ensureSchema().then(
      (_) {},
      onError: (Object e) {
        _schemaReady = null; // 失败不缓存：下次调用重试（fail-closed 不锁死）
        throw e;
      },
    );
    _schemaReady = f;
    return f;
  }

  @override
  Future<AiPlaintextConfirmation?> load({
    required String ownerUid,
    required String targetUid,
  }) async {
    await _schemaReadyOnce();
    final db = (await _db.db)!;
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND target_uid = ?',
      whereArgs: [ownerUid, targetUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    return AiPlaintextConfirmation(
      deploymentId: r['deployment_id']?.toString() ?? '',
      ownerUid: r['user_id']?.toString() ?? '',
      targetUid: r['target_uid']?.toString() ?? '',
      peerIdentityFingerprint: r['peer_identity_fingerprint']?.toString() ?? '',
      identityVersion: int.tryParse('${r['identity_version']}') ?? -1,
      confirmedAt: int.tryParse('${r['confirmed_at']}') ?? 0,
    );
  }

  @override
  Future<void> save(AiPlaintextConfirmation rec) async {
    await _schemaReadyOnce();
    final db = (await _db.db)!;
    await db.execute(
      'INSERT INTO $tableName (user_id, target_uid, deployment_id, '
      "peer_identity_fingerprint, identity_version, confirmed_at) "
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(user_id, target_uid) DO UPDATE SET '
      'deployment_id = excluded.deployment_id, '
      'peer_identity_fingerprint = excluded.peer_identity_fingerprint, '
      'identity_version = excluded.identity_version, '
      'confirmed_at = excluded.confirmed_at',
      [
        rec.ownerUid,
        rec.targetUid,
        rec.deploymentId,
        rec.peerIdentityFingerprint,
        rec.identityVersion,
        rec.confirmedAt,
      ],
    );
  }

  @override
  Future<void> delete({
    required String ownerUid,
    required String targetUid,
  }) async {
    await _schemaReadyOnce();
    final db = (await _db.db)!;
    await db.delete(
      tableName,
      where: 'user_id = ? AND target_uid = ?',
      whereArgs: [ownerUid, targetUid],
    );
  }
}

/// AI 明文通道共享身份门（唯一判定入口）。
class AiPlaintextGate {
  AiPlaintextGate._();

  /// 对端是否带 agent 徽章（account_type=1）。**必要条件，绝不授权**。
  /// 默认实现只读本地 contact 行（autoFetch=false：门内不发网络请求，
  /// 徽章由 contact 同步链路维护）；异常按无徽章处理。
  static Future<bool> Function(String targetUid)? agentBadgeProbe =
      _productionBadgeProbe;

  /// 对端身份材料源。生产默认 [DeploymentScopedPeerIdentitySource]；
  /// 单测注入 fake 覆盖。
  static AiPeerIdentitySource? identitySource =
      const DeploymentScopedPeerIdentitySource();

  /// 确认记录存储。生产默认 [SqliteAiPlaintextConfirmationStore]；
  /// 单测注入 fake 覆盖。
  static AiConfirmationStore? confirmationStore =
      SqliteAiPlaintextConfirmationStore();

  /// 部署身份（稳定、随部署切换而变化）。默认取 API base URL 的 SHA-256
  /// 前 32 hex；空值 fail-closed。
  static String Function()? deploymentIdResolver = _defaultDeploymentId;

  /// 发起确认的本地账号。账号缺失或在确认期间变化均 fail-closed。
  static String Function()? currentUserIdResolver = _defaultCurrentUserId;

  /// UI 确认弹窗处理器。由 UI 层（ChatPage）注册；null = 非 UI 语境
  /// （如 retry）→ 不弹窗、不放行。
  static AiPlaintextPromptHandler? promptHandler;

  static Future<bool> _productionBadgeProbe(String targetUid) async {
    if (targetUid.isEmpty) return false;
    final int badge = await ContactRepo().accountTypeOfUid(
      targetUid,
      autoFetch: false,
    );
    return badge == 1;
  }

  /// 部署身份默认实现：API base URL 指纹（不泄露原值，仅部署内稳定）。
  static String _defaultDeploymentId() {
    final String base;
    try {
      base = Env().apiBaseUrl;
    } catch (_) {
      return '';
    }
    if (base.isEmpty) return '';
    return sha256.convert(utf8.encode(base)).toString().substring(0, 32);
  }

  static String _defaultCurrentUserId() => UserRepoLocal.to.currentUid;

  /// 共享策略入口：当前 (chatType, toId) 是否允许走 AI 明文通道。
  ///
  /// 只有五元组完全匹配的有效用户确认才返回 true；其余一律 false
  /// （调用方按策略要求加密；agent 无设备密钥时加密失败 → 拒发）。
  /// [interactive] 仅 UI 语境（消息发送/附件上传）置 true：无有效确认时
  /// 弹确认、用户同意后落库并放行。retry 等非 UI 语境必须传 false。
  static Future<bool> plaintextChannelAuthorized({
    required String chatType,
    required String toId,
    bool interactive = false,
  }) async {
    // AI 明文通道只存在于 C2C；C2G 由群级 Megolm 强制门独立治理。
    if (chatType != 'C2C' || toId.isEmpty) return false;

    try {
      final source = identitySource;
      final store = confirmationStore;
      final resolveDeployment = deploymentIdResolver;
      final resolveCurrentUserId = currentUserIdResolver;
      // 未接线（身份源/存储/部署身份任一缺失）→ fail-closed。
      if (source == null ||
          store == null ||
          resolveDeployment == null ||
          resolveCurrentUserId == null) {
        return false;
      }
      final String deploymentId = resolveDeployment();
      final String ownerUid = resolveCurrentUserId();
      if (deploymentId.isEmpty || ownerUid.isEmpty) return false;

      // 徽章是必要条件（非 agent 根本不走 AI 明文语义），但绝不充分。
      if (!await (agentBadgeProbe?.call(toId) ?? Future.value(false))) {
        return false;
      }

      final AiPeerIdentity? identity = await source.resolve(toId);
      if (identity == null || identity.fingerprint.isEmpty) return false;

      final rec = await store.load(ownerUid: ownerUid, targetUid: toId);
      if (_matches(rec, deploymentId, ownerUid, toId, identity)) {
        return await _bindingStillCurrent(
          source: source,
          resolveDeployment: resolveDeployment,
          resolveCurrentUserId: resolveCurrentUserId,
          deploymentId: deploymentId,
          ownerUid: ownerUid,
          targetUid: toId,
          identity: identity,
        );
      }

      // 无有效确认（缺失 / uid / deployment / 指纹 / version 任一不匹配）。
      if (!interactive) return false;
      final handler = promptHandler;
      if (handler == null) return false;
      final bool ok;
      try {
        ok = await handler(
          AiPlaintextPromptRequest(
            targetUid: toId,
            peerIdentityFingerprint: identity.fingerprint,
            identityVersion: identity.version,
          ),
        );
      } catch (_) {
        return false; // 弹窗链路异常按用户拒绝处理
      }
      if (!ok) return false;

      if (!await _bindingStillCurrent(
        source: source,
        resolveDeployment: resolveDeployment,
        resolveCurrentUserId: resolveCurrentUserId,
        deploymentId: deploymentId,
        ownerUid: ownerUid,
        targetUid: toId,
        identity: identity,
      )) {
        return false;
      }

      await store.save(
        AiPlaintextConfirmation(
          deploymentId: deploymentId,
          ownerUid: ownerUid,
          targetUid: toId,
          peerIdentityFingerprint: identity.fingerprint,
          identityVersion: identity.version,
          confirmedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      // 弹窗与落库都是异步边界；保存后重读记录并复核当前绑定。任一项变化
      // 都撤销刚写入的确认，避免旧五元组稍后重新匹配。
      var authorized = false;
      try {
        final saved = await store.load(ownerUid: ownerUid, targetUid: toId);
        authorized =
            _matches(saved, deploymentId, ownerUid, toId, identity) &&
            await _bindingStillCurrent(
              source: source,
              resolveDeployment: resolveDeployment,
              resolveCurrentUserId: resolveCurrentUserId,
              deploymentId: deploymentId,
              ownerUid: ownerUid,
              targetUid: toId,
              identity: identity,
            );
        return authorized;
      } finally {
        if (!authorized) {
          await store.delete(ownerUid: ownerUid, targetUid: toId);
        }
      }
    } catch (_) {
      return false; // 存储/身份源异常 → fail-closed
    }
  }

  static Future<bool> _bindingStillCurrent({
    required AiPeerIdentitySource source,
    required String Function() resolveDeployment,
    required String Function() resolveCurrentUserId,
    required String deploymentId,
    required String ownerUid,
    required String targetUid,
    required AiPeerIdentity identity,
  }) async {
    if (resolveDeployment() != deploymentId ||
        resolveCurrentUserId() != ownerUid) {
      return false;
    }
    final currentIdentity = await source.resolve(targetUid);
    if (currentIdentity == null ||
        currentIdentity.fingerprint != identity.fingerprint ||
        currentIdentity.version != identity.version ||
        !await (agentBadgeProbe?.call(targetUid) ?? Future.value(false))) {
      return false;
    }
    return resolveDeployment() == deploymentId &&
        resolveCurrentUserId() == ownerUid;
  }

  static bool _matches(
    AiPlaintextConfirmation? rec,
    String deploymentId,
    String ownerUid,
    String targetUid,
    AiPeerIdentity identity,
  ) {
    return rec != null &&
        rec.deploymentId == deploymentId &&
        rec.ownerUid == ownerUid &&
        rec.targetUid == targetUid &&
        rec.peerIdentityFingerprint == identity.fingerprint &&
        rec.identityVersion == identity.version;
  }

  /// 恢复生产默认接线，清空单测注入的 fake。
  @visibleForTesting
  static void debugReset() {
    agentBadgeProbe = _productionBadgeProbe;
    identitySource = const DeploymentScopedPeerIdentitySource();
    confirmationStore = SqliteAiPlaintextConfirmationStore();
    deploymentIdResolver = _defaultDeploymentId;
    currentUserIdResolver = _defaultCurrentUserId;
    promptHandler = null;
  }

  /// 显式恢复生产徽章探针（污染负例测试用：真实读 contact 表）。
  @visibleForTesting
  static void useProductionBadgeProbe() {
    agentBadgeProbe = _productionBadgeProbe;
  }

  /// 当前生产五元组（确认记录预置/诊断用）。
  @visibleForTesting
  static Future<
    ({String deploymentId, String ownerUid, String fingerprint, int version})
  >
  debugCurrentBinding(String targetUid) async {
    final deploymentId = deploymentIdResolver?.call() ?? '';
    final ownerUid = currentUserIdResolver?.call() ?? '';
    final identity =
        await (identitySource ?? const DeploymentScopedPeerIdentitySource())
            .resolve(targetUid);
    return (
      deploymentId: deploymentId,
      ownerUid: ownerUid,
      fingerprint: identity?.fingerprint ?? '',
      version: identity?.version ?? -1,
    );
  }
}
