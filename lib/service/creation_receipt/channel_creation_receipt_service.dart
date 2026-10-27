/// W04.d.c（channel-group-ux-v2.2 §6.4 C1）：频道创建受理合同编排。
///
/// 生命周期状态机在 [runCreationReceiptFlow]（群/频道共用，同键恢复
/// 语义一致）；本文件只做频道路装配：manifest 能力门、scope 推导、
/// 频道载荷构建。恢复重放一律原键原载荷；能力未启用且无未知意图时
/// 调用方回落既有键less路径（行为零变化）。
///
/// 调用方（channel_create_page 经 CreateChannelNotifier / organization_manage）
/// 只消费 [CreationFlowOutcome]。
library;

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/store/api/channel_api.dart';

/// 频道创建受理操作的 scopeId：工作区频道按工作区隔离；个人域固定
/// 'personal'（与后端 scope/workspace_id 语义对齐）。
String channelCreationScopeId({required bool workspace, String? workspaceId}) =>
    workspace ? (workspaceId ?? 'personal') : 'personal';

class ChannelCreationReceiptService {
  /// 按受理合同创建或恢复频道。
  ///
  /// [workspace]=true 时频道为工作区域（须携带 workspaceId）；创建字段仅在
  /// 生成新意图时进入载荷，恢复重放一律使用存储载荷（同键绝不换载荷）。
  Future<CreationFlowOutcome> createOrRecoverChannel({
    required String account,
    required String name,
    String? description,
    String? avatar,
    int visibility = 0,
    int accessType = 0,
    int joinPolicy = 0,
    String? customId,
    List<String>? tags,
    bool workspace = false,
    String? workspaceId,
  }) {
    return runCreationReceiptFlow(
      account: account,
      operation: 'create_channel',
      scopeId: channelCreationScopeId(
        workspace: workspace,
        workspaceId: workspaceId,
      ),
      capabilityEnabled:
          AppManifestService.manifest?.channelCreateReceiptEnabled ?? false,
      newPayload: <String, dynamic>{
        'name': name,
        'visibility': visibility,
        'access_type': accessType,
        'join_policy': joinPolicy,
        'description': ?description,
        'avatar': ?avatar,
        if (customId != null && customId.isNotEmpty) 'custom_id': customId,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (workspace && workspaceId != null) ...{
          'scope': 'workspace',
          'workspace_id': workspaceId,
        },
      },
      // 成功 payload 即频道对象（后端 maps:merge(Channel, 增量字段)）。
      extractCreatedId: (payload) =>
          payload['id'] == null ? null : '${payload['id']}',
      dispatch:
          ({
            required String requestId,
            required Map<String, dynamic> storedPayload,
            required bool recoverOnly,
          }) {
            return ChannelApi().createChannelWithReceipt(
              requestId: requestId,
              fields: storedPayload,
              recoverOnly: recoverOnly,
            );
          },
    );
  }
}
