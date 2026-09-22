/// 企业 Application 治理接口客户端（FULL-05 / INT-15..22）。
///
/// **通道边界（必读，本模块最重要的设计约束）**
///
/// 这些端点在 manifest 里挂在 `/api/internal/v1/*`，只接受
/// **Application Credential**（`ib_int_<id>.<secret>`）。两条冻结不变量把它
/// 与人端彻底隔开：
/// - INV-2：Application Credential 只能调 `/api/internal/v1/*`；
/// - INV-3：**Human JWT 不得调 `/api/internal/v1/*`**。
///
/// 本文件所在的 Flutter 应用是 **Human 客户端**（其 HTTP 层注入的是用户
/// JWT）。因此：
/// 1. 客户端**不内置**、不读取、不派生任何 Application Credential——
///    契约上它不该有，安全上它绝不能进移动端包体；
/// 2. 通道由 [EnterpriseAppTransport] 注入。生产默认
///    [UnboundEnterpriseAppTransport] **诚实失败**（`channelUnbound`），
///    不伪造空数据、不静默返回空列表；
/// 3. 待部署方决定通道形态后（例如 Human 授权的 `/api/v1/enterprise-app/*`
///    治理面，或经 OA 后台代转）只需实现一个 [EnterpriseAppTransport]，
///    本层与全部 UI/状态无需改动。
///
/// 请求/响应契约逐条对齐后端 handler（路径、幂等键、错误信封），
/// 由单测以「路径常量 == manifest 字面量」+「信封解析」双向钉死。
library;

import 'package:imboy/modules/enterprise_app/domain/asset_retention_governance.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_app_error.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_directory.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_group_admin.dart';

/// 一次企业应用请求的方法（只用到 manifest 里出现的四个）。
enum EnterpriseHttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  final String wireName;

  const EnterpriseHttpMethod(this.wireName);
}

/// 传输层响应。
class EnterpriseAppResponse {
  const EnterpriseAppResponse({required this.httpStatus, this.body});

  final int httpStatus;
  final dynamic body;

  bool get isOk => httpStatus >= 200 && httpStatus < 300;
}

/// 请求描述（由 [EnterpriseAppApi] 组装，传输实现只负责发出）。
class EnterpriseAppRequest {
  const EnterpriseAppRequest({
    required this.method,
    required this.path,
    required this.headers,
    this.body,
  });

  final EnterpriseHttpMethod method;
  final String path;
  final Map<String, String> headers;
  final Object? body;
}

/// 通道未绑定（**不是**后端错误码；是客户端诚实失败）。
class EnterpriseChannelUnboundException implements Exception {
  const EnterpriseChannelUnboundException({
    required this.path,
    required this.reason,
  });

  final String path;
  final String reason;

  @override
  String toString() => 'EnterpriseChannelUnboundException($path): $reason';
}

/// 治理接口调用失败（携带已归一的稳定 UI 状态）。
class EnterpriseAppApiException implements Exception {
  const EnterpriseAppApiException(this.uiState);

  final EnterpriseErrorUiState uiState;

  EnterpriseErrorKind get kind => uiState.kind;

  bool get isRetryable => uiState.isRetryable;

  @override
  String toString() => 'EnterpriseAppApiException($uiState)';
}

/// 传输层接口（唯一通道抽象；生产默认未绑定，见库文档）。
abstract interface class EnterpriseAppTransport {
  /// 是否已绑定可用通道。
  bool get isBound;

  /// 通道人类可读标识（日志用；不得含 secret）。
  String get channelId;

  Future<EnterpriseAppResponse> send(EnterpriseAppRequest request);
}

/// 未绑定通道：任何请求**诚实失败**，绝不返回伪造数据。
class UnboundEnterpriseAppTransport implements EnterpriseAppTransport {
  const UnboundEnterpriseAppTransport();

  /// 未绑定的原因（写死，便于运维定位与文档引用）。
  static const String reason =
      'enterprise governance endpoints require an Application credential '
      'which must not ship inside the human client (INV-2/INV-3); '
      'bind a deployment channel to enable';

  @override
  bool get isBound => false;

  @override
  String get channelId => 'unbound';

  @override
  Future<EnterpriseAppResponse> send(EnterpriseAppRequest request) {
    throw EnterpriseChannelUnboundException(path: request.path, reason: reason);
  }
}

/// 企业应用治理 API 客户端。
class EnterpriseAppApi {
  EnterpriseAppApi({EnterpriseAppTransport? transport})
    : _transport = transport ?? const UnboundEnterpriseAppTransport();

  final EnterpriseAppTransport _transport;

  bool get isBound => _transport.isBound;

  String get channelId => _transport.channelId;

  // ==================== path 常量（== manifest 字面量） ====================

  static const String pathDirectoryMappings =
      '/api/internal/v1/identity-mappings/directory';
  static const String pathDirectoryUsers = '/api/internal/v1/directory/users';

  /// 群路由模板（`{group_id}` 与 A0 登记的 segment 名一致）。
  static const String groupPathTemplate = '/api/internal/v1/groups/{group_id}';
  static const String groupRolesPathTemplate =
      '/api/internal/v1/groups/{group_id}/members/roles';
  static const String pathFilesGovernance = '/api/internal/v1/files/governance';

  /// 群详情/更新/归档路径（INT-18/19/21 共用同一 path）。
  static String groupPath(EntityId groupId) =>
      '/api/internal/v1/groups/${_segment(groupId)}';

  /// 成员角色路径（INT-20）。
  static String groupRolesPath(EntityId groupId) =>
      '/api/internal/v1/groups/${_segment(groupId)}/members/roles';

  // ==================== INT-18 群详情 ====================

  Future<EnterpriseGroupDetail> groupDetail(EntityId groupId) async {
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.get,
      groupPath(groupId),
      idempotencyKey: null,
    );
    return EnterpriseGroupDetail.fromJson(_okMap(resp));
  }

  // ==================== INT-19 群更新 ====================

  Future<EnterpriseGroupDetail> updateGroup(
    EntityId groupId, {
    required EnterpriseGroupUpdateDraft draft,
    required String idempotencyKey,
  }) async {
    // 空更新在本地即拒（后端同样拒绝；本地拒可省一次往返与一条无效审计）。
    final String? invalid = draft.validate();
    if (invalid != null) {
      throw EnterpriseAppApiException(
        EnterpriseErrorUiState(
          kind: EnterpriseErrorKind.invalidRequest,
          httpStatus: 400,
          detail: invalid,
        ),
      );
    }
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.patch,
      groupPath(groupId),
      body: draft.toWire(),
      idempotencyKey: idempotencyKey,
    );
    return EnterpriseGroupDetail.fromJson(_okMap(resp));
  }

  // ==================== INT-21 群归档（单向） ====================

  Future<EnterpriseGroupArchiveOutcome> archiveGroup(
    EntityId groupId, {
    required String idempotencyKey,
  }) async {
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.delete,
      groupPath(groupId),
      idempotencyKey: idempotencyKey,
    );
    return EnterpriseGroupArchiveOutcome.fromJson(_okMap(resp));
  }

  // ==================== INT-20 成员角色 ====================

  Future<Map<String, dynamic>> setMemberRoles(
    EntityId groupId, {
    required List<EnterpriseGroupRoleAssignment> assignments,
    required String idempotencyKey,
  }) async {
    for (final EnterpriseGroupRoleAssignment a in assignments) {
      final String? invalid = a.validate();
      if (invalid != null) {
        throw EnterpriseAppApiException(
          EnterpriseErrorUiState(
            kind: EnterpriseErrorKind.invalidRequest,
            httpStatus: 400,
            detail: invalid,
          ),
        );
      }
    }
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.put,
      groupRolesPath(groupId),
      body: <String, dynamic>{
        'roles': assignments.map((a) => a.toWire()).toList(growable: false),
      },
      idempotencyKey: idempotencyKey,
    );
    return _okMap(resp);
  }

  // ==================== INT-16 / INT-17 受限游标目录 ====================

  /// 映射目录一页（INT-16）。**只此一个入口，没有全量形态**。
  Future<EnterpriseDirectoryResult<DirectoryMappingItem>>
  directoryMappingsPage({
    String cursor = '',
    int pageSize = kDirectoryDefaultPageSize,
  }) async {
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.post,
      EnterpriseAppApi.pathDirectoryMappings,
      body: _directoryBody(cursor: cursor, pageSize: pageSize),
      idempotencyKey: null,
    );
    return parseMappingsPage(_okBody(resp));
  }

  /// 成员目录一页（INT-17，可选 workspace 边界）。**只此一个入口**。
  Future<EnterpriseDirectoryResult<DirectoryMemberItem>> directoryUsersPage({
    String cursor = '',
    int pageSize = kDirectoryDefaultPageSize,
    EntityId workspaceId = '',
  }) async {
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.post,
      EnterpriseAppApi.pathDirectoryUsers,
      body: <String, dynamic>{
        ..._directoryBody(cursor: cursor, pageSize: pageSize),
        if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
      },
      idempotencyKey: null,
    );
    return parseUsersPage(_okBody(resp));
  }

  // ==================== INT-22 附件留存治理 ====================

  Future<AssetGovernanceOutcome> assetGovernance({
    required AssetGovernanceOp op,
    required String objectKey,
    int? retentionDays,
    String holdReason = '',
    required String idempotencyKey,
  }) async {
    final String? invalid = _validateGovernance(
      op: op,
      objectKey: objectKey,
      retentionDays: retentionDays,
      holdReason: holdReason,
    );
    if (invalid != null) {
      throw EnterpriseAppApiException(
        EnterpriseErrorUiState(
          kind: EnterpriseErrorKind.invalidRequest,
          httpStatus: 400,
          detail: invalid,
        ),
      );
    }
    final EnterpriseAppResponse resp = await _send(
      EnterpriseHttpMethod.post,
      EnterpriseAppApi.pathFilesGovernance,
      body: <String, dynamic>{
        'op': op.wireName,
        'object_key': objectKey,
        if (op == AssetGovernanceOp.setRetention)
          'retention_days': retentionDays,
        if (op == AssetGovernanceOp.hold) 'reason': holdReason,
      },
      idempotencyKey: idempotencyKey,
    );
    return AssetGovernanceOutcome.fromJson(_okMap(resp));
  }

  // ==================== 内部 ====================

  /// 本地校验（与后端同规则；本地拒可省一次无效往返）。
  String? _validateGovernance({
    required AssetGovernanceOp op,
    required String objectKey,
    required int? retentionDays,
    required String holdReason,
  }) {
    if (objectKey.isEmpty) return 'object_key_required';
    if (op == AssetGovernanceOp.setRetention) {
      return validateRetentionDays(retentionDays);
    }
    if (op == AssetGovernanceOp.hold) return validateHoldReason(holdReason);
    return null;
  }

  Map<String, dynamic> _directoryBody({
    required String cursor,
    required int pageSize,
  }) {
    final DirectoryQueryValidation v = validateDirectoryPageSize(pageSize);
    if (!v.isValid) {
      // 超上限/非法页大小**拒绝**（不是截断）——与后端同语义，本地即断，
      // 不给「一直成功」的全量循环留任何可能。
      throw EnterpriseAppApiException(
        EnterpriseErrorUiState(
          kind: EnterpriseErrorKind.invalidRequest,
          httpStatus: 400,
          detail: v.reason ?? '',
        ),
      );
    }
    return <String, dynamic>{
      'page_size': v.pageSize,
      if (cursor.isNotEmpty) 'cursor': cursor,
    };
  }

  Future<EnterpriseAppResponse> _send(
    EnterpriseHttpMethod method,
    String path, {
    required String? idempotencyKey,
    Object? body,
  }) async {
    final EnterpriseAppRequest request = EnterpriseAppRequest(
      method: method,
      path: path,
      headers: <String, String>{
        'content-type': 'application/json',
        // INV-7：全部写操作必须带 Idempotency-Key（同 key 同体 → 重放原结果，
        // 同 key 异体 → 409 idempotency_conflict）。
        'idempotency-key': ?idempotencyKey,
      },
      body: body,
    );
    try {
      return await _transport.send(request);
    } on EnterpriseChannelUnboundException {
      throw EnterpriseAppApiException(
        const EnterpriseErrorUiState(kind: EnterpriseErrorKind.channelUnbound),
      );
    } on Object catch (e) {
      throw EnterpriseAppApiException(
        enterpriseErrorUiState(transportError: e),
      );
    }
  }

  /// 2xx → body map；否则按稳定错误信封归一后抛出。
  Map<String, dynamic> _okMap(EnterpriseAppResponse resp) {
    final dynamic body = _okBody(resp);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return const <String, dynamic>{};
  }

  dynamic _okBody(EnterpriseAppResponse resp) {
    if (resp.isOk) return resp.body;
    throw EnterpriseAppApiException(
      enterpriseErrorUiState(httpStatus: resp.httpStatus, body: resp.body),
    );
  }

  static String _segment(EntityId id) => id.isEmpty ? '0' : id;
}
