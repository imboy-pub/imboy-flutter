part of 'web_chat_input.dart';

/// 多选灰度开关（rollout flag，默认关闭 → 零 UI 变化）。
bool webMultiSelectEnabled() =>
    AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatMultiSelectV1);

/// 多选激活态（panel/watch 共用；空 key 恒 false）。
bool webMultiSelectActiveOf(WidgetRef ref, String conversationUk3) =>
    conversationUk3.isEmpty
    ? false
    : ref.watch(messageSelectionProvider(conversationUk3)).active;

/// 长按菜单「多选」→ 进入并选中首条（接 enterMultiSelectWithFeedback 契约）。
String? webEnterMultiSelect(
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

/// 勾选切换（取消已选恒成功；第 101 条 toast 上限）。
String? webToggleMessageSelection(
  WidgetRef ref,
  String conversationUk3,
  Message message,
) {
  if (conversationUk3.isEmpty) return MessageSelectionReason.inactive;
  final reason = ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .toggle(message.id, messageSelectionTraitsOf(message));
  if (reason == MessageSelectionReason.limitExceeded) {
    AppLoading.showToast(
      t.chat.multiSelectLimit(
        count: MessageSelectionNotifier.maxSelectionCount,
      ),
    );
  }
  return reason;
}

/// 退出多选并清空。
void webExitMultiSelect(WidgetRef ref, String conversationUk3) {
  if (conversationUk3.isEmpty) return;
  ref.read(messageSelectionProvider(conversationUk3).notifier).exit();
}

/// 选中集合对账（镜像路径 + post-frame 兜底，复用 reconcile 脏检查）。
void webReconcileMultiSelection(WidgetRef ref, String conversationUk3) {
  if (conversationUk3.isEmpty) return;
  final selection = ref.read(messageSelectionProvider(conversationUk3));
  if (!selection.active) return;
  final liveIds = ref
      .read(chatProvider.notifier)
      .chatService
      ?.messages
      .map((m) => m.id)
      .toList(growable: false);
  ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .reconcile(liveIds ?? const <String>[]);
}

/// 多选消息行包装：勾选框 + 不可选置灰（镜像 mobile chat_message_item 语义）。
Widget webMultiSelectRowWrapper(
  BuildContext context, {
  required WidgetRef ref,
  required String conversationUk3,
  required Message message,
  required Widget child,
}) {
  final selection = conversationUk3.isEmpty
      ? MessageSelectionState()
      : ref.watch(messageSelectionProvider(conversationUk3));
  if (!selection.active) return child;
  final checked = selection.contains(message.id);
  final selectable =
      checked ||
      evaluateMessageSelectability(messageSelectionTraitsOf(message))
          .selectable;
  final colors = Theme.of(context).colorScheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      IconButton(
        key: ValueKey('web-msg-select-checkbox-${message.id}'),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          checked
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.circle,
          size: AppSizes.iconSizeSmall,
          color: selectable ? colors.primary : colors.outlineVariant,
        ),
        tooltip: t.chat.multiSelect,
        onPressed: selectable
            ? () => webToggleMessageSelection(ref, conversationUk3, message)
            : null,
      ),
      Expanded(
        child: selectable ? child : Opacity(opacity: 0.45, child: child),
      ),
    ],
  );
}

/// Web 多选动作栏：接既有策略（forwardEach/bundle/export）与共享编排，
/// 布局语义与 mobile MessageMultiSelectActionBar 一致（取消/计数/转发/导出）。
class WebMultiSelectActionBar extends ConsumerWidget {
  const WebMultiSelectActionBar({
    super.key,
    required this.conversationUk3,
    required this.sourceChatType,
    required this.conversationTitle,
    required this.peerId,
  });

  final String conversationUk3;
  final String sourceChatType;
  final String conversationTitle;
  final String peerId;

  List<Message> _sorted(WidgetRef ref) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.watch(messageSelectionProvider(conversationUk3));
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ??
        const <Message>[];
    return sortMultiSelectMessages(selection, messages);
  }

  void _runCurrent(
    BuildContext context,
    WidgetRef ref,
    List<Message> initial,
    bool Function(Iterable<MessageSelectionTraits> traits) allowed,
    void Function(BuildContext, List<Message>) action,
  ) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.read(messageSelectionProvider(conversationUk3));
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ??
        const <Message>[];
    final fresh = sortMultiSelectMessages(selection, messages);
    if (!canDispatchSelectedMessages(
      active: selection.active,
      current: fresh,
      initial: initial,
      allowed: allowed,
    )) {
      AppLoading.showToast(t.chat.multiSelectUnavailable);
      return;
    }
    action(context, fresh);
  }

  void _showForwardOptions(
    BuildContext context,
    WidgetRef ref,
    List<Message> selected,
    bool forwardEachAllowed,
    bool forwardBundleAllowed,
  ) {
    // 策略不允许 → CupertinoButton 禁用占位（与 mobile
    // MessageMultiSelectActionBar._forwardOption 同形态：ActionSheetAction
    // 的 onPressed 为非空 VoidCallback，禁用项用 Button 表达）。
    Widget option({
      required Key key,
      required String label,
      required bool allowed,
      required VoidCallback onAllowed,
    }) => allowed
        ? CupertinoActionSheetAction(
            key: key,
            onPressed: onAllowed,
            child: Text(label),
          )
        : CupertinoButton(
            key: key,
            minimumSize: const Size(44, 44),
            onPressed: null,
            child: Text(label),
          );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          option(
            key: const ValueKey('web-multi-select-forward-each'),
            label: t.chat.multiSelectForwardEach,
            allowed: forwardEachAllowed,
            onAllowed: () {
              Navigator.of(sheetContext).pop();
              _runCurrent(
                context,
                ref,
                selected,
                forwardEachActionAllowedFor,
                (ctx, fresh) => _forwardEach(ctx, fresh),
              );
            },
          ),
          option(
            key: const ValueKey('web-multi-select-forward-bundle'),
            label: t.chat.multiSelectForwardBundle,
            allowed: forwardBundleAllowed,
            onAllowed: () {
              Navigator.of(sheetContext).pop();
              _runCurrent(
                context,
                ref,
                selected,
                bundleActionAllowedFor,
                (ctx, fresh) => _forwardBundle(ctx, fresh),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          key: const ValueKey('web-multi-select-forward-cancel'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  void _forwardEach(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xLarge),
        child: SendToPage.batch(messages: messages),
      ),
    );
  }

  void _forwardBundle(BuildContext context, List<Message> messages) {
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

  void _export(BuildContext context, List<Message> messages) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.watch(messageSelectionProvider(conversationUk3));
    // 镜像 + post-frame 对账（复用 reconcile 脏检查，幂等收敛）。
    webReconcileMultiSelection(ref, conversationUk3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      webReconcileMultiSelection(ref, conversationUk3);
    });
    final sorted = _sorted(ref);
    final traits = sorted.map(messageSelectionTraitsOf);
    final forwardEachAllowed = forwardEachActionAllowedFor(traits);
    final forwardBundleAllowed = bundleActionAllowedFor(traits);
    final exportAllowed = exportActionAllowedFor(traits);
    final colors = Theme.of(context).colorScheme;
    final countText = t.chat.multiSelectCount(count: selection.count);
    return Container(
      key: const ValueKey('web-multi-select-action-bar'),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.all(AppSpacing.small),
      child: Row(
        children: [
          TextButton(
            key: const ValueKey('web-multi-select-cancel'),
            onPressed: () => webExitMultiSelect(ref, conversationUk3),
            child: Text(t.chat.multiSelectCancel),
          ),
          Expanded(
            child: Text(
              countText,
              key: const ValueKey('web-multi-select-count'),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            key: const ValueKey('web-multi-select-forward'),
            onPressed:
                sorted.isEmpty || (!forwardEachAllowed && !forwardBundleAllowed)
                ? null
                : () => _showForwardOptions(
                    context,
                    ref,
                    sorted,
                    forwardEachAllowed,
                    forwardBundleAllowed,
                  ),
            child: Text(t.chat.forward),
          ),
          TextButton(
            key: const ValueKey('web-multi-select-export'),
            onPressed: exportAllowed
                ? () => _runCurrent(
                    context,
                    ref,
                    sorted,
                    exportActionAllowedFor,
                    _export,
                  )
                : null,
            child: Text(t.chat.multiSelectExport),
          ),
        ],
      ),
    );
  }
}
