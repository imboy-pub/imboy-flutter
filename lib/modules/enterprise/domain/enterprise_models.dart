/// 企业域 DTO（amendment §2.1 / plan §2.1 EB-D03~D06）
///
/// TSID 约定：64-bit ID 后端以 JSON integer 传输，App 端一律经仓内
/// [entityIdOf]（safeParseBigIntJson 语义）转 String 持有（[EntityId]），
/// 全程不回转 int/num；序列化（toJson）时 TSID 也以 String 落 JSON。
///
/// EB-D03 措辞落地：`organizationId` 是资源 owner/租户条件；
/// `senderBusinessIdentityId` 是经办身份；自然人 actor（user_id）仅审计/
/// 展示，不参与资源归属，本 DTO 不承载可写 actor 字段。
///
/// 本文件保持纯 Dart（无 flutter import），可被单测直接驱动。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// 组织成员状态（plan EB-D07：active|suspended|removed）。
enum EnterpriseMemberStatus {
  active('active'),
  suspended('suspended'),
  removed('removed');

  final String wireName;

  const EnterpriseMemberStatus(this.wireName);

  /// 宽容解析：未知值回落 active（服务端权威值另行展示）。
  static EnterpriseMemberStatus parse(dynamic raw) {
    final s = raw is String ? raw : raw?.toString() ?? '';
    return EnterpriseMemberStatus.values.firstWhere(
      (m) => m.wireName == s,
      orElse: () => EnterpriseMemberStatus.active,
    );
  }
}

/// 企业消息发送者类型（plan EB-D05：XOR 复合 FK 的显式 sender）。
enum EnterpriseSenderType {
  contact('contact'),
  businessIdentity('business_identity');

  final String wireName;

  const EnterpriseSenderType(this.wireName);

  /// 宽容解析：未知值回落 contact。
  static EnterpriseSenderType parse(dynamic raw) {
    final s = raw is String ? raw : raw?.toString() ?? '';
    return EnterpriseSenderType.values.firstWhere(
      (t) => t.wireName == s,
      orElse: () => EnterpriseSenderType.contact,
    );
  }
}

/// 企业组织（EnterpriseOrg）。
class EnterpriseOrg {
  final EntityId id;
  final String name;
  final EnterpriseMemberStatus memberStatus;
  final EntityId defaultWorkspaceId;

  const EnterpriseOrg({
    required this.id,
    required this.name,
    this.memberStatus = EnterpriseMemberStatus.active,
    this.defaultWorkspaceId = '',
  });

  factory EnterpriseOrg.fromJson(Map<String, dynamic> json) {
    return EnterpriseOrg(
      id: entityIdOf(json['id']),
      name: parseModelString(json['name']),
      memberStatus: EnterpriseMemberStatus.parse(json['member_status']),
      defaultWorkspaceId: entityIdOf(json['default_workspace_id']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'member_status': memberStatus.wireName,
    if (defaultWorkspaceId.isNotEmpty)
      'default_workspace_id': defaultWorkspaceId,
  };

  /// suspend/offboarding 降级：非 active 一律只读（amendment §2.4）。
  bool get isReadOnly => memberStatus != EnterpriseMemberStatus.active;

  bool get isSuspended => memberStatus == EnterpriseMemberStatus.suspended;
}

/// 业务身份（Business Identity）。
///
/// 业务身份不可登录、不发 JWT、不拥有个人好友（plan EB-D03）；
/// function_key 标识岗位（sales / customer_service 等，服务端权威）。
class BusinessIdentity {
  final EntityId id;
  final EntityId organizationId;
  final String displayName;
  final String functionKey;
  final String status;

  const BusinessIdentity({
    required this.id,
    required this.organizationId,
    this.displayName = '',
    this.functionKey = '',
    this.status = 'active',
  });

  factory BusinessIdentity.fromJson(Map<String, dynamic> json) {
    return BusinessIdentity(
      id: entityIdOf(json['id']),
      organizationId: entityIdOf(json['organization_id']),
      displayName: parseModelString(json['display_name']),
      functionKey: parseModelString(json['function_key']),
      status: parseModelString(json['status'], defaultValue: 'active'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'display_name': displayName,
    'function_key': functionKey,
    'status': status,
  };

  bool get isActive => status == 'active';
}

/// 企业联系人（Enterprise Contact）。
///
/// 企业持有的外部客户记录，关系 owner 是 Org；可选关联 IMBoy user_id
/// 仅作展示，不代表个人好友关系（plan EB-D04）。
class EnterpriseContact {
  final EntityId id;
  final EntityId organizationId;
  final String displayName;
  final EntityId userId;

  const EnterpriseContact({
    required this.id,
    required this.organizationId,
    this.displayName = '',
    this.userId = '',
  });

  factory EnterpriseContact.fromJson(Map<String, dynamic> json) {
    return EnterpriseContact(
      id: entityIdOf(json['id']),
      organizationId: entityIdOf(json['organization_id']),
      displayName: parseModelString(json['display_name']),
      userId: entityIdOf(json['user_id']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'display_name': displayName,
    if (userId.isNotEmpty) 'user_id': userId,
  };
}

/// 企业会话（Enterprise Conversation）。
///
/// 归 Org，显式绑定同 Org 默认 Workspace（服务端解析，API 不接受调用方
/// 指定）；当前经办 identity 可变（handover），历史 sender 不重写。
class EnterpriseConversation {
  final EntityId id;
  final EntityId organizationId;
  final EntityId contactId;
  final EntityId businessIdentityId;
  final String updatedAt;

  const EnterpriseConversation({
    required this.id,
    required this.organizationId,
    required this.contactId,
    required this.businessIdentityId,
    this.updatedAt = '',
  });

  factory EnterpriseConversation.fromJson(Map<String, dynamic> json) {
    return EnterpriseConversation(
      id: entityIdOf(json['id']),
      organizationId: entityIdOf(json['organization_id']),
      contactId: entityIdOf(json['contact_id']),
      businessIdentityId: entityIdOf(json['business_identity_id']),
      updatedAt: parseModelString(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'contact_id': contactId,
    'business_identity_id': businessIdentityId,
    if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
  };
}

/// 企业消息（Enterprise Message）。
///
/// sender 显式二分（plan EB-D05）：contact 入站 / business_identity 出站，
/// 恰好一个非空（[senderXorValid]）。`senderBusinessIdentityName`、
/// `retainUntil`、`policySnapshot` 为服务端只读展示字段；actor_user_id
/// 仅审计，不进客户端可写契约。
class EnterpriseMessage {
  final EntityId id;
  final EntityId conversationId;
  final EntityId organizationId;
  final EnterpriseSenderType senderType;
  final EntityId senderContactId;
  final EntityId senderBusinessIdentityId;

  /// 经办业务身份展示名（列表展示 sender 用，不展示为自然人好友）。
  final String senderBusinessIdentityName;
  final String content;

  /// 非空表示消息带附件；查看仅经企业 content 鉴权代理（EB-D06）。
  final EntityId assetId;

  /// 保留期（服务端 policy 快照字段，只读展示）。
  final String retainUntil;

  /// 保留策略快照（只读展示）。
  final String policySnapshot;
  final String createdAt;

  /// 本地 delivery ACK 状态（仅本地投递标记，不影响真源）。
  final bool delivered;

  const EnterpriseMessage({
    required this.id,
    required this.conversationId,
    required this.organizationId,
    this.senderType = EnterpriseSenderType.contact,
    this.senderContactId = '',
    this.senderBusinessIdentityId = '',
    this.senderBusinessIdentityName = '',
    this.content = '',
    this.assetId = '',
    this.retainUntil = '',
    this.policySnapshot = '',
    this.createdAt = '',
    this.delivered = false,
  });

  factory EnterpriseMessage.fromJson(Map<String, dynamic> json) {
    return EnterpriseMessage(
      id: entityIdOf(json['id']),
      conversationId: entityIdOf(json['conversation_id']),
      organizationId: entityIdOf(json['organization_id']),
      senderType: EnterpriseSenderType.parse(json['sender_type']),
      senderContactId: entityIdOf(json['sender_contact_id']),
      senderBusinessIdentityId: entityIdOf(json['sender_business_identity_id']),
      senderBusinessIdentityName: parseModelString(
        json['sender_business_identity_name'],
      ),
      content: parseModelString(json['content']),
      assetId: entityIdOf(json['asset_id']),
      retainUntil: parseModelString(json['retain_until']),
      policySnapshot: parseModelString(json['policy_snapshot']),
      createdAt: parseModelString(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'organization_id': organizationId,
    'sender_type': senderType.wireName,
    if (senderContactId.isNotEmpty) 'sender_contact_id': senderContactId,
    if (senderBusinessIdentityId.isNotEmpty)
      'sender_business_identity_id': senderBusinessIdentityId,
    if (senderBusinessIdentityName.isNotEmpty)
      'sender_business_identity_name': senderBusinessIdentityName,
    'content': content,
    if (assetId.isNotEmpty) 'asset_id': assetId,
    if (retainUntil.isNotEmpty) 'retain_until': retainUntil,
    if (policySnapshot.isNotEmpty) 'policy_snapshot': policySnapshot,
    if (createdAt.isNotEmpty) 'created_at': createdAt,
    'delivered': delivered,
  };

  /// EB-D05 XOR 约束：恰好一个 sender 非空且与 sender_type 匹配。
  bool get senderXorValid {
    if (senderType == EnterpriseSenderType.contact) {
      return senderContactId.isNotEmpty && senderBusinessIdentityId.isEmpty;
    }
    return senderBusinessIdentityId.isNotEmpty && senderContactId.isEmpty;
  }

  /// 复制并标记已投递（delivery-only：只改本地标记，不删真源）。
  EnterpriseMessage withDelivered() {
    return EnterpriseMessage(
      id: id,
      conversationId: conversationId,
      organizationId: organizationId,
      senderType: senderType,
      senderContactId: senderContactId,
      senderBusinessIdentityId: senderBusinessIdentityId,
      senderBusinessIdentityName: senderBusinessIdentityName,
      content: content,
      assetId: assetId,
      retainUntil: retainUntil,
      policySnapshot: policySnapshot,
      createdAt: createdAt,
      delivered: true,
    );
  }
}

/// 企业附件（Enterprise Asset）。
///
/// DB/客户端只存 object 元信息；客户端不得接收/持久化 presigned GET
/// URL、object key 或 storage endpoint（EB-D06）。
class EnterpriseAsset {
  final EntityId id;
  final EntityId organizationId;
  final EntityId conversationId;
  final EntityId messageId;
  final String mime;
  final int size;

  /// pending（已 presign 未 confirm）| confirmed。
  final String status;

  const EnterpriseAsset({
    required this.id,
    required this.organizationId,
    this.conversationId = '',
    this.messageId = '',
    this.mime = '',
    this.size = 0,
    this.status = 'pending',
  });

  factory EnterpriseAsset.fromJson(Map<String, dynamic> json) {
    return EnterpriseAsset(
      id: entityIdOf(json['id']),
      organizationId: entityIdOf(json['organization_id']),
      conversationId: entityIdOf(json['conversation_id']),
      messageId: entityIdOf(json['message_id']),
      mime: parseModelString(json['mime']),
      size: parseModelInt(json['size']),
      status: parseModelString(json['status'], defaultValue: 'pending'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    if (conversationId.isNotEmpty) 'conversation_id': conversationId,
    if (messageId.isNotEmpty) 'message_id': messageId,
    'mime': mime,
    'size': size,
    'status': status,
  };

  bool get isPending => status == 'pending';
}

/// presigned PUT 结果（短期上传凭证）。
///
/// [uploadUrl] 仅在内存中使用到 PUT 完成为止，禁止持久化（EB-D06）。
class EnterprisePresignResult {
  final EntityId assetId;
  final String uploadUrl;
  final String expiresAt;

  const EnterprisePresignResult({
    required this.assetId,
    required this.uploadUrl,
    this.expiresAt = '',
  });

  factory EnterprisePresignResult.fromJson(Map<String, dynamic> json) {
    return EnterprisePresignResult(
      assetId: entityIdOf(json['asset_id']),
      uploadUrl: parseModelString(json['upload_url']),
      expiresAt: parseModelString(json['expires_at']),
    );
  }
}
