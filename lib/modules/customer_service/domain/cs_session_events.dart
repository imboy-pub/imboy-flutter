part of 'cs_session_flow.dart';

/// 坐席事件流（APP-M02-A02）：SSE 事件只是权威刷新的触发器，作用域判定
/// 与 401/403 降级在此收口。自 [CsSessionFlow] 主体抽出，随同目录 part
/// 风格（cs_session_mutations / cs_session_assets）以 extension 挂载。
extension CsSessionEvents on CsSessionFlow {
  /// 绑定并启动坐席事件流（`seats/me/events`）。事件只是权威刷新触发器：
  /// 信封 payload 不含业务真源，一切以回源请求为准；访客新消息由
  /// message.appended 触发增量拉取在时限内自动出现（无轮询、无风暴）。
  void bindEvents(CsSeatEventsStream stream) {
    _events?.dispose();
    _events = stream;
    stream.start(
      onEvent: _onSeatEvent,
      onError: (error) {
        if (identical(_events, stream) &&
            stream.orgId == orgId &&
            stream.boundWorkspaceId == workspaceId) {
          _onSeatStreamError(error);
        }
      },
    );
  }

  Future<void> _onSeatEvent(CsSseEnvelope e) async {
    // Closed/rated retains authorized reading, including revocation hints.
    if (!_current ||
        readRevoked ||
        !machine.canDownload ||
        !_seatEventInScope(e)) {
      return;
    }
    switch (e.type) {
      case CsSseEnvelope.typeMessageAppended:
        if (!machine.shouldPoll) return;
        // 事件仅触发权威刷新；阅读 ACK 由实际可见消息入口推进。
        await refreshLoadedHistory();

      case CsSseEnvelope.typeSessionChanged:
        if (e.resourceId.isEmpty || e.resourceId == sessionId) {
          await refreshSessionState();
        }
      case CsSseEnvelope.typeAssignmentChanged:
      case CsSseEnvelope.typeSeatChanged:
        // 撤权/挂起/过期最小事件：立即权威刷新，让 403/409/回显定格降级。
        await refreshSessionState();
      case CsSseEnvelope.typeResyncRequired:
        // 游标缺失/过期/不连续：清消息游标 + **未读陈旧化**（null——重连后
        // 不得渲染陈旧未读），重同步读状态后有界刷新最新与已载历史。
        // 重连仅刷新权威数据，不推断消息可见或推进阅读 ACK。
        cursor = '';
        unreadCount = null;
        await refreshSessionState();
        await resyncReadState();
        await refreshLoadedHistory();

      case CsSseEnvelope.typeQueueChanged:
        // 队列事件由工作台页面级流消费；会话页不响应。
        return;
      default:
        return;
    }
    if (_current) onChanged?.call();
  }

  bool _seatEventInScope(CsSseEnvelope e) {
    if (e.organizationId != orgId || e.workspaceId != workspaceId) return false;
    if (e.resourceId.isEmpty) {
      // The production resync envelope deliberately has no resource ID.
      return e.type == CsSseEnvelope.typeResyncRequired;
    }
    return switch (e.type) {
      CsSseEnvelope.typeSeatChanged => e.resourceId == identityId,
      // Ordinary assignments reference a session; the server's revocation
      // close frame references the authenticated business identity.
      CsSseEnvelope.typeAssignmentChanged =>
        e.resourceId == sessionId || e.resourceId == identityId,
      CsSseEnvelope.typeSessionChanged => e.resourceId == sessionId,
      _ => true,
    };
  }

  void _onSeatStreamError(Object error) {
    if (!_current || readRevoked) return;
    final status = error is CsSseOpenException
        ? error.statusCode
        : error is CsApiException
        ? error.code
        : error is DioException
        ? error.response?.statusCode
        : null;
    if (status == 401 || status == 403) {
      _historyFailure(
        CsApiException(status!, 'seat stream authorization refused'),
      );
      onChanged?.call();
    }
  }
}
