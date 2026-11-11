/// 批量逐条转发协调器（chat_multi_select_v1 / W1-B）。
///
/// 纯协调器：只负责排序、上限、串行调度、取消、精确重试与进度上报；
/// **不包含任何发送实现**——单条转发统一通过构造注入的 [forwardOne]
/// 回调完成（W2-F 会用 `SendToNotifier.sendMsg` 适配它），本模块
/// 不得 import send_to_provider / 附件 / E2EE 相关代码。
///
/// 冻结语义（PLAN chat-multi-20261111 §4.2/§4.3）：
/// - 源消息按 `createdAt` 从旧到新，相同时间按传入列表稳定顺序；
/// - 结果单元粒度 = `targetConversationUk3 × sourceMessageId`；
/// - 同一目标会话严格串行，v1 目标会话之间也串行（目标外层循环 ×
///   消息内层循环的全串行）；
/// - 成功单元不回滚、不重复发送；重试只包含失败单元；
/// - 取消/页面销毁后停止排入新单元。
library;

import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

/// 批量转发上限（PLAN §4.2：逐条转发消息 50 条 / 目标 9 个）。
const int kBatchForwardMaxMessages = 50;
const int kBatchForwardMaxTargets = 9;

/// 单元 key 分隔符（uk3 与 Xid 都不会包含 NUL，天然无歧义）。
const String _kUnitKeySeparator = '\u0000';

/// 稳定错误码（UI/i18n/日志只认码，不认文案）。
abstract final class BatchForwardErrorCode {
  /// 消息数为空。
  static const String emptyMessages = 'batch_empty_messages';

  /// 目标会话数为空。
  static const String emptyTargets = 'batch_empty_targets';

  /// 消息数超过 50（打开目标页前拒绝）。
  static const String limitMessages = 'batch_limit_messages';

  /// 目标会话数超过 9。
  static const String limitTargets = 'batch_limit_targets';

  /// 目标列表存在重复 uk3（会 double-send，防御性拒绝）。
  static const String duplicateTargets = 'batch_duplicate_targets';

  /// 消息列表存在重复 id（会 double-send，防御性拒绝）。
  static const String duplicateMessages = 'batch_duplicate_messages';

  /// 上一个 run 尚未结束就再次启动。
  static const String alreadyRunning = 'batch_already_running';

  /// retryFailed 传入的 targets/messages 无法覆盖 report 的失败单元。
  static const String retryUnitsMismatch = 'batch_retry_units_mismatch';

  /// 协调器已 dispose（页面销毁/会话切换）。
  static const String coordinatorDisposed = 'coordinator_disposed';

  /// 单元转发失败（forwardOne 返回 false 或抛 Exception）。
  static const String forwardFailed = 'forward_failed';

  /// 执行中因 cancel() 中止的单元。
  static const String forwardCancelled = 'forward_cancelled';

  /// 因 cancel() 未被排入执行的单元。
  static const String batchCancelled = 'batch_cancelled';
}

/// 携带稳定错误码的批量转发异常（run/retryFailed 入口校验失败时抛出，
/// 由调用方在 UI 层拦截并映射文案）。
class BatchForwardException implements Exception {
  final String code;

  const BatchForwardException(this.code);

  @override
  String toString() => 'BatchForwardException($code)';
}

/// 单个转发单元的结果状态。
enum ForwardUnitStatus { success, failed, cancelled, skipped }

/// 单个转发单元（目标会话 × 源消息）的执行结果。
class ForwardItemResult {
  /// 目标会话唯一键（ConversationModel.uk3）。
  final String targetConversationUk3;

  /// 源消息 ID（MessageModel.id，Xid 字符串）。
  final String sourceMessageId;

  final ForwardUnitStatus status;

  /// 稳定错误码；success 时为空串。
  final String errorCode;

  /// 本单元 forwardOne 的累计尝试次数；从未排入执行（skipped）为 0。
  final int attempt;

  const ForwardItemResult({
    required this.targetConversationUk3,
    required this.sourceMessageId,
    required this.status,
    this.errorCode = '',
    this.attempt = 0,
  });

  /// 与 report.retryableUnitKeys 同一编码的单元 key。
  String get key => unitKey(targetConversationUk3, sourceMessageId);

  bool get isSuccess => status == ForwardUnitStatus.success;
}

/// 一次 run / retryFailed 的整体报告。
///
/// retryFailed 产出的 report 只覆盖被重试的失败单元（冻结合同：
/// 「重试请求只包含失败单元」）；成功单元零重复发送，也不出现在
/// 重试报告里。UI 汇总「整批 X/N」时由调用方自行合并两份报告。
class BatchForwardReport {
  /// 本次执行产生的单元结果，按实际执行顺序排列。
  final List<ForwardItemResult> results;

  /// 开始时间。
  final DateTime startedAt;

  /// 结束时间。
  final DateTime finishedAt;

  /// 本次执行是否因 cancel() 提前终止（dispose 中止不算，由单元
  /// errorCode = coordinator_disposed 表达）。
  final bool cancelled;

  /// 可重试单元 key 集合（仅 failed 单元；cancelled/skipped 不可重试）。
  final Set<String> retryableUnitKeys;

  BatchForwardReport({
    required List<ForwardItemResult> results,
    required this.startedAt,
    required this.finishedAt,
    this.cancelled = false,
  }) : results = List.unmodifiable(results),
       retryableUnitKeys = {
         for (final r in results)
           if (r.status == ForwardUnitStatus.failed) r.key,
       };

  int get totalCount => results.length;
  int get successCount => count(ForwardUnitStatus.success);
  int get failedCount => count(ForwardUnitStatus.failed);
  int get cancelledCount => count(ForwardUnitStatus.cancelled);
  int get skippedCount => count(ForwardUnitStatus.skipped);

  bool get allSucceeded =>
      results.isNotEmpty && failedCount == 0 && cancelledCount == 0;

  int count(ForwardUnitStatus status) =>
      results.where((r) => r.status == status).length;
}

/// 单元 key 编码（uk3 × sourceMessageId）。
String unitKey(String targetConversationUk3, String sourceMessageId) =>
    '$targetConversationUk3$_kUnitKeySeparator$sourceMessageId';

/// 批量入口纯校验：合法返回 null，否则返回稳定错误码
/// （调用方在打开目标页前拦截）。
String? validateBatch(
  List<ConversationModel> targets,
  List<MessageModel> messages,
) {
  if (messages.isEmpty) return BatchForwardErrorCode.emptyMessages;
  if (targets.isEmpty) return BatchForwardErrorCode.emptyTargets;
  if (messages.length > kBatchForwardMaxMessages) {
    return BatchForwardErrorCode.limitMessages;
  }
  if (targets.length > kBatchForwardMaxTargets) {
    return BatchForwardErrorCode.limitTargets;
  }
  if (_hasDuplicate(targets.map((t) => t.uk3))) {
    return BatchForwardErrorCode.duplicateTargets;
  }
  if (_hasDuplicate(messages.map((m) => m.id))) {
    return BatchForwardErrorCode.duplicateMessages;
  }
  return null;
}

bool _hasDuplicate(Iterable<String> values) =>
    values.length != values.toSet().length;

/// 可注入的单条转发回调：向 [target] 转发 [message]。
///
/// [isCurrent] 为本次排入时页面/会话是否仍然有效；真实适配方
/// （W2-F → sendMsg）应转成 `() => isCurrent` 的闭包语义。
/// 返回 true 表示已成功入队发送；false / Exception 表示本单元失败。
typedef ForwardOneFn = Future<bool> Function(
  ConversationModel target,
  MessageModel message,
  bool isCurrent,
);

/// 进度回调：每记录一个单元（含 skipped）触发一次。
typedef BatchForwardProgressFn = void Function(
  int completed,
  int total,
  ForwardItemResult lastResult,
);

/// 批量逐条转发协调器。
///
/// 生命周期：一个协调器实例服务一次批量转发会话（一个 SendToPage）；
/// `dispose()` 后不可再 run/retryFailed，进行中的执行停止排入新单元。
class BatchForwardCoordinator {
  final ForwardOneFn forwardOne;
  final BatchForwardProgressFn? onProgress;

  bool _cancelRequested = false;
  bool _disposed = false;
  bool _running = false;

  BatchForwardCoordinator({required this.forwardOne, this.onProgress});

  /// 是否有执行正在进行。
  bool get isRunning => _running;

  /// 请求取消：后续单元不再排入；已成功单元不回滚不重发；
  /// 未开始单元标记 skipped；执行中被中止的单元标记 cancelled。
  /// 只影响当前（或下一个立即开始的）执行，可被新 run 重置。
  void cancel() => _cancelRequested = true;

  /// 页面销毁/会话切换防护：终态，之后停止排入新单元，
  /// 再启动 run/retryFailed 会抛 coordinator_disposed。
  /// 只置 disposed 位：中止语义由单元 errorCode 表达，
  /// 不污染 report.cancelled（那是 cancel() 专属标志）。
  void dispose() => _disposed = true;

  /// 执行整批转发：目标外层（传入顺序）× 消息内层（createdAt 升序），
  /// 全串行。入口校验失败抛 [BatchForwardException]（稳定码）。
  Future<BatchForwardReport> run(
    List<ConversationModel> targets,
    List<MessageModel> messages,
  ) => _execute(
    targets,
    messages,
    retryFilter: null,
    previousAttempts: const {},
  );

  /// 仅重跑 [report] 中 failed 的单元（保持原排序规则），
  /// 返回只覆盖重试单元的新报告；成功单元零重复发送。
  Future<BatchForwardReport> retryFailed(
    BatchForwardReport report, {
    required List<ConversationModel> targets,
    required List<MessageModel> messages,
  }) async {
    if (report.retryableUnitKeys.isEmpty) {
      final now = DateTime.now();
      return BatchForwardReport(
        results: const [],
        startedAt: now,
        finishedAt: now,
      );
    }
    final previousAttempts = <String, int>{
      for (final r in report.results)
        if (r.status == ForwardUnitStatus.failed) r.key: r.attempt,
    };
    return _execute(
      targets,
      messages,
      retryFilter: report.retryableUnitKeys,
      previousAttempts: previousAttempts,
    );
  }

  Future<BatchForwardReport> _execute(
    List<ConversationModel> targets,
    List<MessageModel> messages, {
    required Set<String>? retryFilter,
    required Map<String, int> previousAttempts,
  }) async {
    _ensureNotDisposed();
    _ensureNotRunning();
    final errorCode = validateBatch(targets, messages);
    if (errorCode != null) throw BatchForwardException(errorCode);

    final planned = _planUnits(
      targets,
      messages,
      retryFilter,
      previousAttempts,
    );
    if (retryFilter != null) {
      final plannedKeys = planned.map((u) => u.key).toSet();
      if (plannedKeys.length != retryFilter.length ||
          !plannedKeys.containsAll(retryFilter)) {
        throw const BatchForwardException(
          BatchForwardErrorCode.retryUnitsMismatch,
        );
      }
    }

    // 新执行开始：清掉上一次遗留的 cancel 请求。
    _cancelRequested = false;
    _running = true;
    final startedAt = DateTime.now();
    final results = <ForwardItemResult>[];
    try {
      for (final unit in planned) {
        final result = await _runUnit(unit);
        results.add(result);
        onProgress?.call(results.length, planned.length, result);
      }
      return BatchForwardReport(
        results: results,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        cancelled: _cancelRequested,
      );
    } finally {
      _running = false;
    }
  }

  /// 执行（或跳过）单个单元。排入前检查 cancel/dispose；
  /// forwardOne 抛出的 Exception 按单元失败隔离，不中断整批。
  Future<ForwardItemResult> _runUnit(_PlannedUnit unit) async {
    if (_disposed) {
      return _skipped(unit, BatchForwardErrorCode.coordinatorDisposed);
    }
    if (_cancelRequested) {
      return _skipped(unit, BatchForwardErrorCode.batchCancelled);
    }

    final isCurrent = !_cancelRequested && !_disposed;
    try {
      final sent = await forwardOne(unit.target, unit.message, isCurrent);
      if (sent) return _done(unit, ForwardUnitStatus.success, '');
      if (_disposed) {
        return _done(
          unit,
          ForwardUnitStatus.cancelled,
          BatchForwardErrorCode.coordinatorDisposed,
        );
      }
      if (_cancelRequested) {
        return _done(
          unit,
          ForwardUnitStatus.cancelled,
          BatchForwardErrorCode.forwardCancelled,
        );
      }
      return _done(
        unit,
        ForwardUnitStatus.failed,
        BatchForwardErrorCode.forwardFailed,
      );
    } on Exception {
      // 单元级异常隔离：本单元按 failed 记录，继续后续单元。
      if (_disposed) {
        return _done(
          unit,
          ForwardUnitStatus.cancelled,
          BatchForwardErrorCode.coordinatorDisposed,
        );
      }
      if (_cancelRequested) {
        return _done(
          unit,
          ForwardUnitStatus.cancelled,
          BatchForwardErrorCode.forwardCancelled,
        );
      }
      return _done(
        unit,
        ForwardUnitStatus.failed,
        BatchForwardErrorCode.forwardFailed,
      );
    }
  }

  ForwardItemResult _skipped(_PlannedUnit unit, String errorCode) =>
      ForwardItemResult(
        targetConversationUk3: unit.uk3,
        sourceMessageId: unit.message.id,
        status: ForwardUnitStatus.skipped,
        errorCode: errorCode,
        attempt: 0,
      );

  ForwardItemResult _done(
    _PlannedUnit unit,
    ForwardUnitStatus status,
    String errorCode,
  ) => ForwardItemResult(
    targetConversationUk3: unit.uk3,
    sourceMessageId: unit.message.id,
    status: status,
    errorCode: errorCode,
    attempt: unit.baseAttempt + 1,
  );

  /// 展开执行计划：目标外层（传入顺序）× 消息内层
  /// （createdAt 从旧到新，相同 createdAt 按传入列表稳定顺序）。
  List<_PlannedUnit> _planUnits(
    List<ConversationModel> targets,
    List<MessageModel> messages,
    Set<String>? retryFilter,
    Map<String, int> previousAttempts,
  ) {
    final sorted = _sortByCreatedAtStable(messages);
    final planned = <_PlannedUnit>[];
    for (final target in targets) {
      final uk3 = target.uk3;
      for (final message in sorted) {
        final key = unitKey(uk3, message.id);
        if (retryFilter != null && !retryFilter.contains(key)) continue;
        planned.add(
          _PlannedUnit(
            target: target,
            message: message,
            uk3: uk3,
            key: key,
            baseAttempt: previousAttempts[key] ?? 0,
          ),
        );
      }
    }
    return planned;
  }

  /// createdAt 升序；并列时按传入索引稳定排序
  /// （Dart List.sort 非稳定排序，显式带索引才能确定序）。
  List<MessageModel> _sortByCreatedAtStable(List<MessageModel> messages) {
    final order = List<int>.generate(messages.length, (i) => i);
    order.sort((a, b) {
      final cmp = messages[a].createdAt.compareTo(messages[b].createdAt);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    return [for (final i in order) messages[i]];
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const BatchForwardException(
        BatchForwardErrorCode.coordinatorDisposed,
      );
    }
  }

  void _ensureNotRunning() {
    if (_running) {
      throw const BatchForwardException(BatchForwardErrorCode.alreadyRunning);
    }
  }
}

class _PlannedUnit {
  final ConversationModel target;
  final MessageModel message;
  final String uk3;
  final String key;

  /// 之前累计的尝试次数（首次执行为 0，重试为 report 中的 attempt）。
  final int baseAttempt;

  const _PlannedUnit({
    required this.target,
    required this.message,
    required this.uk3,
    required this.key,
    required this.baseAttempt,
  });
}
