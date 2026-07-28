import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:synchronized/synchronized.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/identity_verifier.dart';
import 'package:imboy/service/e2ee/olm_claim_request_id.dart';
import 'package:imboy/service/e2ee/otk_refill_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/olm_api.dart';

/// Olm 套件标识（e2ee 元数据 e2ee_suite 字段，区分 RSA/Megolm）
const String kOlmSuite = 'OLM.V1';

/// pre-key 投递 action 名（与 e2ee_room_key 同机制：服务端 content_bearing_action 白名单放行）
const String olmPreKeyAction = 'e2ee_olm_prekey';

/// 客户端 prekey 池低水位（剩余 < 此值时主动补传）
const int _otkLowWaterMark = 5;

/// 客户端 prekey 池目标大小（补传到此数量）
const int _otkTargetCount = 50;

/// pickle 加密密钥派生所用的存储 key（与身份私钥同级保护）
const String _pickleKeyStorageKey = 'olm_pickle_key';

/// Account pickle 存储键（每设备一份长期身份）
const String _accountPickleStorageKey = 'olm_account_pickle';

/// Session pickle 存储键前缀：`olm_session_<peerUid>:<peerDeviceId>`
const String _sessionPicklePrefix = 'olm_session_';

/// Olm（X3DH + Double Ratchet）单聊 E2EE 服务。
///
/// 零信任架构：
/// - 每设备持 1 个 vodozemac `Account`（长期 Ed25519 + Curve25519 身份键）；
/// - 每个 `(peerUid, peerDeviceId)` 持 1 个 outbound/inbound 共用的 `Session`
///   （Double Ratchet 双向 ratchet，per-message 前向保密）；
/// - Account 私钥经 pickle 加密落 `FlutterSecureStorage`（与设备 RSA 私钥同级保护），
///   pickle 主钥同样在 Keychain/Keystore；
/// - Session（ratchet 状态）只落事务性 `CryptoStore`（SQLCipher），单一权威副本——
///   见 [OlmStateCommitException]；
/// - prekey（one-time / fallback）经服务端发布/claim，服务端只存公钥侧；
/// - 服务端消息管线对 Olm 密文视作不透明 map 透传（与 Megolm 同路径）。
///
/// 与 GroupSessionService 的关系：
/// - 群聊（C2G）继续走 Megolm（vodozemac GroupSession）；
/// - 单聊（C2C）新版默认走 Olm（本服务），获得 per-message PFS；
/// - `e2ee_suite` 字段路由：`OLM.V1` → 本服务，`MEGOLM.V1` → GroupSessionService，
///   `RSA-OAEP-256+AES-256-GCM` → 旧 E2EEService。

/// Olm 密文认证失败（MAC 校验失败 / ciphertext 无效）。
///
/// 语义上区别于「会话不可用」（无 session / 身份查不到 / prekey 建会话失败）：
/// - 会话不可用 → 调用方可安全回退到其它包裹通道（如 room key 的 RSA `ek`）；
/// - **认证失败 → 调用方必须拒绝，禁止降级**——密文已到解密阶段却校验失败，
///   意味着被篡改或遭 downgrade 注入，降级会打开 downgrade attack surface（ADR 13 §4）。
class OlmAuthenticationException implements Exception {
  OlmAuthenticationException(this.message);
  final String message;
  @override
  String toString() => 'OlmAuthenticationException: $message';
}

/// E2EE-030: 密码学状态无法**原子持久化**（事务性 CryptoStore 不可用）。
///
/// ADR 14 §4.2 不变量 7：密码学状态更新要么与消息状态同时提交，要么全部回滚；
/// 不得出现「密文已发送但 ratchet 状态未持久化」的可重复密钥状态。因此
/// CryptoStore 不可用时必须 fail-closed 拒绝加/解密，**不得**退化成只写
/// FlutterSecureStorage——那样一次 DB 不可用窗口 + 进程重启就会让 ratchet
/// 回滚到旧状态并重用已消费的 message key（PFS 失效）。
class OlmStateCommitException implements Exception {
  OlmStateCommitException(this.message);
  final String message;
  @override
  String toString() => 'OlmStateCommitException: $message';
}

/// S2.3: 入站消息重复投递（dedupe 命中）。
///
/// 调用方应捕获此异常并静默跳过（消息已处理过），不视为错误。
class DuplicateMessageException implements Exception {
  DuplicateMessageException(this.messageId);
  final String messageId;
  @override
  String toString() => 'DuplicateMessageException: $messageId';
}

/// S3: 对端 identity key 发生变化（TOFU 比对失败）。
///
/// 可能原因：对端换机/重装、或 MITM 攻击。UI 层应提示用户确认。
class IdentityChangedException implements Exception {
  IdentityChangedException({
    required this.peerUid,
    required this.peerDeviceId,
    required this.oldFingerprint,
    required this.newFingerprint,
  });
  final String peerUid;
  final String peerDeviceId;
  final String oldFingerprint;
  final String newFingerprint;
  @override
  String toString() =>
      'IdentityChangedException: $peerUid:$peerDeviceId '
      'old=${oldFingerprint.substring(0, 8)}… new=${newFingerprint.substring(0, 8)}…';
}

class OlmSessionService {
  static final OlmSessionService _instance = OlmSessionService._internal();
  static OlmSessionService get to => _instance;
  OlmSessionService._internal();

  static bool _vodReady = false;
  static Future<void>? _initFuture;

  /// 内存中的 Account（长期身份，懒加载自 pickle）
  vod.Account? _account;

  /// 内存中的 Session 缓存：`$peerUid:$peerDeviceId` → Session
  final Map<String, vod.Session> _sessions = {};

  /// 每对端一把锁：串行化 encrypt/decrypt，避免 ratchet 推进竞态
  final Map<String, Lock> _sessionLocks = {};

  /// Account 操作串行锁（identity 上报、OTK 补传等）
  final Lock _accountLock = Lock();

  /// S2.3: 事务性密码存储（SQLCipher DB）。懒加载，DB 不可用时回退 SecureStorage。
  CryptoStore? _cryptoStore;

  /// 测试专用：清除缓存的 CryptoStore 和 sessions，防止单测之间因全局 singleton 共享关闭的数据库连接而导致 database_closed 错误。
  void resetForTest() {
    _cryptoStore = null;
    _sessions.clear();
  }

  /// 获取 CryptoStore 实例（懒初始化）。DB 不可用返回 null。
  Future<CryptoStore?> get cryptoStore async {
    if (_cryptoStore != null) return _cryptoStore;
    final db = await SqliteService.to.db;
    if (db == null) return null;
    _cryptoStore = CryptoStore(db);
    await _cryptoStore!.ensureSchema();
    return _cryptoStore;
  }

  // ===== 原生库懒加载（与 GroupSessionService 同模式）=====

  Future<void> ensureInitialized() async {
    if (_vodReady) return;
    _initFuture ??= fvod.init();
    try {
      await _initFuture;
      _vodReady = true;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  @visibleForTesting
  static void debugMarkVodReady() => _vodReady = true;

  // ===== pickle 加密密钥（设备级，与身份私钥同级）=====

  Future<Uint8List> _pickleKey() async {
    final existing = await StorageSecureService.to.read(
      key: _pickleKeyStorageKey,
    );
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64.decode(base64.normalize(existing));
      // Olm pickle key 固定 32 字节
      if (bytes.length == 32) return Uint8List.fromList(bytes);
    }
    // CSPRNG 生成 32 字节主钥（ADR 07 §2：Olm pickle key 是 Critical 级 secret，
    // 必须密码学随机；禁止时间戳/计数器等可预测源，否则 pickle 静态加密可被预测破解 T5）。
    final key = _secureBytes(32);
    await StorageSecureService.to.write(
      key: _pickleKeyStorageKey,
      value: base64.encode(key),
    );
    return key;
  }

  /// CSPRNG 生成 [length] 字节。`Random.secure()` 走平台原生熵源
  /// （iOS SecRandomCopyBytes / Android SecureRandom / 桌面 OS RNG），与
  /// db_encryption_key_service / e2ee_service 同一随机源。
  Uint8List _secureBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  /// 测试挂钩：暴露 CSPRNG 字节生成，供守护测试验证熵源
  /// （olm_pickle_key_csprng_test，映射 ADR 08 T5）。
  @visibleForTesting
  Uint8List debugSecureBytes(int length) => _secureBytes(length);

  // ===== Account（长期身份）管理 =====

  /// 加载或创建本设备的 Olm Account。
  /// 首次调用会生成新身份键并触发服务端上报。
  Future<vod.Account> _loadOrCreateAccount() async {
    if (_account != null) return _account!;
    final pickleKey = await _pickleKey();
    final stored = await StorageSecureService.to.read(
      key: _accountPickleStorageKey,
    );
    if (stored != null && stored.isNotEmpty) {
      try {
        _account = vod.Account.fromPickleEncrypted(
          pickle: stored,
          pickleKey: pickleKey,
        );
        return _account!;
      } catch (e, s) {
        AppLogger.error('[olm] account unpickle failed, regenerating', e, s);
        // pickle 损坏：重建身份（旧 Session 因依赖旧身份将失效，符合密钥重置语义）
      }
    }
    // 首次生成
    _account = vod.Account();
    await _persistAccount(pickleKey);
    return _account!;
  }

  Future<void> _persistAccount(Uint8List pickleKey) async {
    final account = _account;
    if (account == null) return;
    final pickle = account.toPickleEncrypted(pickleKey);
    await StorageSecureService.to.write(
      key: _accountPickleStorageKey,
      value: pickle,
    );
  }

  /// 上报设备 Olm 身份键 + 首批 prekey 到服务端（登录/换设备后调用）。
  Future<void> publishIdentityAndPrekeys({String? deviceType}) async {
    await ensureInitialized();
    await _accountLock.synchronized(() async {
      final account = await _loadOrCreateAccount();
      final identityKeys = account.identityKeys;
      final ed25519 = identityKeys.ed25519.toBase64();
      final curve25519 = identityKeys.curve25519.toBase64();
      // 用 Ed25519 私钥对 curve25519 公钥签名（防服务端篡改，对端可验签）
      final signature = account.sign(curve25519).toBase64();

      // 上报身份键
      await OlmApi().reportIdentity(
        deviceId: deviceId,
        deviceType: deviceType ?? 'unknown',
        ed25519Key: ed25519,
        curve25519Key: curve25519,
        signature: signature,
      );

      // 生成并上报首批 one-time keys（首次注册：池必然为空，直接铺满）
      await _refillOneTimeKeys(account, seed: true);

      // 生成并上报 fallback key
      account.generateFallbackKey();
      final fbKey = account.fallbackKey;
      if (fbKey.isNotEmpty) {
        final entry = fbKey.entries.first;
        await OlmApi().reportFallbackKey(
          deviceId: deviceId,
          keyId: entry.key,
          keyBase64: entry.value.toBase64(),
        );
      }
      account.markKeysAsPublished();
      await _persistAccount(await _pickleKey());
    });
  }

  /// OTK 池低水位补传：剩余 < _otkLowWaterMark 时补到 _otkTargetCount。
  ///
  /// [seed] 为首次注册：此时池必然为空，不必也不该依赖查询——否则一次查询
  /// 失败就会让新设备永远没有 OTK。
  Future<int> _refillOneTimeKeys(
    vod.Account account, {
    bool seed = false,
  }) async {
    // 查询剩余（服务端计数，确保多端一致）。null = 未知，**不是** 0。
    final remaining = seed ? null : await OlmApi().countPrekeys();
    final need = otkRefillCount(
      remaining: remaining,
      lowWaterMark: _otkLowWaterMark,
      targetCount: _otkTargetCount,
      seed: seed,
    );
    if (need <= 0) return 0;
    account.generateOneTimeKeys(need);
    final otkMap = account.oneTimeKeys;
    final keys = <Map<String, String>>[];
    for (final entry in otkMap.entries) {
      keys.add({'key_id': entry.key, 'key_base64': entry.value.toBase64()});
    }
    if (keys.isEmpty) return 0;
    final uploaded = await OlmApi().reportPrekeys(
      deviceId: deviceId,
      keys: keys,
    );
    account.markKeysAsPublished();
    iPrint(
      '[olm] OTK refill: remaining=${remaining ?? "unknown"} uploaded=$uploaded',
    );
    return uploaded;
  }

  // ===== Session（每对端 DR 会话）管理 =====

  String _sessionKey(String peerUid, String peerDeviceId) =>
      '$_sessionPicklePrefix$peerUid:$peerDeviceId';

  /// E2EE-030: 取事务存储；不可用时驱逐内存会话副本并 fail-closed。
  ///
  /// 驱逐是必需的：`session.encrypt/decrypt` 会就地推进内存中的 ratchet，若此时
  /// 无法持久化又保留内存副本，就会出现「内存已推进、磁盘未推进」的分叉——进程
  /// 重启后回滚到磁盘状态，重用已消费的 message key（ADR 14 §4.2 不变量 6/7）。
  Future<CryptoStore> _requireStore(String peerUid, String peerDeviceId) async {
    final store = await cryptoStore;
    if (store == null) {
      _sessions.remove(_sessionKey(peerUid, peerDeviceId));
      throw OlmStateCommitException(
        'crypto store unavailable; refusing to advance ratchet for '
        '$peerUid:$peerDeviceId',
      );
    }
    return store;
  }

  Future<vod.Session?> _loadSession(String peerUid, String peerDeviceId) async {
    final key = _sessionKey(peerUid, peerDeviceId);
    final cached = _sessions[key];
    if (cached != null) return cached;
    final pickleKey = await _pickleKey();

    // E2EE-030: 事务存储（SQLCipher）是 ratchet 状态的唯一权威副本
    final store = await _requireStore(peerUid, peerDeviceId);
    var stored = await store.loadSession(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
    );

    // 升级路径：旧版本把同一份 pickle 双写在 SecureStorage。此处一次性导入并
    // **立即删除** legacy 副本——两份状态长期并存时，任一侧漏写都会在重启后被
    // 另一侧的陈旧值覆盖，造成 ratchet 回滚与 message key 重用。
    if (stored == null || stored.isEmpty) {
      final legacy = await StorageSecureService.to.read(key: key);
      if (legacy != null && legacy.isNotEmpty) {
        await store.persistSession(
          peerUid: peerUid,
          peerDeviceId: peerDeviceId,
          pickle: legacy,
        );
        await StorageSecureService.to.delete(key: key);
        stored = legacy;
      }
    }
    if (stored == null || stored.isEmpty) return null;

    try {
      final session = vod.Session.fromPickleEncrypted(
        pickle: stored,
        pickleKey: pickleKey,
      );
      _sessions[key] = session;
      return session;
    } catch (e, s) {
      AppLogger.error(
        '[olm] session unpickle failed $peerUid:$peerDeviceId',
        e,
        s,
      );
      return null;
    }
  }

  /// E2EE-030: 只写事务存储；不可提交则 fail-closed（不再双写 SecureStorage）。
  Future<void> _persistSession(
    String peerUid,
    String peerDeviceId,
    vod.Session session,
  ) async {
    final store = await _requireStore(peerUid, peerDeviceId);
    final pickleKey = await _pickleKey();
    await store.persistSession(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
      pickle: session.toPickleEncrypted(pickleKey),
    );
    _sessions[_sessionKey(peerUid, peerDeviceId)] = session;
  }

  // ===== 会话标识（PFv3 protected_header.session_ref）=====

  /// 取得与 [peerUid]/[peerDeviceId] 的 Olm 会话标识（必要时先完成 X3DH 协商）。
  ///
  /// **为什么需要它（E2EE-025）**：PFv3 的 `protected_header.session_ref` 是
  /// `ProtectedFrameV3.buildProtectedHeader` 的**入参**，而 header 又要先进
  /// inner_frame 才能被 `protocol.encrypt` 加密——于是 session id 必须在加密
  /// **之前**就已知。但 `encryptC2CMessage` 的 session 是在其内部
  /// load-or-establish 出来的，返回值才带 sessionId，形成循环依赖。
  /// `E2eeSessionProtocol` 接口被 ADR 02 §10 冻结，无法加方法取该值，
  /// 故在本服务上单独暴露一个查询入口（方案 A）。
  ///
  /// 与 [encryptC2CMessage] 共用同一把 per-device 锁与同一套
  /// load-or-establish 逻辑，因此本方法返回后再调 encrypt，**绝大多数情况下**
  /// 拿到的是同一个 session。
  ///
  /// ⚠️ 已知竞态：两次调用之间若会话被替换（例如并发触发重新协商），
  /// header 里的 `session_ref` 会与实际加密所用 session 不一致。后果是接收侧
  /// `_validateContextBinding` 判 `context_mismatch_session_id` 并**拒收该条
  /// 消息**——方向 fail-closed，不产生可被利用的绑定弱化。
  ///
  /// ⚠️ 副作用：对某设备**首次**发消息时，claim prekey 的网络请求会发生在
  /// 本方法内（而非 encrypt 内），时序比改动前提前一步。
  Future<String> ensureSessionId(String peerUid, String peerDeviceId) async {
    await ensureInitialized();
    final lockKey = '$peerUid:$peerDeviceId';
    final lock = _sessionLocks.putIfAbsent(lockKey, () => Lock());
    return lock.synchronized(() async {
      final loaded = await _loadSession(peerUid, peerDeviceId);
      if (loaded != null) return loaded.sessionId;

      // 新建会话必须**立即持久化**：`_establishOutboundSession` 只返回 session，
      // 既不写 `_sessions` 缓存也不落库（持久化由其调用方负责）。若这里不落，
      // 随后的 `encryptC2CMessage` 会再走一次 `_establishOutboundSession`，
      // 结果是：① 再 claim 一个对端 OTK（无谓消耗，助长 OTK 耗尽）；
      // ② 拿到**另一个** session id，与已写进 header 的 `session_ref` 必然不符，
      // 每条首发消息都会被接收侧判 `context_mismatch_session_id`。
      final session = await _establishOutboundSession(peerUid, peerDeviceId);
      await _persistSession(peerUid, peerDeviceId, session);
      return session.sessionId;
    });
  }

  // ===== 加密（出站，X3DH 协商 + DR 加密）=====

  /// 加密一条单聊消息（C2C）。
  /// 首次对某对端设备：claim prekey → createOutboundSession → encrypt(type=0 prekey message)。
  /// 后续：直接 session.encrypt（type=1 normal）。
  ///
  /// S2.3: 当 [outboxId] + [outboxPayload] 非空且 CryptoStore 可用时，
  /// ratchet advance 与 outbox 写入在同一 SQLite 事务内完成（崩溃安全）。
  Future<({String sessionId, int messageType, String ciphertext})>
  encryptC2CMessage({
    required String peerUid,
    required String peerDeviceId,
    required String plaintext,
    String? outboxId,
    String? outboxPayload,
  }) async {
    await ensureInitialized();
    final lockKey = '$peerUid:$peerDeviceId';
    final lock = _sessionLocks.putIfAbsent(lockKey, () => Lock());
    return lock.synchronized(() async {
      // 首次（无本地 session）：claim prekey + X3DH 协商
      final session =
          await _loadSession(peerUid, peerDeviceId) ??
          await _establishOutboundSession(peerUid, peerDeviceId);
      final result = session.encrypt(plaintext);

      // S2.3: 原子 ratchet + outbox
      if (outboxId != null && outboxPayload != null) {
        final store = await _requireStore(peerUid, peerDeviceId);
        final pickleKey = await _pickleKey();
        await store.persistSessionWithOutbox(
          peerUid: peerUid,
          peerDeviceId: peerDeviceId,
          pickle: session.toPickleEncrypted(pickleKey),
          outboxId: outboxId,
          payload: outboxPayload,
        );
        _sessions[_sessionKey(peerUid, peerDeviceId)] = session;
      } else {
        await _persistSession(peerUid, peerDeviceId, session);
      }

      return (
        sessionId: session.sessionId,
        messageType: result.messageType,
        ciphertext: result.ciphertext,
      );
    });
  }

  /// room key 分发专用：用与对端设备的 Olm 会话包裹 [exportedKey]（Megolm
  /// 导出的 room key），返回 `(type, body)` 供 ADR 13 §3.1 双包线格式的 `olm`
  /// 子对象填充（`sid` 由调用方以本设备 id 填）。
  ///
  /// 失败（对端无 Olm 身份 / claim OTK 失败 / 建会话异常）返回 `null`——语义为
  /// 「该设备不可 Olm，调用方仅写 RSA `ek` 回退」，不阻断整体分发（ADR 13 §4）。
  Future<({int type, String body})?> wrapRoomKey({
    required String peerUid,
    required String peerDeviceId,
    required String exportedKey,
  }) async {
    try {
      final r = await encryptC2CMessage(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        plaintext: exportedKey,
      );
      return (type: r.messageType, body: r.ciphertext);
    } on Object catch (e) {
      iPrint('[olm] wrapRoomKey 回退 RSA（$peerUid:$peerDeviceId）: $e');
      return null;
    }
  }

  /// X3DH 协商：claim 对端 prekey + 用本端身份建出站 Session。
  Future<vod.Session> _establishOutboundSession(
    String peerUid,
    String peerDeviceId,
  ) async {
    final account = await _loadOrCreateAccount();
    // E2EE-062：幂等键。同一次建会话尝试的重投（MessageRetry 退避重发会重新
    // 进入本方法）带同一个 id，服务端只消费一条 OTK；成功后丢弃换新。
    final requestId = OlmClaimRequestId.issue(peerUid, peerDeviceId);
    // claim：服务端返回 one_time（优先）或 fallback + 对端 identity
    final claim = await OlmApi().claimKey(
      targetUid: peerUid,
      deviceId: peerDeviceId,
      requestId: requestId,
    );
    final identity = claim['identity'] as Map<String, dynamic>;
    final theirCurve25519 = identity['curve25519_key'] as String;
    final oneTimeKey = claim['key_base64'] as String;

    // P0-1: 验证 identity key 签名（防服务端/MITM 替换公钥）
    _verifyIdentitySignature(identity, peerUid, peerDeviceId);

    // S3 TOFU: 首次固定 fingerprint，后续比对（变化 → fail-closed）
    await _enforceTofu(peerUid, peerDeviceId, theirCurve25519);

    final session = account.createOutboundSession(
      identityKey: vod.Curve25519PublicKey.fromBase64(theirCurve25519),
      oneTimeKey: vod.Curve25519PublicKey.fromBase64(oneTimeKey),
    );
    // 这条 OTK 已经变成一条活会话；后续任何**新的**建会话都应消费新 OTK。
    // 在此处（而非持久化成功后）丢弃是有意的安全方向：宁可多消费一条，
    // 也不能让两条不同的会话共用同一条 one-time prekey。
    OlmClaimRequestId.complete(peerUid, peerDeviceId);
    return session;
  }

  /// P0-1: 验证对端 identity key 的 Ed25519 自签名。
  /// 委托 [verifyIdentitySignature]（独立可测试），失败抛 OlmAuthenticationException。
  void _verifyIdentitySignature(
    Map<String, dynamic> identity,
    String peerUid,
    String peerDeviceId,
  ) {
    try {
      verifyIdentitySignature(identity, context: '$peerUid:$peerDeviceId');
    } on IdentityVerificationException catch (e) {
      throw OlmAuthenticationException(e.message);
    }
  }

  /// S3 TOFU: 比对 identity fingerprint，首次固定，变化则 fail-closed。
  ///
  /// [curve25519Base64] 为对端 identity curve25519 公钥（已通过 Ed25519 签名验证）。
  /// CryptoStore 不可用时跳过（降级为无 TOFU，不阻塞通信）。
  Future<void> _enforceTofu(
    String peerUid,
    String peerDeviceId,
    String curve25519Base64,
  ) async {
    final store = await cryptoStore;
    if (store == null) return; // 降级：无持久化则跳过 TOFU

    final pinned = await store.loadPinnedFingerprint(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
    );

    if (pinned == null) {
      // Trust On First Use：首次通信，固定 fingerprint
      await store.pinIdentity(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        fingerprint: curve25519Base64,
      );
      return;
    }

    if (pinned != curve25519Base64) {
      // Identity 变化：可能是换机、也可能是 MITM → fail-closed
      throw IdentityChangedException(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        oldFingerprint: pinned,
        newFingerprint: curve25519Base64,
      );
    }
    // 匹配：正常通过
  }

  // ===== 解密（入站，X3DH 接收 + DR 解密）=====

  /// 解密一条单聊消息（C2C）。
  /// 首次收到某对端的消息（messageType=0 prekey）：createInboundSession。
  /// 后续（messageType=1）：直接 session.decrypt。
  ///
  /// S2.3: 当 [messageId] 非空且 CryptoStore 可用时，dedupe 检查与 ratchet
  /// advance 在同一 SQLite 事务内完成——重复投递不会推进 ratchet。
  Future<String> decryptC2CMessage({
    required String peerUid,
    required String peerDeviceId,
    required int messageType,
    required String ciphertext,
    String? messageId,
  }) async {
    await ensureInitialized();
    final lockKey = '$peerUid:$peerDeviceId';
    final lock = _sessionLocks.putIfAbsent(lockKey, () => Lock());
    return lock.synchronized(() async {
      // S2.3: 快速 dedupe 前置检查（避免无谓解密开销）
      if (messageId != null) {
        final store = await cryptoStore;
        if (store != null && await store.isDuplicate(messageId)) {
          throw DuplicateMessageException(messageId);
        }
      }

      final account = await _loadOrCreateAccount();
      var session = await _loadSession(peerUid, peerDeviceId);

      if (messageType == 0) {
        // pre-key message：首次接收，建入站 Session
        final theirIdentity = await _lookupPeerIdentityKey(
          peerUid,
          peerDeviceId,
        );
        late final dynamic result;
        try {
          result = account.createInboundSession(
            theirIdentityKey: vod.Curve25519PublicKey.fromBase64(theirIdentity),
            preKeyMessageBase64: ciphertext,
          );
        } on Object catch (e) {
          throw OlmAuthenticationException(
            'createInboundSession 失败（prekey 密文无效）: $e',
          );
        }
        session = result.session as vod.Session;
        await _persistSessionWithDedupe(
          peerUid,
          peerDeviceId,
          session,
          messageId,
        );
        // 入站会话建立后，本端可能需补传 OTK
        unawaited(
          _refillOneTimeKeys(account).then((_) async {
            final pickleKey = await _pickleKey();
            await _persistAccount(pickleKey);
          }),
        );
        return result.plaintext as String;
      }

      // normal message
      if (session == null) {
        throw Exception(
          'olm normal message but no inbound session: $peerUid:$peerDeviceId',
        );
      }
      final String plaintext;
      try {
        plaintext = session.decrypt(
          messageType: messageType,
          ciphertext: ciphertext,
        );
      } on Object catch (e) {
        throw OlmAuthenticationException('olm decrypt 认证失败: $e');
      }
      await _persistSessionWithDedupe(
        peerUid,
        peerDeviceId,
        session,
        messageId,
      );
      return plaintext;
    });
  }

  /// S2.3: 接收侧原子持久化——dedupe + ratchet advance 同事务。
  /// [messageId] 为 null 时退化为普通 _persistSession。
  Future<void> _persistSessionWithDedupe(
    String peerUid,
    String peerDeviceId,
    vod.Session session,
    String? messageId,
  ) async {
    if (messageId != null) {
      final store = await _requireStore(peerUid, peerDeviceId);
      final pickleKey = await _pickleKey();
      final accepted = await store.dedupeAndPersistSession(
        messageId: messageId,
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        pickle: session.toPickleEncrypted(pickleKey),
      );
      if (!accepted) {
        throw DuplicateMessageException(messageId);
      }
      _sessions[_sessionKey(peerUid, peerDeviceId)] = session;
    } else {
      await _persistSession(peerUid, peerDeviceId, session);
    }
  }

  /// 查询对端 curve25519 身份键（createInboundSession 需要）
  Future<String> _lookupPeerIdentityKey(
    String peerUid,
    String peerDeviceId,
  ) async {
    final identity = await OlmApi().getIdentity(
      uid: peerUid,
      deviceId: peerDeviceId,
    );
    // P0-1: 入站路径同样验证 identity 签名（防 MITM 替换公钥）
    _verifyIdentitySignature(identity, peerUid, peerDeviceId);
    final curve25519 = identity['curve25519_key'] as String;
    // S3 TOFU: 入站同样执行 fingerprint 比对
    await _enforceTofu(peerUid, peerDeviceId, curve25519);
    return curve25519;
  }

  // ===== 清理 =====

  /// 清除所有内存与持久化的 Olm 状态（退出登录/换设备时调用）。
  Future<void> clearAll() async {
    _sessions.clear();
    _sessionLocks.clear();
    _account = null;
    // E2EE-030: ratchet 状态只在事务存储中，`olm_` 前缀擦除覆盖不到，须显式清。
    // DB 不可用时不阻断登出——SQLCipher 主钥同时被销毁，残留行不可读。
    final store = await cryptoStore;
    await store?.deleteAllSessions();
    await StorageSecureService.to.delete(key: _accountPickleStorageKey);
    await StorageSecureService.to.delete(key: _pickleKeyStorageKey);
    // 升级前版本遗留的 `olm_session_*` 明面副本由 E2eeSecretInventory 的
    // `olm_` 前缀全量 wipe 兜底。
    iPrint('[olm] all state cleared');
  }
}

/// 「fire and forget」辅助（避免 await 阻塞主流程）。
void unawaited(Future<void> future) {
  // ignore: unawaited_futures
  future.catchError((Object e, StackTrace s) {
    AppLogger.error('[olm] background task failed', e, s);
  });
}
