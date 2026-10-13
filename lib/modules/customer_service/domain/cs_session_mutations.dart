part of 'cs_session_flow.dart';

/// Authority captured when the user begins a confirmation, never refreshed silently.
class CsSessionActionSnapshot {
  final String sessionId, organizationId, conversationId, assignee, status;
  final int version;
  CsSessionActionSnapshot(CsSessionDetail detail)
    : sessionId = detail.sessionId,
      organizationId = detail.organizationId,
      conversationId = detail.conversationId,
      assignee = detail.assigneeIdentityId,
      status = detail.status,
      version = detail.version;
  bool matches(CsSessionDetail? detail) =>
      detail != null &&
      version > 0 &&
      sessionId == detail.sessionId &&
      organizationId == detail.organizationId &&
      conversationId == detail.conversationId &&
      assignee == detail.assigneeIdentityId &&
      status == detail.status &&
      version == detail.version;
}

extension CsSessionMutations on CsSessionFlow {
  Future<CsSeatFailureKind?> transferTo(
    String toIdentityId, {
    CsSessionActionSnapshot? snapshot,
  }) async {
    if (_actionPending ||
        _writesInFlight > 0 ||
        pendingClientMsgId != null ||
        !_current ||
        readRevoked ||
        !machine.canSend) {
      return CsSeatFailureKind.other;
    }
    final intent =
        snapshot ?? (detail == null ? null : CsSessionActionSnapshot(detail!));
    if (intent == null ||
        !intent.matches(detail) ||
        intent.status != 'active' ||
        toIdentityId.isEmpty ||
        toIdentityId == identityId) {
      return CsSeatFailureKind.conflict;
    }
    _actionPending = true;
    try {
      return await _transferConfirmed(toIdentityId, intent.version);
    } finally {
      _actionPending = false;
    }
  }

  Future<CsSeatFailureKind?> closeSession({
    String? reason,
    CsSessionActionSnapshot? snapshot,
  }) async {
    if (_actionPending ||
        _writesInFlight > 0 ||
        pendingClientMsgId != null ||
        !_current ||
        readRevoked ||
        !machine.canSend) {
      return CsSeatFailureKind.other;
    }
    final intent =
        snapshot ?? (detail == null ? null : CsSessionActionSnapshot(detail!));
    if (intent == null ||
        !intent.matches(detail) ||
        !['queued', 'active'].contains(intent.status)) {
      return CsSeatFailureKind.conflict;
    }
    _actionPending = true;
    try {
      return await _closeConfirmed(intent.version, reason: reason);
    } finally {
      _actionPending = false;
    }
  }

  Future<CsSeatFailureKind?> _transferConfirmed(
    String toIdentityId,
    int version,
  ) async {
    if (!_current) return CsSeatFailureKind.other;
    final scope = _scope();
    try {
      await _csApi.transfer(
        orgId,
        sessionId,
        toIdentityId: toIdentityId,
        expectedVersion: version,
        // CSB-02R workspace 门必填（缺省必 422）；空时透传由服务端裁决。
        workspaceId: workspaceId,
      );
      if (!_same(scope)) return CsSeatFailureKind.other;
      machine.markTransferredAway();
      unreadCount = null;
      lastFailureKind = null;
      return null;
    } on CsApiException catch (e) {
      if (!_same(scope)) return CsSeatFailureKind.other;
      final kind = applyActionFailure(e);
      // CAS 冲突：刷新真实状态再提示（不做乐观伪成功）。
      if (kind == CsSeatFailureKind.conflict) {
        await refreshSessionState();
      }
      return kind;
    }
  }

  /// 关闭（CAS + 可选 reason）。成功 → 状态机 closed（所有写入口禁用，
  /// 等待访客评分）。409：刷新真实状态（可能已被关闭/转走）。
  Future<CsSeatFailureKind?> _closeConfirmed(
    int version, {
    String? reason,
  }) async {
    if (!_current) return CsSeatFailureKind.other;
    final scope = _scope();
    try {
      await _csApi.close(
        orgId,
        sessionId,
        expectedVersion: version,
        reason: reason,
        // CSB-02R workspace 门必填（缺省必 422）；空时透传由服务端裁决。
        workspaceId: workspaceId,
      );
      if (!_same(scope)) return CsSeatFailureKind.other;
      machine.markClosed();
      unreadCount = null;
      lastFailureKind = null;
      return null;
    } on CsApiException catch (e) {
      if (!_same(scope)) return CsSeatFailureKind.other;
      final kind = applyActionFailure(e);
      if (kind == CsSeatFailureKind.conflict) {
        await refreshSessionState();
      }
      return kind;
    }
  }
}
