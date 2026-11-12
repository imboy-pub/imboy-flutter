/// 多选消息接线（chat_multi_select_v1 / W2-E；W5-G1 G1-9 自 chat_page.dart
/// 抽离的多选接线块：动作策略 + 动作 handler + 对账 + action bar 面板）。
///
/// 抽离前散落在 ChatPageState 的成员 → 此处职责映射：
/// - `_bundleActionAllowed` / `_exportActionAllowed` 策略 getter →
///   [ChatMultiSelectPanel.build] 内基于**同一次**排序结果的局部策略
///   （G1-2：抽离前 build 内 `_multiSelectSortedMessages()` 三重计算）；
/// - `_forwardEachSelected` / `_forwardBundleSelected` / `_exportSelected`
///   → [ChatMultiSelectActions]（controller）；
/// - `_reconcileMultiSelection` → [ChatMultiSelectReconciler]
///   （G1-6：镜像 listen 之外增加 post-frame 对账）；
/// - `_multiSelectSortedMessages` → [sortMultiSelectMessages]（纯函数）；
/// - `_enterMultiSelect` 的 enter+反馈 → [enterMultiSelectWithFeedback]
///   （toggle 反馈本就在 chat_message_item 的
///   `toggleMessageSelectionWithFeedback`）；
/// - build 内 action bar 分支构造 → [ChatMultiSelectPanel]（panel widget）。
///
/// 退出多选（`_exitMultiSelect`）与长按菜单入口判定仍留在 chat_page
///（与返回键 canPop、消息事件路径强耦合）。
library;

import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/presentation/export/chat_export_flow.dart';
import 'package:imboy/page/chat/chat/bundle_forward_dispatcher.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart' show chatProvider;
import 'package:imboy/page/chat/chat/message_action_handler.dart';
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart';
import 'package:imboy/page/chat/send_to/batch_forward_coordinator.dart'
    show kBatchForwardMaxMessages;
import 'package:imboy/page/chat/widget/message_multi_select_action_bar.dart';

/// 多选已选消息排序（冻结合同 §4.3）：createdAt 旧→新，同时间按当前列表
/// 稳定序。selectedIds 只是插入序集合（不保序 createdAt），W1-B 批量转发
/// 依赖这里输出确定顺序。
///
/// G1-2：抽离前 `_multiSelectSortedMessages()` 在 build 内被
/// selectedMessages / 合并转发策略 / 导出策略三处各算一次；抽离后由
/// [ChatMultiSelectPanel.build] 计算**一次**并复用。
List<Message> sortMultiSelectMessages(
  MessageSelectionState selection,
  List<Message> messages,
) {
  final picked = <int, Message>{};
  for (var i = 0; i < messages.length; i++) {
    if (selection.contains(messages[i].id)) picked[i] = messages[i];
  }
  final entries = picked.entries.toList()
    ..sort((a, b) {
      final ca = a.value.createdAt?.millisecondsSinceEpoch ?? 0;
      final cb = b.value.createdAt?.millisecondsSinceEpoch ?? 0;
      if (ca != cb) return ca.compareTo(cb);
      // Dart List.sort 非稳定排序：同时间用原列表下标补稳定序。
      return a.key.compareTo(b.key);
    });
  return entries.map((e) => e.value).toList(growable: false);
}

/// 多选 action bar「逐条转发」按钮动作策略（W5-G1 G1-1）。
///
/// SendToPage.batch 的批量协调器以 [kBatchForwardMaxMessages]（50）为硬上
/// 限（batch_forward_coordinator.dart），超限在目标选择页内才失败 —— 这里
/// 与合并转发（bundleActionAllowedFor ≤ HistoryBundleContract.maxEntries）
/// 同口径在入口先行禁用：1..50 条才可用，0 条（未勾选）禁用。action bar
/// 对 null callback 的禁用处理与 bundle/export 一致（按钮灰显不可点）。
bool forwardEachActionAllowedFor(Iterable<MessageSelectionTraits> traits) {
  var count = 0;
  for (final _ in traits) {
    count++;
    if (count > kBatchForwardMaxMessages) return false;
  }
  return count > 0;
}

/// 多选动作控制器：承接原 ChatPageState 的逐条/合并转发与导出 handler。
class ChatMultiSelectActions {
  const ChatMultiSelectActions({
    required this.conversationUk3,
    required this.sourceChatType,
    required this.conversationTitle,
    required this.peerId,
    required this.messageActionHandlerResolver,
  });

  /// 多选状态归属会话（messageSelectionProvider family key）。
  final String conversationUk3;

  /// 源会话类型（C2C/C2G/C2S，bundle/export 的源口径）。
  final String sourceChatType;

  /// 会话标题（bundle 标题 / 导出文件名语境）。
  final String conversationTitle;

  /// 对端 ID（导出入口参数）。
  final String peerId;

  /// 宿主 [MessageActionHandler] 的延迟解析：宿主字段为 late final 且在
  /// 首帧后才初始化，构造期直接读取会抛 LateInitializationError —— 与
  /// 抽离前「回调触发时才访问 `_messageActionHandler`」的时序保持一致。
  final MessageActionHandler Function() messageActionHandlerResolver;

  /// 逐条转发（action bar → 批量 SendToPage / W2-F）。
  void forwardEach(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    messageActionHandlerResolver().forwardMessages(context, messages);
  }

  /// 合并转发（action bar → bundle 发送编排 / Central Wiring）。
  void forwardBundle(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    unawaited(
      BundleForwardDispatcher.forwardAsHistoryBundle(
        context,
        messages: messages,
        sourceChatType: sourceChatType,
        title: conversationTitle,
      ),
    );
  }

  /// 导出并系统分享（action bar → runChatExportFlow / W3-J）。
  void export(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    unawaited(
      runChatExportFlow(
        context,
        conversationUk3: conversationUk3,
        conversationTitle: conversationTitle,
        messages: messages,
        chatType: sourceChatType,
        toId: peerId,
      ),
    );
  }
}

/// 长按菜单「多选」→ 进入多选并选中被长按的消息（W1-A enter 契约；
/// 承接原 ChatPageState._enterMultiSelect）。
///
/// enter 被拒：不进入多选并按 reason 反馈。菜单入口只在可选时提供，
/// 实际可达的只有上限与状态并发变化两类。
String? enterMultiSelectWithFeedback(
  WidgetRef ref,
  String conversationUk3,
  Message message,
) {
  if (conversationUk3.isEmpty) return MessageSelectionReason.inactive;
  final reason = ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .enter(message.id, messageSelectionTraitsOf(message));
  if (reason == MessageSelectionReason.limitExceeded) {
    AppLoading.showToast(
      t.chat.multiSelectLimit(
        count: MessageSelectionNotifier.maxSelectionCount,
      ),
    );
  } else if (reason != null) {
    AppLoading.showToast(t.chat.multiSelectUnavailable);
  }
  return reason;
}

/// 多选选中集合对账器（承接原 `_reconcileMultiSelection`）。
///
/// 两条触发路径：
/// 1. `ChatState.messages` 镜像变化（收/发/删/翻页关键路径
///    syncMessagesToState）→ panel build 内 `ref.listen` 直调 [runIfActive]；
/// 2. **post-frame 对账（W5-G1 G1-6）**：remove/revoke 等路径直接改
///    `chatService.messages`，不回写 `ChatState.messages` 镜像，路径 1 不
///    触发 —— 多选激活期间每帧注册一次 [schedulePostFrame]，保证选区在
///    下一帧收敛。
///
/// 幂等与防循环：`MessageSelectionNotifier.reconcile` 自带脏检查（无失效
/// id 不写 state），无失效时下帧不再重建 → post-frame 注册自然收敛，不会
/// 形成 rebuild 循环。
class ChatMultiSelectReconciler {
  const ChatMultiSelectReconciler({
    required this.conversationUk3,
    required this.existingMessageIds,
  });

  /// 多选状态归属会话。
  final String conversationUk3;

  /// 当前会话仍存在的消息 ID（生产实现读 chatService.messages 实时镜像）。
  final Iterable<String> Function() existingMessageIds;

  /// 对账：移除已不存在的选中项（未激活/无失效时为 no-op）。
  void runIfActive(WidgetRef ref) {
    if (conversationUk3.isEmpty) return;
    if (!ref.read(messageSelectionProvider(conversationUk3)).active) return;
    ref
        .read(messageSelectionProvider(conversationUk3).notifier)
        .reconcile(existingMessageIds());
  }

  /// 注册 post-frame 对账（G1-6）：面板当帧被卸载（如退出多选）时跳过。
  void schedulePostFrame(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      runIfActive(ref);
    });
  }
}

/// 多选模式底部面板：包装 [MessageMultiSelectActionBar] 并完成全部接线
/// （ChatPage 多选分支的唯一 UI 入口，G1-9 自 chat_page build 抽离）。
///
/// 进入多选时 ChatInput 被本面板替换（卸载）。已知限制（W5-G1 G1-8，
/// PARTIAL）：ChatInput 的草稿保存是 300ms 防抖
/// （chat_input.dart `_handleTextControllerChange`），dispose 只取消
/// Timer 不 flush，且 ChatInputState / AccountDraftStore 均无公开的
/// 立即保存 API、文本也只在 ChatInput 私有 controller 中 —— 进入多选
/// 前最后 300ms 内的输入可能丢失。修复需在 chat_input.dart 增加 flush
/// API（不在本波次文件范围内），此处仅记录。
class ChatMultiSelectPanel extends ConsumerWidget {
  const ChatMultiSelectPanel({
    super.key,
    required this.conversationUk3,
    required this.actions,
    required this.onExit,
  });

  /// 多选状态归属会话（messageSelectionProvider family key）。
  final String conversationUk3;

  /// 多选动作控制器（转发/导出 handler）。
  final ChatMultiSelectActions actions;

  /// 退出多选（返回键 / ✕ 共用：exit 并清空）。
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 多选模式状态：conversationUk3 为空（防御路径，激活入口已挡）时
    // 视为初始 inactive 态 —— 与抽离前 chat_page 的 watch 守卫同口径。
    final MessageSelectionState selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.watch(messageSelectionProvider(conversationUk3));

    // 对账器：existingIds 读 chatService.messages（真实真相源，含不经
    // ChatState.messages 镜像的 remove/revoke 变更）。
    final reconciler = ChatMultiSelectReconciler(
      conversationUk3: conversationUk3,
      existingMessageIds: () =>
          ref
              .read(chatProvider.notifier)
              .chatService
              ?.messages
              .map((m) => m.id)
              .toList(growable: false) ??
          const <String>[],
    );

    // 路径 1：ChatState.messages 镜像变化（收/发/删/翻页）→ 对账。
    ref.listen(chatProvider.select((s) => s.messages), (previous, next) {
      reconciler.runIfActive(ref);
    });
    // 路径 2（G1-6）：post-frame 对账兜底 remove/revoke 等不回写镜像的
    // 路径 —— 仅多选激活（本面板挂载）期间注册，无脏变更时 no-op 收敛。
    reconciler.schedulePostFrame(context, ref);

    // G1-2：排序结果计算一次，三个动作策略与 selectedMessages 复用
    //（抽离前 build 内三重计算）。
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ??
        const <Message>[];
    final sorted = sortMultiSelectMessages(selection, messages);
    final traits = sorted.map(messageSelectionTraitsOf);

    // typed callbacks（Central Wiring §12）：按动作策略分别 enable/disable
    // （§12.5）——策略不允许时传 null → 按钮禁用占位；逐条转发 ≤50 条
    // （G1-1），合并转发/导出门槛不变。
    final forwardEachAllowed = forwardEachActionAllowedFor(traits);
    final forwardBundleAllowed = bundleActionAllowedFor(traits);
    final exportAllowed = exportActionAllowedFor(traits);

    return MessageMultiSelectActionBar(
      selectedMessages: sorted,
      onCancel: onExit,
      onClearSelection: conversationUk3.isEmpty
          ? null
          : () => ref
                .read(messageSelectionProvider(conversationUk3).notifier)
                .clear(),
      onForwardEach: forwardEachAllowed
          ? (list) => actions.forwardEach(context, list)
          : null,
      onForwardBundle: forwardBundleAllowed
          ? (list) => actions.forwardBundle(context, list)
          : null,
      onExport: exportAllowed ? (list) => actions.export(context, list) : null,
    );
  }
}
