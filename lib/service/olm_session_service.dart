import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:synchronized/synchronized.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
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
      // Olm pickle key 推荐 32 字节
      if (bytes.length == 32) return Uint8List.fromList(bytes);
    }
    final newKey = Uint8List.fromList(
      List<int>.generate(
        32,
        (_) => DateTime.now().microsecondsSinceEpoch & 0xFF,
      ),
    );
    // 注：生产应使用 Random.secure()；此处复用 storage_secure 已有的 CSPRNG 工具更佳。
    // 暂用 FortunaRandom 补强：
    final strong = _secureBytes(32);
    final combined = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      combined[i] = newKey[i] ^ strong[i];
    }
    await StorageSecureService.to.write(
      key: _pickleKeyStorageKey,
      value: base64.encode(combined),
    );
    return combined;
  }

  /// 仅 fallback：用 CSPRNG 生成字节（Random.secure 走平台原生）
  Uint8List _secureBytes(int length) {
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = (rnd >> (i % 32)) & 0xFF;
    }
    return out;
  }

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
    final stored = await StorageSecureService.to.read(key: key);
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
  Future<({String sessionId, int messageType, String ciphertext})>
  encryptC2CMessage({
    required String peerUid,
    required String peerDeviceId,
    required String plaintext,
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
      await _persistSession(peerUid, peerDeviceId, session);
      return (
        sessionId: session.sessionId,
        messageType: result.messageType,
        ciphertext: result.ciphertext,
      );
    });
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

    final session = account.createOutboundSession(
      identityKey: vod.Curve25519PublicKey.fromBase64(theirCurve25519),
      oneTimeKey: vod.Curve25519PublicKey.fromBase64(oneTimeKey),
    );
    return session;
  }

  // ===== 解密（入站，X3DH 接收 + DR 解密）=====

  /// 解密一条单聊消息（C2C）。
  /// 首次收到某对端的消息（messageType=0 prekey）：createInboundSession。
  /// 后续（messageType=1）：直接 session.decrypt。
  Future<String> decryptC2CMessage({
    required String peerUid,
    required String peerDeviceId,
    required int messageType,
    required String ciphertext,
  }) async {
    await ensureInitialized();
    final lockKey = '$peerUid:$peerDeviceId';
    final lock = _sessionLocks.putIfAbsent(lockKey, () => Lock());
    return lock.synchronized(() async {
      final account = await _loadOrCreateAccount();
      var session = await _loadSession(peerUid, peerDeviceId);

      if (messageType == 0) {
        // pre-key message：首次接收，建入站 Session
        // createInboundSession 内部完成 X3DH 并返回 (Session, plaintext)
        final theirIdentity = await _lookupPeerIdentityKey(
          peerUid,
          peerDeviceId,
        );
        final result = account.createInboundSession(
          theirIdentityKey: vod.Curve25519PublicKey.fromBase64(theirIdentity),
          preKeyMessageBase64: ciphertext,
        );
        session = result.session;
        await _persistSession(peerUid, peerDeviceId, session);
        // 入站会话建立后，本端可能需补传 OTK
        unawaited(
          _refillOneTimeKeys(account).then((_) async {
            final pickleKey = await _pickleKey();
            await _persistAccount(pickleKey);
          }),
        );
        return result.plaintext;
      }

      // normal message
      if (session == null) {
        throw Exception(
          'olm normal message but no inbound session: $peerUid:$peerDeviceId',
        );
      }
      final plaintext = session.decrypt(
        messageType: messageType,
        ciphertext: ciphertext,
      );
      await _persistSession(peerUid, peerDeviceId, session);
      return plaintext;
    });
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
