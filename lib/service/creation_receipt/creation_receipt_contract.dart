/// W04.d（channel-group-ux-v2.2 §6.4 C1）：创建受理合同客户端侧纯策略。
///
/// 本文件只放无 I/O 的判定函数与常量，供群/频道两路创建入口与测试复用：
/// - manifest 合同能力门（J27.d/e 精度：仅 `create_request_id == 1` 整数
///   才启用；缺失 / `true` / `"1"` / `2` 一律视为未启用，绝不激进解释）；
/// - 24h 客户端派发窗口（J24.a）：进程内单调 elapsed 由调用方保证，这里
///   以持久 wall-clock 年龄判定；23:59:59.999 仍可原键创建，24h 精确边界
///   （含）后仅 recover_only 只查；时钟倒退视为不可信，只查不创建。
library;

/// 服务端稳定错误符号（error_code.hrl 5462-5465）。
const int creationErrRequestIdConflict = 5462;
const int creationErrNotAccepted = 5463;
const int creationErrRecoveryExpired = 5464;
const int creationErrResourceUnavailable = 5465;

/// 客户端可创建（可能首次受理/原键重放）的恢复窗口：24h。
/// 这是客户端派发截止，不是服务端受理有效期（服务端 7d 独立判定）。
const int creationRecoveryWindowMs = 24 * 60 * 60 * 1000;

/// 合同能力门：仅当 `contracts['create_request_id']` 恰为整数 1 才启用。
///
/// 缺失/未知版本不启新入口；已有未知意图只保留/核对，绝不剥离键走旧
/// POST（§6.4 App 启用列）。`is int` 排除 true/"1"/2/1.0 等一切非精确
/// 整数 1 的值（J27.d/e：绝不激进解释）。
bool createReceiptContractEnabled(Map<String, dynamic>? contracts) =>
    contracts != null &&
    contracts['create_request_id'] is int &&
    contracts['create_request_id'] == 1;

/// 派发判定结果。
class CreationDispatch {
  /// true=可发「可能创建」的原键请求（首受理或 <24h 重放）。
  final bool mayCreate;

  /// true=仅发 recover_only 只查（>=24h 或时钟不可信）。
  final bool recoverOnly;

  /// true=wall-clock 相对意图创建时间倒退，时间不可信（J24.a）。
  final bool clockUntrusted;

  const CreationDispatch({
    required this.mayCreate,
    required this.recoverOnly,
    this.clockUntrusted = false,
  });
}

/// 无意图 → 可创建（首次受理）。
/// 意图年龄 < 24h → 原键重放仍可创建（含响应丢失场景）。
/// 意图年龄 >= 24h（精确边界含）→ 仅 recover_only，不剥键、不换键。
/// now 早于意图创建时间（时钟倒退/不可信）→ 仅 recover_only。
CreationDispatch decideCreationDispatch({
  required int? intentCreatedAtMs,
  required int nowMs,
}) {
  if (intentCreatedAtMs == null) {
    return const CreationDispatch(mayCreate: true, recoverOnly: false);
  }
  if (nowMs < intentCreatedAtMs) {
    return const CreationDispatch(
      mayCreate: false,
      recoverOnly: true,
      clockUntrusted: true,
    );
  }
  final age = nowMs - intentCreatedAtMs;
  if (age < creationRecoveryWindowMs) {
    return const CreationDispatch(mayCreate: true, recoverOnly: false);
  }
  return const CreationDispatch(mayCreate: false, recoverOnly: true);
}

/// 服务端 envelope 数值码 → 稳定错误符号；非合同码返回 null。
String? creationErrorSymbol(int code) {
  switch (code) {
    case creationErrRequestIdConflict:
      return 'request_id_conflict';
    case creationErrNotAccepted:
      return 'create_not_accepted';
    case creationErrRecoveryExpired:
      return 'create_recovery_expired';
    case creationErrResourceUnavailable:
      return 'create_resource_unavailable';
    default:
      return null;
  }
}

/// 受理合同请求结果（群/频道两路通用）。
class CreationReceiptResult {
  final bool ok;

  /// accepted | replayed（成功时服务端回显）。
  final String? creationState;

  /// 服务端回显的意图键。
  final String? requestId;

  /// 合同稳定符号（仅 5462-5465；其余失败为 null）。
  final String? errorSymbol;

  /// 服务端/网络文案（透传展示用）。
  final String? errorText;

  /// 过期/不可用时的核对资源 ID（payload.gid / payload.channel_id）。
  final String? resourceId;

  /// true=已完成 HTTP 交换且信封明确拒绝（服务器无受理记录，事务回滚）；
  /// false=传输层失败/未知（结果未知，调用方必须保留意图）。
  final bool envelopeRejection;

  /// 成功时的完整响应 payload（群：group/member_list + 增量字段；
  /// 频道：频道对象 + 增量字段），供调用方本地落库。
  final Map<String, dynamic> payload;

  const CreationReceiptResult({
    required this.ok,
    this.creationState,
    this.requestId,
    this.errorSymbol,
    this.errorText,
    this.resourceId,
    this.envelopeRejection = false,
    this.payload = const {},
  });
}

/// 从信封字段解析受理结果（纯函数；群/频道 API 层各自传入资源 ID 提取器）。
///
/// 成功：creation_state/request_id 为增量字段，缺失（旧后端）不致命。
/// 失败：code ∈ 5462-5465 → 稳定符号 + payload 内核对 ID；
/// 其余信封错误 → envelopeRejection=true、无符号；
/// 调用方对传输层失败（HTTP 异常路径）直接构造
/// `CreationReceiptResult(ok: false, errorText: ...)`（envelopeRejection
/// 缺省 false = 结果未知）。
CreationReceiptResult parseCreationReceiptResponse({
  required bool ok,
  required int code,
  required String msg,
  required dynamic payload,
  required String? Function(Map<String, dynamic> payload) extractResourceId,
}) {
  if (ok) {
    final map = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    return CreationReceiptResult(
      ok: true,
      creationState: map['creation_state']?.toString(),
      requestId: map['request_id']?.toString(),
      payload: map,
    );
  }
  final symbol = creationErrorSymbol(code);
  final map = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
  return CreationReceiptResult(
    ok: false,
    errorSymbol: symbol,
    errorText: msg,
    resourceId: symbol == null ? null : extractResourceId(map),
    envelopeRejection: true,
  );
}
