part of 'chat_provider.dart';

Future<bool> _runChatAccountTask(
  ChatNotifier notifier,
  Future<void> Function(bool Function() isCurrent) operation,
) async {
  if (!notifier._preferences.isCurrent) return false;
  try {
    return await AccountLocalTaskRegistry.instance.run(
      notifier._preferences.owner,
      operation: (task) async {
        bool current() => notifier._preferences.isCurrent && !task.isCancelled;
        if (!current()) return false;
        await operation(current);
        return current();
      },
    );
  } on AccountLocalTaskCancelledException {
    return false;
  }
}

Future<void> _flushChatPending(ChatNotifier notifier, String key) async {
  if (!notifier._preferences.isCurrent || !MessagingFacade.instance.isOnline) {
    return;
  }
  if (!notifier._flushingPending.add(key)) {
    notifier._pendingFlushAgain.add(key);
    return;
  }
  final owner = notifier._preferences.owner.uid;
  final completed = <String>{};
  var retry = false;
  var active = false;
  try {
    active = await _runChatAccountTask(notifier, (isCurrent) async {
      final items = await PendingChatActions.instance.snapshot(key);
      for (final item in items.whereType<Map<String, dynamic>>()) {
        if (!isCurrent()) break;
        if (item['from'] != owner) continue;
        if (await notifier._dispatchPending(key, item, isCurrent: isCurrent)) {
          completed.add('${item['id']}');
        } else {
          retry = true;
        }
      }
      if (completed.isEmpty) return;
      await PendingChatActions.instance.update(
        key,
        (items) => items.removeWhere(
          (item) =>
              item is Map &&
              item['from'] == owner &&
              completed.contains('${item['id']}'),
        ),
        isCurrent: isCurrent,
      );
    });
  } catch (e) {
    active = notifier._preferences.isCurrent;
    retry = true;
    iPrint('[chat_provider] pending receipt failure=${e.runtimeType}');
  } finally {
    notifier._flushingPending.remove(key);
    final again = notifier._pendingFlushAgain.remove(key);
    if (active && (retry || again) && notifier._preferences.isCurrent) {
      if (key == ChatNotifier._spPendingReadReceiptsKey) {
        notifier._readReceiptFlushTimer?.cancel();
        notifier._readReceiptFlushTimer = Timer(
          retry ? const Duration(seconds: 5) : Duration.zero,
          notifier._flushPendingReadReceipts,
        );
      } else if (again) {
        unawaited(notifier._flushPending(key));
      }
    }
  }
}
