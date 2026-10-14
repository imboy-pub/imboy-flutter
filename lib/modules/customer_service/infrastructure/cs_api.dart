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

import 'dart:typed_data';

import '../domain/cs_session_detail.dart';
import 'cs_asset_put_transport.dart';
import 'cs_asset_content.dart';
export 'cs_asset_content.dart';
import 'cs_asset_upload_operation.dart';
export 'cs_asset_upload_operation.dart';
export '../domain/cs_session_detail.dart';

import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// SSE 响应透传 transformer：长连接事件流不是 JSON envelope，payload
/// 原样交付 ResponseBody（鉴权/签名/重试等仍走 HttpClient 统一链路；
/// CSM-03：本模块不 import 个人域 store/repo）。
class _StreamPassthroughTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    return IMBoyHttpResponse.success(response.data);
  }
}

final _streamPassthroughTransformer = _StreamPassthroughTransformer();

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

  /// 409 的 offboarding 降级子语义（APP-M02-A05 与普通 409 分类分离：
  /// 服务端 envelope msg 携带 `offboarding_required`；普通 409 是 CAS
  /// 竞争、可刷新重试，offboarding 是终态降级、不可重试）。
  bool get isOffboardingRequired =>
      code == 409 && message.toLowerCase().contains('offboarding');

  /// 409 的席位容量满子语义（联调实证 2026-10-02：坐席 active 会话数达
  /// `max_concurrent` 时 claim/append 返回 409 + msg `seat_at_capacity`，
  /// 与 CAS 竞争同码不同因——刷新重试无效，必须先关闭会话或调容量）。
  bool get isSeatAtCapacity =>
      code == 409 && message.toLowerCase().contains('seat_at_capacity');

  @override
  String toString() => 'CsApiException($code): $message';
}

/// 历史消息附件投影（CSX-01 冻结契约，后端 CS-BE-01 已交付）。
///
/// 读面（GET 坐席消息历史 / POST 回显）逐消息携带
/// `assets:[{id,mime,size_bytes,file_name,status}]`（**五键白名单**，
/// 无 object_key/upload_url/token）；纯文本 `assets: []`。旧 flat
/// `asset_ids` 键真实响应不存在（历史断链形状，已废）。
///
/// `id` 是 TSID（后端 encode_entity 出站为十进制字符串；[entityIdOf]
/// 对 int/string 两形均安全）。查看只经授权 content 代理，客户端不持有
/// object key / storage URL。
class CsMessageAsset {
  final String id;
  final String mime;

  /// 字节数（服务端权威；UI 展示格式化）。
  final int sizeBytes;

  /// 展示文件名（可空——未在 presign 声明时后端为 null）。
  final String fileName;

  /// 资产状态（active=已确认可见）。
  final String status;

  const CsMessageAsset({
    required this.id,
    this.mime = '',
    this.sizeBytes = 0,
    this.fileName = '',
    this.status = '',
  });

  bool get isImage => mime.startsWith('image/');

  bool get isActive => status.isEmpty || status == 'active';

  factory CsMessageAsset.fromJson(Map<String, dynamic> json) {
    return CsMessageAsset(
      id: entityIdOf(json['id']),
      mime: parseModelString(json['mime']),
      sizeBytes: parseModelInt(json['size_bytes']),
      fileName: parseModelString(json['file_name']),
      status: parseModelString(json['status']),
    );
  }
}

/// 解析历史消息 `assets` 投影（五键白名单；缺键/类型漂移宽容降级为空，
/// 单行 id 为空的残行丢弃——不因投影残缺炸整页历史）。
List<CsMessageAsset> csMessageAssets(Map<dynamic, dynamic> raw) {
  final list = raw['assets'];
  if (list is! List) return const <CsMessageAsset>[];
  final out = <CsMessageAsset>[];
  for (final e in list) {
    if (e is! Map) continue;
    final asset = CsMessageAsset.fromJson(Map<String, dynamic>.from(e));
    if (asset.id.isNotEmpty) out.add(asset);
  }
  return List.unmodifiable(out);
}

/// 会话消息（坐席侧读面）：EB 真源消息 + 该消息绑定的 assets 投影
///（§3.7 原子绑定回显；查看只经授权 content 代理，客户端不持有
/// object key / storage URL）。
class CsConversationMessage {
  final EnterpriseMessage message;

  /// 服务端回显的附件绑定投影（空 = 纯文本消息）。
  final List<CsMessageAsset> assets;

  const CsConversationMessage({
    required this.message,
    this.assets = const <CsMessageAsset>[],
  });

  /// 附件 id 列表（发送/绑定面复用同组 id）。
  List<String> get assetIds => assets.map((a) => a.id).toList(growable: false);

  factory CsConversationMessage.fromJson(Map<String, dynamic> json) =>
      CsConversationMessage(
        message: EnterpriseMessage.fromJson(json),
        assets: csMessageAssets(json),
      );
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

  /// 服务端只下发末条消息元数据；[lastMessagePreview] 是服务端解密后的
  /// 正文摘要（CS-BE-02，Unicode 码点截断 64 字符）；附件-only（空正文）
  /// 与解密失败行 preview 为 null → 空串（UI 不渲染加密占位——产品裁决
  /// 2026-10-02：队列预览不再展示「[加密消息]」）。
  final bool hasLastMessage;

  /// 末条消息正文摘要（服务端已解密；空串 = 无消息或摘要不可用）。
  final String lastMessagePreview;

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
    this.lastMessagePreview = '',
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
      lastMessagePreview: lastMessage is Map
          ? parseModelString(lastMessage['preview'])
          : '',
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
/// CS-APP-02（CS-DEC-02）：坐席运行态（服务端派生值，客户端只读展示）。
enum CsPresenceStatus { online, away, busy, offline }

CsPresenceStatus csPresenceStatusFromWire(String raw) {
  switch (raw) {
    case 'online':
      return CsPresenceStatus.online;
    case 'away':
      return CsPresenceStatus.away;
    case 'busy':
      return CsPresenceStatus.busy;
    case 'offline':
      return CsPresenceStatus.offline;
    default:
      throw CsApiException(0, 'presence-status-invalid');
  }
}

/// presence 视图（heartbeat/presence 返回；fail-closed 解析）。
class CsPresence {
  CsPresence({
    required this.status,
    this.lastHeartbeatAt,
    this.manualStatus,
    required this.enabled,
    required this.maxConcurrent,
    required this.activeCount,
  });

  factory CsPresence.fromJson(Map<dynamic, dynamic> json) {
    final rawStatus = json['status'];
    if (rawStatus is! String) {
      throw CsApiException(0, 'presence-status-invalid');
    }
    return CsPresence(
      status: csPresenceStatusFromWire(rawStatus),
      lastHeartbeatAt: json['last_heartbeat_at'] is int
          ? json['last_heartbeat_at'] as int
          : null,
      manualStatus: json['manual_status'] == 'away' ? 'away' : null,
      enabled: json['enabled'] == true,
      maxConcurrent: json['max_concurrent'] is int
          ? json['max_concurrent'] as int
          : 0,
      activeCount: json['active_count'] is int
          ? json['active_count'] as int
          : 0,
    );
  }

  final CsPresenceStatus status;
  final int? lastHeartbeatAt;
  final String? manualStatus;
  final bool enabled;
  final int maxConcurrent;
  final int activeCount;
}

/// 会话读状态（游标 + 未读数；未读 badge 数据源）。
///
/// fail-closed 投影（对齐 Web `toSeatReadState`）：session_id /
/// last_read_message_id / unread_count 任一缺失或类型漂移即 throw
/// （后端 read_state 出站恒携带三键，TSID 已编码为十进制字符串——
/// [entityIdOf] 对 int/string 两形均安全），不猜不垫。
class CsReadState {
  CsReadState({
    required this.sessionId,
    required this.lastReadMessageId,
    required this.unreadCount,
  });

  factory CsReadState.fromJson(Map<dynamic, dynamic> json) {
    final sid = entityIdOf(json['session_id']);
    final cursor = entityIdOf(json['last_read_message_id']);
    final unread = json['unread_count'];
    if (sid.isEmpty || cursor.isEmpty || unread is! int) {
      throw const CsApiException(0, 'read-state-invalid');
    }
    return CsReadState(
      sessionId: sid,
      lastReadMessageId: cursor,
      unreadCount: unread,
    );
  }

  final String sessionId;
  final String lastReadMessageId;
  final int unreadCount;
}

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
  CsApi({
    CsAssetPutTransport Function()? putTransportFactory,
    EnterpriseApi Function()? assetApiFactory,
  }) : _putTransportFactory = putTransportFactory ?? CsAssetPutTransport.new,
       _assetApiFactory = assetApiFactory ?? EnterpriseApi.new;
  final CsAssetPutTransport Function() _putTransportFactory;
  final EnterpriseApi Function() _assetApiFactory;

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
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D5a）：`cs_tenant_handler` 的 workspace 门
  /// 对 claim（无 optional 声明）要求正文必带 `workspace_id`——旧仅
  /// `{expected_version}` 形状必 422。[workspaceId] 非空时按冻结契约携带；
  /// 空时透传发出（对齐 [conversationMessages] 先例：缺失由服务端 422
  /// fail-closed 裁决，调用方降级路径已就绪），接线归调用方。
  Future<CsClaimResult> claim(
    String orgId,
    String sessionId, {
    required int expectedVersion,
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/claim',
      data: {
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
        'expected_version': expectedVersion,
      },
    );
    _ensureOk(resp);
    return CsClaimResult.fromJson(sessionId, resp.payload);
  }

  /// transfer：转接给目标业务身份（CAS，§12.5.1 CSM-02）。
  ///
  /// A0 冻结参数表（cs_actions:session_transfer）：`to_identity_id`（tsid）
  /// 与 `expected_version`（int）均必填；正文另受面级 workspace 门
  /// （PR-W2-C01：与 claim 同门对齐，缺 `workspace_id` 即 422）。
  /// 并发/状态竞争 409（[CsApiException.isConflict]），
  /// 调用方刷新真实状态后提示，不做乐观伪成功。
  Future<void> transfer(
    String orgId,
    String sessionId, {
    required String toIdentityId,
    required int expectedVersion,
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/transfer',
      data: {
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
        'to_identity_id': toIdentityId,
        'expected_version': expectedVersion,
      },
    );
    _ensureOk(resp);
  }

  /// close：结束会话（CAS + 可选 reason，§12.5.1 CSM-02）。
  ///
  /// A0 冻结参数表（cs_actions:session_close）：`expected_version` 必填、
  /// `reason` 可选（审计文本，调用方先经 [csSanitizeCloseReason] 白名单清洗）；
  /// 正文另受面级 workspace 门（PR-W2-C01：与 claim 同门对齐）。
  Future<void> close(
    String orgId,
    String sessionId, {
    required int expectedVersion,
    String? reason,
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/close',
      data: {
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
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
  ///
  /// 契约（真机 A02 实证 2026-09-30）：session_detail 动作表无
  /// `workspace => optional` 声明，CSB-02R workspace 门 required——缺
  /// `workspace_id` 必 422（转接 CAS 拿不到 version 的根因）。空时透传，
  /// 接线归调用方（与 claim/close 同口径）。
  Future<CsSessionDetail> sessionDetail(
    String orgId,
    String sessionId, {
    String workspaceId = '',
  }) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId',
      queryParameters: <String, dynamic>{
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
      },
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
  /// `/api/v1/enterprise/conversations/:conversationId/messages`。
  ///
  /// 冻结 query 契约（cs_tenant 面 org_source=param + workspace 门必填）：
  /// `organization_id` 必填（申报值，服务端用凭证/事实证明）、`workspace_id`
  /// 必填（缺一即 422）；`after_id`/`limit` 非空才携带（EB 真源键集分页；
  /// 游标缺省语义 = 全量首拉）。
  ///
  /// payload 形状：EB `list_messages` 返回裸消息数组（宽容兼容
  /// `{messages: [...]}` / `{list: [...]}` 包裹）。逐行解析为
  /// [CsConversationMessage]（真源消息 + `assets` 五键投影）。
  Future<List<CsConversationMessage>> conversationMessages(
    String conversationId, {
    required String orgId,
    String workspaceId = '',
    String afterId = '',
    int limit = 0,
  }) async {
    final resp = await get(
      '/api/v1/enterprise/conversations/$conversationId/messages',
      queryParameters: {
        'organization_id': orgId,
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
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
        .map(
          (m) => CsConversationMessage.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList(growable: false);
  }

  /// 坐席出站消息（复用 EB 写真源端点，F-SEC-02：conversation.write）：
  /// POST `/api/v1/enterprise/organizations/{orgId}/conversations/{conversationId}/messages`。
  ///
  /// A0/EB 冻结提交面：`client_msg_id`（幂等键，重试必须复用同一 id）、
  /// `sender_type`（坐席恒 business_identity）、`body`、`identity_id`
  /// （经办业务身份）。禁止走个人 C2C/attachment 通道。
  ///
  /// APP-M02-A03（§3.7）：`assetIds` 非空时提交 `asset_ids`——confirmed
  /// asset 与消息**原子绑定**（服务端单事务锁定 active+unbound asset；
  /// 同 client_msg_id + asset_ids 重试返回同一 message，其他重放 409）。
  /// 回显按 CS-BE-01 同形状携带 `assets` 投影（解析见
  /// [CsConversationMessage]）。
  ///
  /// 契约（PR-W2-C01 同门对齐 / 真机 A02 实证 2026-09-30）：EB-03-A01
  /// 显式 workspace 归属必填——旧形状缺 `workspace_id` 必 422
  /// missing_workspace_id（真机发送恒失败的根因）。[workspaceId] 非空时
  /// 携带；空时透传发出（服务端 422 fail-closed 裁决），接线归调用方
  /// （[cs_session_flow] send 已 fail-closed + resolveWorkspaceId）。
  Future<CsConversationMessage> sendConversationMessage(
    String orgId,
    String conversationId, {
    required String body,
    required String clientMsgId,
    required String identityId,
    List<String> assetIds = const <String>[],
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/enterprise/organizations/$orgId/conversations/$conversationId/messages',
      data: {
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
        'client_msg_id': clientMsgId,
        'sender_type': EnterpriseSenderType.businessIdentity.wireName,
        'body': body,
        'identity_id': identityId,
        if (assetIds.isNotEmpty) 'asset_ids': assetIds,
      },
    );
    _ensureOk(resp);
    final map = IMBoyHttpResponse.payloadAsMap(resp.payload);
    final message = map['message'];
    return CsConversationMessage.fromJson(
      message is Map ? Map<String, dynamic>.from(message) : map,
    );
  }

  /// delivery ACK（幂等，delivery-only；EB 合同 `recipient_ref` 必填）。
  ///
  /// 成功与否都不触发本地删除/隐藏语义——本地只置投递标记。
  ///
  /// 契约（PR-W2-C01 / V1.2 D3d 同门）：本方法打 enterprise 面 ack 动作，
  /// 正文另受面级 workspace 门（`workspace_id` 必带，缺即 422）。
  /// [workspaceId] 非空时携带；空时透传发出（[conversationMessages] 先例：
  /// 缺失由服务端 422 fail-closed 裁决），接线归调用方。
  Future<void> ackDelivery(
    String orgId,
    String conversationId,
    String messageId, {
    required String recipientRef,
    String deviceId = '',
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/enterprise/organizations/$orgId/conversations/$conversationId/messages/$messageId/ack',
      data: {
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
        'recipient_ref': recipientRef,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
    );
    _ensureOk(resp);
  }

  /// Member attachment upload: authenticated presign → bound member PUT → confirm.
  /// The HTTP producer adds its own API PUT URL to the opaque facade view.
  /// The PUT uses authorization captured from this authenticated presign instance;
  /// it never inherits this CsApi instance's stale headers or follows redirects.
  /// URL/ref/headers remain operation memory only. Missing or unbound targets
  /// stop before PUT; object-storage producers require a separate trusted origin.
  Future<EnterpriseAsset> uploadEnterpriseAsset(
    String orgId, {
    required String workspaceId,
    required String conversationId,
    required String mime,
    required Uint8List bytes,
    String fileName = '',
    CsAssetUploadOperation? operation,
  }) async {
    final ownedApi = _assetApiFactory();
    try {
      return await (operation ?? CsAssetUploadOperation()).upload(
        api: ownedApi,
        transportFactory: _putTransportFactory,
        org: orgId,
        workspace: workspaceId,
        conversation: conversationId,
        mime: mime,
        bytes: bytes,
        fileName: fileName,
      );
    } on CsAssetOperationException catch (e) {
      if (operation != null) rethrow;
      throw CsApiException(e.status ?? 0, 'asset ${e.failure.name}');
    } finally {
      ownedApi.dio.close(force: true);
    }
  }

  /// Authorized content bytes, accepted only with matching server ID, SHA-256
  /// and content length. Workspace is mandatory; errors retain the enterprise
  /// exception contract. The returned bytes are immutable and contain no URL.
  Future<Uint8List> fetchAssetBytes(
    String orgId,
    String assetId, {
    String workspaceId = '',
  }) async =>
      (await fetchAssetContent(orgId, assetId, workspaceId: workspaceId)).bytes;

  Future<CsVerifiedAssetContent> fetchAssetContent(
    String orgId,
    String assetId, {
    required String workspaceId,
  }) async {
    if (workspaceId.isEmpty) {
      throw const EnterpriseApiException(422, 'missing_workspace_id');
    }
    if (!CsVerifiedAssetContent.isAssetId(assetId)) {
      throw const EnterpriseApiException(0, 'asset content ID refused');
    }
    final resp = await get(
      EnterpriseApi().assetContentPath(orgId, assetId),
      queryParameters: {'workspace_id': workspaceId},
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        maxRedirects: 0,
      ),
      httpTransformer: CsAssetContentTransformer(assetId),
    );
    if (!resp.ok) throw EnterpriseApiException(resp.code, resp.msg);
    if (resp.payload is CsVerifiedAssetContent) {
      return resp.payload as CsVerifiedAssetContent;
    }
    throw const EnterpriseApiException(0, 'asset content integrity refused');
  }

  /// 打开坐席事件 SSE 流（底层；由 [CsSeatEventsStream] 驱动重连/游标/
  /// 解析，本方法只负责一次建流）。
  ///
  /// 契约（SSE-EVENT-CONTRACT-V1）：
  /// GET `/api/v1/cs/organizations/:org_id/seats/me/events?workspace_id=...`，
  /// `Last-Event-ID` 头存在时优先于 after_id 查询参数（首连无游标时才带
  /// after_id）。响应 `Content-Type: text/event-stream`；长连接放宽接收
  /// 超时（心跳保活；死连接由超时/对端关闭暴露后走重连退避）。
  /// 非法/跨租户游标返回 400/403 → 抛 [CsSseOpenException]，不静默回退。
  ///
  /// 鉴权/签名/令牌刷新全部走 [HttpClient] 统一链路（透传 transformer
  /// 只免掉 JSON envelope 解析）；测试经 `HttpClient.adapterForTest`
  /// 拦截，不打真网。
  Future<Stream<List<int>>> openSeatEventsStream(
    String orgId,
    String workspaceId, {
    String lastEventId = '',
    String afterId = '',
    CancelToken? cancelToken,
  }) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/seats/me/events',
      queryParameters: {
        'workspace_id': workspaceId,
        if (lastEventId.isEmpty && afterId.isNotEmpty) 'after_id': afterId,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 1),
        headers: {
          'accept': 'text/event-stream',
          'cache-control': 'no-store',
          if (lastEventId.isNotEmpty) 'Last-Event-ID': lastEventId,
        },
      ),
      httpTransformer: _streamPassthroughTransformer,
      cancelToken: cancelToken,
    );
    if (!resp.ok) {
      throw CsSseOpenException(resp.code, '');
    }
    final body = resp.payload;
    if (body is! ResponseBody) {
      throw CsSseOpenException(resp.code, 'unexpected-payload');
    }
    return body.stream;
  }

  // ---- CS-APP-02（CS-DEC-02/CS-RUNTIME-04）：presence 与已读游标 ----
  // 与 Web 端（CS-WEB-05）共用 wire 语义：heartbeat POST（at 服务端派生
  // 时钟，客户端不可报时）、presence PUT/GET（manual_status away|缺省）、
  // read-cursor GET/POST（服务端单调 upsert，重复/乱序旧值零副作用）。

  /// POST /api/v1/cs/organizations/:org_id/seats/me/heartbeat。
  /// 返回派生运行态（online/away/busy/offline）。调用时机由
  /// [CsPresenceController] 按前台/后台门控——后台不发，不谎报 online。
  ///
  /// 契约（PR-W2-C01 同门对齐 / 真机 A02 实证 2026-09-30）：动作表
  /// `seat_presence_heartbeat` 未声明 `workspace => optional`，workspace 门
  /// required——旧空体形状必 422 missing_workspace_id（坐席恒「状态不可用」
  /// 的根因）。[workspaceId] 非空时携带；空时透传发出，接线归调用方
  /// （控制器对空 workspaceId 诚实不发）。
  Future<CsPresence> seatHeartbeat(
    String orgId, {
    String workspaceId = '',
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/seats/me/heartbeat',
      data: <String, dynamic>{
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
      },
    );
    _ensureOk(resp);
    return CsPresence.fromJson(_presencePayload(resp));
  }

  /// GET /api/v1/cs/organizations/:org_id/seats/me/presence（只读视图，
  /// 降级展示用；不发心跳）。`workspaceId` 同 heartbeat（workspace 门必填）。
  Future<CsPresence> seatPresence(
    String orgId, {
    String workspaceId = '',
  }) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/seats/me/presence',
      queryParameters: <String, dynamic>{
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
      },
    );
    _ensureOk(resp);
    return CsPresence.fromJson(_presencePayload(resp));
  }

  /// PUT seats/me/presence：manualStatus='away' 设手动离开；null=清除
  /// （回到心跳/负载自动派生）。`workspaceId` 同 heartbeat（workspace 门必填）。
  Future<CsPresence> setSeatPresence(
    String orgId,
    String? manualStatus, {
    String workspaceId = '',
  }) async {
    final resp = await put(
      '/api/v1/cs/organizations/$orgId/seats/me/presence',
      data: <String, dynamic>{
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
        'manual_status': ?manualStatus,
      },
    );
    _ensureOk(resp);
    return CsPresence.fromJson(_presencePayload(resp));
  }

  /// GET sessions/:id/read-cursor：游标 + 未读数（未读 badge 数据源）。
  Future<CsReadState> seatReadState(String orgId, String sessionId) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/read-cursor',
    );
    _ensureOk(resp);
    final payload = resp.payload;
    if (payload is! Map) {
      throw const CsApiException(0, 'read-state-invalid');
    }
    return CsReadState.fromJson(payload);
  }

  /// presence 视图 payload 门：非 Map（含 null）即 fail-closed 抛
  /// [CsApiException]——绝不 `as Map`（TypeError 会击穿调用方的
  /// `on Exception` 诚实降级路径）。
  Map<dynamic, dynamic> _presencePayload(IMBoyHttpResponse resp) {
    final payload = resp.payload;
    if (payload is! Map) {
      throw const CsApiException(0, 'presence-invalid');
    }
    return payload;
  }

  /// POST sessions/:id/read-cursor：ACK（服务端单调 upsert——多端/多标签
  /// 页交错后到的旧值是零副作用 no-op，游标不倒退）。
  Future<void> seatAckRead(
    String orgId,
    String sessionId,
    String lastReadMessageId,
  ) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/sessions/$sessionId/read-cursor',
      data: <String, dynamic>{'last_read_message_id': lastReadMessageId},
    );
    _ensureOk(resp);
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
