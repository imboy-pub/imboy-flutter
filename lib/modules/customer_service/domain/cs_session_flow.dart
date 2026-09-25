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

import 'dart:typed_data';

import 'package:xid/xid.dart';

import 'package:imboy/modules/customer_service/domain/cs_presence_controller.dart'
    show nextAckTarget;
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';

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
    try {
      final d = await _csApi.sessionDetail(orgId, sessionId);
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
      if (d.hasRating) {
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
      applyFailure(e);
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
    try {
      final s = await _csApi.seatReadState(orgId, sessionId);
      ackedCursor = s.lastReadMessageId;
      unreadCount = s.unreadCount;
    } on CsApiException {
      unreadCount = null;
    }
  }

  /// 「权威展示完成」时 ACK（CS-RUNTIME-04）：把已加载最大消息 id 推进
  /// 读游标。单调裁决（[nextAckTarget]）：无新消息/旧值不发（服务端本就
  /// no-op，本地也不发）；成功后未读清零（本端刚读完）。失败保留水位与
  /// 未读——不本地伪读，下次展示完成重试。
  Future<void> ackReadSeen() async {
    if (messages.isEmpty) return;
    final target = nextAckTarget(current: ackedCursor, seen: messages.last.id);
    if (target == null) return;
    try {
      await _csApi.seatAckRead(orgId, sessionId, target);
      ackedCursor = target;
      unreadCount = 0;
    } on CsApiException {
      // 保留水位：不推进、不清未读（诚实——ACK 未被服务端确认）。
    }
  }

  // ==================== 消息通道 ====================

  /// after_id 增量拉取：游标之后的新消息入库 + 追加（按 id 去重），
  /// 随后对入站未投递消息 delivery ACK（delivery-only，不删真源）。
  ///
  /// [poll] 为 true 时受 [machine.shouldPoll] 门控：降级后停止后台拉取。
  Future<List<EnterpriseMessage>> loadIncremental({bool poll = false}) async {
    if (poll && !machine.shouldPoll) return const [];
    if (conversationId.isEmpty) return const [];
    try {
      await resolveWorkspaceId();
      final fresh = await _csApi.conversationMessages(
        conversationId,
        orgId: orgId,
        workspaceId: workspaceId,
        afterId: cursor,
      );
      final assets = Map<String, List<CsMessageAsset>>.from(messageAssets);
      final inbound = <EnterpriseMessage>[];
      for (final m in fresh) {
        await _store.saveMessage(m.message);
        if (m.assets.isNotEmpty) {
          assets[m.message.id] = m.assets;
        }
        inbound.add(m.message);
      }
      messageAssets = assets;
      final known = messages.map((m) => m.id).toSet();
      final merged = [
        ...messages,
        ...inbound.where((m) => !known.contains(m.id)),
      ]..sort((a, b) => a.id.compareTo(b.id));
      messages = merged;
      if (inbound.isNotEmpty) {
        cursor = inbound
            .map((m) => m.id)
            .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      }
      await _ackInbound(inbound);
      // 降级读成功（suspend 只读）：允许恢复（服务端权威）。
      if (machine.phase == CsSeatSessionPhase.readOnlySuspended) {
        machine.restoreFromSuspension();
      }
      return inbound;
    } on CsApiException catch (e) {
      applyFailure(e);
      return const [];
    } on EnterpriseApiException catch (e) {
      // 企业面 403/409 同样触发降级（同 Org 事实）。
      if (e.isForbidden) machine.markSuspended();
      if (e.isOffboardingRequired) machine.markOffboarding();
      return const [];
    }
  }

  /// delivery ACK：只确认投递；本地只置标记（withDelivered 副本），
  /// 消息本体保留在 [messages] 与 store（真源不删）。
  ///
  /// APP-M02-A01：recipient_ref 恒为 `identity:<business_identity_id>`
  /// （服务端 ACK 面唯一合法形状；`seat:` 前缀为后端 400 契约，客户端
  /// 绝不产生）。只写 delivery，不删真源。
  Future<void> _ackInbound(List<EnterpriseMessage> fresh) async {
    final undelivered = fresh
        .where((m) => !m.delivered)
        .map((m) => m.id)
        .toList();
    if (undelivered.isEmpty) return;
    for (final mid in undelivered) {
      await _csApi.ackDelivery(
        orgId,
        conversationId,
        mid,
        recipientRef: 'identity:$identityId',
      );
    }
    await _store.markDelivered(orgId, conversationId, undelivered);
    final marked = undelivered.toSet();
    messages = messages
        .map((m) => marked.contains(m.id) ? m.withDelivered() : m)
        .toList(growable: false);
  }

  /// 发送坐席消息（幂等）：未确认前重试复用同一 `client_msg_id`；
  /// 附件消息同时复用同一组 `asset_ids`（A03）。
  ///
  /// 返回 true = 已确认（服务端 accepted 形状已入库）；false = 失败
  /// （pendingClientMsgId / pendingAssetIds 保留，下一次发送复用同键；
  /// [lastFailureKind] 给出分类）。失败不产生文件名文本附件——附件消息
  /// 与文本消息同面提交，无文本兜底伪成功。
  Future<bool> send(String text, {List<String> assetIds = const []}) async {
    final body = text.trim();
    if (body.isEmpty && assetIds.isEmpty) return false;
    if (!machine.canSend) return false;
    if (conversationId.isEmpty) {
      // 通道绑定缺失（CSB-02R 前服务端可能不回显）：可解释不可用，
      // 禁止构造非法请求，更禁止 fallback 个人 IM。
      return false;
    }
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
        body: body,
        clientMsgId: clientMsgId,
        identityId: identityId,
        assetIds: ids,
      );
      pendingClientMsgId = null;
      pendingAssetIds = null;
      lastFailureKind = null;
      final sentMessage = sent.message;
      await _store.saveMessage(sentMessage);
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
      applyFailure(e);
      return false;
    }
  }

  // ==================== 附件（企业通道，EB-D06 + §3.7） ====================

  /// Workspace 权威解析：种子为空时经 seat-contexts 取本 Org 第一个
  /// workspace（会话页路由种子只是展示值）。每个 flow 实例只尝试一次
  /// （失败保持空 = 请求面 422 fail-closed，不做本地默认值）。
  Future<String> resolveWorkspaceId() async {
    if (workspaceId.isNotEmpty || _workspaceResolveTried) return workspaceId;
    _workspaceResolveTried = true;
    try {
      final contexts = await _csApi.seatContexts();
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

  /// 附件上传三步：presign（object_hash = SHA-256(bytes)）→ 裸 PUT
  /// （嵌套 upload.url，缺失 fail-closed）→ confirm（upload_ref）；
  /// 成功后返回 assetId（confirmed_unbound，等待与消息原子绑定）。
  /// `upload_url` / `upload_ref` 不出本方法作用域（不持久化、不进
  /// store、不进 UI）。
  Future<String> uploadAsset({
    required String mime,
    required Uint8List bytes,
    String fileName = '',
  }) async {
    if (!machine.canSend) return '';
    if (conversationId.isEmpty) return '';
    await resolveWorkspaceId();
    final asset = await _csApi.uploadEnterpriseAsset(
      orgId,
      workspaceId: workspaceId,
      conversationId: conversationId,
      mime: mime,
      bytes: bytes,
      fileName: fileName,
    );
    return asset.id;
  }

  /// 附件内容字节：仅经企业 content 鉴权代理（每次请求重新鉴权）。
  ///
  /// 门控（A04 读写分离）：closed/rated 只读态仍可查看（服务端代理仍
  /// 是唯一权威）；suspend / offboarding / transferredAway 不再发请求
  /// （旧凭证已被拒 / 经办权已离开）。请求侧 403 / offboarding 409 同样
  /// 触发降级。返回 null = 已降级/通道缺失（UI 不渲染内容）。
  ///
  /// 图片气泡（Image.memory）与文件文本预览（utf8 解码）共用本入口；
  /// **禁止** Image.network/CachedNetworkImage 裸 URL（EB-D06）。
  Future<Uint8List?> fetchAssetBytes(String assetId) async {
    if (!machine.canDownload) return null;
    if (conversationId.isEmpty) return null;
    try {
      return await _csApi.fetchAssetBytes(orgId, assetId);
    } on EnterpriseApiException catch (e) {
      if (e.isForbidden) machine.markSuspended();
      if (e.isOffboardingRequired) machine.markOffboarding();
      return null;
    }
  }

  // ==================== 会话动作 ====================

  /// 转接（CAS）。409 冲突：刷新真实状态（detail + 消息面不受影响），
  /// 返回 [CsSeatFailureKind.conflict] 供 UI 提示；成功 → 旧坐席**立即
  /// 只读**（A04 transferredAway，目标坐席经其自身权威回显接管）。
  Future<CsSeatFailureKind?> transferTo(String toIdentityId) async {
    final version = detail?.version ?? 0;
    if (version <= 0) {
      // 无可信版本：先刷新拿真实 version（不盲发 CAS）。
      await refreshSessionState();
      return CsSeatFailureKind.conflict;
    }
    try {
      await _csApi.transfer(
        orgId,
        sessionId,
        toIdentityId: toIdentityId,
        expectedVersion: version,
      );
      machine.markTransferredAway();
      unreadCount = null;
      lastFailureKind = null;
      return null;
    } on CsApiException catch (e) {
      final kind = applyFailure(e);
      // CAS 冲突：刷新真实状态再提示（不做乐观伪成功）。
      if (kind == CsSeatFailureKind.conflict) {
        await refreshSessionState();
      }
      return kind;
    }
  }

  /// 关闭（CAS + 可选 reason）。成功 → 状态机 closed（所有写入口禁用，
  /// 等待访客评分）。409：刷新真实状态（可能已被关闭/转走）。
  Future<CsSeatFailureKind?> closeSession({String? reason}) async {
    final version = detail?.version ?? 0;
    if (version <= 0) {
      await refreshSessionState();
      return CsSeatFailureKind.conflict;
    }
    try {
      await _csApi.close(
        orgId,
        sessionId,
        expectedVersion: version,
        reason: reason,
      );
      machine.markClosed();
      unreadCount = null;
      lastFailureKind = null;
      return null;
    } on CsApiException catch (e) {
      final kind = applyFailure(e);
      if (kind == CsSeatFailureKind.conflict) {
        await refreshSessionState();
      }
      return kind;
    }
  }

  // ==================== 坐席事件流（APP-M02-A02） ====================

  CsSeatEventsStream? _events;

  /// 绑定并启动坐席事件流（`seats/me/events`）。事件只是权威刷新触发器：
  /// 信封 payload 不含业务真源，一切以回源请求为准；访客新消息由
  /// message.appended 触发增量拉取在时限内自动出现（无轮询、无风暴）。
  void bindEvents(CsSeatEventsStream stream) {
    _events?.dispose();
    _events = stream;
    stream.start(onEvent: _onSeatEvent);
  }

  void _onSeatEvent(CsSseEnvelope e) {
    // 降级/只读终态后停止消费（不再发任何刷新请求；撤权降级由权威
    // 请求的 403/409 驱动，服务端也会在撤权后关闭流）。
    if (!machine.shouldPoll) return;
    switch (e.type) {
      case CsSseEnvelope.typeMessageAppended:
        // 访客新消息：增量权威拉取（游标防重，事件重复无害）→ 页面在场
        // 消费即「展示完成」→ ACK 推进读游标（CS-APP-02）。
        loadIncremental().then((_) => ackReadSeen());
      case CsSseEnvelope.typeSessionChanged:
        if (e.resourceId.isEmpty || e.resourceId == sessionId) {
          refreshSessionState();
        }
      case CsSseEnvelope.typeAssignmentChanged:
      case CsSseEnvelope.typeSeatChanged:
        // 撤权/挂起/过期最小事件：立即权威刷新，让 403/409/回显定格降级。
        refreshSessionState();
      case CsSseEnvelope.typeResyncRequired:
        // 游标缺失/过期/不连续：清消息游标 + **未读陈旧化**（null——重连后
        // 不得渲染陈旧未读），先重同步读状态（游标/未读权威值）再增量
        // 拉取渲染，展示完成后 ACK 推进（CS-RUNTIME-04 重连顺序）。
        cursor = '';
        unreadCount = null;
        refreshSessionState();
        resyncReadState()
            .then((_) => loadIncremental())
            .then((_) => ackReadSeen());
      case CsSseEnvelope.typeQueueChanged:
        // 队列事件由工作台页面级流消费；会话页不响应。
        break;
      default:
        break;
    }
  }

  /// 释放事件流（页面 dispose 时调用；重连定时器/订阅一并取消）。
  void dispose() {
    _events?.dispose();
    _events = null;
  }
}
