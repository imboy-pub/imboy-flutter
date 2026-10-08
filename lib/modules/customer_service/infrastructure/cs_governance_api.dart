/// 企业自助客服治理 API 客户端（CS-APP-03 / CS-GOV-02B）。
///
/// 契约依据（后端 imboy_router.erl + cs_actions.erl + cs_http.erl 已核对，
/// 候选 67e18677 集成面）：以下端点全部是**租户治理面**（route metadata
/// `auth_context => enterprise_owner_admin` + `required_governance =>
/// [owner, admin]`），凭证 = 移动端统一 Human JWT（HttpClient 链路）：
/// - `GET  /api/v1/cs/organizations/:org_id/seat-limit?workspace_id=`
///   （额度视图）；
/// - `PUT  /api/v1/cs/organizations/:org_id/seat-limit`（body 形如
///    `{"seat_limit": n, "workspace_id": ws}`；seat_limit 缺省 = 清除 →
///    unlimited；CS-BE-06）；
/// - `GET  /api/v1/cs/organizations/:org_id/seats?workspace_id=&after_id=&limit=`
///   （seat 列表键集分页，行投影含 enabled/max_concurrent/active_count）；
/// - `POST /api/v1/cs/organizations/:org_id/seats/:id/suspend`（body 含
///   workspace_id；reason 可选）/ `POST .../seats/:id/resume`（enabled 治理）。
///
/// workspace 门（CS-BE-02）：租户治理面 `workspace_id` 是 handler 级必填
/// ——GET 走查询串、写走正文，缺失即 422 `missing_workspace_id`（真机
/// 「加载失败：missing_workspace_id (422)」的根因即本客户端此前未携带）。
/// 取数来源 = 组织默认工作区指针（C05
/// `GET /api/v1/organizations/:org_id/default-workspace`），由治理页解析
/// 后透传；本客户端不自行解析。
///
/// 凭证纪律（任务卡红线）：本客户端只走 Human JWT 租户面——**绝不**请求
/// `/api/adm`（平台 Admin Cookie 面），也不消费 Seat JWT 专属端点
/// （heartbeat/presence 等 cs_seat 主体路径不在本文件出现，compile-time
/// 可审计）。
///
/// 错误 envelope（elib_response）：HTTP 状态 + `{code, msg, payload}`
/// ——`code` = HTTP 状态整数、`msg` = 服务端 tag——msg 承载分类 tag
/// （governance_insufficient / seat_limit_exceeded / invalid_seat_limit /
/// seat_disabled / not_found），[CsGovernanceApiException] 按 tag + code
/// 双口径分型，客户端展示即事实、不伪装成功。
///
/// TSID lossless：后端 encode_entity 把 `*_id` 出站编码为十进制字符串，
/// [entityIdOf] 对 int/string 两形均安全（19 位 TSID 超 double 精度，
/// 全链 String 保真）。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// seat-limit 额度视图（GET/PUT 共用回显形状）。
///
/// wire：`{organization_id: "…", seat_limit: "unlimited"|n, used: m}`——
/// `seat_limit` 是字符串 `"unlimited"` 或正整数；`used` 是服务端现算的
/// enabled seat 计数。
class CsSeatLimitView {
  const CsSeatLimitView({
    required this.organizationId,
    required this.isUnlimited,
    this.limitValue,
    this.used = 0,
  });

  factory CsSeatLimitView.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    final raw = map['seat_limit'];
    final unlimited = raw == 'unlimited' || raw == null;
    return CsSeatLimitView(
      organizationId: entityIdOf(map['organization_id']),
      isUnlimited: unlimited,
      limitValue: unlimited ? null : parseModelInt(raw),
      used: parseModelInt(map['used']),
    );
  }

  final String organizationId;

  /// true = 无限额度（组织缺省；服务端无行）。
  final bool isUnlimited;

  /// 有限额度值（正整数）；[isUnlimited] 为 true 时为 null。
  final int? limitValue;

  /// 已占用额度（服务端现算 enabled seat 计数，客户端不本地推断）。
  final int used;

  /// 是否已达上限（无限额度恒 false；有限额度 used >= limit）。
  bool get isAtCapacity => !isUnlimited && used >= (limitValue ?? 0);
}

/// 治理面 seat 行（GET /seats 分页投影）。
class CsGovernanceSeatRow {
  const CsGovernanceSeatRow({
    required this.organizationId,
    required this.businessIdentityId,
    this.functionKey = '',
    this.enabled = false,
    this.maxConcurrent = 0,
    this.activeCount = 0,
  });

  factory CsGovernanceSeatRow.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return CsGovernanceSeatRow(
      organizationId: entityIdOf(map['organization_id']),
      businessIdentityId: entityIdOf(map['business_identity_id']),
      functionKey: parseModelString(map['function_key']),
      enabled: map['enabled'] == true,
      maxConcurrent: parseModelInt(map['max_concurrent']),
      activeCount: parseModelInt(map['active_count']),
    );
  }

  final String organizationId;

  /// 坐席绑定的业务身份（TSID string；suspend/resume 的路径参数）。
  final String businessIdentityId;
  final String functionKey;

  /// enabled 治理事实（suspend → false / resume → true）。
  final bool enabled;
  final int maxConcurrent;
  final int activeCount;
}

/// seat 列表页（键集分页）。
class CsGovernanceSeatPage {
  const CsGovernanceSeatPage({required this.rows, this.nextAfterId = ''});

  factory CsGovernanceSeatPage.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    final raw = map['seats'];
    final rows = raw is List
        ? raw.map(CsGovernanceSeatRow.fromJson).toList(growable: false)
        : const <CsGovernanceSeatRow>[];
    final next = map['next_after_id'];
    return CsGovernanceSeatPage(
      rows: rows,
      nextAfterId: next == null ? '' : next.toString(),
    );
  }

  final List<CsGovernanceSeatRow> rows;

  /// 下一页游标（TSID string）；空 = 无更多页。
  final String nextAfterId;

  bool get hasMore => nextAfterId.isNotEmpty;
}

/// 治理 API 失败（透传服务端 envelope code 与 msg tag）。
class CsGovernanceApiException implements Exception {
  const CsGovernanceApiException(this.code, this.message);

  final int code;

  /// 服务端错误 tag（governance_insufficient / seat_limit_exceeded /
  /// invalid_seat_limit / seat_disabled / not_found / …）。
  final String message;

  /// 401：Human JWT 失效 / 未授权。
  bool get isUnauthorized => code == 401;

  /// 403：治理权限不足（member / 非 owner·admin；服务端唯一裁决）。
  bool get isForbidden => code == 403;

  /// 404：资源不在本租户作用域（不区分不存在与跨 Org，避免枚举）。
  bool get isNotFound => code == 404;

  /// 409：并发/状态竞争（CAS mismatch 等）。
  bool get isConflict => code == 409;

  /// 席位额度超额（创建/启用坐席撞 seat_limit 上限）。判定以服务端
  /// envelope tag 为准（`seat_limit_exceeded`），不依赖 HTTP 码兜底——
  /// 后端 classify 未显式登记该 tag 时状态码可能漂移，tag 是稳定契约。
  bool get isSeatLimitExceeded =>
      message.toLowerCase().contains('seat_limit_exceeded');

  /// seat_limit 取值不成立（非正整数；422 面）。
  bool get isInvalidSeatLimit =>
      message.toLowerCase().contains('invalid_seat_limit');

  @override
  String toString() => 'CsGovernanceApiException($code): $message';
}

/// 企业自助客服治理 API 客户端（Human JWT 租户治理面，owner/admin）。
class CsGovernanceApi extends HttpClient {
  /// 额度视图：GET /api/v1/cs/organizations/:org_id/seat-limit。
  Future<CsSeatLimitView> seatLimitView(
    EntityId orgId, {
    required EntityId workspaceId,
  }) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/seat-limit',
      queryParameters: <String, dynamic>{'workspace_id': workspaceId},
    );
    _ensureOk(resp);
    return CsSeatLimitView.fromJson(resp.payload);
  }

  /// 配置/清除组织级 seat_limit（CS-BE-06）：
  /// PUT /api/v1/cs/organizations/:org_id/seat-limit。
  ///
  /// [seatLimit] 正整数 = 配置上限；null = 清除（→ unlimited，组织缺省）。
  /// 成功回显新额度视图（含现算 used）；403（治理权限不足）/ 422
  /// （invalid_seat_limit）诚实抛出。
  Future<CsSeatLimitView> setSeatLimit(
    EntityId orgId,
    int? seatLimit, {
    required EntityId workspaceId,
  }) async {
    final resp = await put(
      '/api/v1/cs/organizations/$orgId/seat-limit',
      data: <String, dynamic>{
        'workspace_id': workspaceId,
        'seat_limit': ?seatLimit,
      },
    );
    _ensureOk(resp);
    return CsSeatLimitView.fromJson(resp.payload);
  }

  /// seat 列表（键集分页）：GET /api/v1/cs/organizations/:org_id/seats。
  Future<CsGovernanceSeatPage> seatsPage(
    EntityId orgId, {
    required EntityId workspaceId,
    String? afterId,
    int? limit,
  }) async {
    final resp = await get(
      '/api/v1/cs/organizations/$orgId/seats',
      queryParameters: <String, dynamic>{
        'workspace_id': workspaceId,
        if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
        if (limit != null && limit > 0) 'limit': limit,
      },
    );
    return _ensureOkPage(resp);
  }

  /// 停用坐席（enabled=false：新 claim 即时被拒，既有会话不自动迁移）：
  /// POST /api/v1/cs/organizations/:org_id/seats/:id/suspend。
  Future<void> suspendSeat(
    EntityId orgId,
    EntityId businessIdentityId, {
    required EntityId workspaceId,
    String? reason,
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/seats/$businessIdentityId/suspend',
      data: <String, dynamic>{'workspace_id': workspaceId, 'reason': ?reason},
    );
    _ensureOk(resp);
  }

  /// 恢复坐席（enabled=true）：
  /// POST /api/v1/cs/organizations/:org_id/seats/:id/resume。
  Future<void> resumeSeat(
    EntityId orgId,
    EntityId businessIdentityId, {
    required EntityId workspaceId,
  }) async {
    final resp = await post(
      '/api/v1/cs/organizations/$orgId/seats/$businessIdentityId/resume',
      data: <String, dynamic>{'workspace_id': workspaceId},
    );
    _ensureOk(resp);
  }

  void _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw CsGovernanceApiException(resp.code, resp.msg);
    }
  }

  CsGovernanceSeatPage _ensureOkPage(IMBoyHttpResponse resp) {
    _ensureOk(resp);
    return CsGovernanceSeatPage.fromJson(resp.payload);
  }
}
