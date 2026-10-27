/// W04.d.g（channel-group-ux-v2.2 §6.4 C1）：群创建受理合同编排。
///
/// 生命周期状态机在 [runCreationReceiptFlow]（群/频道共用，同键恢复
/// 语义一致）；本文件只做群路装配：manifest 能力门、scope 推导、
/// 群载荷构建与重放时的原载荷携带。
///
/// 调用方（organization_manage / launch_chat）只消费 [CreationFlowOutcome]。
library;

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 群创建受理操作的 scopeId（意图存储隔离段）。
String groupCreationScopeId(EntityId? workspaceId) => workspaceId ?? 'personal';

class GroupCreationReceiptService {
  /// 按受理合同创建或恢复群。
  ///
  /// [account]/[workspaceId] 用于意图存储隔离；[workspaceId] 非空即工作区群。
  /// [memberUserIds]/[title] 仅在生成新意图时进入载荷；恢复重放一律使用
  /// 存储载荷（同键绝不换载荷）。
  Future<CreationFlowOutcome> createOrRecoverGroup({
    required String account,
    required EntityId? workspaceId,
    required List<String> memberUserIds,
    String? title,
  }) {
    return runCreationReceiptFlow(
      account: account,
      operation: 'create_group',
      scopeId: groupCreationScopeId(workspaceId),
      capabilityEnabled:
          AppManifestService.manifest?.groupCreateReceiptEnabled ?? false,
      newPayload: <String, dynamic>{
        'member_uids': memberUserIds,
        if (title != null && title.isNotEmpty) 'title': title,
        'workspace_id': ?workspaceId,
      },
      extractCreatedId: (payload) {
        final group = payload['group'];
        if (group is! Map<String, dynamic>) return null;
        final gid = group['id'] ?? group['gid'];
        return gid == null ? null : '$gid';
      },
      dispatch:
          ({
            required String requestId,
            required Map<String, dynamic> storedPayload,
            required bool recoverOnly,
          }) {
            // 重放/只查一律携带存储载荷（同键绝不换载荷）。
            final members =
                (storedPayload['member_uids'] as List?)
                    ?.map((e) => '$e')
                    .toList() ??
                memberUserIds;
            final storedTitle = storedPayload['title'] as String?;
            return GroupApi().createGroupWithReceipt(
              requestId: requestId,
              memberUserIds: members,
              title: storedTitle,
              workspaceId: workspaceId,
              recoverOnly: recoverOnly,
            );
          },
    );
  }
}
