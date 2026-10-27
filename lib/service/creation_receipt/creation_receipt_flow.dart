/// W04.d（channel-group-ux-v2.2 §6.4 C1）：创建受理编排核心。
///
/// 群（W04.d.g）与频道（W04.d.c）两路创建共用的意图生命周期状态机，
/// 保证两路「同键恢复一致」（计划 J23/J24/J27 定向验证共同依赖）：
///
/// 能力门（manifest）→ 意图持久化（提交前保存）→ 24h/recover_only
/// 派发策略 → 合同请求（重放一律原键原载荷）→ 结果分类与意图生命周期：
/// - 受理成功（accepted/replayed）→ 清除意图；
/// - create_recovery_expired / create_resource_unavailable → 服务端可证明
///   终止 → 清除意图（此后用户可显式新建意图=新键）；
/// - request_id_conflict / create_not_accepted / 传输失败 / 其他 → 意图
///   保留（未知或非终态；§6.4：不提供换键恢复）；
/// - 能力未启用 → 不发新键；已有未知意图绝不剥键走旧 POST。
library;

import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';

/// 创建受理失败分类（群/频道共用语义）。
enum CreationFlowFailure {
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

/// 编排结果（群/频道通用；资源对象由调用方从 payload 自取）。
class CreationFlowOutcome {
  final bool ok;

  /// true=replayed（服务端重放既有受理）；false=accepted（首次受理）。
  final bool replayed;

  /// 成功时创建/恢复出的资源 id 字符串（群 gid / 频道 id）。
  final String createdId;

  /// 成功时的完整响应 payload（资源对象 + 增量字段），供调用方本地落库。
  final Map<String, dynamic> payload;

  final CreationFlowFailure? failure;

  /// 失败文案（服务端 msg 透传；界面可按 failure 覆写）。
  final String? errorText;

  /// 过期/不可用时可用于核对的资源 ID。
  final String? resourceId;

  /// capabilityMissing 时区分两种情形：false=无未知意图（调用方可走旧
  /// 键less路径，行为零变化）；true=已有未知意图（禁止旧路径——绝不剥键，
  /// 界面应展示恢复不可用并保留意图）。
  final bool pendingIntentBlocked;

  const CreationFlowOutcome({
    required this.ok,
    this.replayed = false,
    this.createdId = '',
    this.payload = const {},
    this.failure,
    this.errorText,
    this.resourceId,
    this.pendingIntentBlocked = false,
  });
}

/// 共享编排。群/频道两路创建必须走本函数（同键恢复语义一致，禁止各自
/// 复制一份生命周期分支）。
///
/// - [operation]：'create_group' | 'create_channel'（意图存储隔离段）。
/// - [capabilityEnabled]：manifest 合同能力门（J27.d/e 精度判定由
///   createReceiptContractEnabled 完成，调用方只透传结果）。
/// - [newPayload]：仅生成新意图时进入载荷；已有意图时忽略（同键绝不换载荷）。
/// - [dispatch]：发合同请求；载荷一律取存储意图的原载荷。
/// - [extractCreatedId]：成功时从 payload 提取资源 id（群 gid / 频道 id）。
Future<CreationFlowOutcome> runCreationReceiptFlow({
  required String account,
  required String operation,
  required String scopeId,
  required bool capabilityEnabled,
  required Map<String, dynamic>? newPayload,
  required String? Function(Map<String, dynamic> payload) extractCreatedId,
  required Future<CreationReceiptResult> Function({
    required String requestId,
    required Map<String, dynamic> storedPayload,
    required bool recoverOnly,
  })
  dispatch,
}) async {
  final intent = await loadCreationIntent(
    account: account,
    operation: operation,
    scopeId: scopeId,
  );
  if (!capabilityEnabled) {
    // 无能力：不启新入口；已有未知意图只保留/核对，绝不剥离键走旧 POST。
    return CreationFlowOutcome(
      ok: false,
      failure: CreationFlowFailure.capabilityMissing,
      pendingIntentBlocked: intent != null,
    );
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final dispatch_ = decideCreationDispatch(
    intentCreatedAtMs: intent?.createdAtMs,
    nowMs: nowMs,
  );
  var requestId = intent?.requestId;
  var storedPayload = intent?.payload ?? const <String, dynamic>{};
  if (requestId == null) {
    // 新意图：提交前保存（§6.4）。
    requestId = generateCreationRequestId();
    storedPayload = newPayload ?? const <String, dynamic>{};
    await saveCreationIntent(
      account: account,
      operation: operation,
      scopeId: scopeId,
      intent: CreationIntent(
        requestId: requestId,
        createdAtMs: nowMs,
        payload: storedPayload,
      ),
    );
  }

  final result = await dispatch(
    requestId: requestId,
    storedPayload: storedPayload,
    recoverOnly: dispatch_.recoverOnly,
  );

  if (result.ok) {
    await clearCreationIntent(
      account: account,
      operation: operation,
      scopeId: scopeId,
    );
    return CreationFlowOutcome(
      ok: true,
      replayed: result.creationState == 'replayed',
      createdId: extractCreatedId(result.payload) ?? '',
      payload: result.payload,
    );
  }

  switch (result.errorSymbol) {
    case 'request_id_conflict':
      return CreationFlowOutcome(
        ok: false,
        failure: CreationFlowFailure.conflict,
        errorText: result.errorText,
      );
    case 'create_not_accepted':
      // 仅表示查询时未见受理，不证明在途请求不会迟到；意图保留。
      return CreationFlowOutcome(
        ok: false,
        failure: CreationFlowFailure.notAcceptedPending,
        errorText: result.errorText,
      );
    case 'create_recovery_expired':
      await clearCreationIntent(
        account: account,
        operation: operation,
        scopeId: scopeId,
      );
      return CreationFlowOutcome(
        ok: false,
        failure: CreationFlowFailure.recoveryExpired,
        errorText: result.errorText,
        resourceId: result.resourceId,
      );
    case 'create_resource_unavailable':
      await clearCreationIntent(
        account: account,
        operation: operation,
        scopeId: scopeId,
      );
      return CreationFlowOutcome(
        ok: false,
        failure: CreationFlowFailure.resourceUnavailable,
        errorText: result.errorText,
        resourceId: result.resourceId,
      );
    default:
      // 信封业务拒绝（无受理副作用）且是新意图 → 清除，避免载荷变更后
      // 同键冲突；恢复派发（已有意图）的未知失败一律保留。
      if (intent == null && result.envelopeRejection) {
        await clearCreationIntent(
          account: account,
          operation: operation,
          scopeId: scopeId,
        );
      }
      return CreationFlowOutcome(
        ok: false,
        failure: CreationFlowFailure.unknownPending,
        errorText: result.errorText,
      );
  }
}
