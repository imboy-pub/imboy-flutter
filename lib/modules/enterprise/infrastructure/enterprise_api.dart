/// 企业 API 客户端（amendment §2.1 / plan §5.1 租户 Enterprise API）
///
/// 契约要点：
/// - 路径严格 `/api/v1/enterprise/organizations/{orgId}/...`；orgId 是
///   资源 owner/租户条件（EB-D03），全部方法显式携带并拼入路径；
/// - ACK 为 delivery-only POST（`.../messages/{id}/ack`）：只确认投递，
///   无任何删除语义，本地真源不因 ACK 改变（见 EnterpriseStore）；
/// - 上传走短期 presigned PUT（presign→PUT→confirm 重新鉴权）；下载仅经
///   企业 content 鉴权代理路径，客户端不接收/不持久化 presigned GET
///   URL、object key 或 storage endpoint（EB-D06）；
/// - 错误映射：401 未授权 / 403 禁止 / 409 offboarding_required
///   （[EnterpriseApiException] 判定属性）。
///
/// 镜像 [WorkspaceApi] 的 HttpClient 模式：失败抛异常而非静默空值。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

/// 企业 API 失败（透传服务端 envelope code 与消息）。
class EnterpriseApiException implements Exception {
  final int code;
  final String message;

  const EnterpriseApiException(this.code, this.message);

  /// 401：JWT 失效 / 未授权。
  bool get isUnauthorized => code == 401;

  /// 403：非 active member / 无 active assignment / suspend 后访问。
  bool get isForbidden => code == 403;

  /// 409 offboarding_required：存在 active business identity assignment，
  /// 直接移除被拒（plan EB-D07）。
  bool get isOffboardingRequired => code == 409;

  @override
  String toString() => 'EnterpriseApiException($code): $message';
}

/// 企业 API 客户端。
class EnterpriseApi extends HttpClient {
  /// 我可访问的企业组织列表（成员视角；suspend 成员仍可读到降级状态）。
  Future<List<EnterpriseOrg>> myOrganizations() async {
    final resp = await get('/api/v1/enterprise/organizations');
    return _unwrapList(resp, EnterpriseOrg.fromJson);
  }

  /// 业务身份列表（GET business-identities）。
  Future<List<BusinessIdentity>> businessIdentities(EntityId orgId) async {
    final resp = await get(_org(orgId, 'business-identities'));
    return _unwrapList(resp, BusinessIdentity.fromJson);
  }

  /// 企业联系人列表。
  Future<List<EnterpriseContact>> contacts(EntityId orgId) async {
    final resp = await get(_org(orgId, 'contacts'));
    return _unwrapList(resp, EnterpriseContact.fromJson);
  }

  /// 企业会话列表。
  Future<List<EnterpriseConversation>> conversations(EntityId orgId) async {
    final resp = await get(_org(orgId, 'conversations'));
    return _unwrapList(resp, EnterpriseConversation.fromJson);
  }

  /// 会话消息列表（after_id 增量：只返回游标之后的消息）。
  Future<List<EnterpriseMessage>> messages(
    EntityId orgId,
    EntityId conversationId, {
    EntityId afterId = '',
  }) async {
    final resp = await get(
      _org(orgId, 'conversations/$conversationId/messages'),
      queryParameters: afterId.isEmpty ? null : {'after_id': afterId},
    );
    return _unwrapList(resp, EnterpriseMessage.fromJson);
  }

  /// 发送企业托管消息（服务端 accepted 晚于 canonical + snapshot + audit
  /// 提交；本方法只透传契约，不掺本地语义）。
  Future<EnterpriseMessage> sendMessage(
    EntityId orgId,
    EntityId conversationId, {
    required String content,
    EntityId assetId = '',
  }) async {
    final resp = await post(
      _org(orgId, 'conversations/$conversationId/messages'),
      data: {'content': content, if (assetId.isNotEmpty) 'asset_id': assetId},
    );
    return _unwrap(
      resp,
      EnterpriseMessage.fromJson,
      fallback: EnterpriseMessage(
        id: '',
        conversationId: conversationId,
        organizationId: orgId,
        senderType: EnterpriseSenderType.businessIdentity,
        content: content,
        assetId: assetId,
      ),
    );
  }

  /// delivery ACK（幂等，delivery-only）。
  ///
  /// 反向防误读：本方法只发 POST；成功与否都不触发本地删除/隐藏语义。
  Future<void> ackDelivered(
    EntityId orgId,
    EntityId conversationId,
    EntityId messageId,
  ) async {
    final resp = await post(
      _org(orgId, 'conversations/$conversationId/messages/$messageId/ack'),
      data: <String, dynamic>{},
    );
    _ensureOk(resp);
  }

  /// 申请短期 presigned PUT（返回体含 upload_url；仅内存使用，禁止持久化）。
  Future<EnterprisePresignResult> presignAsset(
    EntityId orgId, {
    required String fileName,
    required String mime,
    required int size,
  }) async {
    final resp = await post(
      _org(orgId, 'assets/presign'),
      data: {'file_name': fileName, 'mime': mime, 'size': size},
    );
    return _unwrap(
      resp,
      EnterprisePresignResult.fromJson,
      fallback: const EnterprisePresignResult(assetId: '', uploadUrl: ''),
    );
  }

  /// 上传后 confirm（独立请求重新鉴权；suspend 后 fail-closed，EB-D06）。
  Future<EnterpriseAsset> confirmAsset(EntityId orgId, EntityId assetId) async {
    final resp = await post(
      _org(orgId, 'assets/confirm'),
      data: {'asset_id': assetId},
    );
    return _unwrap(
      resp,
      EnterpriseAsset.fromJson,
      fallback: EnterpriseAsset(
        id: assetId,
        organizationId: orgId,
        status: 'pending',
      ),
    );
  }

  /// 附件 content 鉴权代理路径（唯一合法的附件查看入口，EB-D06）。
  ///
  /// 返回相对路径（由 HttpClient 统一加 baseUrl 与鉴权头）；客户端不得
  /// 在此拼接 presigned 参数 / object key / storage endpoint。
  String assetContentPath(EntityId orgId, EntityId assetId) =>
      _org(orgId, 'assets/$assetId/content');

  /// 附件内容文本预览（GET 企业 content 代理；仅文本类型返回内容，
  /// 其余返回占位说明——V1 不做二进制渲染）。
  Future<String> fetchAssetContentText(EntityId orgId, EntityId assetId) async {
    final resp = await get(assetContentPath(orgId, assetId));
    _ensureOk(resp);
    final payload = resp.payload;
    if (payload is String && payload.isNotEmpty) {
      return payload;
    }
    if (payload is Map) {
      final text = payload['text'];
      if (text is String && text.isNotEmpty) {
        return text;
      }
    }
    return '(binary content, preview unavailable)';
  }

  // ==================== 内部 ====================

  /// org 绑定路径（orgId 恒为第一段路径参数——租户条件的物理体现）。
  String _org(EntityId orgId, String rest) =>
      '/api/v1/enterprise/organizations/$orgId/$rest';

  Map<String, dynamic> _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw EnterpriseApiException(resp.code, resp.msg);
    }
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  T _unwrap<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson, {
    required T fallback,
  }) {
    final payload = _ensureOk(resp);
    if (payload.isEmpty) return fallback;
    return fromJson(payload);
  }

  List<T> _unwrapList<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _ensureOk(resp);
    return IMBoyHttpResponse.payloadList(resp.payload).map(fromJson).toList();
  }
}
