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

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
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

  const CsQueueItem({
    required this.sessionId,
    required this.contactId,
    this.contactName = '',
    this.waitingSince = '',
    this.version = 0,
    this.status = '',
    this.source = '',
    this.lastMessageSummary = '',
  });

  factory CsQueueItem.fromJson(Map<String, dynamic> json) {
    return CsQueueItem(
      sessionId: entityIdOf(json['session_id']),
      contactId: entityIdOf(json['contact_id']),
      contactName: parseModelString(json['contact_name']),
      waitingSince: parseModelString(json['waiting_since']),
      version: parseModelInt(json['version']),
      status: parseModelString(json['status']),
      source: parseModelString(json['source']),
      lastMessageSummary: parseModelString(json['last_message_summary']),
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

  /// transfer：转接给目标业务身份。
  Future<void> transfer(
    String sessionId, {
    required String toIdentityId,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/transfer',
      data: {'to_identity_id': toIdentityId},
    );
    _ensureOk(resp);
  }

  /// close：结束会话。
  Future<void> close(String sessionId) async {
    final resp = await post('/api/v1/cs/sessions/$sessionId/close');
    _ensureOk(resp);
  }

  /// rating：会话评分（1..5）。
  Future<void> rate(String sessionId, {required int score}) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/rating',
      data: {'score': score},
    );
    _ensureOk(resp);
  }

  void _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw CsApiException(resp.code, resp.msg);
    }
  }
}
