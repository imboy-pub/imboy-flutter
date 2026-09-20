/// 客服（坐席侧）API 客户端（amendment §2.4 / plan §5.2 + T-2 裁定）
///
/// 契约（api-surface-freeze API-SURFACE-FREEZE-V1，权威）：坐席端点全部
/// **org 作用域**——路径显式携带 organization_id，服务端逐字校验
/// path org == session.org == 坐席 active member org（客户端申报值只作
/// 逐字比对，不是授权事实）：
/// - `GET /api/v1/cs/me/seat-contexts`（唯一主体作用域端点，无 org 键）；
/// - `GET /api/v1/cs/organizations/:org_id/sessions/queue`（queued 视图）；
/// - `GET /api/v1/cs/organizations/:org_id/seats/sessions?status=active|closed`
///   （active/closed 视图；status 必填且仅接受这两值）；
/// - `GET /api/v1/cs/organizations/:org_id/sessions/:id`（会话详情）；
/// - `GET /api/v1/cs/organizations/:org_id/transfer-targets`（同 Org 坐席
///   最小投影；无 owner/admin 权限要求）；
/// - `POST .../sessions/:id/claim|transfer|close`（CAS 动作，org 在路径）。
///
/// 列表统一键集分页（`after_id`/`limit`）+ 服务端计数（`total` /
/// `total_by_status`，缺省 null——客户端禁止本地推断计数）。
///
/// 错误映射：401 未授权 / 403 被拒绝（含被 suspend 后的 claim 等写操作）
/// / 409 冲突或 offboarding_required；镜像 [EnterpriseApiException] 判定属性。
library;

import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// queue 键集分页默认每页条数（与服务端 page_view limit 语义一致）。
const int kCsQueuePageSize = 20;

/// 客服 API 失败。
class CsApiException implements Exception {
  final int code;
  final String message;

  const CsApiException(this.code, this.message);

  bool get isUnauthorized => code == 401;

  /// 403：无权限 / 坐席被 suspend（降级只读）。
  bool get isForbidden => code == 403;

  /// 409：并发/状态竞争（CAS mismatch、not_claimable、invalid_transition 等，
  /// 见 cs_http:classify 的 409 段）。
  bool get isConflict => code == 409;

  /// 409 的 offboarding 降级子语义（envelope `offboarding_required`）。
  bool get isOffboardingRequired => code == 409;

  @override
  String toString() => 'CsApiException($code): $message';
}

/// 客服排队会话条目。
class CsQueueItem {
  final String sessionId;
  final String contactId;
  final String contactName;

  /// 排队起始（毫秒时间戳字符串；由服务端 epoch 秒规范化，缺省为空）。
  final String waitingSince;

  /// 服务端会话乐观锁版本（claim 的 `expected_version` 来源；
  /// SESSION_LIST_PROJECTION 的 `version` 投影，缺省 0 表示服务端未给出，
  /// 此时调用方不得发起 CAS claim）。
  final int version;

  /// 会话状态 wire 值（queued/active/...，服务端缺省为空）。
  final String status;

  /// 来源渠道（widget 直访 / 其它接入面；服务端缺省为空则 UI 隐藏渠道标识）。
  final String source;

  /// 服务端只下发末条消息元数据，不下发正文；用于显示安全占位。
  final bool hasLastMessage;

  /// 租户与会话绑定（A0 投影含 organization_id；conversation_id 服务端
  /// 给出即用——缺省时由会话详情补齐，禁止任何个人 IM fallback）。
  final String organizationId;
  final String conversationId;

  /// 经办坐席业务身份（服务端投影 `business_identity_id`；queued 视图
  /// 接单前可能为空——claim 回显 / detail 回显为准）。
  final String assigneeIdentityId;

  const CsQueueItem({
    required this.sessionId,
    required this.contactId,
    this.contactName = '',
    this.waitingSince = '',
    this.version = 0,
    this.status = '',
    this.source = '',
    this.hasLastMessage = false,
    this.organizationId = '',
    this.conversationId = '',
    this.assigneeIdentityId = '',
  });

  factory CsQueueItem.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'];
    final lastMessage = json['last_message'];
    return CsQueueItem(
      // 后端 seat 队列投影主键为 `id`（seat_session_view 白名单）；
      // `session_id` 仅 widget 建会话响应有别名——`id` 优先，避免接单
      // URL 拼空（历史漂移：曾只读 session_id 致 /sessions//claim）。
      sessionId: entityIdOf(json['id'] ?? json['session_id']),
      contactId: entityIdOf(json['contact_id']),
      contactName: contact is Map
          ? parseModelString(contact['masked_name'])
          : '',
      waitingSince: _epochSecondsToMilliseconds(json['queued_at']),
      version: parseModelInt(json['version']),
      status: parseModelString(json['status']),
      source: parseModelString(json['source']),
      hasLastMessage:
          lastMessage is Map && entityIdOf(lastMessage['id']).isNotEmpty,
      organizationId: entityIdOf(json['organization_id']),
      conversationId: entityIdOf(json['conversation_id']),
      assigneeIdentityId: entityIdOf(json['business_identity_id']),
    );
  }
}

String _epochSecondsToMilliseconds(dynamic value) {
  final seconds = int.tryParse(parseModelString(value));
  return seconds == null || seconds <= 0 ? '' : '${seconds * 1000}';
}

/// queue 列表页（键集分页 + 服务端计数元数据）。
///
/// 计数纪律（§12.5.1）：徽标计数只取服务端键（`total` / `total_by_status`）；
/// 服务端未给出的计数一律为 null（UI 隐藏数字），**禁止**用已加载行数、
/// 全表行数差或本地累加推断。
class CsQueuePage {
  final List<CsQueueItem> items;

  /// 下一页游标（TSID string）。空 = 服务端 `next_after_id` 为 null/缺失，
  /// 即没有更多页（page_view 语义：返回行数 < limit 时为 null）。
  final String nextAfterId;

  /// 服务端总计数（缺省 null = 服务端未提供，不得本地推断）。
  final int? total;

  /// 服务端按状态计数（如 `{queued: 3, active: 1}`；缺省 null = 未提供）。
  final Map<String, int>? totalByStatus;

  const CsQueuePage({
    required this.items,
    this.nextAfterId = '',
    this.total,
    this.totalByStatus,
  });

  bool get hasMore => nextAfterId.isNotEmpty;

  /// 指定状态的徽标计数：只信服务端键，未提供返回 null。
  int? countOf(String status) {
    if (totalByStatus != null) {
      return totalByStatus![status];
    }
    return null;
  }

  /// payload 列表键：A0 真源 `page_view` 输出 `{sessions: [...]}`（键 = 资源
  /// 名复数）；W2 冻结契约测试与既有客户端使用 `list`。两者同为服务端下发，
  /// 取 `sessions` 优先、`list` 兜底，均缺失视为空页（不抛错，分页语义）。
  static List<dynamic> _listOf(dynamic payload) {
    if (payload is! Map) return const [];
    final sessions = payload['sessions'];
    if (sessions is List) return sessions;
    final list = payload['list'];
    if (list is List) return list;
    return const [];
  }

  factory CsQueuePage.fromJson(dynamic payload) {
    final items = _listOf(payload)
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => CsQueueItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    final meta = payload is Map ? payload : const <String, dynamic>{};
    final nextRaw = meta['next_after_id'];
    final next = nextRaw == null ? '' : nextRaw.toString();
    final byStatusRaw = meta['total_by_status'];
    Map<String, int>? byStatus;
    if (byStatusRaw is Map) {
      byStatus = byStatusRaw.map(
        (k, v) => MapEntry(k.toString(), parseModelInt(v)),
      );
    }
    final totalRaw = meta['total'];
    return CsQueuePage(
      items: items,
      nextAfterId: next,
      total: totalRaw == null ? null : parseModelInt(totalRaw),
      totalByStatus: byStatus,
    );
  }
}

/// claim 成功结果（服务端回显的会话投影，宽容解析）。
class CsClaimResult {
  final String sessionId;
  final String status;

  /// claim 后的会话版本（后续 transfer/close 的 expected_version 基数）。
  final int version;

  /// 经办坐席业务身份（服务端派生，客户端不可自报）。
  final String assigneeIdentityId;

  const CsClaimResult({
    required this.sessionId,
    this.status = '',
    this.version = 0,
    this.assigneeIdentityId = '',
  });

  factory CsClaimResult.fromJson(String sessionId, dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    return CsClaimResult(
      sessionId: entityIdOf(map['session_id'] ?? map['id'] ?? sessionId),
      status: parseModelString(map['status']),
      version: parseModelInt(map['version']),
      assigneeIdentityId: entityIdOf(map['business_identity_id']),
    );
  }
}

/// 坐席会话详情（CSB-03：GET /api/v1/cs/sessions/:id 回显投影，宽容解析）。
class CsSessionDetail {
  final String sessionId;
  final String organizationId;

  /// 会话绑定的企业会话（消息通道的必要输入；服务端缺省为空——缺失时
  /// 消息通道显示可解释不可用态，禁止任何个人 IM fallback）。
  final String conversationId;
  final String status;
  final int version;

  /// 访客评分（0 = 未评分；坐席端只展示评分状态，不代访客评分）。
  final int rating;
  final String contactId;
  final String assigneeIdentityId;

  const CsSessionDetail({
    required this.sessionId,
    this.organizationId = '',
    this.conversationId = '',
    this.status = '',
    this.version = 0,
    this.rating = 0,
    this.contactId = '',
    this.assigneeIdentityId = '',
  });

  bool get isClosed => status == 'closed';

  bool get hasRating => rating > 0;

  factory CsSessionDetail.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    return CsSessionDetail(
      sessionId: entityIdOf(map['session_id'] ?? map['id']),
      organizationId: entityIdOf(map['organization_id']),
      conversationId: entityIdOf(map['conversation_id']),
      status: parseModelString(map['status']),
      version: parseModelInt(map['version']),
      rating: parseModelInt(map['rating']),
      contactId: entityIdOf(map['contact_id']),
      assigneeIdentityId: entityIdOf(map['business_identity_id']),
    );
  }
}

/// 坐席上下文内的 Workspace 引用（BE-S01a 投影 `#{id, name}`）。
class CsSeatWorkspaceRef {
  final String id;
  final String name;

  const CsSeatWorkspaceRef({required this.id, this.name = ''});
}

/// 坐席上下文（BE-S01a：GET /api/v1/cs/me/seat-contexts 每 Org 一行）。
///
/// 服务端已按四张事实表聚合过滤（active member + active workspace +
/// active customer_service assignment + seat），但**行内仍以字段为准**：
/// `businessIdentityId` 非空 = active assignment；`seatEnabled` = enabled
/// seat。两者同时成立才是可用坐席上下文（入口/组织选择器唯一口径）。
class CsSeatContext implements CsSeatContextLike {
  final String organizationId;
  final String organizationName;
  final List<CsSeatWorkspaceRef> workspaces;

  /// 服务端派生的经办业务身份（客户端不可自报；claim/detail 以服务端
  /// 回显为准）。
  final String businessIdentityId;
  final bool seatEnabled;
  final List<String> capabilities;

  const CsSeatContext({
    required this.organizationId,
    this.organizationName = '',
    this.workspaces = const <CsSeatWorkspaceRef>[],
    this.businessIdentityId = '',
    this.seatEnabled = false,
    this.capabilities = const <String>[],
  });

  /// 可用坐席上下文：active assignment（身份非空）+ enabled seat 同时成立。
  @override
  bool get isEligible => seatEnabled && businessIdentityId.isNotEmpty;

  factory CsSeatContext.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    final workspacesRaw = map['workspaces'];
    final workspaces = workspacesRaw is List
        ? workspacesRaw
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (m) => CsSeatWorkspaceRef(
                  id: entityIdOf(m['id']),
                  name: parseModelString(m['name']),
                ),
              )
              .toList(growable: false)
        : const <CsSeatWorkspaceRef>[];
    final capabilitiesRaw = map['capabilities'];
    final capabilities = capabilitiesRaw is List
        ? capabilitiesRaw.map(parseModelString).toList(growable: false)
        : const <String>[];
    return CsSeatContext(
      organizationId: entityIdOf(map['organization_id']),
      organizationName: parseModelString(map['organization_name']),
      workspaces: workspaces,
      businessIdentityId: entityIdOf(map['business_identity_id']),
      seatEnabled: map['seat_enabled'] == true,
      capabilities: capabilities,
    );
  }
}

/// seat-contexts 响应（`{contexts: [...], user_id}`）。
class CsSeatContexts {
  final List<CsSeatContext> contexts;
  final String userId;

  const CsSeatContexts({required this.contexts, this.userId = ''});

  factory CsSeatContexts.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    final raw = map['contexts'];
    final contexts = raw is List
        ? raw.map(CsSeatContext.fromJson).toList(growable: false)
        : const <CsSeatContext>[];
    return CsSeatContexts(
      contexts: contexts,
      userId: entityIdOf(map['user_id']),
    );
  }
}

/// 转接目标（BE-S01a：GET .../transfer-targets 行投影）。
///
/// 服务端已排除调用者本人（认证派生 business_identity_id）；
/// `available` = active 会话数未达 max_concurrent（store 同语句计数）。
class CsTransferTarget {
  final String identityId;
  final String displayName;
  final bool available;

  const CsTransferTarget({
    required this.identityId,
    this.displayName = '',
    this.available = false,
  });

  factory CsTransferTarget.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return CsTransferTarget(
      identityId: entityIdOf(map['business_identity_id']),
      displayName: parseModelString(map['display_name']),
      available: map['available'] == true,
    );
  }
}

/// transfer-targets 页（键集分页；列表键 `targets`）。
class CsTransferTargetPage {
  final List<CsTransferTarget> items;

  /// 下一页游标；空 = 无更多页。
  final String nextAfterId;

  const CsTransferTargetPage({required this.items, this.nextAfterId = ''});

  bool get hasMore => nextAfterId.isNotEmpty;

  factory CsTransferTargetPage.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    final raw = map['targets'];
    final items = raw is List
        ? raw.map(CsTransferTarget.fromJson).toList(growable: false)
        : const <CsTransferTarget>[];
    final nextRaw = map['next_after_id'];
    return CsTransferTargetPage(
      items: items,
      nextAfterId: nextRaw == null ? '' : nextRaw.toString(),
    );
  }
}

/// 客服（坐席侧）API 客户端。
class CsApi extends HttpClient {
  /// 坐席上下文清单（主体作用域，无 org 键；api-surface-freeze 坐席面入口）：
  /// GET /api/v1/cs/me/seat-contexts。一次返回当前用户全部 active member
  /// Org 的坐席事实（workspace / active customer_service identity /
  /// seat enabled / capabilities）。入口与组织选择器以此为准，客户端
  /// 不手填 TSID、不猜测 Org。
  Future<CsSeatContexts> seatContexts() async {
    final resp = await get('/api/v1/cs/me/seat-contexts');
    _ensureOk(resp);
    return CsSeatContexts.fromJson(resp.payload);
  }

  /// 坐席排队会话列表（queued 视图；T-2 后 org 显式在路径）：
  /// GET /api/v1/cs/organizations/:org_id/sessions/queue，
  /// query 仅携带非空 `after_id`/`limit`（A0 冻结分页键名）。返回
  /// [CsQueuePage]（列表 + 游标 + 服务端计数元数据）。
  Future<CsQueuePage> queuePage(
    String orgId, {
    String? afterId,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
      if (limit != null && limit > 0) 'limit': limit,
    };
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/sessions/queue',
      queryParameters: query,
    );
    _ensureOk(resp);
    return CsQueuePage.fromJson(resp.payload);
  }

  /// 坐席 active/closed 两视图（CSB-02R）：GET
  /// /api/v1/cs/organizations/:org_id/seats/sessions。
  ///
  /// `status` 必填且仅接受 `active`/`closed`（queued 视图冻结在
  /// sessions/queue，服务端显式拒绝其他值）；分页与计数口径同
  /// [queuePage]。返回与队列同形的 [CsQueuePage]。
  Future<CsQueuePage> seatSessionsPage(
    String orgId, {
    required String status,
    String? afterId,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      'status': status,
      if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
      if (limit != null && limit > 0) 'limit': limit,
    };
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/seats/sessions',
      queryParameters: query,
    );
    _ensureOk(resp);
    return CsQueuePage.fromJson(resp.payload);
  }

  /// claim：坐席接单（CAS，§12.5.1；T-2 后 org 显式在路径）。
  ///
  /// `expectedVersion` 为接单前从 queue 详情读到的会话 [CsQueueItem.version]；
  /// 服务端 A0 冻结参数表要求必填。并发竞争（他坐席先接 / 状态已推进）返回
  /// 409（[CsApiException.isConflict]），调用方必须刷新真实状态后提示，
  /// 不得做乐观伪成功。
  Future<CsClaimResult> claim(
    String orgId,
    String sessionId, {
    required int expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/claim',
      data: {'expected_version': expectedVersion},
    );
    _ensureOk(resp);
    return CsClaimResult.fromJson(sessionId, resp.payload);
  }

  /// transfer：转接给目标业务身份（CAS，§12.5.1 CSM-02）。
  ///
  /// A0 冻结参数表（cs_actions:session_transfer）：`to_identity_id`（tsid）
  /// 与 `expected_version`（int）均必填。并发/状态竞争 409（[CsApiException.isConflict]），
  /// 调用方刷新真实状态后提示，不做乐观伪成功。
  Future<void> transfer(
    String orgId,
    String sessionId, {
    required String toIdentityId,
    required int expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/transfer',
      data: {
        'to_identity_id': toIdentityId,
        'expected_version': expectedVersion,
      },
    );
    _ensureOk(resp);
  }

  /// close：结束会话（CAS + 可选 reason，§12.5.1 CSM-02）。
  ///
  /// A0 冻结参数表（cs_actions:session_close）：`expected_version` 必填、
  /// `reason` 可选（审计文本，调用方先经 [csSanitizeCloseReason] 白名单清洗）。
  Future<void> close(
    String orgId,
    String sessionId, {
    required int expectedVersion,
    String? reason,
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/close',
      data: {
        'expected_version': expectedVersion,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    _ensureOk(resp);
  }

  /// 坐席会话详情（CSB-03）：GET /api/v1/cs/organizations/:org_id/sessions/:id。
  ///
  /// 用途：打开会话页的**权威** identity/conversation 事实源（路由 query
  /// 只是展示种子，不作授权事实）、claim/transfer/close 冲突后刷新真实
  /// 状态、close 后回显 rating 状态（坐席端只展示评分状态，不代访客评分）。
  Future<CsSessionDetail> sessionDetail(String orgId, String sessionId) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId',
    );
    _ensureOk(resp);
    return CsSessionDetail.fromJson(resp.payload);
  }

  /// 转接目标最小投影（BE-S01a）：GET
  /// /api/v1/cs/organizations/:org_id/transfer-targets。
  ///
  /// 同 Org 其他可用坐席（identity id / 显示名 / available），服务端已排除
  /// 调用者本人；无 owner/admin 权限要求——**不复用**治理 identity 列表。
  Future<CsTransferTargetPage> transferTargets(
    String orgId, {
    String? afterId,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
      if (limit != null && limit > 0) 'limit': limit,
    };
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/transfer-targets',
      queryParameters: query,
    );
    _ensureOk(resp);
    return CsTransferTargetPage.fromJson(resp.payload);
  }

  /// 坐席侧企业消息历史（A0 冻结读路径）：GET
  /// `/api/v1/enterprise/conversations/:conversationId/messages`，
  /// query 仅携带非空 `after_id`/`limit`（EB 真源键集分页；游标缺省语义
  /// = 全量首拉）。
  ///
  /// payload 形状：EB `list_messages` 返回裸消息数组（宽容兼容
  /// `{messages: [...]}` / `{list: [...]}` 包裹）。
  Future<List<EnterpriseMessage>> conversationMessages(
    String conversationId, {
    String afterId = '',
    int limit = 0,
  }) async {
    final resp = await get(
      '/api/v1/enterprise/conversations/$conversationId/messages',
      queryParameters: {
        if (afterId.isNotEmpty) 'after_id': afterId,
        if (limit > 0) 'limit': limit,
      },
    );
    _ensureOk(resp);
    final payload = resp.payload;
    List<dynamic> raw;
    if (payload is List) {
      raw = payload;
    } else if (payload is Map) {
      raw =
          (payload['messages'] ?? payload['list'] ?? const <dynamic>[])
              as List<dynamic>;
    } else {
      raw = const <dynamic>[];
    }
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => EnterpriseMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// 坐席出站消息（复用 EB 写真源端点，F-SEC-02：conversation.write）：
  /// POST `/api/v1/enterprise/organizations/{orgId}/conversations/{conversationId}/messages`。
  ///
  /// A0/EB 冻结提交面：`client_msg_id`（幂等键，重试必须复用同一 id）、
  /// `sender_type`（坐席恒 business_identity）、`body`、`identity_id`
  /// （经办业务身份）。禁止走个人 C2C/attachment 通道。
  Future<EnterpriseMessage> sendConversationMessage(
    String orgId,
    String conversationId, {
    required String body,
    required String clientMsgId,
    required String identityId,
  }) async {
    final resp = await post(
      '/api/v1/enterprise/organizations/$orgId/conversations/$conversationId/messages',
      data: {
        'client_msg_id': clientMsgId,
        'sender_type': EnterpriseSenderType.businessIdentity.wireName,
        'body': body,
        'identity_id': identityId,
      },
    );
    _ensureOk(resp);
    final map = IMBoyHttpResponse.payloadAsMap(resp.payload);
    return EnterpriseMessage.fromJson(map);
  }

  /// delivery ACK（幂等，delivery-only；EB 合同 `recipient_ref` 必填）。
  ///
  /// 成功与否都不触发本地删除/隐藏语义——本地只置投递标记。
  Future<void> ackDelivery(
    String orgId,
    String conversationId,
    String messageId, {
    required String recipientRef,
    String deviceId = '',
  }) async {
    final resp = await post(
      '/api/v1/enterprise/organizations/$orgId/conversations/$conversationId/messages/$messageId/ack',
      data: {
        'recipient_ref': recipientRef,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
    );
    _ensureOk(resp);
  }

  /// 企业附件三步上传（presign → 短期 presigned PUT → confirm）。
  ///
  /// EB-D06 纪律：`upload_url` 仅在内存中使用到 PUT 完成为止，本方法
  /// 不返回、不记录、不持久化该 URL；confirm 走独立请求重新鉴权。
  /// 只允许企业附件通道，禁止个人 attachment fallback。
  Future<EnterpriseAsset> uploadEnterpriseAsset(
    String orgId, {
    required String fileName,
    required String mime,
    required int size,
    required Stream<List<int>> byteStream,
  }) async {
    final enterpriseApi = EnterpriseApi();
    final presign = await enterpriseApi.presignAsset(
      orgId,
      fileName: fileName,
      mime: mime,
      size: size,
    );
    // 短期 presigned PUT：直传对象存储，走裸 dio（不叠 IMBoy 鉴权头；
    // 失败 fail-closed 抛出，upload_url 随请求结束即弃）。
    final putResp = await dio.put<Object>(
      presign.uploadUrl,
      data: byteStream,
      options: Options(headers: {'Content-Type': mime}),
    );
    final status = putResp.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw CsApiException(status ?? 0, 'asset PUT failed');
    }
    return enterpriseApi.confirmAsset(orgId, presign.assetId);
  }

  // rating 面是访客侧动作（/api/v1/cs/sessions/:id/rating = cs_visit 主体）：
  // 坐席端只展示评分状态（sessionDetail.rating），不代访客评分——CsApi
  // 无评分提交面（compile-time 事实，契约测试钉住）。

  void _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw CsApiException(resp.code, resp.msg);
    }
  }
}
