import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'batch_forward_coordinator.dart';
import 'send_to_provider.dart';

import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

/// 发送给 页面
///
/// 两种请求形态（chat_multi_select_v1 / W2-F）：
/// - 单条（默认构造 `SendToPage(msg: ...)`，含 `onConfirmedSend` 注入）：
///   既有行为零变化；
/// - 批量逐条转发（`SendToPage.batch(messages: ...)`）：复用同一联系人
///   多选 UI，目标上限 [kBatchForwardMaxTargets]（第 10 个拒绝选择）；
///   确认后交给 [BatchForwardCoordinator] 全串行调度，提供进度、
///   成功/失败汇总与「仅重试失败」。
class SendToPage extends ConsumerStatefulWidget {
  /// 单条模式的源消息；批量模式为 null。
  final Message? msg;

  /// 批量模式（W2-F）的源消息列表；单条模式为 null。
  final List<Message>? batchMessages;

  final Future<bool> Function(List<ConversationModel>)? onConfirmedSend;

  const SendToPage({super.key, required Message this.msg, this.onConfirmedSend})
    : batchMessages = null;

  /// 批量逐条转发构造（chat_multi_select_v1 / W2-F）。
  const SendToPage.batch({super.key, required List<Message> messages})
    : msg = null,
      batchMessages = messages,
      onConfirmedSend = null;

  /// 是否批量逐条转发模式。
  bool get isBatch => batchMessages != null;

  @override
  ConsumerState<SendToPage> createState() => _SendToPageState();
}

class _SendToPageState extends ConsumerState<SendToPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _confirming = false;

  // ---- 批量逐条转发状态（chat_multi_select_v1 / W2-F）----
  BatchForwardCoordinator? _coordinator;
  BatchForwardReport? _lastReport;
  List<ConversationModel> _lastTargets = const [];
  List<MessageModel> _lastModels = const [];
  bool _batchRunning = false;
  int _completed = 0;
  int _total = 0;

  /// 单元 key → 最近一次结果。首次 run 整体填充；「仅重试失败」只覆盖
  /// 被重试的单元，成功单元保持首次结果，汇总即整批口径。
  Map<String, ForwardItemResult> _mergedResults = const {};

  int _mergedCount(ForwardUnitStatus status) =>
      _mergedResults.values.where((r) => r.status == status).length;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (widget.onConfirmedSend != null || widget.isBatch) {
        ref.read(sendToProvider.notifier).clearSelection();
      }
      await ref.read(sendToProvider.notifier).conversationsList();
    });
  }

  @override
  void dispose() {
    // 页面销毁即停止排入新单元（冻结合同 §4.3）；已入队的不回滚。
    _coordinator?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // 底色走 Scaffold 而不是包一层 Container：Container 的 ColoredBox 会挡在
      // Scaffold 的 Material 和下面的 ListTile 之间，点击水波纹画不出来，
      // 且 Flutter 会持续刷 "ink was not painted" 错误（批次27 真机实测）。
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        titleWidget: Text(
          t.chat.forwardTo,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize:
                textTheme.titleMedium?.fontSize ?? FontSizeType.medium.size,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: () => context.pop(),
          child: Icon(
            semanticLabel: '返回',
            CupertinoIcons.back,
            color: colorScheme.primary,
            size: 22,
          ),
        ),
        rightDMActions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // 批量执行中：按钮变「取消」（停排新单元，已成功不回滚）；
            // 批量已执行完：禁用，防止整批重复发送（重试只走「仅重试失败」）。
            onPressed: _batchRunning
                ? _onCancelBatch
                : (widget.isBatch && _mergedResults.isNotEmpty)
                ? null
                : _send,
            child: Text(
              _batchRunning ? t.common.cancel : t.common.buttonSend,
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: FontWeight.w600,
                color: _batchRunning
                    ? colorScheme.primary
                    : AppColors.getIosBlue(Theme.of(context).brightness),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: CupertinoTextField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _searchController,
              placeholder: t.common.search,
              prefix: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.search,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize:
                    textTheme.bodyMedium?.fontSize ?? FontSizeType.normal.size,
              ),
              onChanged: (query) {
                ref.read(sendToProvider.notifier).search(query);
              },
            ),
          ),
          // 批量模式：进度 / 完成汇总卡（含「仅重试失败」入口）
          if (widget.isBatch && (_batchRunning || _mergedResults.isNotEmpty))
            _batchStatusCard(theme),
          // 联系人列表
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(sendToProvider);
                final searchResults = state.searchResults;
                final selectedContacts = state.selectedContacts;

                if (searchResults.isEmpty) {
                  return Center(
                    child: Text(
                      t.common.noContacts,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize:
                            textTheme.bodyMedium?.fontSize ??
                            FontSizeType.normal.size,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final contact = searchResults[index];
                    final isSelected = selectedContacts.any(
                      (element) => element.id == contact.id,
                    );
                    return GestureDetector(
                      onTap: () {
                        if (_rejectBatchTargetSelection(
                          contact,
                          selectedContacts,
                        )) {
                          return;
                        }
                        ref
                            .read(sendToProvider.notifier)
                            .toggleContactSelection(contact);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image(
                                image: avatarImageProvider(contact.avatar),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 48,
                                  height: 48,
                                  color: colorScheme.primaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.displayTitle,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize:
                                          textTheme.titleMedium?.fontSize ??
                                          FontSizeType.medium.size,
                                    ),
                                  ),
                                  if (contact.subtitle.isNotEmpty)
                                    Text(
                                      contact.subtitle,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize:
                                            textTheme.bodySmall?.fontSize ??
                                            FontSizeType.small.size,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? CupertinoIcons.checkmark_circle
                                  : CupertinoIcons.circle,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 发送消息
  Future<void> _send() async {
    if (widget.isBatch) {
      await _sendBatch();
      return;
    }
    if (_confirming) return;
    final selectedContacts = ref.read(sendToProvider).selectedContacts;
    if (selectedContacts.isEmpty) {
      context.pop();
      return;
    }

    if (widget.onConfirmedSend case final send?) {
      _confirming = true;
      try {
        final sent = await send(List.of(selectedContacts));
        if (mounted) context.pop(sent);
      } finally {
        _confirming = false;
      }
      return;
    }
    final notifier = ref.read(sendToProvider.notifier);
    final failCount = await notifier.sendToSelected(widget.msg!);
    if (!mounted) return;

    if (failCount > 0) {
      // 存在转发失败，留在当前页提示用户，避免静默丢消息
      final failedMsg = failCount == selectedContacts.length
          ? t.common.sendFailed
          : '${t.common.sendFailed} ($failCount/${selectedContacts.length})';
      AppLoading.showError(failedMsg);
      return;
    }

    AppLoading.showSuccess(
      t.chat.forwardedToChats(count: selectedContacts.length),
    );
    context.pop();
  }

  // ============ 批量逐条转发（chat_multi_select_v1 / W2-F）============

  /// 目标上限兜底（冻结合同 §4.2：第 10 个拒绝选择并提示）。
  /// 返回 true 表示本次点击被拒绝（不改选择状态）。
  ///
  /// 适用范围（S1-L3）：批量逐条转发（isBatch）与合并转发
  /// （onConfirmedSend 注入，bundle 每目标独立构建+附件逐目标重传，
  /// 无上限会资源放大）共用同一 9 目标闸；普通单条转发
  /// （无 onConfirmedSend 的 msg 构造）保持既有不限量行为。
  bool _rejectBatchTargetSelection(
    ConversationModel contact,
    List<ConversationModel> selectedContacts,
  ) {
    if (!widget.isBatch && widget.onConfirmedSend == null) return false;
    final already = selectedContacts.any((e) => e.id == contact.id);
    if (already || selectedContacts.length < kBatchForwardMaxTargets) {
      return false;
    }
    AppLoading.showToast(
      t.chat.batchForwardTargetLimit(max: kBatchForwardMaxTargets),
    );
    return true;
  }

  BatchForwardCoordinator _buildCoordinator(
    SendToNotifier notifier,
    Map<String, Message> messagesById,
  ) => BatchForwardCoordinator(
    forwardOne: (target, message, isCurrent) => notifier.forwardOneForBatch(
      target,
      message,
      isCurrent,
      messagesById: messagesById,
    ),
    onProgress: (completed, total, _) {
      if (!mounted) return;
      setState(() {
        _completed = completed;
        _total = total;
      });
    },
  );

  /// 确认按钮（批量模式）：兜底校验后整批交给协调器（目标外层 × 消息
  /// 旧→新内层，全串行）。50 条 / 9 目标超限在打开本页前已由调用方拦
  /// 截，此处按同一合同再兜底一次。
  Future<void> _sendBatch() async {
    if (_batchRunning) return;
    final messages = widget.batchMessages;
    if (messages == null) return;
    final selectedContacts = ref.read(sendToProvider).selectedContacts;
    if (selectedContacts.isEmpty) {
      context.pop();
      return;
    }
    final targets = List<ConversationModel>.from(selectedContacts);
    final models = SendToNotifier.toCoordinatorMessageModels(messages);
    final errorCode = validateBatch(targets, models);
    if (errorCode != null) {
      AppLoading.showError(_batchErrorCodeText(errorCode));
      return;
    }
    final coordinator = _buildCoordinator(ref.read(sendToProvider.notifier), {
      for (final m in messages) m.id: m,
    });
    _coordinator = coordinator;
    setState(() {
      _batchRunning = true;
      _completed = 0;
      _total = targets.length * models.length;
    });
    final report = await _runBatchSafely(
      () => coordinator.run(targets, models),
    );
    if (report == null || !mounted) return;
    _applyBatchReport(report, targets: targets, models: models);
  }

  /// 「仅重试失败」：只重跑上次报告中 failed 的单元（冻结合同 §4.3），
  /// 成功单元零重复发送；重试结果按单元 key 覆盖合并。
  Future<void> _retryFailedBatch() async {
    final coordinator = _coordinator;
    final lastReport = _lastReport;
    if (_batchRunning || coordinator == null || lastReport == null) return;
    if (lastReport.retryableUnitKeys.isEmpty) return;
    setState(() {
      _batchRunning = true;
      _completed = 0;
      _total = lastReport.retryableUnitKeys.length;
    });
    final report = await _runBatchSafely(
      () => coordinator.retryFailed(
        lastReport,
        targets: _lastTargets,
        messages: _lastModels,
      ),
    );
    if (report == null || !mounted) return;
    _applyBatchReport(report, targets: _lastTargets, models: _lastModels);
  }

  Future<BatchForwardReport?> _runBatchSafely(
    Future<BatchForwardReport> Function() body,
  ) async {
    try {
      return await body();
    } on BatchForwardException catch (e) {
      // W5 G4-4：BatchForwardException 之外的 Error（如 send 路径透传的
      // StateError，协调器只捕 Exception）也会走到 on Object 兜底；
      // 无论哪个分支，finally 统一复位 _batchRunning，否则按钮永久卡在
      // 「取消」态。
      if (mounted) {
        AppLoading.showError(_batchErrorCodeText(e.code));
      }
      return null;
    } on Object catch (e) {
      // 未知错误兜底（含 Error 族）：按既有通用发送失败文案呈现；
      // 只记类型不输出异常对象（Finding 014 口径）。
      debugPrint(
        '[send_to_page] batch forward crashed, errType=${e.runtimeType}',
      );
      if (mounted) {
        AppLoading.showError(t.common.sendFailed);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _batchRunning = false);
      }
    }
  }

  void _applyBatchReport(
    BatchForwardReport report, {
    required List<ConversationModel> targets,
    required List<MessageModel> models,
  }) {
    setState(() {
      _batchRunning = false;
      _lastReport = report;
      _lastTargets = targets;
      _lastModels = models;
      _mergedResults = {
        ..._mergedResults,
        for (final r in report.results) r.key: r,
      };
    });
    _notifyBatchSummary();
  }

  /// 完成汇总：全部成功 → 复用既有 `forwardedToChats` 文案并关页；
  /// 存在失败/未完成 → 留页展示汇总卡（失败可「仅重试失败」）。
  void _notifyBatchSummary() {
    if (_mergedResults.isEmpty) return;
    final success = _mergedCount(ForwardUnitStatus.success);
    final failed = _mergedCount(ForwardUnitStatus.failed);
    final unfinished = _mergedResults.length - success - failed;
    if (failed == 0 && unfinished == 0) {
      AppLoading.showSuccess(
        t.chat.forwardedToChats(count: _lastTargets.length),
      );
      context.pop();
      return;
    }
    AppLoading.showToast(
      t.chat.batchForwardDone(success: success, failed: failed),
    );
  }

  /// 批量执行中的「取消」：停止排入新单元；已成功单元不回滚不重发。
  void _onCancelBatch() => _coordinator?.cancel();

  String _batchErrorCodeText(String code) {
    switch (code) {
      case BatchForwardErrorCode.limitMessages:
        return t.chat.batchForwardLimitMessages(max: kBatchForwardMaxMessages);
      case BatchForwardErrorCode.limitTargets:
        return t.chat.batchForwardTargetLimit(max: kBatchForwardMaxTargets);
      default:
        return t.common.sendFailed;
    }
  }

  /// 进度 / 完成汇总卡。
  Widget _batchStatusCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    if (_batchRunning) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        padding: AppSpacing.allSmall,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.small),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.chat.batchForwardProgress(completed: _completed, total: _total),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize:
                    theme.textTheme.bodyMedium?.fontSize ??
                    FontSizeType.normal.size,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            LinearProgressIndicator(
              value: _total > 0 ? _completed / _total : null,
              minHeight: 4,
            ),
          ],
        ),
      );
    }
    final failed = _mergedCount(ForwardUnitStatus.failed);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      padding: AppSpacing.allSmall,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.small),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.chat.batchForwardDone(
                success: _mergedCount(ForwardUnitStatus.success),
                failed: failed,
              ),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize:
                    theme.textTheme.bodyMedium?.fontSize ??
                    FontSizeType.normal.size,
              ),
            ),
          ),
          if (failed > 0)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
              onPressed: _retryFailedBatch,
              child: Text(
                t.chat.batchForwardRetryFailed,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getIosBlue(theme.brightness),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
