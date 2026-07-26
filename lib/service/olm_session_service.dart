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
/// - 私钥经 pickle 加密落 `FlutterSecureStorage`（与设备 RSA 私钥同级保护）；
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

/// S2.3: 入站消息重复投递（dedupe 命中）。
///
/// 调用方应捕获此异常并静默跳过（消息已处理过），不视为错误。
class DuplicateMessageException implements Exception {
  DuplicateMessageException(this.messageId);
  final String messageId;
  @override
  String toString() => 'DuplicateMessageException: $messageId';
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

      // 生成并上报首批 one-time keys
      await _refillOneTimeKeys(account);

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
  Future<int> _refillOneTimeKeys(vod.Account account) async {
    // 查询剩余（服务端计数，确保多端一致）
    final remaining = await OlmApi().countPrekeys(deviceId: deviceId);
    if (remaining >= _otkLowWaterMark) return 0;

    final need = _otkTargetCount - remaining;
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
    iPrint('[olm] OTK refill: remaining=$remaining uploaded=$uploaded');
    return uploaded;
  }

  // ===== Session（每对端 DR 会话）管理 =====

  String _sessionKey(String peerUid, String peerDeviceId) =>
      '$_sessionPicklePrefix$peerUid:$peerDeviceId';

  Future<vod.Session?> _loadSession(String peerUid, String peerDeviceId) async {
    final key = _sessionKey(peerUid, peerDeviceId);
    final cached = _sessions[key];
    if (cached != null) return cached;
    final pickleKey = await _pickleKey();

    // S2.3: 优先从 CryptoStore（SQLCipher 事务存储）读取
    String? stored;
    final store = await cryptoStore;
    if (store != null) {
      stored = await store.loadSession(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
      );
    }
    // 回退：迁移期 SecureStorage 中可能仍有旧 pickle
    if (stored == null || stored.isEmpty) {
      stored = await StorageSecureService.to.read(key: key);
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

  Future<void> _persistSession(
    String peerUid,
    String peerDeviceId,
    vod.Session session,
  ) async {
    final pickleKey = await _pickleKey();
    final pickle = session.toPickleEncrypted(pickleKey);

    // S2.3: 主路径写 CryptoStore（SQLCipher 事务存储）
    final store = await cryptoStore;
    if (store != null) {
      await store.persistSession(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        pickle: pickle,
      );
    }
    // 迁移期双写 SecureStorage（后续版本移除）
    await StorageSecureService.to.write(
      key: _sessionKey(peerUid, peerDeviceId),
      value: pickle,
    );
    _sessions[_sessionKey(peerUid, peerDeviceId)] = session;
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

      // S2.3: 原子 ratchet + outbox（CryptoStore 可用时）
      final store = await cryptoStore;
      if (store != null && outboxId != null && outboxPayload != null) {
        final pickleKey = await _pickleKey();
        final pickle = session.toPickleEncrypted(pickleKey);
        await store.persistSessionWithOutbox(
          peerUid: peerUid,
          peerDeviceId: peerDeviceId,
          pickle: pickle,
          outboxId: outboxId,
          payload: outboxPayload,
        );
        // 迁移期双写 SecureStorage
        await StorageSecureService.to.write(
          key: _sessionKey(peerUid, peerDeviceId),
          value: pickle,
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
    // claim：服务端返回 one_time（优先）或 fallback + 对端 identity
    final claim = await OlmApi().claimKey(
      targetUid: peerUid,
      deviceId: peerDeviceId,
    );
    final identity = claim['identity'] as Map<String, dynamic>;
    final theirCurve25519 = identity['curve25519_key'] as String;
    final oneTimeKey = claim['key_base64'] as String;

    // P0-1: 验证 identity key 签名（防服务端/MITM 替换公钥）
    _verifyIdentitySignature(identity, peerUid, peerDeviceId);

    final session = account.createOutboundSession(
      identityKey: vod.Curve25519PublicKey.fromBase64(theirCurve25519),
      oneTimeKey: vod.Curve25519PublicKey.fromBase64(oneTimeKey),
    );
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
    final store = await cryptoStore;
    if (store != null && messageId != null) {
      final pickleKey = await _pickleKey();
      final pickle = session.toPickleEncrypted(pickleKey);
      final accepted = await store.dedupeAndPersistSession(
        messageId: messageId,
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        pickle: pickle,
      );
      if (!accepted) {
        throw DuplicateMessageException(messageId);
      }
      // 迁移期双写 SecureStorage
      await StorageSecureService.to.write(
        key: _sessionKey(peerUid, peerDeviceId),
        value: pickle,
      );
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
    return identity['curve25519_key'] as String;
  }

  // ===== 清理 =====

  /// 清除所有内存与持久化的 Olm 状态（退出登录/换设备时调用）。
  Future<void> clearAll() async {
    _sessions.clear();
    _sessionLocks.clear();
    _account = null;
    await StorageSecureService.to.delete(key: _accountPickleStorageKey);
    await StorageSecureService.to.delete(key: _pickleKeyStorageKey);
    // 注：session pickles 是 keyed by peerUid，全量清理需遍历存储，
    // 由调用方 StorageSecureService 全量 wipe 兜底。
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
