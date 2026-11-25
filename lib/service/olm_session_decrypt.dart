part of 'olm_session_service.dart';

/// 入站解密、入站持久化与对端身份查询（自 OlmSessionService 抽出的扩展，行为与调用方零变更）。
extension OlmSessionInbound on OlmSessionService {
  // ===== 解密（入站，X3DH 接收 + DR 解密）=====

  /// 解密一条单聊消息（C2C）。
  /// pre-key 消息优先复用已有会话；仅新会话调用 createInboundSession。
  /// 对端收到回复前，连续发送的消息仍可为 messageType=0。
  ///
  /// S2.3: 当 [messageId] 非空且 CryptoStore 可用时，dedupe 检查与 ratchet
  /// advance 在同一 SQLite 事务内完成——重复投递不会推进 ratchet。
  Future<String> decryptC2CMessage({
    required String peerUid,
    required String peerDeviceId,
    required int messageType,
    required String ciphertext,
    String? messageId,
    String? inboxScope,
    String? ciphertextDigest,
  }) async {
    final guard = _captureWebSessionGuard();
    await ensureInitialized();
    final lockKey = '$peerUid:$peerDeviceId';
    final lock = _sessionLocks.putIfAbsent(lockKey, () => Lock());
    return lock.synchronized(() async {
      guard();
      // S2.3: 快速 dedupe 前置检查（避免无谓解密开销）
      if (messageId != null) {
        final store = await cryptoStore;
        if (store != null && await store.isDuplicate(messageId)) {
          throw DuplicateMessageException(messageId);
        }
      }

      final account = await _loadOrCreateAccount(guard);
      var session = await _loadSession(peerUid, peerDeviceId);
      guard();

      String? preKeyPlaintext;
      if (messageType == 0 && session != null) {
        // 在副本上试解，认证失败不能改变既有 ratchet；新会话仍走身份校验。
        final pickleKey = await _pickleKey(guard);
        final candidate = vod.Session.fromPickleEncrypted(
          pickle: session.toPickleEncrypted(pickleKey),
          pickleKey: pickleKey,
        );
        try {
          preKeyPlaintext = candidate.decrypt(
            messageType: messageType,
            ciphertext: ciphertext,
          );
          session = candidate;
        } on Object {
          // 不匹配的 pre-key 可能属于对端新建的会话。
        }
      }

      if (messageType == 0 && preKeyPlaintext == null) {
        // pre-key message：首次接收，建入站 Session
        final theirIdentity = await _lookupPeerIdentityKey(
          peerUid,
          peerDeviceId,
        );
        guard();
        late final dynamic result;
        try {
          result = account.createInboundSession(
            theirIdentityKey: vod.Curve25519PublicKey.fromBase64(theirIdentity),
            preKeyMessageBase64: ciphertext,
            // vodozemac 0.7 默认改为 config v2；当前协议仍使用 v1。
            config: legacyOlmSessionConfig(),
          );
        } on Object catch (e) {
          // Finding 014：不把底层库错误原文（可能含 prekey 密文）拼进异常消息
          throw OlmAuthenticationException(
            'createInboundSession 失败（prekey 密文无效）: ${e.runtimeType}',
          );
        }
        session = result.session as vod.Session;
        await _persistSessionWithDedupe(
          peerUid,
          peerDeviceId,
          session,
          messageId,
          guard: guard,
          decryptedPayload: result.plaintext as String,
          inboxScope: inboxScope,
          ciphertextDigest: ciphertextDigest,
        );
        guard();
        // 入站会话建立后，本端可能需补传 OTK
        unawaited(
          _accountLock.synchronized(() async {
            await _refillOneTimeKeys(account, sessionGuard: guard);
            // E2EE-062：入站建会话后补传并检查 fallback 周期轮换。
            await maybeRotateFallbackKey(sessionGuard: guard);
            await _persistAccount(await _pickleKey(guard), guard);
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
        plaintext =
            preKeyPlaintext ??
            session.decrypt(messageType: messageType, ciphertext: ciphertext);
      } on Object catch (e) {
        // Finding 014：不把底层库错误原文（可能含密文片段）拼进异常消息
        throw OlmAuthenticationException('olm decrypt 认证失败: ${e.runtimeType}');
      }
      await _persistSessionWithDedupe(
        peerUid,
        peerDeviceId,
        session,
        messageId,
        guard: guard,
        decryptedPayload: plaintext,
        inboxScope: inboxScope,
        ciphertextDigest: ciphertextDigest,
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
    String? messageId, {
    required void Function() guard,
    String? decryptedPayload,
    String? inboxScope,
    String? ciphertextDigest,
  }) async {
    if (messageId != null) {
      final store = await _requireStore(peerUid, peerDeviceId);
      final pickleKey = await _pickleKey(guard);
      final hasRecoveryContext =
          inboxScope != null &&
          inboxScope.isNotEmpty &&
          ciphertextDigest != null &&
          ciphertextDigest.isNotEmpty;
      late final bool accepted;
      try {
        accepted = await store.dedupeAndPersistSession(
          messageId: messageId,
          peerUid: peerUid,
          peerDeviceId: peerDeviceId,
          pickle: session.toPickleEncrypted(pickleKey),
          scope: hasRecoveryContext ? inboxScope : null,
          ciphertextDigest: hasRecoveryContext ? ciphertextDigest : null,
          decryptedPayload: hasRecoveryContext ? decryptedPayload : null,
        );
        guard();
      } on Object {
        _sessions.remove(_sessionKey(peerUid, peerDeviceId));
        rethrow;
      }
      if (!accepted) {
        _sessions.remove(_sessionKey(peerUid, peerDeviceId));
        throw DuplicateMessageException(messageId);
      }
      _sessions[_sessionKey(peerUid, peerDeviceId)] = session;
    } else {
      await _persistSession(peerUid, peerDeviceId, session, guard);
    }
  }

  /// 查询对端 curve25519 身份键（createInboundSession 需要）
  Future<String> _lookupPeerIdentityKey(
    String peerUid,
    String peerDeviceId,
  ) async {
    final identity = await _lookupPeerIdentity(peerUid, peerDeviceId);
    return identity['curve25519_key'] as String;
  }

  /// 查询对端已验证 identity（ed25519 + curve25519 + signature）。
  ///
  /// 与 [_lookupPeerIdentityKey] 同一条安全路径：Ed25519 自签核验 + TOFU pin。
  /// trust/record 上报需要 `target_ed25519`（签进 canonical 的对方身份快照），
  /// 必须与本路径同源，禁止裸调 [OlmApi.getIdentity]。
  ///
  /// C17b 复审 gap：响应结构由 `OlmApi.parseIdentityPayload` 收口保证
  /// （`curve25519_key` 等字段已证明为非空 String），下方/调用方的
  /// `as String` cast 与 `_establishOutboundSession` 对 claim 的 cast 同型，
  /// 不会以 TypeError 泄漏。
  Future<Map<String, dynamic>> _lookupPeerIdentity(
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
    return identity;
  }

  /// 对端已验证 identity 的公开入口（trust/record 上报用）。
  ///
  /// 返回 `{device_id, ed25519_key, curve25519_key, signature}`，
  /// 全部经过 Ed25519 自签核验与 TOFU pin（与建会话同路径）。
  Future<Map<String, dynamic>> peerIdentityKeys(
    String peerUid,
    String peerDeviceId,
  ) async {
    await ensureInitialized();
    return _lookupPeerIdentity(peerUid, peerDeviceId);
  }
}
