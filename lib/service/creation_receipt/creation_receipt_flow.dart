/// W04.d（channel-group-ux-v2.2 §6.4 C1）：创建受理编排核心。
///
/// 群（W04.d.g）与频道（W04.d.c）两路创建共用的意图生命周期状态机，
/// 保证两路「同键恢复一致」（计划 J23/J24/J27 定向验证共同依赖）：
///
/// 能力门（manifest）→ 意图持久化（提交前保存）→ 24h/recover_only
/// 派发策略 → 合同请求（重放一律原键原载荷）→ 结果分类与意图生命周期：
/// - 受理成功（accepted/replayed）→ 清除意图；
/// - 一切失败（业务拒绝码、传输失败、502/504 等）→ 统一 unknownPending、
///   意图保留：HTTP 解析层不保留可证明的响应来源与终态，任何失败都可能
///   是代理伪造的终态文案，据此清除意图会违反 §6.4（不提供换键恢复）；
/// - 能力未启用 → 不发新键；已有未知意图绝不剥键走旧 POST。
library;

import 'package:imboy/config/env.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';

/// 创建受理失败分类（群/频道共用语义）。
enum CreationFlowFailure {
  /// manifest 未声明合同能力。意图不存在时可走旧键less路径；
  /// 已有未知意图时禁止旧路径（保留/核对，绝不剥键）。
  capabilityMissing,

  /// 一切失败结果（业务拒绝码、传输失败、502/504 等不可证明终态的
  /// 响应）。意图保留（§6.4：不提供换键恢复，不透传可伪造文案）。
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
  void Function()? guard,
  required Future<CreationReceiptResult> Function({
    required String requestId,
    required Map<String, dynamic> storedPayload,
    required bool recoverOnly,
  })
  dispatch,
}) {
  final endpoint = Env().apiBaseUrl;
  final key = creationIntentStorageKey(
    account,
    operation,
    scopeId,
    endpoint: endpoint,
  );
  return withCreationIntentLock(key, () async {
    guard?.call();
    final intent = await loadCreationIntent(
      account: account,
      operation: operation,
      scopeId: scopeId,
      endpoint: endpoint,
      guard: guard,
    );
    guard?.call();
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
        endpoint: endpoint,
        guard: guard,
        intent: CreationIntent(
          requestId: requestId,
          createdAtMs: nowMs,
          payload: storedPayload,
        ),
      );
    }

    guard?.call();
    final result = await dispatch(
      requestId: requestId,
      storedPayload: storedPayload,
      recoverOnly: dispatch_.recoverOnly,
    );
    guard?.call();

    if (result.ok) {
      final createdId = extractCreatedId(result.payload);
      if (result.requestId != requestId ||
          !const {'accepted', 'replayed'}.contains(result.creationState) ||
          createdId == null ||
          !RegExp(r'^[0-9]+$').hasMatch(createdId) ||
          (BigInt.tryParse(createdId) ?? BigInt.zero) <= BigInt.zero ||
          (BigInt.tryParse(createdId) ?? BigInt.zero) >
              BigInt.parse('9223372036854775807')) {
        return const CreationFlowOutcome(
          ok: false,
          failure: CreationFlowFailure.unknownPending,
        );
      }
      await clearCreationIntent(
        account: account,
        operation: operation,
        scopeId: scopeId,
        endpoint: endpoint,
        guard: guard,
        expectedRequestId: requestId,
      );
      return CreationFlowOutcome(
        ok: true,
        replayed: result.creationState == 'replayed',
        createdId: createdId,
        payload: result.payload,
      );
    }

    // HTTP 解析层未保留可证明的来源与状态，任何失败都可能是代理响应。
    // 不透传可能伪造的终态文案，保留原键和载荷供后续安全恢复。
    return const CreationFlowOutcome(
      ok: false,
      failure: CreationFlowFailure.unknownPending,
    );
  });
}
