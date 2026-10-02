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

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

/// 面级 workspace 门镜像（PR-W2-C01 / V1.2 D3a/c/d/e）：后端
/// `eb_tenant_handler` 对**全部** JSON 动作先过
/// `eb_enterprise_http:workspace_id/2`（GET 走查询串、写走正文，缺一即
/// 422 `missing_workspace_id`，绝不取默认值）。SDK 在同一位置前置同码
/// 同语义的本地异常：调用方现有 `on EnterpriseApiException` 分支自然
/// 接管，且不再发出必败请求。
Never _missingWorkspaceId() =>
    throw const EnterpriseApiException(422, 'missing_workspace_id');

/// 企业附件 content 字节响应透传：对象字节本体不是 JSON envelope，原样
/// 交付（鉴权/签名/重试仍走 HttpClient 统一链路）。
class _BytesPassthroughTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    return IMBoyHttpResponse.success(response.data);
  }
}

final _bytesPassthroughTransformer = _BytesPassthroughTransformer();

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
  /// 我可访问的企业组织列表（成员视角）。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D1）：enterprise 面路由表**不存在** bare
  /// `GET /api/v1/enterprise/organizations`（只有 `:org_id/...` 形态），
  /// 该旧调用必 404。组织列表能力实际由组织域提供：
  /// `GET /api/v1/organizations/mine`（`organization_logic:mine/3`，响应
  /// `{list:[org public_view]}`）。行键 `id`/`name` 进 [EnterpriseOrg]；
  /// `member_status`/`default_workspace_id` 行内缺失时模型宽容降级
  /// （active / 空），suspend 事实以行内 `status`/后续调用为准。
  Future<List<EnterpriseOrg>> myOrganizations() async {
    final resp = await get('/api/v1/organizations/mine');
    return _unwrapList(resp, EnterpriseOrg.fromJson);
  }

  /// 业务身份列表（GET business-identities）。
  ///
  /// 契约（eb_enterprise_actions 动作表，F-LAY-10）：GET 查询串必带
  /// `workspace_id`（缺即 422）；`after_id`/`limit` 可选键集分页。
  Future<List<BusinessIdentity>> businessIdentities(
    EntityId orgId, {
    EntityId workspaceId = '',
    EntityId afterId = '',
    int limit = 0,
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final resp = await get(
      _org(orgId, 'business-identities'),
      queryParameters: {
        'workspace_id': workspaceId,
        if (afterId.isNotEmpty) 'after_id': afterId,
        if (limit > 0) 'limit': limit,
      },
    );
    return _unwrapList(resp, BusinessIdentity.fromJson);
  }

  /// 企业联系人列表。
  ///
  /// 契约（PR-W2-C01 / V1.2 D3a）：GET 查询串必带 `workspace_id`（后端
  /// 面级门，真 HTTP 实证 422 `missing_workspace_id`）；[afterId]/[limit]
  /// 是动作表登记的可选分页键。
  Future<List<EnterpriseContact>> contacts(
    EntityId orgId, {
    EntityId workspaceId = '',
    EntityId afterId = '',
    int limit = 0,
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final resp = await get(
      _org(orgId, 'contacts'),
      queryParameters: {
        'workspace_id': workspaceId,
        if (afterId.isNotEmpty) 'after_id': afterId,
        if (limit > 0) 'limit': limit,
      },
    );
    return _unwrapList(resp, EnterpriseContact.fromJson);
  }

  /// 企业会话列表（**后端不提供**——契约对齐说明见方法体）。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D4）：该路径唯一登记动作
  /// `open_conversation` 是 POST；GET 由后端 405 拒绝
  /// （`eb_route_contract_tests` a03_405 真 HTTP 守护）。列表能力应改由
  /// 本地真源 [EnterpriseStore.conversations] 提供（已存在），网络拉增量
  /// 走 [messages] 的 after_id 键集分页。本方法保留签名（调用方兼容），
  /// 调用即前置抛镜像后端的 405（同码同语义，失败点前移）。
  Future<List<EnterpriseConversation>> conversations(EntityId orgId) async {
    throw const EnterpriseApiException(
      405,
      'method_not_allowed: GET list not exposed; '
      'use EnterpriseStore.conversations for listing and '
      'openConversation/messages for the network path',
    );
  }

  /// 打开（或幂等取回）企业会话——该路径后端唯一真实动作。
  ///
  /// 契约（eb_enterprise_actions:open_conversation）：POST 正文必带
  /// `contact_id`(tsid) + `business_identity_id`(tsid)，另受面级
  /// workspace 门（正文 `workspace_id` 必带，缺即 422）。
  Future<EnterpriseConversation> openConversation(
    EntityId orgId, {
    required EntityId workspaceId,
    required EntityId contactId,
    required EntityId businessIdentityId,
  }) async {
    final resp = await post(
      _org(orgId, 'conversations'),
      data: {
        'workspace_id': workspaceId,
        'contact_id': contactId,
        'business_identity_id': businessIdentityId,
      },
    );
    return _unwrap(
      resp,
      EnterpriseConversation.fromJson,
      fallback: EnterpriseConversation(
        id: '',
        organizationId: orgId,
        contactId: contactId,
        businessIdentityId: businessIdentityId,
      ),
    );
  }

  /// 会话消息列表（after_id 增量：只返回游标之后的消息）。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D3c + 分页键补全）：GET 查询串必带
  /// `workspace_id`（面级门，缺即 422）；[afterId]/[limit] 是动作表
  /// `list_messages` 登记的完整键集分页参数（游标缺省 = 全量首拉）。
  Future<List<EnterpriseMessage>> messages(
    EntityId orgId,
    EntityId conversationId, {
    EntityId afterId = '',
    EntityId workspaceId = '',
    int limit = 0,
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final resp = await get(
      _org(orgId, 'conversations/$conversationId/messages'),
      queryParameters: {
        'workspace_id': workspaceId,
        if (afterId.isNotEmpty) 'after_id': afterId,
        if (limit > 0) 'limit': limit,
      },
    );
    return _unwrapList(resp, EnterpriseMessage.fromJson);
  }

  /// 发送企业托管消息（服务端 accepted 晚于 canonical + snapshot + audit
  /// 提交；本方法只透传契约，不掺本地语义）。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D2）：提交面是动作表 `append_message` 的
  /// 白名单——`client_msg_id`（幂等键，**required**；重试必须复用同一 id，
  /// 缺省时本方法用 [Xid] 自动生成并随返回对象语义由调用方持有）、
  /// `sender_type`（**required**；企业托管出站恒 business_identity，缺省
  /// 即该值）、`body`（optional——纯文本在应用层要求非空）、
  /// `asset_ids`（list，optional）。旧键形 `{'content', 'asset_id'}` 是
  /// 表外键（服务端忽略）+ 缺必填 422，已废。
  Future<EnterpriseMessage> sendMessage(
    EntityId orgId,
    EntityId conversationId, {
    required String content,
    EntityId workspaceId = '',
    EntityId assetId = '',
    String clientMsgId = '',
    EnterpriseSenderType senderType = EnterpriseSenderType.businessIdentity,
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final msgId = clientMsgId.isEmpty ? Xid().toString() : clientMsgId;
    final resp = await post(
      _org(orgId, 'conversations/$conversationId/messages'),
      data: {
        'workspace_id': workspaceId,
        'client_msg_id': msgId,
        'sender_type': senderType.wireName,
        'body': content,
        if (assetId.isNotEmpty) 'asset_ids': [assetId],
      },
    );
    return _unwrap(
      resp,
      EnterpriseMessage.fromJson,
      fallback: EnterpriseMessage(
        id: '',
        conversationId: conversationId,
        organizationId: orgId,
        senderType: senderType,
        content: content,
        assetId: assetId,
      ),
    );
  }

  /// delivery ACK（幂等，delivery-only）。
  ///
  /// 反向防误读：本方法只发 POST；成功与否都不触发本地删除/隐藏语义。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D3d）：后端动作表要求正文 `recipient_ref`
  /// **required**（+ `device_id` optional），且面级 workspace 门要求正文
  /// `workspace_id` 必带——旧空 `{}` 形状必 422。缺失时前置抛镜像 422。
  Future<void> ackDelivered(
    EntityId orgId,
    EntityId conversationId,
    EntityId messageId, {
    EntityId workspaceId = '',
    String recipientRef = '',
    String deviceId = '',
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    if (recipientRef.isEmpty) {
      throw const EnterpriseApiException(422, 'missing_recipient_ref');
    }
    final resp = await post(
      _org(orgId, 'conversations/$conversationId/messages/$messageId/ack'),
      data: {
        'workspace_id': workspaceId,
        'recipient_ref': recipientRef,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
    );
    _ensureOk(resp);
  }

  /// 申请上传凭证（POST assets/presign，后端冻结契约 CSX-01）。
  ///
  /// 请求体键白名单（eb_enterprise_actions:presign 动作表）：
  /// `{workspace_id, conversation_id, mime, size_bytes, object_hash,
  /// file_name?}`——[objectHash] 是文件字节的 SHA-256（64 位小写 hex，
  /// PUT 后服务端复核）；旧键形 `{file_name, mime, size}` 缺
  /// conversation_id/size_bytes/object_hash 必 422（历史断链形状，已废）。
  ///
  /// 返回体含不透明 `upload_ref` 与嵌套 `upload.url`（企业面恒无 url，
  /// 见 [EnterprisePresignResult]）；两者仅内存使用，禁止持久化（EB-D06）。
  Future<EnterprisePresignResult> presignAsset(
    EntityId orgId, {
    required EntityId workspaceId,
    required EntityId conversationId,
    required String mime,
    required int sizeBytes,
    required String objectHash,
    String fileName = '',
  }) async {
    final resp = await post(
      _org(orgId, 'assets/presign'),
      data: {
        'workspace_id': workspaceId,
        'conversation_id': conversationId,
        'mime': mime,
        'size_bytes': sizeBytes,
        'object_hash': objectHash,
        if (fileName.isNotEmpty) 'file_name': fileName,
      },
    );
    return _unwrap(
      resp,
      EnterprisePresignResult.fromJson,
      fallback: const EnterprisePresignResult(assetId: ''),
    );
  }

  /// 上传后 confirm（独立请求重新鉴权；suspend 后 fail-closed，EB-D06）。
  ///
  /// 冻结契约入参是 presign 下发的 `upload_ref`（不透明凭证）+ 本面必填的
  /// `workspace_id`——**不是** asset_id（旧形状已废）；重复 confirm 服务端
  /// 409（重放不算成功）。
  Future<EnterpriseAsset> confirmAsset(
    EntityId orgId, {
    required EntityId workspaceId,
    required String uploadRef,
  }) async {
    final resp = await post(
      _org(orgId, 'assets/confirm'),
      data: {'workspace_id': workspaceId, 'upload_ref': uploadRef},
    );
    return _unwrap(
      resp,
      EnterpriseAsset.fromJson,
      fallback: EnterpriseAsset(
        id: '',
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

  /// 附件内容字节（GET 企业 content 代理；响应是对象字节本体，非 JSON
  /// envelope——走透传 transformer，鉴权/签名仍经 HttpClient 统一链路）。
  ///
  /// 图片渲染（Image.memory）与文本预览（utf8 解码）共用本入口：**禁止**
  /// `Image.network`/`CachedNetworkImage` 裸 URL（客户端不持有任何可裸访
  /// 的对象 URL，EB-D06）。
  ///
  /// 契约对齐（PR-W2-C01 / V1.2 D3e）：content 走 invoke_json 面级门，
  /// GET 查询串必带 `workspace_id`（缺即 422）——旧无 query 形状已废。
  Future<Uint8List> fetchAssetContentBytes(
    EntityId orgId,
    EntityId assetId, {
    EntityId workspaceId = '',
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final resp = await get(
      assetContentPath(orgId, assetId),
      queryParameters: {'workspace_id': workspaceId},
      options: Options(responseType: ResponseType.bytes),
      httpTransformer: _bytesPassthroughTransformer,
    );
    if (!resp.ok) {
      throw EnterpriseApiException(resp.code, resp.msg);
    }
    final payload = resp.payload;
    if (payload is Uint8List) return payload;
    if (payload is List<int>) return Uint8List.fromList(payload);
    throw const EnterpriseApiException(0, 'asset content: unexpected payload');
  }

  /// 附件内容文本预览（GET 企业 content 代理；仅文本类型返回内容，
  /// 其余返回占位说明——V1 不做二进制渲染）。
  ///
  /// 契约同 [fetchAssetContentBytes]：查询串必带 `workspace_id`
  /// （PR-W2-C01 / V1.2 D3e，同形状漂移一并修复）。
  Future<String> fetchAssetContentText(
    EntityId orgId,
    EntityId assetId, {
    EntityId workspaceId = '',
  }) async {
    if (workspaceId.isEmpty) _missingWorkspaceId();
    final resp = await get(
      assetContentPath(orgId, assetId),
      queryParameters: {'workspace_id': workspaceId},
    );
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
