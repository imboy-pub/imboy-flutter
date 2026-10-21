/// 面聊记录（talk_record）授权模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_grant（活跃 UNIQUE(record_id,
/// grantee_user_id)；不能移除最后 owner——owner 在主表）+ §4 grants 端点
/// （owner 才可查全量 ACL；其他人只看自己的权限）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

class TalkRecordGrantModel {
  final EntityId id;
  final EntityId recordId;
  final EntityId granteeUserId;

  /// 服务端目录允许的最小信息（§11.3；可缺省）。
  final String granteeDisplayName;
  final TalkRecordGrantRole role;

  /// viewer/editor 均不隐含导出（§1：导出须单独 allow_export=true）。
  final bool allowExport;
  final EntityId grantedBy;
  final DateTime? revokedAt;
  final DateTime? expiresAt;

  const TalkRecordGrantModel({
    required this.id,
    this.recordId = '',
    this.granteeUserId = '',
    this.granteeDisplayName = '',
    this.role = TalkRecordGrantRole.unknown,
    this.allowExport = false,
    this.grantedBy = '',
    this.revokedAt,
    this.expiresAt,
  });

  factory TalkRecordGrantModel.fromJson(Map<String, dynamic> json) {
    final displayName = parseModelString(json['grantee_display_name']);
    return TalkRecordGrantModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      granteeUserId: entityIdOf(json['grantee_user_id']),
      granteeDisplayName: displayName.isEmpty
          ? parseModelString(json['display_name'])
          : displayName,
      role: TalkRecordGrantRole.parse(json['role']),
      allowExport: parseModelBool(json['allow_export']),
      grantedBy: entityIdOf(json['granted_by']),
      revokedAt: parseModelNullableDateTime(json['revoked_at']),
      expiresAt: parseModelNullableDateTime(json['expires_at']),
    );
  }

  bool get isActive => revokedAt == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'grantee_user_id': granteeUserId,
    'grantee_display_name': granteeDisplayName,
    'role': role.wireName,
    'allow_export': allowExport,
    'granted_by': grantedBy,
    if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
  };
}

/// PUT /:id/grants 请求体元素（owner 提交全量受权用户/角色/export/expiry）。
class TalkRecordGrantInput {
  final EntityId granteeUserId;
  final TalkRecordGrantRole role;
  final bool allowExport;
  final DateTime? expiresAt;

  const TalkRecordGrantInput({
    required this.granteeUserId,
    required this.role,
    this.allowExport = false,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'grantee_user_id': granteeUserId,
    'role': role.toWire(),
    'allow_export': allowExport,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
  };
}
