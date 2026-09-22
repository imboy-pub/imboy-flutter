/// 企业应用接口的稳定错误 → UI 状态映射（FULL-05 / plan-full §3.3、§7）。
///
/// 真源是后端 `/api/internal/v1/*` 的统一错误信封
/// （`enterprise_internal_error.erl`，本文件逐条对齐，未新增码）：
///
/// ```
/// HTTP 401  invalid_credential | credential_expired
/// HTTP 403  application_disabled | organization_disabled | insufficient_scope
///           | organization_boundary_violation
/// HTTP 404  resource_not_found
/// HTTP 409  idempotency_conflict
/// HTTP 422  identity_not_mapped
/// HTTP 429  rate_limited
/// HTTP 503  security_gate_closed
/// HTTP 400  invalid_request
/// HTTP 500  internal_error
/// ```
///
/// 信封形态：`{"error":{"code":"<stable>","message":"<generic>"}}`——
/// message 是固定通用文案，不含请求细节。**UI 不展示服务端 message**：
/// 它是英文通用串，且按契约不携带可操作信息；UI 一律用本文件给出的
/// 稳定分类渲染本地化文案，避免把服务端文案直接漏给最终用户。
///
/// 硬要求（本文件存在的理由）：401/403/404/409/422/429/503 **每一类都有
/// 各自稳定的 UI 状态**——不得塌成同一个「出错了」，也不得静默吞掉
/// （[EnterpriseErrorUiState.isSilent] 恒 false，测试钉死）。
///
/// 纯 Dart（零 Flutter / 零 IO）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';

/// 企业应用错误分类（13 个后端稳定码 + 客户端侧通道/网络/未知）。
enum EnterpriseErrorKind {
  /// 401 invalid_credential。
  invalidCredential('invalid_credential', 401),

  /// 401 credential_expired。
  credentialExpired('credential_expired', 401),

  /// 403 application_disabled。
  applicationDisabled('application_disabled', 403),

  /// 403 organization_disabled。
  organizationDisabled('organization_disabled', 403),

  /// 403 insufficient_scope。
  insufficientScope('insufficient_scope', 403),

  /// 403 organization_boundary_violation。
  organizationBoundaryViolation('organization_boundary_violation', 403),

  /// 404 resource_not_found（含跨租户不泄露存在性的场景）。
  resourceNotFound('resource_not_found', 404),

  /// 422 identity_not_mapped。
  identityNotMapped('identity_not_mapped', 422),

  /// 409 idempotency_conflict。
  idempotencyConflict('idempotency_conflict', 409),

  /// 429 rate_limited。
  rateLimited('rate_limited', 429),

  /// 503 security_gate_closed（限流配置缺失等 fail-closed 门）。
  securityGateClosed('security_gate_closed', 503),

  /// 400 invalid_request。
  invalidRequest('invalid_request', 400),

  /// 500 internal_error。
  internalError('internal_error', 500),

  /// 客户端侧：企业治理接口需要应用凭据，当前构建未绑定任何通道。
  ///
  /// 不是服务端码——是**诚实失败**：不伪造数据、不静默空列表。
  channelUnbound('channel_unbound', 0),

  /// 客户端侧：网络不可达 / 超时。
  network('network', 0),

  /// 未知（含服务端回了表外码——表外码契约上按 internal_error 处理，
  /// 但客户端保留 unknown 以便如实区分「没见过的码」）。
  unknown('unknown', 0);

  final String wireCode;
  final int httpStatus;

  const EnterpriseErrorKind(this.wireCode, this.httpStatus);
}

/// wire 码 → 分类（表外码 → [EnterpriseErrorKind.unknown]）。
EnterpriseErrorKind enterpriseErrorKindFromCode(dynamic rawCode) {
  final String code = parseModelString(rawCode);
  if (code.isEmpty) return EnterpriseErrorKind.unknown;
  for (final EnterpriseErrorKind kind in EnterpriseErrorKind.values) {
    if (kind.wireCode == code) return kind;
  }
  return EnterpriseErrorKind.unknown;
}

/// 分类 → HTTP 状态（与服务端 `?STATUS_MAP` 同表；客户端侧分类为 0）。
int enterpriseHttpStatusForCode(dynamic rawCode) =>
    enterpriseErrorKindFromCode(rawCode).httpStatus;

/// 稳定 UI 状态（每个错误分类恰好一个）。
class EnterpriseErrorUiState {
  const EnterpriseErrorUiState({
    required this.kind,
    this.httpStatus = 0,
    this.detail = '',
  });

  final EnterpriseErrorKind kind;

  /// 实际观测到的 HTTP 状态（0 = 无 HTTP 层，例如网络失败/通道未绑定）。
  final int httpStatus;

  /// 服务端 detail 片段（**仅用于日志/审计**；UI 不展示服务端 message）。
  ///
  /// 后端 detail 是内部枚举（`members_over_limit` / `purge_blocked_by_hold`
  /// 等），可能含内部语义，故不对最终用户渲染。
  final String detail;

  /// 分类对应的 i18n 键前缀（文案在 `enterpriseApp` 命名空间）。
  ///
  /// 例：`unknown` → `errorUnknownTitle` / `errorUnknownHint`。
  String get messageKeyPrefix {
    switch (kind) {
      case EnterpriseErrorKind.invalidCredential:
      case EnterpriseErrorKind.credentialExpired:
        return 'error401';
      case EnterpriseErrorKind.applicationDisabled:
      case EnterpriseErrorKind.organizationDisabled:
        return 'error403';
      case EnterpriseErrorKind.insufficientScope:
        return 'error403Scope';
      case EnterpriseErrorKind.organizationBoundaryViolation:
        return 'error403Boundary';
      case EnterpriseErrorKind.resourceNotFound:
        return 'error404';
      case EnterpriseErrorKind.identityNotMapped:
        return 'error422Identity';
      case EnterpriseErrorKind.idempotencyConflict:
        return 'error409';
      case EnterpriseErrorKind.rateLimited:
        return 'error429';
      case EnterpriseErrorKind.securityGateClosed:
        return 'error503';
      case EnterpriseErrorKind.invalidRequest:
        return 'error400';
      case EnterpriseErrorKind.internalError:
        return 'error500';
      case EnterpriseErrorKind.channelUnbound:
        return 'errorUnbound';
      case EnterpriseErrorKind.network:
        return 'errorNetwork';
      case EnterpriseErrorKind.unknown:
        return 'errorUnknown';
    }
  }

  /// 是否可重试（429/503/网络/500 可重试；鉴权与边界类需先改正身份/范围）。
  bool get isRetryable {
    switch (kind) {
      case EnterpriseErrorKind.rateLimited:
      case EnterpriseErrorKind.securityGateClosed:
      case EnterpriseErrorKind.network:
      case EnterpriseErrorKind.internalError:
      case EnterpriseErrorKind.unknown:
      case EnterpriseErrorKind.idempotencyConflict:
        return true;
      default:
        return false;
    }
  }

  /// 是否需要在 UI 上引导重新登录（401 两码）。
  bool get needsReauth =>
      kind == EnterpriseErrorKind.invalidCredential ||
      kind == EnterpriseErrorKind.credentialExpired;

  /// **恒 false**：任何错误都必须有可见状态，不允许静默吞掉。
  bool get isSilent => false;

  @override
  String toString() =>
      'EnterpriseErrorUiState(${kind.wireCode}, http=$httpStatus, '
      'detail=$detail)';
}

/// 从 HTTP 状态 + 响应体（或传输层异常）解析稳定 UI 状态。
///
/// [body] 期望是 `{"error":{"code":...,"message":...}}`；也容忍扁平
/// `{"code":...}` 形态（老约定）。解析不出码时按 HTTP 状态归类
/// （[enterpriseErrorKindFromHttpStatus]），仍解析不出则 unknown。
EnterpriseErrorUiState enterpriseErrorUiState({
  int httpStatus = 0,
  dynamic body,
  Object? transportError,
}) {
  if (transportError != null) {
    return EnterpriseErrorUiState(
      kind: EnterpriseErrorKind.network,
      detail: transportError.runtimeType.toString(),
    );
  }
  final String code = enterpriseEnvelopeCode(body);
  if (code.isNotEmpty) {
    final EnterpriseErrorKind kind = enterpriseErrorKindFromCode(code);
    if (kind != EnterpriseErrorKind.unknown) {
      return EnterpriseErrorUiState(
        kind: kind,
        httpStatus: httpStatus,
        detail: enterpriseEnvelopeDetail(body),
      );
    }
  }
  return EnterpriseErrorUiState(
    kind: enterpriseErrorKindFromHttpStatus(httpStatus),
    httpStatus: httpStatus,
    detail: enterpriseEnvelopeDetail(body),
  );
}

/// HTTP 状态 → 分类（无码兜底；401/403 无法细分时取该状态的**代表码**）。
EnterpriseErrorKind enterpriseErrorKindFromHttpStatus(int httpStatus) {
  switch (httpStatus) {
    case 400:
      return EnterpriseErrorKind.invalidRequest;
    case 401:
      return EnterpriseErrorKind.invalidCredential;
    case 403:
      return EnterpriseErrorKind.insufficientScope;
    case 404:
      return EnterpriseErrorKind.resourceNotFound;
    case 409:
      return EnterpriseErrorKind.idempotencyConflict;
    case 422:
      return EnterpriseErrorKind.identityNotMapped;
    case 429:
      return EnterpriseErrorKind.rateLimited;
    case 503:
      return EnterpriseErrorKind.securityGateClosed;
    case 500:
    case 502:
    case 504:
      return EnterpriseErrorKind.internalError;
    default:
      return EnterpriseErrorKind.unknown;
  }
}

/// 从服务端信封取出稳定码（`error.code` 优先，扁平 `code` 兜底）。
String enterpriseEnvelopeCode(dynamic body) {
  final Map<String, dynamic>? root = _asMap(body);
  if (root == null) return '';
  final Map<String, dynamic>? nested = _asMap(root['error']);
  final String nestedCode = parseModelString(nested?['code']);
  if (nestedCode.isNotEmpty) return nestedCode;
  return parseModelString(root['code']);
}

/// 从服务端信封取出 detail（`error.detail`，缺失为空串）。
String enterpriseEnvelopeDetail(dynamic body) {
  final Map<String, dynamic>? root = _asMap(body);
  if (root == null) return '';
  final Map<String, dynamic>? nested = _asMap(root['error']);
  final String nestedDetail = parseModelString(nested?['detail']);
  if (nestedDetail.isNotEmpty) return nestedDetail;
  return parseModelString(root['detail']);
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return parseModelJsonMap(raw);
}
