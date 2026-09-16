/// 坐席会话数据流（§12.5.1 / CSM-02）
///
/// 纯 Dart controller（零 Flutter import，HTTP 经 HttpClient.adapterForTest
/// 注入桩即可单测）。职责：
///
/// - 历史 after_id 增量（游标 = 已加载最大消息 id；交付企业 store 缓存）；
/// - 发送（幂等 `client_msg_id`：未确认前重试复用同一 id；服务端幂等语义
///   = 同 id 重放不增行）； sender 恒 business_identity（EB 真源写真源，
///   禁止个人 C2C 通道）；
/// - delivery ACK：对入站未投递消息逐条 ACK；本地只置投递标记
///   （delivery-only），绝不删除消息真源；
/// - 附件：presign → 短期 presigned PUT → confirm；`upload_url` 仅在内存
///   中存在到 PUT 完成为止（不持久化、不进 store、不进 UI）；查看仅走
///   企业 content 鉴权代理（EB-D06），客户端不接收 object key / storage
///   endpoint；
/// - 降级：403 / offboarding 409 → [CsSeatSessionMachine] 清写入口、
///   停后台发送；可解释只读态由 [phase] 驱动 UI。
library;

import 'package:xid/xid.dart';

import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';

/// 坐席失败分类（409 双语义：CAS 竞争 vs offboarding 降级——envelope
/// 双通道语义，标签在 message 文本中）。
enum CsSeatFailureKind { suspended, offboarding, conflict, other }

CsSeatFailureKind csClassifySeatFailure(CsApiException e) {
  if (e.isForbidden) return CsSeatFailureKind.suspended;
  if (e.isConflict) {
    if (e.message.toLowerCase().contains('offboarding')) {
      return CsSeatFailureKind.offboarding;
    }
    return CsSeatFailureKind.conflict;
  }
  return CsSeatFailureKind.other;
}

/// 坐席会话数据流。
class CsSessionFlow {
  final CsApi _csApi;
  final EnterpriseApi _enterpriseApi;
  final EnterpriseStore _store;

  final String orgId;
  final String sessionId;

  /// 会话绑定的企业会话（消息通道；服务端 detail 可补齐）。
  String conversationId;

  /// 经办坐席业务身份（发送的 sender 身份）。
  final String identityId;

  /// 已掩码客户名（入站消息展示）。
  final String contactMaskedName;

  CsSeatSessionMachine machine = CsSeatSessionMachine();

  List<EnterpriseMessage> messages = const <EnterpriseMessage>[];

  /// after_id 游标（已加载最大消息 id）。
  String cursor = '';

  /// 服务端 detail 快照（status/version/rating 同步用）。
  CsSessionDetail? detail;

  /// 未确认出站消息的幂等键（确认成功后清空；重试复用同一 id）。
  String? pendingClientMsgId;

  CsSessionFlow({
    required this.orgId,
    required this.sessionId,
    required this.identityId,
    this.conversationId = '',
    this.contactMaskedName = '',
    CsApi? csApi,
    EnterpriseApi? enterpriseApi,
    EnterpriseStore? store,
  }) : _csApi = csApi ?? CsApi(),
       _enterpriseApi = enterpriseApi ?? EnterpriseApi(),
       _store = store ?? EnterpriseStoreHolder.instance;

  // ==================== 会话状态同步 ====================

  /// 拉取服务端会话详情（打开页面 / 冲突后刷新真实状态）。
  ///
  /// 同步：closed → 输入禁用；rating 回显 → rated（坐席端只展示状态）。
  /// 403/offboarding → 状态机降级。
  Future<CsSessionDetail?> refreshSessionState() async {
    try {
      final d = await _csApi.sessionDetail(sessionId);
      detail = d;
      if (conversationId.isEmpty && d.conversationId.isNotEmpty) {
        conversationId = d.conversationId;
      }
      if (d.hasRating) {
        machine.markRated();
      } else if (d.isClosed) {
        machine.markClosed();
      } else if (machine.phase == CsSeatSessionPhase.readOnlySuspended) {
        // 服务端读成功且未关闭：suspend 只读允许恢复（服务端权威）。
        machine.restoreFromSuspension();
      }
      return d;
    } on CsApiException catch (e) {
      applyFailure(e);
      return null;
    }
  }

  /// 统一失败分类 → 状态机降级（返回分类供 UI 提示）。
  CsSeatFailureKind applyFailure(CsApiException e) {
    final kind = csClassifySeatFailure(e);
    switch (kind) {
      case CsSeatFailureKind.suspended:
        machine.markSuspended();
      case CsSeatFailureKind.offboarding:
        machine.markOffboarding();
      case CsSeatFailureKind.conflict:
      case CsSeatFailureKind.other:
        break;
    }
    return kind;
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
      final fresh = await _csApi.conversationMessages(
        conversationId,
        afterId: cursor,
      );
      for (final m in fresh) {
        await _store.saveMessage(m);
      }
      final known = messages.map((m) => m.id).toSet();
      final merged = [...messages, ...fresh.where((m) => !known.contains(m.id))]
        ..sort((a, b) => a.id.compareTo(b.id));
      messages = merged;
      if (fresh.isNotEmpty) {
        cursor = fresh
            .map((m) => m.id)
            .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      }
      await _ackInbound(fresh);
      // 降级读成功（suspend 只读）：允许恢复（服务端权威）。
      if (machine.phase == CsSeatSessionPhase.readOnlySuspended) {
        machine.restoreFromSuspension();
      }
      return fresh;
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
        recipientRef: 'seat:$identityId',
      );
    }
    await _store.markDelivered(orgId, conversationId, undelivered);
    final marked = undelivered.toSet();
    messages = messages
        .map((m) => marked.contains(m.id) ? m.withDelivered() : m)
        .toList(growable: false);
  }

  /// 发送坐席消息（幂等）：未确认前重试复用同一 `client_msg_id`。
  ///
  /// 返回 true = 已确认（服务端 accepted 形状已入库）；false = 失败
  /// （pendingClientMsgId 保留，下一次发送复用同 id）。
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return false;
    if (!machine.canSend) return false;
    if (conversationId.isEmpty) {
      // 通道绑定缺失（CSB-02R 前服务端可能不回显）：可解释不可用，
      // 禁止构造非法请求，更禁止 fallback 个人 IM。
      return false;
    }
    final clientMsgId = pendingClientMsgId ?? Xid().toString();
    pendingClientMsgId = clientMsgId;
    try {
      final sent = await _csApi.sendConversationMessage(
        orgId,
        conversationId,
        body: body,
        clientMsgId: clientMsgId,
        identityId: identityId,
      );
      pendingClientMsgId = null;
      await _store.saveMessage(sent);
      final known = messages.map((m) => m.id).toSet();
      if (!known.contains(sent.id)) {
        messages = [...messages, sent]..sort((a, b) => a.id.compareTo(b.id));
      }
      if (sent.id.compareTo(cursor) > 0) {
        cursor = sent.id;
      }
      return true;
    } on CsApiException catch (e) {
      applyFailure(e);
      return false;
    }
  }

  // ==================== 附件（企业通道，EB-D06） ====================

  /// 附件上传三步：presign → presigned PUT → confirm；成功后返回
  /// assetId（调用方随后作为消息 asset 通道引用）。`upload_url` 不出
  /// 本方法作用域（不持久化、不进 store、不进 UI）。
  Future<String> uploadAsset({
    required String fileName,
    required String mime,
    required int size,
    required Stream<List<int>> byteStream,
  }) async {
    if (!machine.canSend) return '';
    if (conversationId.isEmpty) return '';
    final asset = await _csApi.uploadEnterpriseAsset(
      orgId,
      fileName: fileName,
      mime: mime,
      size: size,
      byteStream: byteStream,
    );
    return asset.id;
  }

  /// 附件查看：仅经企业 content 鉴权代理（每次请求重新鉴权）。
  Future<String> viewAsset(String assetId) =>
      _enterpriseApi.fetchAssetContentText(orgId, assetId);

  // ==================== 会话动作 ====================

  /// 转接（CAS）。409 冲突：刷新真实状态（detail + 消息面不受影响），
  /// 返回 [CsSeatFailureKind.conflict] 供 UI 提示；成功返回 null。
  Future<CsSeatFailureKind?> transferTo(String toIdentityId) async {
    final version = detail?.version ?? 0;
    if (version <= 0) {
      // 无可信版本：先刷新拿真实 version（不盲发 CAS）。
      await refreshSessionState();
      return CsSeatFailureKind.conflict;
    }
    try {
      await _csApi.transfer(
        sessionId,
        toIdentityId: toIdentityId,
        expectedVersion: version,
      );
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

  /// 关闭（CAS + 可选 reason）。成功 → 状态机 closed（输入禁用，等待
  /// 访客评分）。409：刷新真实状态（可能已被关闭/转走）。
  Future<CsSeatFailureKind?> closeSession({String? reason}) async {
    final version = detail?.version ?? 0;
    if (version <= 0) {
      await refreshSessionState();
      return CsSeatFailureKind.conflict;
    }
    try {
      await _csApi.close(sessionId, expectedVersion: version, reason: reason);
      machine.markClosed();
      return null;
    } on CsApiException catch (e) {
      final kind = applyFailure(e);
      if (kind == CsSeatFailureKind.conflict) {
        await refreshSessionState();
      }
      return kind;
    }
  }
}
