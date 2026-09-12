import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:imboy/service/e2ee/vodozemac_init.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:synchronized/synchronized.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';

/// Megolm 会话套件标识（e2ee 元数据 e2ee_suite 字段，区分既有 RSA+AES 套件）
const String kMegolmSuite = 'MEGOLM.V1';

/// ADR 13 room-key-over-Olm：Olm 包裹结果（填 keys[].olm 子对象的 type/body）。
typedef OlmWrapped = ({int type, String body});

/// 发送侧 Olm 包裹回调：对接收设备 [peerDeviceId] 用 Olm 会话包裹 [exportedKey]。
/// 返回 null = 该设备不可 Olm（无身份 / 建会话失败）→ 仅 RSA 回退（ADR 13 §4）。
///
/// peerDeviceId → uid/session 的解析由回调实现方（OlmSessionService）负责，本类型
/// 不引入用户身份映射——crypto payload builder 与 identity/session lookup 解耦。
typedef OlmWrapFn =
    Future<OlmWrapped?> Function(String peerDeviceId, String exportedKey);

/// E2EE 会话服务（vodozemac Megolm，C2G 群聊 + C2C 单聊统一走此套件）
///
/// 零信任架构：
/// - 每个发送者对每个会话域（群 gid / 单聊对端 uid）持有自己的 outbound
///   GroupSession（Megolm 标准语义，单聊即 2 人房间）；
/// - session key 在任何 encrypt 之前导出（棘轮推进后旧 index 不可再导出）；
/// - 导出 key 经 Olm 会话逐设备包裹（v3 Olm-only，E2EE-011；RSA `ek` 仅存于
///   compliance 审计条目），经具名 action
///   `e2ee_room_key` 消息分发（C2G/C2C 同名 action）——服务端视 payload 为
///   不透明字节（后端 EUnit c2g_e2ee_room_key_relayed_opaque_and_skips_gate
///   与 C2C 管道保真集成测试守护透传）；
/// - 接收方设备集合变化 → rotate（新建 session 全量重分发）；
/// - compliance_e2ee 模式：分发列表追加合规公钥包裹条目（审计可解密）。
class GroupSessionService {
  static final GroupSessionService _instance = GroupSessionService._internal();
  static GroupSessionService get to => _instance;
  GroupSessionService._internal();

  static const String _flagKeyPrefix = 'group_e2ee_mode_';
  static const String _inboundKeyPrefix = 'megolm_inbound_';
  static const String roomKeyAction = 'e2ee_room_key';

  /// room key 分发列表条目上限（成员×设备的合理倍数，防超大列表 CPU/内存 DoS）
  static const int _maxRoomKeyEntries = 4096;

  /// P0-2: Megolm outbound session 最大加密消息数（超过则强制 rotate）
  /// Signal 协议建议 100 条/会话；此处取 100 对齐行业实践。
  static const int _maxMessagesPerSession = 100;

  /// P0-2: Megolm outbound session 最大存活时间（7 天，超过则强制 rotate）
  static const int _maxSessionAgeMs = 7 * 24 * 60 * 60 * 1000;

  /// C2C 单聊的会话域前缀（outbound map 键 'c2c:$peerUid'，inbound 存储域 'c2c'）
  static const String c2cScope = 'c2c';

  /// 发送侧：会话域（gid / 'c2c:$peerUid'）→ outbound 会话状态
  final Map<String, _OutboundGroupSession> _outbound = {};

  /// 接收侧：'$storageScope:$sessionId' → inbound 会话（内存缓存，落地在安全存储）
  final Map<String, vod.InboundGroupSession> _inbound = {};
  final Map<String, MegolmHistoryGrant?> _restoredGrants = {};
  final Set<String> _restoredGrantLookups = {};

  /// 成员/设备集合可能已变化的会话域（S2C join/leave 标记，下次发送强刷公钥并 rotate）
  final Set<String> _staleGids = {};

  /// 每会话域一把发送锁：串行化 encrypt，避免 rotate 竞态（被踢成员前向保密缺口）
  final Map<String, Lock> _sendLocks = {};

  /// 清除内存中的 Megolm 会话状态（logout 时由 E2eeSecretInventory 调用；
  /// 落地的 inbound pickles 由 secure storage 前缀清理负责）。
  void clearMemory() {
    _outbound.clear();
    _inbound.clear();
    _restoredGrants.clear();
    _restoredGrantLookups.clear();
    _staleGids.clear();
    _sendLocks.clear();
  }

  /// 懒加载 vodozemac 原生库（失败可重试）
  ///
  /// 状态收口在 [VodozemacInit]：flutter_rust_bridge 的初始化是进程级全局的，
  /// 本类与 OlmSessionService 各存一份就绪标志时，谁先 init 成功，
  /// 另一个必然重复 init 并抛 `Should not initialize flutter_rust_bridge twice`。
  Future<void> ensureInitialized() => VodozemacInit.ensure();

  /// 测试专用：测试进程自行 vod.init(libraryPath:) 后标记就绪
  @visibleForTesting
  static void debugMarkVodReady() => VodozemacInit.debugMarkReady();

  /// 测试专用：捕获 room key 分发，避免单测建立真实 WebSocket。
  /// 生产环境保持 null，仍走 [WebSocketService]。
  @visibleForTesting
  void Function(String chatType, String to, Map<String, dynamic> payload)?
  debugRoomKeySender;

  /// 测试专用：替换发送侧 Olm room-key 包裹器，验证会话服务自身的分发编排。
  /// 生产环境保持 null，仍委托 [OlmSessionService]。
  @visibleForTesting
  OlmWrapFn? debugOlmWrap;

  @visibleForTesting
  Future<E2EEGroupHistoryGrant> Function(String gid, String sessionId)?
  debugHistoryGrantLoader;

  // ===== 群级 E2EE 旗标（来源：S2C group_e2ee_mode 广播 / 群详情 / 收到 room key）=====

  /// 旗标存安全存储（与私钥同级保护，防本机篡改清零导致明文降级）
  Future<bool> isGroupE2EE(String gid) async {
    if (gid.isEmpty) return false;
    final v = await StorageSecureService.to.read(key: '$_flagKeyPrefix$gid');
    return v == '1';
  }

  Future<void> setGroupE2EEMode(String gid, int mode) async {
    // 后端契约 0→1 单向开启；本地只升不降（写 '1' 幂等，无需先读）。
    // 权威来源仅限服务端：group_e2ee_mode S2C 广播 + 群详情同步。
    if (gid.isEmpty || mode != 1) return;
    await StorageSecureService.to.write(key: '$_flagKeyPrefix$gid', value: '1');
    iPrint('[group_session] 群 $gid E2EE 已开启');
  }

  /// 群成员/设备变化标记：下次发送强刷公钥快照并 rotate
  void markGroupStale(String gid) {
    if (gid.isNotEmpty) _staleGids.add(gid);
  }

  @visibleForTesting
  bool debugIsGroupStale(String gid) => _staleGids.contains(gid);

  // ===== 发送侧 =====

  /// 加密一条群消息；必要时自动建会话/rotate 并分发 room key。
  Future<({String sessionId, String ciphertext})> encryptGroupMessage({
    required String gid,
    required String plaintext,
  }) => _encryptScoped(
    scopeKey: gid,
    isGroup: true,
    target: gid,
    plaintext: plaintext,
  );

  /// 加密一条单聊消息（C2C 即 2 人 Megolm 房间，与群聊同一套件/分发机制）
  Future<({String sessionId, String ciphertext})> encryptC2CMessage({
    required String peerUid,
    required String plaintext,
  }) => _encryptScoped(
    scopeKey: '$c2cScope:$peerUid',
    isGroup: false,
    target: peerUid,
    plaintext: plaintext,
  );

  /// 取得群会话域的 outbound Megolm session 标识（必要时 rotate 并分发
  /// room key），**不加密、不推进消息计数**。
  ///
  /// **为什么需要它（E2EE-025 同源，方案 A 的 Megolm 版）**：PFv3 的
  /// `protected_header.session_ref` 是 header 构造入参，而 header 要先进
  /// inner_frame 才能被 `protocol.encrypt` 加密——session id 必须在加密
  /// **之前**就已知。此前发送侧只能先 `encryptGroupMessage`「加密一次」拿
  /// sessionId，该段密文直接丢弃，再由 `E2eeOutboundRouter.encryptV3` 内部
  /// 第二次加密：每条消息 ratchet 推进两步（`_maxMessagesPerSession` 的
  /// 100 条配额实际只发 50 条）并白耗一次加密。与 Olm 侧
  /// [OlmSessionService.ensureSessionId] 同构。
  ///
  /// 与 [encryptGroupMessage] 共用同一把 per-scope 发送锁与同一套 rotate
  /// 判定，返回后调用 encrypt 复用同一会话。
  ///
  /// ⚠️ 已知竞态：本方法与随后的 encrypt 之间若发生 rotate（成员/设备集合
  /// 变化），header 的 `session_ref` 会与实际加密 session 不一致——接收侧
  /// 判 `context_mismatch_session_id` 拒收该条，方向 fail-closed（与 Olm
  /// 侧 ensureSessionId 一致，不产生可利用的绑定弱化）。
  Future<String> ensureOutboundSession({required String gid}) async {
    await ensureInitialized();
    final lock = _sendLocks.putIfAbsent(gid, () => Lock());
    return lock.synchronized(() async {
      final outbound = await _resolveOutbound(
        isGroup: true,
        scopeKey: gid,
        target: gid,
      );
      return outbound.sessionId;
    });
  }

  /// 同一会话域的并发发送串行化：stale 标记消费→公钥刷新→rotate→encrypt 必须原子，
  /// 否则被踢成员离群到 rotate 之间的窗口内会有新消息仍用旧 session（前向保密缺口）。
  Future<({String sessionId, String ciphertext})> _encryptScoped({
    required String scopeKey,
    required bool isGroup,
    required String target,
    required String plaintext,
  }) async {
    await ensureInitialized();
    final lock = _sendLocks.putIfAbsent(scopeKey, () => Lock());
    return lock.synchronized(() async {
      final outbound = await _resolveOutbound(
        isGroup: isGroup,
        scopeKey: scopeKey,
        target: target,
      );
      final ciphertext = outbound.session.encrypt(plaintext);
      outbound.messageCount++;
      return (sessionId: outbound.sessionId, ciphertext: ciphertext);
    });
  }

  /// 发送锁内调用：确保会话域上存在与当前设备集合匹配的 outbound 会话
  /// （设备集合变化 / 消息数 / 存活时间超限 → rotate + 全量重分发）。
  Future<_OutboundGroupSession> _resolveOutbound({
    required bool isGroup,
    required String scopeKey,
    required String target,
  }) async {
    final force = _staleGids.remove(scopeKey);
    final deviceKeys = isGroup
        ? await E2EEService.getGroupDevicePublicKeys(
            target,
            forceRefresh: force,
          )
        : await E2EEService.getUserDevicePublicKeys(
            target,
            forceRefresh: force,
          );
    final didToPem = deviceKeys['didToPem'] ?? const <String, String>{};
    if (didToPem.isEmpty) {
      throw Exception('no_recipient_keys');
    }
    final didSet = didToPem.keys.toSet();

    var outbound = _outbound[scopeKey];
    // P0-2: 设备集合变化 OR 消息数/时间超限 → rotate
    final needsRotate =
        outbound == null ||
        !setEquals(outbound.dids, didSet) ||
        outbound.messageCount >= _maxMessagesPerSession ||
        (DateTime.now().millisecondsSinceEpoch - outbound.createdAt) >=
            _maxSessionAgeMs;
    if (needsRotate) {
      // ponytail: 任何成员/设备集合变化都整体 rotate + 全量重分发；
      // 若 key 消息量成为负担，可对"仅新增设备"改为 exportAt(当前 index) 定向补发
      outbound = await _rotateAndDistribute(
        isGroup: isGroup,
        target: target,
        didToPem: didToPem,
        didToKid: deviceKeys['didToKid'] ?? const <String, String>{},
        didToUid: deviceKeys['didToUid'] ?? const <String, String>{},
        didSet: didSet,
      );
      _outbound[scopeKey] = outbound;
    }
    return outbound;
  }

  Future<_OutboundGroupSession> _rotateAndDistribute({
    required bool isGroup,
    required String target,
    required Map<String, String> didToPem,
    required Map<String, String> didToKid,
    required Map<String, String> didToUid,
    required Set<String> didSet,
  }) async {
    final session = vod.GroupSession();
    final sessionId = session.sessionId;
    // 棘轮语义：必须在任何 encrypt 之前导出（此后 exportAt(0) 返 null）
    final exported = session.toInbound().exportAt(0);
    if (exported == null || exported.isEmpty) {
      throw Exception('megolm_export_failed');
    }
    // 自持一份 inbound（本机换端恢复 / 历史重解密）
    await _storeInbound(isGroup ? target : c2cScope, sessionId, exported);

    final compliance = await _complianceKeyEntry(exported);
    // 发送端在上面已经保存了同一份 outbound 对应的 inbound session，
    // 不需要再把 room key 发回自己的设备。后端返回的群设备快照包含
    // 当前设备，若原样放入 payload，本机收到后会因没有 self-to-self
    // Olm 入站会话而拒绝该条目；更重要的是严格模式会误把本机条目当成
    // “必须成功包裹的远端设备”。设备集合 didSet 仍保留完整快照，用于
    // 成员/设备变化检测与后续 rotate。
    final recipientDidToPem = Map<String, String>.from(didToPem)
      ..remove(deviceId);
    final recipientDidToKid = Map<String, String>.from(didToKid)
      ..remove(deviceId);
    final recipientDidToUid = Map<String, String>.from(didToUid)
      ..remove(deviceId);
    final payload = buildRoomKeyPayload(
      gid: isGroup ? target : null,
      sessionId: sessionId,
      exportedKey: exported,
      didToPem: recipientDidToPem,
      didToKid: recipientDidToKid,
      extraKeys: compliance == null ? const [] : [compliance],
    );
    // ADR 13 双包：给可 Olm 的接收设备追加 olm 子对象（RSA ek 保留）。
    // did→uid 由分发列表解析（C2C 兜底为对端 target），委托 OlmSessionService 建会话。
    await attachOlmWraps(
      keys: payload['keys'] as List,
      exportedKey: exported,
      senderDeviceId: deviceId,
      olmWrap: (String did, String exportedKey) async {
        final debugWrap = debugOlmWrap;
        if (debugWrap != null) return debugWrap(did, exportedKey);
        final uid = recipientDidToUid[did] ?? (isGroup ? '' : target);
        if (uid.isEmpty) return null;
        return OlmSessionService.to.wrapRoomKey(
          peerUid: uid,
          peerDeviceId: did,
          exportedKey: exportedKey,
        );
      },
    );
    _sendRoomKeyMessage(isGroup ? 'C2G' : 'C2C', target, payload);
    iPrint(
      '[group_session] rotate scope=${isGroup ? target : '$c2cScope:$target'} '
      'session=$sessionId devices=${didSet.length}',
    );
    return _OutboundGroupSession(session, sessionId, didSet);
  }

  /// compliance_e2ee 模式：room key 额外用合规公钥包裹一份（审计侧可导入解密）；
  /// 获取失败、过期或为 null 都必须 fail-closed 抛异常阻断发送，决不降级（ADR 14 §S1.1 / CB-09/10）。
  /// checkedComplianceKey 额外做 TOFU pin 校验（审计 P1-1）：与本地固定不一致
  /// → fire ComplianceKeyChangedEvent + 抛 compliance_key_changed。
  Future<Map<String, dynamic>?> _complianceKeyEntry(String exportedKey) async {
    if (EncryptionModeService.current != EncryptionMode.complianceE2ee) {
      return null;
    }
    try {
      final verifiedKey = await PolicyGate.checkedComplianceKey();
      return complianceEntryFor(exportedKey: exportedKey, key: verifiedKey);
    } on E2eeSecurityException {
      rethrow;
    } on Object catch (e) {
      // Finding 014：网络/策略异常原文可能携带响应体片段，只记类型
      iPrint('[group_session] 获取合规密钥发生未预期异常: ${e.runtimeType}');
      throw const E2eeSecurityException('compliance_key_unavailable');
    }
  }

  /// room key 经既有 C2G/C2C 通道分发（具名 action：服务端零查库放行、payload
  /// 不透明透传、save 语义离线接收方重连可拉取、websocket 队列离线兜底）
  void _sendRoomKeyMessage(
    String chatType,
    String to,
    Map<String, dynamic> payload,
  ) {
    final msgId =
        'rk_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(999999)}';
    // from 必填：服务端 WS validate_peer_fields 对 C2G/C2C 帧要求 from+to
    // 双非空，缺失即 missing_required_fields 拒收——room key 曾因此从未送达
    // （接收端 megolm 恒解密失败，2026-09-03 双端真机群聊定案）；接收侧
    // handleRoomKeyMessage 也依赖 data['from'] 解析 senderUid。
    final from = UserRepoLocal.to.currentUid;
    final msg = {
      'id': msgId,
      'type': chatType,
      'from': from,
      'to': to,
      'msg_type': roomKeyAction,
      'action': roomKeyAction,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    final debugSender = debugRoomKeySender;
    if (debugSender != null) {
      debugSender(chatType, to, payload);
      return;
    }
    WebSocketService.to.sendMessage(jsonEncode(msg), msgId);
  }

  // ===== 接收侧 =====

  /// 处理入站 e2ee_room_key 消息（message_actions.dart 分发过来）
  Future<bool> handleRoomKeyMessage(Map<String, dynamic> data) async {
    try {
      final payload = parseModelJsonMap(data['payload']);
      if (payload == null) return true;
      if (payload['msg_type']?.toString() != roomKeyAction) return true;

      // 域一致性校验（安全关键）：opaque payload 声明的域（gid/scope）必须与后端
      // 已鉴权的传输层字段（type + to）一致，否则任意用户可构造 type=C2G,to=群A
      // 但 payload.gid=群B 的消息，向"自己无权限"的群 B 命名空间注入伪造 session。
      // 后端对 e2ee_room_key 仅按 type+to 校验 is_member，故域必须锚定 type+to。
      final envelopeType = data['type']?.toString();
      final envelopeTo = data['to']?.toString() ?? '';
      final scope = payload['scope']?.toString() ?? '';
      String gid = payload['gid']?.toString() ?? '';
      if (gid.isEmpty && scope != c2cScope && envelopeType == 'C2G') {
        gid = envelopeTo; // 旧版群 payload 缺 gid，仅 C2G 通道回退到已鉴权目标
      }
      if (gid.isNotEmpty) {
        // 群 key 只能来自对应群的 C2G 通道（gid 必须等于后端校验过的 is_member 目标）
        if (envelopeType != 'C2G' || gid != envelopeTo) {
          AppLogger.error('[group_session] 群 room key 域不匹配，丢弃 gid=$gid');
          return true;
        }
      } else if (scope == c2cScope) {
        // 单聊 key 只能来自 C2C 通道（session_id 高熵全局唯一，无需锚定 to）
        if (envelopeType != 'C2C') {
          AppLogger.error('[group_session] c2c room key 非 C2C 通道，丢弃');
          return true;
        }
      } else {
        return true; // 既非群 key 也非 c2c key，无法判定会话域
      }
      final storageScope = gid.isNotEmpty ? gid : c2cScope;
      final sessionId = payload['session_id']?.toString() ?? '';
      final keys = payload['keys'];
      if (sessionId.isEmpty || keys is! List) {
        return true;
      }
      if (keys.length > _maxRoomKeyEntries) {
        AppLogger.error(
          '[group_session] room key keys 超限，丢弃 scope=$storageScope',
        );
        return true;
      }

      final entry = pickMyKeyEntry(keys, deviceId);
      if (entry == null) return true; // 本设备不在分发列表

      // 接收状态机（ADR 13 §4 + E2EE-011）：v3（meta_version>=3）Olm-only，
      // 任何 Olm 失败（缺 sid / 伪造 sid / 认证失败 / 会话不可用 / 无 olm）一律拒绝，
      // 绝不回退 RSA（防 downgrade）。仅明确 legacy meta 版本走 RSA decrypt-only 读历史。
      final metaVersion = payload['meta_version'];
      final olmRequired =
          metaVersion is int && metaVersion >= roomKeyMetaVersionV3;
      final exported = await _unwrapEntry(
        entry,
        senderUid: data['from']?.toString() ?? '',
        olmRequired: olmRequired,
      );
      if (exported == null) return true;

      await ensureInitialized();
      final inbound = vod.InboundGroupSession.import(exported);
      if (inbound.sessionId != sessionId) {
        AppLogger.error(
          '[group_session] session_id 不匹配，丢弃 scope=$storageScope',
        );
        return true;
      }
      await StorageSecureService.to.write(
        key: '$_inboundKeyPrefix$storageScope:$sessionId',
        value: exported,
      );
      _inbound['$storageScope:$sessionId'] = inbound;
      await _storeAuthoritativeHistoryGrant(storageScope, sessionId);
      // 安全：不从 room key 反推群策略旗标——e2ee_room_key 是任意成员可发的 C2G
      // 具名 action（后端仅校验 is_member，不校验群主/群 e2ee_mode），据此翻转
      // 本地强制加密旗标会让普通成员越权触发"仅群主可决策"的群级策略。旗标权威
      // 来源仅限服务端：group_e2ee_mode S2C 广播 + group_api 群详情同步。
      // 这里只存 inbound key 供解密收到的密文，不改旗标。
      iPrint(
        '[group_session] 收到 room key scope=$storageScope session=$sessionId',
      );
      return true;
    } on Object catch (e) {
      iPrint('[group_session] room key persistence failed: ${e.runtimeType}');
      return false;
    }
  }

  /// room-key 版本标记：v3 = Olm-only（单聊 Olm / 群 Megolm room-key 经 Olm 分发）。
  /// meta_version 缺失或 < 3 视为 legacy（历史 RSA+AES 密文，仅 decrypt-only）。
  static const int roomKeyMetaVersionV3 = 3;

  /// 接收侧解包单个 key 条目（E2EE-011 Olm-only 状态机）。
  ///
  /// [olmRequired]（v3/Strict，meta_version>=3）：**只解 Olm，任何失败即拒绝，
  /// 绝不回退 RSA**（防 downgrade attack）。以下全部返回 null（拒绝，RSA 调用为 0）：
  /// 无 olm 子对象（删除 olm / 无 Olm 身份设备被跳过）、olm 字段不全（缺 sid /
  /// 伪造结构）、Olm 认证失败、Olm 会话不可用。
  ///
  /// ![olmRequired]（明确 legacy meta 版本）：仅供读历史密文 decrypt-only：
  /// olm 有效 → 试 Olm（认证失败仍拒绝，不降级）；olm 不全 / 无 olm → RSA 解包 `ek`。
  ///
  /// 返回 null = 无法解包或被拒绝（调用方丢弃该 room key）。
  Future<String?> _unwrapEntry(
    Map<String, dynamic> entry, {
    required String senderUid,
    required bool olmRequired,
  }) async {
    final olm = entry['olm'];
    if (olm is Map) {
      final sid = olm['sid']?.toString() ?? '';
      final body = olm['body']?.toString() ?? '';
      final type = olm['type'];
      final olmFieldsValid =
          sid.isNotEmpty &&
          body.isNotEmpty &&
          senderUid.isNotEmpty &&
          type is int;
      if (olmFieldsValid) {
        try {
          return await (debugOlmUnwrap ?? _defaultOlmUnwrap)(
            senderUid,
            sid,
            type,
            body,
          );
        } on OlmAuthenticationException {
          // 认证失败 → 拒绝，禁止降级 RSA（防 downgrade）。v3/legacy 一致。
          AppLogger.error('[group_session] room key Olm 认证失败，拒绝该条目');
          return null;
        } on Object catch (e) {
          if (olmRequired) {
            // v3 Olm-only：会话不可用等任何失败一律拒绝，不回退 RSA。
            // Finding 014：不记录异常对象（可能含密文/会话材料），只记类型
            AppLogger.error(
              '[group_session] v3 room key Olm 解包失败，拒绝（不回退 RSA） '
              'errType=${e.runtimeType}',
            );
            return null;
          }
          // Finding 014：同上，legacy 回退路径也只记类型
          iPrint(
            '[group_session] legacy room key Olm 不可用，回退 RSA: '
            '${e.runtimeType}',
          );
        }
      } else if (olmRequired) {
        // v3 声明 Olm 但字段不全（缺 sid / 伪造结构）→ 拒绝，不回退 RSA。
        AppLogger.error('[group_session] v3 room key olm 字段不全，拒绝');
        return null;
      }
      // legacy 且 olm 字段不全 → 落 RSA 回退（历史兼容）。
    } else if (olmRequired) {
      // v3 但无 olm 子对象（删除 olm 攻击 / 无 Olm 身份设备被跳过）→ 拒绝，不回退 RSA。
      AppLogger.error('[group_session] v3 room key 缺 olm 子对象，拒绝（不回退 RSA）');
      return null;
    }

    // 仅 legacy（!olmRequired）到达此处：RSA decrypt-only（读历史密文）。
    final kid = entry['kid']?.toString() ?? '';
    final ek = entry['ek']?.toString() ?? '';
    if (ek.isEmpty) return null;
    final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(kid);
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      AppLogger.error('[group_session] room key 私钥不存在 kid=$kid');
      return null;
    }
    return unwrapSessionKey(ek: ek, privateKeyPem: privateKeyPem);
  }

  /// 默认 Olm 解包器：委托 OlmSessionService（生产路径）。
  /// 测试用 [debugOlmUnwrap] 覆盖以免依赖真 vodozemac / 网络 claim。
  Future<String> _defaultOlmUnwrap(
    String senderUid,
    String sid,
    int type,
    String body,
  ) => OlmSessionService.to.decryptC2CMessage(
    peerUid: senderUid,
    peerDeviceId: sid,
    messageType: type,
    ciphertext: body,
  );

  /// 测试注入：接收侧 Olm 解包器（返回 exportedKey 或抛 OlmAuthenticationException）。
  @visibleForTesting
  Future<String> Function(String senderUid, String sid, int type, String body)?
  debugOlmUnwrap;

  /// 测试专用：暴露接收侧解包状态机（保持 [_unwrapEntry] 私有语义）。
  /// [olmRequired] 默认 true（v3 Strict）；传 false 测明确 legacy decrypt-only。
  @visibleForTesting
  Future<String?> debugUnwrapEntry(
    Map<String, dynamic> entry, {
    required String senderUid,
    bool olmRequired = true,
  }) => _unwrapEntry(entry, senderUid: senderUid, olmRequired: olmRequired);

  /// 解密 Megolm 群消息（E2EEService.decryptE2EEMessage 按 e2ee_suite 委托过来）
  Future<String> decryptGroupMessage({
    required String gid,
    required String sessionId,
    required String ciphertext,
    int? convSeq,
  }) => _decryptScoped(gid, sessionId, ciphertext, convSeq: convSeq);

  /// 解密 Megolm 单聊消息（session_id 全局唯一，C2C 统一存 'c2c' 域）
  Future<String> decryptC2CMessage({
    required String sessionId,
    required String ciphertext,
  }) => _decryptScoped(c2cScope, sessionId, ciphertext);

  Future<String> _decryptScoped(
    String storageScope,
    String sessionId,
    String ciphertext, {
    int? convSeq,
  }) async {
    await ensureInitialized();
    if (storageScope != c2cScope) {
      await _enforceRestoredHistoryGrant(storageScope, sessionId, convSeq);
    }
    var inbound = _inbound['$storageScope:$sessionId'];
    if (inbound == null) {
      final exported = await StorageSecureService.to.read(
        key: '$_inboundKeyPrefix$storageScope:$sessionId',
      );
      if (exported == null || exported.isEmpty) {
        throw Exception(
          'no key found for device: megolm $storageScope/$sessionId',
        );
      }
      inbound = vod.InboundGroupSession.import(exported);
      _inbound['$storageScope:$sessionId'] = inbound;
    }
    return inbound.decrypt(ciphertext).plaintext;
  }

  Future<void> _storeInbound(
    String storageScope,
    String sessionId,
    String exported,
  ) async {
    _inbound['$storageScope:$sessionId'] = vod.InboundGroupSession.import(
      exported,
    );
    await StorageSecureService.to.write(
      key: '$_inboundKeyPrefix$storageScope:$sessionId',
      value: exported,
    );
    await _storeAuthoritativeHistoryGrant(storageScope, sessionId);
  }

  Future<void> _storeAuthoritativeHistoryGrant(
    String storageScope,
    String sessionId,
  ) async {
    final gid = BigInt.tryParse(storageScope);
    if (gid == null || gid <= BigInt.zero) return;
    try {
      final grant = await _loadAuthoritativeHistoryGrant(
        storageScope,
        sessionId,
      );
      await StorageSecureService.to.write(
        key: '$kMegolmHistoryGrantPrefix$storageScope:$sessionId',
        value: jsonEncode(grant.toJson()),
      );
    } on Object catch (e) {
      iPrint(
        '[group_session] history grant unavailable '
        'scope=$storageScope error=${e.runtimeType}',
      );
    }
  }

  Future<MegolmHistoryGrant> _loadAuthoritativeHistoryGrant(
    String gid,
    String sessionId,
  ) async {
    final remote =
        await (debugHistoryGrantLoader ??
            (gid, sid) => E2EEApi().groupHistoryGrant(
              gid: gid,
              sessionId: sid,
            ))(gid, sessionId);
    return MegolmHistoryGrant(
      scope: gid,
      sessionId: remote.sessionId,
      generationNo: remote.generationNo,
      startSeq: remote.startSeq,
      endSeq: remote.endSeq,
    );
  }

  @visibleForTesting
  Future<void> debugStoreAuthoritativeHistoryGrant(
    String gid,
    String sessionId,
  ) => _storeAuthoritativeHistoryGrant(gid, sessionId);

  Future<void> _enforceRestoredHistoryGrant(
    String gid,
    String sessionId,
    int? convSeq,
  ) async {
    final suffix = '$gid:$sessionId';
    if (!_restoredGrantLookups.contains(suffix)) {
      final raw = await StorageSecureService.to.read(
        key: '$kMegolmRestoredGrantPrefix$suffix',
      );
      if (raw != null) {
        _restoredGrants[suffix] = MegolmHistoryGrant.parse(
          raw,
          expectedScope: gid,
          expectedSessionId: sessionId,
        );
      }
      _restoredGrantLookups.add(suffix);
    }
    if (!_restoredGrants.containsKey(suffix)) return;
    var grant = _restoredGrants[suffix];
    if (grant != null && convSeq != null && convSeq > grant.endSeq) {
      try {
        final refreshed = await _loadAuthoritativeHistoryGrant(gid, sessionId);
        if (refreshed.generationNo != grant.generationNo ||
            refreshed.startSeq != grant.startSeq ||
            refreshed.endSeq < convSeq) {
          throw StateError('historical_room_key_scope_denied');
        }
        final encoded = jsonEncode(refreshed.toJson());
        await StorageSecureService.to.write(
          key: '$kMegolmRestoredGrantPrefix$suffix',
          value: encoded,
        );
        await StorageSecureService.to.write(
          key: '$kMegolmHistoryGrantPrefix$suffix',
          value: encoded,
        );
        _restoredGrants[suffix] = refreshed;
        grant = refreshed;
      } on Object {
        throw StateError('historical_room_key_scope_denied');
      }
    }
    if (grant == null || !grant.allows(convSeq)) {
      throw StateError('historical_room_key_scope_denied');
    }
  }

  @visibleForTesting
  Future<void> debugEnforceRestoredHistoryGrant(
    String gid,
    String sessionId,
    int? convSeq,
  ) => _enforceRestoredHistoryGrant(gid, sessionId, convSeq);

  // ===== 纯函数（可独立单测，不依赖原生库）=====

  /// 组装 room key 分发 payload（v3 Olm-only）。
  /// [gid] 非空 → 群 payload；空/null → C2C payload（带 scope='c2c'）。
  /// [extraKeys] 追加条目（如合规审计 RSA 包裹，ADR 18），不参与设备集合比较。
  ///
  /// E2EE-011 Olm-only：设备条目不再生成 RSA `ek`；olm 子对象由 [attachOlmWraps]
  /// 追加。无 Olm 身份设备最终无 olm 无 ek → 接收侧 v3 跳过（不回退 RSA）。
  ///
  /// ponytail: [exportedKey]/[didToPem] 参数暂保留以稳定签名（仅 didToPem.keys
  /// 用作设备集合来源）；更广的签名瘦身与 RSA 套件清理随后续 pass 一并做。
  static Map<String, dynamic> buildRoomKeyPayload({
    String? gid,
    required String sessionId,
    required String exportedKey,
    required Map<String, String> didToPem,
    required Map<String, String> didToKid,
    List<Map<String, dynamic>> extraKeys = const [],
  }) {
    final keys = <Map<String, dynamic>>[];
    for (final did in didToPem.keys) {
      keys.add({'did': did, 'kid': didToKid[did] ?? did});
    }
    keys.addAll(extraKeys);
    return {
      'msg_type': roomKeyAction,
      // E2EE-011：标记 v3 → 接收侧 Olm-only、任何失败拒绝、不回退 RSA。
      'meta_version': roomKeyMetaVersionV3,
      if (gid != null && gid.isNotEmpty) 'gid': gid,
      if (gid == null || gid.isEmpty) 'scope': c2cScope,
      'session_id': sessionId,
      'alg': kMegolmSuite,
      'keys': keys,
    };
  }

  /// ADR 13 §3.1 发送侧双包后处理：给每个可 Olm 的接收设备条目**追加** olm
  /// 子对象 `{v,type,sid,body}`，RSA `ek` 保留不变（双包灰度期）。
  /// - 逐条目调 [olmWrap]（注入，纯函数可测）；返回 null（对端无 Olm 身份/建会话
  ///   失败）→ 该条目仅 RSA 回退，不阻断分发（ADR 13 §4）。
  /// - `compliance-audit` 条目跳过（合规侧无 Olm 会话，恒 RSA，ADR 13 §3.3）。
  /// - [senderDeviceId] 填 olm.sid（发送方 deviceId），供接收侧定位 Olm 入站会话。
  /// - 发送方自己的设备不需要建立“给自己”的 Olm 会话：发送侧已经在
  ///   [_rotateAndDistribute] 中保存同一份 inbound session，故该设备条目
  ///   保留为无 olm 的自持条目并跳过包裹。否则严格模式会因本机不存在
  ///   self-to-self 入站 Olm session 而把整条群消息错误拒发。
  /// - **严格模式和合规模式下（ADR 14 §S1.1 / HOTFIX-03）**：包装必须 100% 成功，
  ///   任何包装失败或缺失、以及无 senderDeviceId，均直接 fail-closed 抛异常，绝不静默跳过、省略或仅 RSA 降级。
  @visibleForTesting
  static Future<void> attachOlmWraps({
    required List<dynamic> keys,
    required String exportedKey,
    required String senderDeviceId,
    required OlmWrapFn olmWrap,
  }) async {
    final bool strict = EncryptionModeService.current.requiresEncryption;
    if (senderDeviceId.isEmpty) {
      if (strict) {
        throw const E2eeSecurityException('sender_device_id_missing');
      }
      return; // 无本设备 id 无法填 sid → 全部仅 RSA
    }
    for (final k in keys) {
      if (k is! Map) continue;
      final did = k['did']?.toString() ?? '';
      if (did.isEmpty || did == 'compliance-audit') continue;
      // 本机已在 rotate 时保存 outbound 对应的 inbound session；不需要、
      // 也不能通过 X3DH 给自己建立一个可接收的 self-to-self Olm 会话。
      if (did == senderDeviceId) continue;
      OlmWrapped? wrapped;
      try {
        wrapped = await olmWrap(did, exportedKey);
      } on Object catch (e) {
        // Finding 014：异常可能携带 room key 密文/底层 Olm 错误原文，只记类型
        AppLogger.error(
          '[group_session] olmWrap 异常，该 did 仅 RSA: $did '
          'errType=${e.runtimeType}',
        );
        if (strict) {
          throw E2eeSecurityException('olm_wrap_failed: ${e.runtimeType}');
        }
        continue;
      }
      if (wrapped == null) {
        if (strict) {
          throw const E2eeSecurityException(
            'olm_wrap_failed: empty wrapped key',
          );
        }
        continue; // 对端不可 Olm → 仅 RSA
      }
      k['olm'] = <String, dynamic>{
        'v': kOlmSuite,
        'type': wrapped.type,
        'sid': senderDeviceId,
        'body': wrapped.body,
      };
    }
  }

  /// 组装合规审计密钥条目（纯函数，供 _complianceKeyEntry 与单测复用）
  static Map<String, dynamic> complianceEntryFor({
    required String exportedKey,
    required ComplianceKeyInfo key,
  }) => {
    'did': 'compliance-audit',
    'kid': key.keyId,
    'wrap_alg': 'RSA-OAEP-256',
    'ek': wrapSessionKey(exportedKey: exportedKey, publicKeyPem: key.publicKey),
  };

  /// 在 keys 列表中找到本设备条目
  static Map<String, dynamic>? pickMyKeyEntry(List<dynamic> keys, String did) {
    for (final k in keys) {
      if (k is Map && k['did']?.toString() == did) {
        return Map<String, dynamic>.from(k);
      }
    }
    return null;
  }

  /// RSA-OAEP-256 包裹导出的 session key（导出 key ≈165B < OAEP-2048 上限 190B，单次可装）
  static String wrapSessionKey({
    required String exportedKey,
    required String publicKeyPem,
  }) {
    final keyBytes = base64.decode(base64.normalize(exportedKey));
    final pub = RSAService.parsePublicKeyFromPem(publicKeyPem);
    final wrapped = RSAService.rsaEncrypt(pub, Uint8List.fromList(keyBytes));
    return base64.encode(wrapped);
  }

  /// 解包并重编码为 unpadded base64（vodozemac 期望无填充）
  static String unwrapSessionKey({
    required String ek,
    required String privateKeyPem,
  }) {
    final wrapped = base64.decode(base64.normalize(ek));
    final priv = RSAService.parsePrivateKeyFromPem(privateKeyPem);
    final keyBytes = RSAService.rsaDecrypt(priv, Uint8List.fromList(wrapped));
    return base64.encode(keyBytes).replaceAll('=', '');
  }
}

class _OutboundGroupSession {
  _OutboundGroupSession(this.session, this.sessionId, this.dids)
    : createdAt = DateTime.now().millisecondsSinceEpoch,
      messageCount = 0;
  final vod.GroupSession session;
  final String sessionId;
  final Set<String> dids;

  /// P0-2: 创建时间戳（毫秒），用于 max_age 轮转判断
  final int createdAt;

  /// P0-2: 已加密消息计数，用于 max_messages 轮转判断
  int messageCount;
}
