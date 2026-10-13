/// 坐席事件 SSE 流客户端（plan §3.6 / SSE-EVENT-CONTRACT-V1）
///
/// 端点：`GET /api/v1/cs/organizations/:org_id/seats/me/events?workspace_id=...`
///（后端已交付真流式：retry:2000、Last-Event-ID 游标补偿、resync.required、
/// 按 event_id 去重、X-CS-Event-Retention-Seconds=86400）。
///
/// EventSource 语义（本类实现）：
/// - **Last-Event-ID 头**：重连时携带最后收到的 event_id（头优先于
///   after_id 查询参数；首连无游标时用 initialAfterId 作 after_id）；
/// - **retry**：首写 `retry: 2000` 即重连基础间隔；打开失败按指数退避
///   （2s→30s 封顶），成功打开后清零——**任何路径都不产生请求风暴**；
/// - **有界去重**：event_id 走 LRU 窗口（默认 512），at-least-once 重投
///   丢弃；心跳注释行不占业务 id、不下发；
/// - **resync.required**：作为信封转发（消费方清游标 + 权威 refresh）；
///   流本身从当前水位继续，不重置游标；
/// - 事件只是**权威刷新的触发器**：payload 不含业务真源，消费方必须
///   回源拉取（queue/detail/messages）。
///
/// 可注入：[CsSseOpener]（默认走 [CsApi.openSeatEventsStream]，测试注入
/// fake 流）与 workspace 解析器（默认 seat-contexts 推导）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:collection' show LinkedHashSet;

import 'package:dio/dio.dart' show CancelToken;

import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

/// SSE 打开失败（非 200 / 非事件流 content-type）。
class CsSseOpenException implements Exception {
  final int statusCode;
  final String contentType;

  const CsSseOpenException(this.statusCode, this.contentType);

  @override
  String toString() =>
      'CsSseOpenException(status=$statusCode, contentType=$contentType)';
}

/// 打开一条 SSE 字节流（由 [CsSeatEventsStream] 驱动重连/解析/游标）。
typedef CsSseOpener = Future<Stream<List<int>>> Function(
  String orgId,
  String workspaceId, {
  String lastEventId,
  String afterId,
});

/// 坐席事件信封（SSE-EVENT-CONTRACT-V1 envelope；宽容解析）。
class CsSseEnvelope {
  static const String typeQueueChanged = 'queue.changed';
  static const String typeSessionChanged = 'session.changed';
  static const String typeMessageAppended = 'message.appended';
  static const String typeAssignmentChanged = 'assignment.changed';
  static const String typeSeatChanged = 'seat.changed';
  static const String typeResyncRequired = 'resync.required';

  /// TSID 字符串（单 Org+Workspace stream 内单调唯一）。
  final String eventId;
  final String type;
  final String organizationId;
  final String workspaceId;
  final String resourceType;
  final String resourceId;
  final int resourceVersion;

  /// RFC3339。
  final String occurredAt;

  /// created|updated|revoked|expired|unknown。
  final String reason;

  const CsSseEnvelope({
    required this.eventId,
    this.type = '',
    this.organizationId = '',
    this.workspaceId = '',
    this.resourceType = '',
    this.resourceId = '',
    this.resourceVersion = 0,
    this.occurredAt = '',
    this.reason = '',
  });

  bool get isResyncRequired => type == typeResyncRequired;

  /// 撤权类语义：assignment/seat 被 revoked/expired → 下一次请求将被
  /// 服务端 401/403，消费方应立即权威刷新触发降级。
  bool get isRevocation => reason == 'revoked' || reason == 'expired';

  factory CsSseEnvelope.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v == null ? '' : v.toString();
    return CsSseEnvelope(
      eventId: s(json['event_id']),
      type: s(json['type']),
      organizationId: s(json['organization_id']),
      workspaceId: s(json['workspace_id']),
      resourceType: s(json['resource_type']),
      resourceId: s(json['resource_id']),
      resourceVersion: json['resource_version'] is int
          ? json['resource_version'] as int
          : int.tryParse('${json['resource_version']}') ?? 0,
      occurredAt: s(json['occurred_at']),
      reason: s(json['reason']),
    );
  }
}

/// 有界 event_id 去重窗口（LRU；默认 512——at-least-once 重投丢弃，
/// 窗口滚动后极旧重投按新事件处理，权威刷新语义保证无害）。
class CsSseDedupWindow {
  CsSseDedupWindow({this.capacity = 512}) : assert(capacity > 0);

  final int capacity;
  final LinkedHashSet<String> _seen = LinkedHashSet<String>();

  bool contains(String id) => _seen.contains(id);

  /// 已见过返回 true（重复，丢弃）；否则记录并返回 false。
  bool seenAndAdd(String id) {
    if (_seen.contains(id)) return true;
    _seen.add(id);
    while (_seen.length > capacity) {
      _seen.remove(_seen.first);
    }
    return false;
  }
}

/// 坐席事件 SSE 流（连接生命周期 + 帧解析 + 去重 + 游标 + 重连）。
class CsSeatEventsStream {
  final String orgId;

  /// Workspace 作用域（契约 query 必填；为空时经 [resolveWorkspaceId]
  /// 解析，仍为空则打开失败走退避重试）。
  final String workspaceId;

  /// 首连游标（after_id；Last-Event-ID 头存在时服务端忽略它）。
  final String initialAfterId;

  final CsSseOpener? opener;
  CancelToken? _requestCancelToken;

  /// Workspace 解析器（默认实现走 seat-contexts；测试可注入）。
  final Future<String> Function()? resolveWorkspaceId;

  /// 服务端 retry 间隔（首写 retry:2000；clamp [1s, 60s]）。
  int _retryMs = 2000;
  int _connectAttempt = 0;
  bool _running = false;
  bool _disposed = false;
  String _lastEventId = '';
  String _resolvedWorkspaceId = '';

  // 当前帧累积（id/event/data/retry）。
  String _frameId = '';
  String _frameEvent = '';
  StringBuffer _frameData = StringBuffer();

  StreamSubscription<String>? _sub;
  Timer? _reconnectTimer;
  final CsSseDedupWindow _dedup;

  void Function(CsSseEnvelope envelope)? _onEvent;
  void Function(Object error)? _onError;

  CsSeatEventsStream({
    required this.orgId,
    this.workspaceId = '',
    this.initialAfterId = '',
    this.opener,
    this.resolveWorkspaceId,
    int dedupCapacity = 512,
  }) : _dedup = CsSseDedupWindow(capacity: dedupCapacity);

  /// 默认 opener：走 [CsApi.openSeatEventsStream]（adapterForTest 可拦截）。
  Future<Stream<List<int>>> _defaultOpener(
    String orgId,
    String workspaceId, {
    String lastEventId = '',
    String afterId = '',
  }) {
    final token = CancelToken();
    _requestCancelToken = token;
    return CsApi().openSeatEventsStream(
      orgId,
      workspaceId,
      lastEventId: lastEventId,
      afterId: afterId,
      cancelToken: token,
    );
  }

  /// Actual workspace used by the most recent connection, after resolution.
  String get boundWorkspaceId => _resolvedWorkspaceId;

  /// 最后收到的 event_id（重连 Last-Event-ID 游标；测试/持久化可读）。
  String get lastEventId => _lastEventId;

  /// 当前生效的重连间隔（ms；服务端 retry 驱动，clamp 后）。
  int get retryMs => _retryMs;

  bool get isConnected => _sub != null;

  /// 启动（幂等：已运行则忽略）。事件只触发权威刷新——消费方不得把
  /// 信封 payload 当业务真源。
  void start({
    required void Function(CsSseEnvelope envelope) onEvent,
    void Function(Object error)? onError,
  }) {
    if (_disposed || _running) return;
    _running = true;
    _onEvent = onEvent;
    _onError = onError;
    _connect();
  }

  /// 停止并释放（定时器/订阅全取消；之后不可复用）。
  void dispose() {
    _disposed = true;
    _running = false;
    _requestCancelToken?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _connect() async {
    if (!_running || _disposed) return;
    _connectAttempt++;
    try {
      var ws = workspaceId;
      final resolver = resolveWorkspaceId;
      if (ws.isEmpty && resolver != null) {
        ws = await resolver();
        if (!_running || _disposed) return;
      }
      _resolvedWorkspaceId = ws;
      final stream = await (opener ?? _defaultOpener)(
        orgId,
        _resolvedWorkspaceId,
        lastEventId: _lastEventId,
        afterId: _lastEventId.isEmpty ? initialAfterId : '',
      );
      // dispose 竞态保护：opener 挂起期间被释放则放弃建流。
      if (!_running || _disposed) return;
      // 打开成功：退避清零（只在真正建流后）。
      _connectAttempt = 0;
      _sub = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _onLine,
            onDone: _onStreamClosed,
            onError: (Object e) {
              _onStreamClosed();
              _onError?.call(e);
            },
            cancelOnError: true,
          );
    } on Object catch (e) {
      if (!_running || _disposed) return;
      _onError?.call(e);
      _scheduleReconnect(openFailure: true);
    }
  }

  void _onStreamClosed() {
    _requestCancelToken?.cancel();
    _sub = null;
    _scheduleReconnect();
  }

  /// 重连：流正常关闭按服务端 retry 间隔；打开失败按指数退避
  ///（2^n × retry，30s 封顶）——断线自愈但绝不请求风暴。
  void _scheduleReconnect({bool openFailure = false}) {
    if (!_running || _disposed) return;
    var delay = _retryMs;
    if (openFailure) {
      final shift = _connectAttempt.clamp(0, 5);
      final backoff = _retryMs * (1 << shift);
      delay = backoff > _maxBackoffMs ? _maxBackoffMs : backoff;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), _connect);
  }

  void _onLine(String line) {
    // SSE 注释/心跳：不占业务 event_id，不下发。
    if (line.isEmpty) {
      _dispatchFrame();
      return;
    }
    if (line.startsWith(':')) return;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'id':
        _frameId = value;
      case 'event':
        _frameEvent = value;
      case 'data':
        _frameData
          ..write(_frameData.isEmpty ? '' : '\n')
          ..write(value);
      case 'retry':
        final ms = int.tryParse(value);
        if (ms != null && ms > 0) {
          _retryMs = ms.clamp(_minRetryMs, _maxRetryMs);
        }
    }
  }

  void _dispatchFrame() {
    final data = _frameData.toString().trim();
    final id = _frameId;
    final frameEvent = _frameEvent;
    _frameId = '';
    _frameEvent = '';
    _frameData = StringBuffer();
    // 契约：业务帧必带 id 与 JSON data；无 id（纯心跳）/无 data 不下发、
    // 不进游标、不进去重窗口。
    if (id.isEmpty || data.isEmpty) return;
    if (_dedup.seenAndAdd(id)) return;
    _lastEventId = id;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      json = null;
    }
    if (json == null) return;
    // envelope.type 缺失时以 event: 行兜底（信封权威仍在 data JSON）。
    final declaredType = '${json['type'] ?? ''}';
    if (declaredType.isEmpty && frameEvent.isNotEmpty) {
      json['type'] = frameEvent;
    }
    final envelope = CsSseEnvelope.fromJson(json);
    // 跨租户防御：非本 Org 信封静默丢弃（流是 org 作用域，双保险）。
    if (envelope.organizationId.isNotEmpty &&
        envelope.organizationId != orgId) {
      return;
    }
    _onEvent?.call(envelope);
  }

  static const int _minRetryMs = 1000;
  static const int _maxRetryMs = 60000;
  static const int _maxBackoffMs = 30000;
}
