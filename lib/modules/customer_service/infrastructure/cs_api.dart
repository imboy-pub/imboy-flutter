/// 客服（坐席侧）API 客户端（amendment §2.4 / plan §5.2 客服 API）
///
/// 契约：plan §5.2 保留 V3 的 session/claim/transfer/close/rating 能力，
/// 但 V3 具体路径不在冻结件中（契约疑问已在 A4 报告登记）。本客户端按
/// 最小形状实现：`/api/v1/cs/sessions/...`，路径参数为 session id，动作
/// 全部为 POST（claim/transfer/close/rating）。
///
/// §12.5.1（CSM-01）补充：queue 列表键集分页（`after_id`/`limit`，键名与
/// A0 冻结的 `conversation_messages`/`seats` 分页一致）与 CAS 接单
/// （claim 携带 `expected_version`，A0 冻结参数表 cs_actions:session_claim
/// required）。409 = 并发/状态竞争（CAS 冲突 / offboarding 降级），客户端
/// 不做乐观伪成功：冲突时刷新真实状态再提示。
///
/// 错误映射：401 未授权 / 403 被拒绝（含被 suspend 后的 claim 等写操作）
/// / 409 冲突或 offboarding_required；镜像 [EnterpriseApiException] 判定属性。
library;

import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
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

  /// 排队起始（毫秒时间戳字符串；服务端缺省为空）。
  final String waitingSince;

  /// 服务端会话乐观锁版本（claim 的 `expected_version` 来源；
  /// SESSION_LIST_PROJECTION 的 `version` 投影，缺省 0 表示服务端未给出，
  /// 此时调用方不得发起 CAS claim）。
  final int version;

  /// 会话状态 wire 值（queued/active/...，服务端缺省为空）。
  final String status;

  /// 来源渠道（widget 直访 / 其它接入面；服务端缺省为空则 UI 隐藏渠道标识）。
  final String source;

  /// 最后一条消息的安全摘要（服务端脱敏后下发；缺省为空则 UI 隐藏）。
  final String lastMessageSummary;

  /// 租户与会话绑定（A0 投影含 organization_id；conversation_id 服务端
  /// 给出即用——缺省时由会话详情补齐，禁止任何个人 IM fallback）。
  final String organizationId;
  final String conversationId;

  const CsQueueItem({
    required this.sessionId,
    required this.contactId,
    this.contactName = '',
    this.waitingSince = '',
    this.version = 0,
    this.status = '',
    this.source = '',
    this.lastMessageSummary = '',
    this.organizationId = '',
    this.conversationId = '',
  });

  factory CsQueueItem.fromJson(Map<String, dynamic> json) {
    return CsQueueItem(
      // 后端 seat 队列投影主键为 `id`（seat_session_view 白名单）；
      // `session_id` 仅 widget 建会话响应有别名——`id` 优先，避免接单
      // URL 拼空（历史漂移：曾只读 session_id 致 /sessions//claim）。
      sessionId: entityIdOf(json['id'] ?? json['session_id']),
      contactId: entityIdOf(json['contact_id']),
      contactName: parseModelString(json['contact_name']),
      waitingSince: parseModelString(json['waiting_since']),
      version: parseModelInt(json['version']),
      status: parseModelString(json['status']),
      source: parseModelString(json['source']),
      lastMessageSummary: parseModelString(json['last_message_summary']),
      organizationId: entityIdOf(json['organization_id']),
      conversationId: entityIdOf(json['conversation_id']),
    );
  }
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

/// 客服（坐席侧）API 客户端。
class CsApi extends HttpClient {
  /// 排队会话列表（W2 冻结形状：GET、无 query 参数；返回条目列表）。
  Future<List<CsQueueItem>> queue() async {
    final resp = await get('/api/v1/cs/sessions/queue');
    _ensureOk(resp);
    return CsQueuePage.fromJson(resp.payload).items;
  }

  /// 排队会话列表（键集分页，§12.5.1）：GET 同路径，query 仅携带非空
  /// `after_id`/`limit`（A0 冻结分页键名；`after_id` 为上一页末条
  /// session id，`limit` 每页条数）。返回 [CsQueuePage]（列表 + 游标 +
  /// 服务端计数元数据）。
  Future<CsQueuePage> queuePage({String? afterId, int? limit}) async {
    final query = <String, dynamic>{
      if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
      if (limit != null && limit > 0) 'limit': limit,
    };
    final resp = await get('/api/v1/cs/sessions/queue', queryParameters: query);
    _ensureOk(resp);
    return CsQueuePage.fromJson(resp.payload);
  }

  /// claim：坐席接单（CAS，§12.5.1）。
  ///
  /// `expectedVersion` 为接单前从 queue 详情读到的会话 [CsQueueItem.version]；
  /// 服务端 A0 冻结参数表要求必填。并发竞争（他坐席先接 / 状态已推进）返回
  /// 409（[CsApiException.isConflict]），调用方必须刷新真实状态后提示，
  /// 不得做乐观伪成功。
  Future<CsClaimResult> claim(
    String sessionId, {
    required int expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/claim',
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
    String sessionId, {
    required String toIdentityId,
    required int expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/transfer',
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
    String sessionId, {
    required int expectedVersion,
    String? reason,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/close',
      data: {
        'expected_version': expectedVersion,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    _ensureOk(resp);
  }

  /// 坐席会话详情（CSB-03）：GET /api/v1/cs/sessions/:id。
  ///
  /// 用途：claim/transfer/close 冲突后刷新真实状态、close 后回显 rating
  /// 状态（坐席端只展示评分状态，不代访客评分）。
  Future<CsSessionDetail> sessionDetail(String sessionId) async {
    final resp = await get('/api/v1/cs/sessions/$sessionId');
    _ensureOk(resp);
    return CsSessionDetail.fromJson(resp.payload);
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

  /// rating：会话评分（1..5，CAS——expected_version 取自会话视图 version）。
  Future<void> rate(
    String sessionId, {
    required int rating,
    required int expectedVersion,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/rating',
      data: {'rating': rating, 'expected_version': expectedVersion},
    );
    _ensureOk(resp);
  }

  void _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw CsApiException(resp.code, resp.msg);
    }
  }
}
