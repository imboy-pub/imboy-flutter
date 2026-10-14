/// 坐席会话数据流（§12.5.1 / CSM-02 + APP-M02）
///
/// 纯 Dart controller（零 Flutter import，HTTP 经 HttpClient.adapterForTest
/// 注入桩即可单测）。职责：
///
/// - 历史 after_id 增量（游标 = 已加载最大消息 id；交付企业 store 缓存）；
///   附件按 CSX-01 冻结投影 `assets:[{id,mime,size_bytes,file_name,status}]`
///   解析（纯文本 `assets: []`）；
/// - 发送（幂等 `client_msg_id`：未确认前重试复用同一 id；服务端幂等语义
///   = 同 id 重放不增行）； sender 恒 business_identity（EB 真源写真源，
///   禁止个人 C2C 通道）；附件消息同时复用同一组 `asset_ids`（A03：
///   同 client_msg_id + asset_ids 重试 = 同一 message）；
/// - delivery ACK：对入站未投递消息逐条 ACK；recipient_ref 恒为
///   `identity:<business_identity_id>`（A01）；本地只置投递标记
///   （delivery-only），绝不删除消息真源；
/// - 附件：presign（object_hash = SHA-256）→ 裸 PUT（嵌套 upload.url，
///   缺失 fail-closed）→ confirm（upload_ref）→ 消息带 asset_ids 原子
///   绑定（§3.7）；`upload_url` 仅在内存中存在到 PUT 完成为止（不持久
///   化、不进 store、不进 UI）；查看仅走企业 content 鉴权代理取字节
///   （EB-D06），客户端不接收 object key / storage endpoint；
/// - SSE（A02）：`seats/me/events` 事件只是**权威刷新的触发器**——
///   message.appended → 增量拉取；session/assignment/seat.changed →
///   detail 权威刷新；resync.required → 清游标全量刷新；降级后停止消费；
/// - 生命周期（A04）：transfer 成功 / 服务端回显经办人已非当前坐席 →
///   transferredAway 立即只读；close → 全写入口禁用；
/// - 降级（A05）：403 / offboarding 409 / 普通 409 分类明确
///   （[lastFailureKind]），失败/重试状态不伪成功。
library;

import 'dart:async';
import 'dart:typed_data';

import 'cs_conversation_history.dart';
import 'cs_delivery_ack_ledger.dart';

import 'package:imboy/service/auth_session_scope.dart';

import 'package:xid/xid.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:imboy/modules/customer_service/domain/cs_presence_controller.dart'
    show nextAckTarget;
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';

part 'cs_session_mutations.dart';
part 'cs_session_assets.dart';

/// 坐席失败分类（A05：403 / 普通 409 / offboarding 409 各自语义分离）。
enum CsSeatFailureKind { suspended, offboarding, conflict, other }

CsSeatFailureKind csClassifySeatFailure(CsApiException e) {
  if (e.isForbidden) return CsSeatFailureKind.suspended;
  if (e.isOffboardingRequired) return CsSeatFailureKind.offboarding;
  if (e.isConflict) return CsSeatFailureKind.conflict;
  return CsSeatFailureKind.other;
}

/// 坐席会话数据流。
class CsSessionFlow {
  final CsApi _csApi;
  final EnterpriseStore _store;
  final void Function()? onChanged;
  bool _disposed = false;
  bool _actionPending = false;
  int _writesInFlight = 0;
  CsAssetUploadOperation? assetOperation;
  final bool Function()? scopeCurrent;
  final CsDeliveryAckLedger? deliveryLedger;
  final AuthSessionScope? deliveryAuthScope;
  bool get _current => !_disposed && (scopeCurrent?.call() ?? true);
  String _scope() =>
      '$orgId/$workspaceId/$sessionId/$conversationId/$identityId';
  bool _same(String scope) => _current && !readRevoked && _scope() == scope;
  bool hasOlder = false;
  bool loadingOlder = false;
  bool readRevoked = false;
  Map<String, DateTime> messageReadAt = const {};
  String? _olderCursor;
  bool _ackPending = false;
  int _historyGeneration = 0;
  CsApiException? historyError;
  CsApiException? olderError;
  Completer<void>? _historyRefresh;
  bool _refreshAgain = false;
  Timer? _refreshTimer;
  final String orgId;
  final String sessionId;

  /// 会话绑定的企业会话（消息通道；服务端 detail 可补齐）。
  String conversationId;

  /// Workspace 作用域（消息历史/presign/confirm 的冻结 query/body 必填键；
  /// 路由展示种子，空时经 seat-contexts 权威解析补齐——见
  /// [resolveWorkspaceId]，解析失败保持空 = 服务端 422 fail-closed）。
  String workspaceId;

  /// 当前坐席自己的经办业务身份（发送的 sender 身份、ACK recipient_ref）。
  ///
  /// 权威事实只来自服务端（seat-contexts / claim 回显 / detail 回显）；
  /// 路由 query 携带的 identity 只是展示种子，detail 回显非空时补齐。
  /// APP-M02-A04：detail 回显与本值**不一致**即「经办人已变更」权威信号
  /// → transferredAway（本值不被回显覆盖——回显是他人身份）。
  String identityId;

  /// 已掩码客户名（入站消息展示）。
  final String contactMaskedName;

  CsSeatSessionMachine machine = CsSeatSessionMachine();

  List<EnterpriseMessage> messages = const <EnterpriseMessage>[];

  /// 消息 id → 附件绑定投影（§3.7 `assets` 五键白名单回显；查看只经
  /// 授权代理）。
  Map<String, List<CsMessageAsset>> messageAssets =
      const <String, List<CsMessageAsset>>{};

  /// after_id 游标（已加载最大消息 id）。
  String cursor = '';

  /// 服务端 detail 快照（status/version/rating 同步用）。
  CsSessionDetail? detail;

  /// 未确认出站消息的幂等键（确认成功后清空；重试复用同一 id）。
  String? pendingClientMsgId;

  /// 未确认附件消息的 asset_ids（与 pendingClientMsgId 同生命周期：
  /// 重试必须复用同一组，A03 同键同附件 = 同一 message）。
  List<String>? pendingAssetIds;

  /// 最近一次失败的分类（A05：页面按类分流文案/可重试性；成功清空）。
  CsSeatFailureKind? lastFailureKind;

  // ==================== 已读游标与未读（CS-APP-02 / CS-RUNTIME-04） ====================

  /// 本地已 ACK 单调水位（服务端 read cursor 镜像）。进入会话 /
  /// resync.required 后由 [resyncReadState] 权威重置；只被更大的
  /// 消息 id 推进（[nextAckTarget]），多端交错不回退。
  String ackedCursor = '';

  /// 服务端未读数快照（未读 badge 唯一数据源）。
  ///
  /// null = 陈旧/未知（重连/resync 进行中或读面失败）——**不渲染未读**
  /// （fail-closed：转接/撤权/离线重连后不得出现陈旧未读）。
  int? unreadCount;

  CsSessionFlow({
    required this.orgId,
    required this.sessionId,
    required this.identityId,
    this.conversationId = '',
    this.workspaceId = '',
    this.contactMaskedName = '',
    CsApi? csApi,
    EnterpriseStore? store,
    this.onChanged,
    this.scopeCurrent,
    this.deliveryLedger,
    this.deliveryAuthScope,
  }) : _csApi = csApi ?? CsApi(),
       _store = store ?? EnterpriseStoreHolder.instance;

  // ==================== 会话状态同步 ====================

  /// 拉取服务端会话详情（打开页面 / 冲突后 / SSE session.changed 后刷新）。
  ///
  /// 权威事实合并（APP-M01-A04 + APP-M02-A04）：detail 回显的
  /// conversation_id 覆盖路由种子；business_identity_id 与当前坐席身份
  /// 不一致 → 服务端权威「已转交他人」→ transferredAway 立即只读。
  /// 同步：closed → 输入禁用；rating 回显 → rated（坐席端只展示状态）。
  /// 403/offboarding → 状态机降级。
  Future<CsSessionDetail?> refreshSessionState() async {
    if (!_current || readRevoked) return null;
    final scope = _scope();
    try {
      final d = await _csApi.sessionDetail(
        orgId,
        sessionId,
        // CSB-02R workspace 门必填（session_detail 无 optional 声明，缺省
        // 必 422——真机转接 CAS 拿不到 version 的根因，2026-09-30 实证）。
        workspaceId: workspaceId,
      );
      if (!_same(scope)) return null;
      detail = d;
      if (d.conversationId.isNotEmpty) {
        conversationId = d.conversationId;
      }
      if (identityId.isEmpty && d.assigneeIdentityId.isNotEmpty) {
        // 种子缺失：采纳服务端权威回显（APP-M01-A04）。
        identityId = d.assigneeIdentityId;
      } else if (d.assigneeIdentityId.isNotEmpty &&
          d.assigneeIdentityId != identityId) {
        // 服务端权威：经办人已非当前坐席（被转接/接管）→ 立即只读。
        machine.markTransferredAway();
      }
      if (d.isClosed && d.evaluationState == CsEvaluationState.rated) {
        machine.markRated();
      } else if (d.isClosed) {
        machine.markClosed();
      } else if (machine.phase == CsSeatSessionPhase.readOnlySuspended) {
        // 服务端读成功且未关闭：suspend 只读允许恢复（服务端权威）。
        machine.restoreFromSuspension();
      }
      _invalidateStaleUnread();
      return d;
    } on CsApiException catch (e) {
      if (_same(scope)) _historyFailure(e);
      return null;
    }
  }

  /// 统一失败分类 → 状态机降级（返回分类供 UI 提示）。
  CsSeatFailureKind applyFailure(CsApiException e) {
    final kind = csClassifySeatFailure(e);
    lastFailureKind = kind;
    switch (kind) {
      case CsSeatFailureKind.suspended:
        machine.markSuspended();
      case CsSeatFailureKind.offboarding:
        machine.markOffboarding();
      case CsSeatFailureKind.conflict:
      case CsSeatFailureKind.other:
        break;
    }
    _invalidateStaleUnread();
    return kind;
  }

  /// Current action/target refusal shares the fail-closed read authority boundary.
  CsSeatFailureKind applyActionFailure(CsApiException e) {
    if (!_current) return CsSeatFailureKind.other;
    if (e.isUnauthorized || e.isForbidden) {
      _historyFailure(e);
      machine.markSuspended();
      onChanged?.call();
      return lastFailureKind ?? CsSeatFailureKind.other;
    }
    return applyFailure(e);
  }

  /// 只读终态（转接/撤权/关闭/评分）后未读已无意义：陈旧化（null =
  /// 不渲染）——转接/撤权后不得残留旧坐席视角的未读（CS-RUNTIME-04）。
  void _invalidateStaleUnread() {
    if (!machine.shouldPoll) unreadCount = null;
  }

  // ==================== 已读游标与未读（CS-APP-02 / CS-RUNTIME-04） ====================

  /// 重同步读状态（进入会话 / resume / resync.required 后、渲染未读
  /// **之前**）：权威拉取游标 + 未读数。
  ///
  /// 失败 fail-closed：未读置 null（不渲染陈旧值），本地水位不倒退。
  Future<void> resyncReadState() async {
    if (!_current || readRevoked) return;
    final scope = _scope();
    try {
      final s = await fetchCsReadState(_csApi, orgId, workspaceId, sessionId);
      if (!_same(scope)) return;
      if (nextAckTarget(current: ackedCursor, seen: s.lastReadMessageId) !=
          null) {
        ackedCursor = s.lastReadMessageId;
      }
      unreadCount = s.unreadCount;
    } on CsApiException catch (e) {
      if (_same(scope)) {
        unreadCount = null;
        _historyFailure(e);
      }
    }
  }

  /// 兼容旧调用；获取消息不证明可见，不推进阅读游标。
  Future<void> ackReadSeen() async {}

  Future<void> ackVisibleMessages(Iterable<String> visibleIds) async {
    if (!_current || readRevoked || _ackPending) return;
    final loaded = messages.map((m) => m.id).toSet();
    final visible = visibleIds.where(loaded.contains).toList();
    if (visible.isEmpty) return;
    visible.sort((a, b) => csMessageId(a).compareTo(csMessageId(b)));
    final target = nextAckTarget(current: ackedCursor, seen: visible.last);
    if (target == null) return;
    final scope = _scope();
    _ackPending = true;
    try {
      await acknowledgeCsVisible(_csApi, orgId, workspaceId, sessionId, target);
      if (_same(scope)) {
        if (nextAckTarget(current: ackedCursor, seen: target) != null) {
          ackedCursor = target;
        }
        await resyncReadState();
      }
    } on CsApiException catch (e) {
      if (_same(scope)) _historyFailure(e);
    } finally {
      _ackPending = false;
    }
  }

  Future<List<EnterpriseMessage>> loadLatest() {
    _historyGeneration++;
    return _loadHistory(latest: true);
  }

  Future<List<EnterpriseMessage>> loadOlder() async {
    if (loadingOlder || !hasOlder || _olderCursor == null) return const [];
    olderError = null;
    loadingOlder = true;
    try {
      return await _loadHistory(latest: true, before: _olderCursor);
    } finally {
      loadingOlder = false;
    }
  }

  Future<List<EnterpriseMessage>> loadIncremental({bool poll = false}) async {
    if (poll && !machine.shouldPoll) return const [];
    return _loadHistory(after: cursor);
  }

  Future<List<EnterpriseMessage>> _loadHistory({
    bool latest = false,
    String? before,
    String? after,
  }) async {
    if (!_current || readRevoked || conversationId.isEmpty) return const [];
    await resolveWorkspaceId();
    if (!_current || readRevoked || workspaceId.isEmpty) return const [];
    final scope = _scope();
    final generation = _historyGeneration;
    try {
      final page = await fetchCsHistoryPage(
        _csApi,
        orgId: orgId,
        workspaceId: workspaceId,
        conversationId: conversationId,
        latest: latest,
        beforeId: before,
        afterId: after,
      );
      if (!_same(scope) || generation != _historyGeneration) return const [];
      final result = await _mergeHistory(page, scope, generation);
      if (!_same(scope) || generation != _historyGeneration) return const [];
      if (latest && (before != null || _olderCursor == null)) {
        hasOlder = page.messages.length == csHistoryPageLimit;
        if (page.messages.isNotEmpty) {
          _olderCursor = page.messages.last.message.id;
        }
      }
      if (before == null) historyError = null;
      return result;
    } on CsApiException catch (e) {
      if (_same(scope) && generation == _historyGeneration) {
        if (before != null) olderError = e;
        _historyFailure(e);
      }
      return const [];
    }
  }

  Future<List<EnterpriseMessage>> _mergeHistory(
    CsConversationHistoryPage page,
    String scope,
    int generation, {
    bool delivery = true,
  }) async {
    final delivered = messages
        .where((m) => m.delivered)
        .map((m) => m.id)
        .toSet();
    final auth = deliveryAuthScope;
    final rows = page.messages.map((row) {
      final acknowledged =
          delivered.contains(row.message.id) ||
          (auth != null &&
              deliveryLedger?.contains(auth, scope, row.message.id) == true);
      return CsConversationMessage(
        message: acknowledged ? row.message.withDelivered() : row.message,
        assets: row.assets,
      );
    }).toList();
    for (final row in rows) {
      if (!_same(scope) || generation != _historyGeneration) return const [];
      await _store.saveMessage(row.message);
    }
    if (!_same(scope) || generation != _historyGeneration || readRevoked) {
      return const [];
    }
    final byId = {for (final m in messages) m.id: m};
    final reads = Map<String, DateTime>.from(messageReadAt);
    final assets = Map<String, List<CsMessageAsset>>.from(messageAssets);
    for (final row in rows) {
      byId[row.message.id] = row.message;
      if (row.assets.isEmpty) {
        assets.remove(row.message.id);
      } else {
        assets[row.message.id] = row.assets;
      }
      reads.remove(row.message.id);
    }
    reads.addAll(page.readAt);
    messages = byId.values.toList()
      ..sort((a, b) => csMessageId(a.id).compareTo(csMessageId(b.id)));
    messageAssets = Map.unmodifiable(assets);
    messageReadAt = Map.unmodifiable(reads);
    if (messages.isNotEmpty) cursor = messages.last.id;
    final fresh = rows.map((r) => r.message).toList();
    if (delivery) await _ackInbound(fresh);
    return _same(scope) && generation == _historyGeneration ? fresh : const [];
  }

  void _historyFailure(CsApiException e) {
    historyError = e;
    if (e.isUnauthorized || e.isForbidden) invalidateReadScope();
    applyFailure(e);
  }

  /// Invalidates only this flow's obsolete read projection, including auth loss.
  void invalidateReadScope() {
    deliveryLedger?.invalidateScope(_scope());
    readRevoked = true;
    machine.revokeReadAuthority();
    _events?.dispose();
    assetOperation?.cancel();
    detail = null;
    messages = const [];
    messageAssets = const {};
    messageReadAt = const {};
    unreadCount = null;
    hasOlder = false;
  }

  /// Coalesce hints; each pass reads at most twenty existing fifty-row pages.
  Future<void> refreshLoadedHistory() {
    if (!_current || readRevoked) return Future.value();
    if (_historyRefresh != null) {
      _refreshAgain = true;
      return _historyRefresh!.future;
    }
    _refreshTimer?.cancel();
    final done = Completer<void>();
    _historyRefresh = done;
    unawaited(_drainHistoryRefresh(done, _scope()));
    return done.future;
  }

  Future<void> _drainHistoryRefresh(Completer<void> done, String scope) async {
    try {
      for (var round = 0; round < 2; round++) {
        _refreshAgain = false;
        await _refreshLoadedOnce();
        if (!_same(scope) || readRevoked || !_refreshAgain) break;
      }
    } on CsApiException catch (e) {
      if (_same(scope)) _historyFailure(e);
    } catch (_) {
      if (_same(scope)) {
        _historyFailure(const CsApiException(0, 'history-refresh-failed'));
      }
    } finally {
      _historyRefresh = null;
      done.complete();
      if (_refreshAgain && _same(scope) && !readRevoked) {
        _refreshTimer = Timer(const Duration(milliseconds: 100), () {
          if (_same(scope)) unawaited(refreshLoadedHistory());
        });
      }
    }
  }

  Future<void> _refreshLoadedOnce() async {
    if (!_current ||
        readRevoked ||
        workspaceId.isEmpty ||
        conversationId.isEmpty) {
      return;
    }
    final scope = _scope();
    final generation = ++_historyGeneration;
    final oldest = messages.isEmpty ? null : csMessageId(messages.first.id);
    final rows = <CsConversationMessage>[];
    final reads = <String, DateTime>{};
    String? before;
    for (var count = 0; count < 20; count++) {
      if (!_same(scope) || generation != _historyGeneration) return;
      final page = await fetchCsHistoryPage(
        _csApi,
        orgId: orgId,
        workspaceId: workspaceId,
        conversationId: conversationId,
        latest: true,
        beforeId: before,
      );
      if (!_same(scope) || generation != _historyGeneration) return;
      rows.addAll(page.messages);
      reads.addAll(page.readAt);
      final last = page.messages.isEmpty ? null : page.messages.last.message.id;
      if (last == null ||
          page.messages.length < csHistoryPageLimit ||
          oldest == null ||
          csMessageId(last) <= oldest) {
        await _finishRefresh(
          CsConversationHistoryPage(rows, reads),
          scope,
          generation,
        );
        return;
      }
      before = last;
    }
    await _finishRefresh(
      CsConversationHistoryPage(rows, reads),
      scope,
      generation,
      bounded: true,
    );
  }

  Future<void> _finishRefresh(
    CsConversationHistoryPage page,
    String scope,
    int generation, {
    bool bounded = false,
  }) async {
    await _mergeHistory(page, scope, generation, delivery: false);
    if (_same(scope) && generation == _historyGeneration) {
      historyError = bounded
          ? const CsApiException(0, 'history-refresh-bounded')
          : null;
    }
  }

  /// delivery ACK：只确认投递；本地只置标记（withDelivered 副本），
  /// 消息本体保留在 [messages] 与 store（真源不删）。
  ///
  /// APP-M02-A01：recipient_ref 恒为 `identity:<business_identity_id>`
  /// （服务端 ACK 面唯一合法形状；`seat:` 前缀为后端 400 契约，客户端
  /// 绝不产生）。只写 delivery，不删真源。
  Future<void> _ackInbound(List<EnterpriseMessage> fresh) async {
    if (!_current || readRevoked) return;
    final scope = _scope();
    final undelivered = fresh
        .where((m) => !m.delivered)
        .map((m) => m.id)
        .toList();
    if (undelivered.isEmpty) return;
    await resolveWorkspaceId();
    if (workspaceId.isEmpty) return;
    for (final mid in undelivered) {
      if (!_same(scope) || readRevoked) return;
      await _csApi.ackDelivery(
        orgId,
        conversationId,
        mid,
        workspaceId: workspaceId,
        recipientRef: 'identity:$identityId',
      );
      if (!_same(scope)) return;
      if (deliveryAuthScope != null) {
        deliveryLedger?.record(deliveryAuthScope!, scope, mid);
      }
      await _store.markDelivered(orgId, conversationId, [mid]);
      if (!_same(scope)) return;
      messages = messages
          .map((m) => m.id == mid ? m.withDelivered() : m)
          .toList(growable: false);
    }
  }

  /// 发送坐席消息（幂等）：未确认前重试复用同一 `client_msg_id`；
  /// 附件消息同时复用同一组 `asset_ids`（A03）。
  ///
  /// 返回 true = 已确认（服务端 accepted 形状已入库）；false = 失败
  /// （pendingClientMsgId / pendingAssetIds 保留，下一次发送复用同键；
  /// [lastFailureKind] 给出分类）。失败不产生文件名文本附件——附件消息
  /// 与文本消息同面提交，无文本兜底伪成功。
  Future<bool> send(String text, {List<String> assetIds = const []}) async {
    if (!_current || readRevoked || _actionPending || _writesInFlight > 0) {
      return false;
    }
    _writesInFlight++;
    try {
      return await _sendMessage(text, assetIds: assetIds);
    } finally {
      _writesInFlight--;
    }
  }

  Future<bool> _sendMessage(
    String text, {
    List<String> assetIds = const [],
  }) async {
    if (!_current) return false;
    final body = text.trim();
    if (body.isEmpty && assetIds.isEmpty) return false;
    if (!machine.canSend) return false;
    if (conversationId.isEmpty) {
      // 通道绑定缺失（CSB-02R 前服务端可能不回显）：可解释不可用，
      // 禁止构造非法请求，更禁止 fallback 个人 IM。
      return false;
    }
    // EB-03-A01 显式 workspace 归属（缺省必 422 missing_workspace_id）；
    // 解析失败保持空 = fail-closed（不构造注定失败的请求）。
    await resolveWorkspaceId();
    if (workspaceId.isEmpty) return false;
    if (!_current || readRevoked || _actionPending || !machine.canSend) {
      return false;
    }
    final scope = _scope();
    final clientMsgId = pendingClientMsgId ?? Xid().toString();
    pendingClientMsgId = clientMsgId;
    // 重试稳定性：已有 pending 附件组必须原样复用（A03 同键同附件）。
    final ids = pendingAssetIds ?? List<String>.from(assetIds);
    if (ids.isNotEmpty) {
      pendingAssetIds = ids;
    }
    try {
      final sent = await _csApi.sendConversationMessage(
        orgId,
        conversationId,
        workspaceId: workspaceId,
        body: body,
        clientMsgId: clientMsgId,
        identityId: identityId,
        assetIds: ids,
      );
      if (!_same(scope)) return false;
      pendingClientMsgId = null;
      pendingAssetIds = null;
      lastFailureKind = null;
      final sentMessage = sent.message;
      await _store.saveMessage(sentMessage);
      if (!_same(scope)) return false;
      if (ids.isNotEmpty) {
        // 服务端 POST 回显同形状 assets 投影（CS-BE-01）；本地兜底：回显
        // 未携带投影时用提交的 id 组成最小投影（文件名/mime 待历史刷新）。
        messageAssets = {
          ...messageAssets,
          sentMessage.id: sent.assets.isNotEmpty
              ? sent.assets
              : ids.map((id) => CsMessageAsset(id: id)).toList(),
        };
      }
      final known = messages.map((m) => m.id).toSet();
      if (!known.contains(sentMessage.id)) {
        messages = [...messages, sentMessage]
          ..sort((a, b) => a.id.compareTo(b.id));
      }
      if (sentMessage.id.compareTo(cursor) > 0) {
        cursor = sentMessage.id;
      }
      return true;
    } on CsApiException catch (e) {
      if (_same(scope)) applyActionFailure(e);
      return false;
    }
  }

  // ==================== 附件（企业通道，EB-D06 + §3.7） ====================

  /// Workspace 权威解析：种子为空时经 seat-contexts 取本 Org 第一个
  /// workspace（会话页路由种子只是展示值）。每个 flow 实例只尝试一次
  /// （失败保持空 = 请求面 422 fail-closed，不做本地默认值）。
  Future<String> resolveWorkspaceId() async {
    if (!_current) return '';
    if (workspaceId.isNotEmpty || _workspaceResolveTried) return workspaceId;
    final scope = _scope();
    _workspaceResolveTried = true;
    try {
      final contexts = await _csApi.seatContexts();
      if (!_same(scope)) return '';
      for (final c in contexts.contexts) {
        if (c.organizationId == orgId && c.workspaces.isNotEmpty) {
          workspaceId = c.workspaces.first.id;
          break;
        }
      }
    } on CsApiException {
      // 解析失败保持空（fail-closed），不阻塞消息面外层语义。
    }
    return workspaceId;
  }

  bool _workspaceResolveTried = false;

  // ==================== 坐席事件流（APP-M02-A02） ====================

  CsSeatEventsStream? _events;

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

  /// 释放事件流（页面 dispose 时调用；重连定时器/订阅一并取消）。
  void dispose() {
    _disposed = true;
    assetOperation?.cancel();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _events?.dispose();
    _events = null;
  }
}
