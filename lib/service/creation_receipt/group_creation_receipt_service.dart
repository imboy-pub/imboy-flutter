/// W04.d.g（channel-group-ux-v2.2 §6.4 C1）：群创建受理合同编排。
///
/// 串起 能力门（manifest）→ 意图持久化（提交前保存）→ 24h/recover_only
/// 派发策略 → GroupApi 合同请求 → 结果分类与意图生命周期：
/// - 受理成功（accepted/replayed）→ 清除意图；
/// - create_recovery_expired / create_resource_unavailable → 服务端可证明
///   终止 → 清除意图（此后用户可显式新建意图=新键）；
/// - request_id_conflict / create_not_accepted / 传输失败 / 其他 → 意图
///   保留（未知或非终态；§6.4：不提供换键恢复）；
/// - 能力未启用 → 不发新键；已有未知意图绝不剥键走旧 POST。
///
/// 调用方（organization_manage / launch_chat）只消费 [GroupCreationOutcome]。
library;

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 群创建受理操作的 scopeId（意图存储隔离段）。
String groupCreationScopeId(EntityId? workspaceId) => workspaceId ?? 'personal';

enum GroupCreationFailure {
  /// manifest 未声明合同能力。意图不存在时可走旧键less路径；
  /// 已有未知意图时禁止旧路径（保留/核对，绝不剥键）。
  capabilityMissing,

  /// 同键已绑定不同规范载荷。意图保留。
  conflict,

  /// 只查未见受理（仅表示查询时未见，不证明在途请求不会迟到）。意图保留。
  notAcceptedPending,

  /// 服务端受理已过 7d 窗口。意图已清除，可显式新建意图（新键）。
  recoveryExpired,

  /// 资源已删除/撤权/无资格。意图已清除，可显式新建意图（新键）。
  resourceUnavailable,

  /// 传输失败或其他未知结果。意图保留。
  unknownPending,
}

class GroupCreationOutcome {
  final bool ok;

  /// true=replayed（服务端重放既有受理）；false=accepted（首次受理）。
  final bool replayed;

  /// 成功时创建/恢复出的群 id。
  final String? gid;

  /// 成功时的完整响应 payload（group/member_list + 增量字段）。
  final Map<String, dynamic> payload;

  final GroupCreationFailure? failure;

  /// 失败文案（服务端 msg 透传；界面可按 failure 覆写）。
  final String? errorText;

  /// 过期/不可用时可用于核对的资源 ID。
  final String? resourceId;

  /// capabilityMissing 时区分两种情形：false=无未知意图（调用方可走旧
  /// 键less路径，行为零变化）；true=已有未知意图（禁止旧路径——绝不剥键，
  /// 界面应展示恢复不可用并保留意图）。
  final bool pendingIntentBlocked;

  const GroupCreationOutcome({
    required this.ok,
    this.replayed = false,
    this.gid,
    this.payload = const {},
    this.failure,
    this.errorText,
    this.resourceId,
    this.pendingIntentBlocked = false,
  });
}

class GroupCreationReceiptService {
  /// 按受理合同创建或恢复群。
  ///
  /// [account]/[scopeId] 用于意图存储隔离；[workspaceId] 非空即工作区群。
  /// [memberUserIds]/[title] 仅在生成新意图时进入载荷；恢复重放一律使用
  /// 存储载荷（同键绝不换载荷）。
  Future<GroupCreationOutcome> createOrRecoverGroup({
    required String account,
    required EntityId? workspaceId,
    required List<String> memberUserIds,
    String? title,
  }) async {
    final scopeId = groupCreationScopeId(workspaceId);
    final enabled =
        AppManifestService.manifest?.groupCreateReceiptEnabled ?? false;
    final intent = await loadCreationIntent(
      account: account,
      operation: 'create_group',
      scopeId: scopeId,
    );
    if (!enabled) {
      // 无能力：不启新入口；已有未知意图只保留/核对，绝不剥离键走旧 POST。
      return GroupCreationOutcome(
        ok: false,
        failure: GroupCreationFailure.capabilityMissing,
        pendingIntentBlocked: intent != null,
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dispatch = decideCreationDispatch(
      intentCreatedAtMs: intent?.createdAtMs,
      nowMs: nowMs,
    );
    var requestId = intent?.requestId;
    var storedPayload = intent?.payload;
    if (requestId == null) {
      // 新意图：提交前保存（§6.4）。
      requestId = generateCreationRequestId();
      storedPayload = <String, dynamic>{
        'member_uids': memberUserIds,
        if (title != null && title.isNotEmpty) 'title': title,
        'workspace_id': ?workspaceId,
      };
      await saveCreationIntent(
        account: account,
        operation: 'create_group',
        scopeId: scopeId,
        intent: CreationIntent(
          requestId: requestId,
          createdAtMs: nowMs,
          payload: storedPayload,
        ),
      );
    }

    // 重放/只查一律携带存储载荷（同键绝不换载荷）。
    final members =
        (storedPayload?['member_uids'] as List?)?.map((e) => '$e').toList() ??
        memberUserIds;
    final storedTitle = storedPayload?['title'] as String?;
    final result = await GroupApi().createGroupWithReceipt(
      requestId: requestId,
      memberUserIds: members,
      title: storedTitle,
      workspaceId: workspaceId,
      recoverOnly: dispatch.recoverOnly,
    );

    if (result.ok) {
      await clearCreationIntent(
        account: account,
        operation: 'create_group',
        scopeId: scopeId,
      );
      final group = result.payload['group'];
      final gid = group is Map<String, dynamic>
          ? '${group['id'] ?? group['gid'] ?? ''}'
          : '';
      return GroupCreationOutcome(
        ok: true,
        replayed: result.creationState == 'replayed',
        gid: gid,
        payload: result.payload,
      );
    }

    switch (result.errorSymbol) {
      case 'request_id_conflict':
        return GroupCreationOutcome(
          ok: false,
          failure: GroupCreationFailure.conflict,
          errorText: result.errorText,
        );
      case 'create_not_accepted':
        // 仅表示查询时未见受理，不证明在途请求不会迟到；意图保留。
        return GroupCreationOutcome(
          ok: false,
          failure: GroupCreationFailure.notAcceptedPending,
          errorText: result.errorText,
        );
      case 'create_recovery_expired':
        await clearCreationIntent(
          account: account,
          operation: 'create_group',
          scopeId: scopeId,
        );
        return GroupCreationOutcome(
          ok: false,
          failure: GroupCreationFailure.recoveryExpired,
          errorText: result.errorText,
          resourceId: result.resourceId,
        );
      case 'create_resource_unavailable':
        await clearCreationIntent(
          account: account,
          operation: 'create_group',
          scopeId: scopeId,
        );
        return GroupCreationOutcome(
          ok: false,
          failure: GroupCreationFailure.resourceUnavailable,
          errorText: result.errorText,
          resourceId: result.resourceId,
        );
      default:
        // 信封业务拒绝（无受理副作用）且是新意图 → 清除，避免载荷变更后
        // 同键冲突；恢复派发（已有意图）的未知失败一律保留。
        if (intent == null && result.envelopeRejection) {
          await clearCreationIntent(
            account: account,
            operation: 'create_group',
            scopeId: scopeId,
          );
        }
        return GroupCreationOutcome(
          ok: false,
          failure: GroupCreationFailure.unknownPending,
          errorText: result.errorText,
        );
    }
  }
}
