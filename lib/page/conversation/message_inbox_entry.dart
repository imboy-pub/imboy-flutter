import 'package:flutter/widgets.dart';

/// Presentation-only types; optional channel bundles never enter the chat model.
enum MessageInboxKind { direct, group, channel, other }

enum MessageInboxFilter { all, unread, direct, group, channel }

class MessageInboxEntry {
  const MessageInboxEntry({
    required this.key,
    required this.kind,
    required this.title,
    required this.preview,
    required this.lastTime,
    required this.unreadCount,
    required this.isPinned,
    required this.builder,
    this.manualPending = false,
  });

  final String key;
  final MessageInboxKind kind;
  final String title;
  final String preview;
  final int lastTime;
  final int unreadCount;
  final bool isPinned;
  final bool manualPending;
  final WidgetBuilder builder;
}

/// Pure projection of existing state. Filtering never marks messages as read.
List<MessageInboxEntry> selectMessageInboxEntries(
  Iterable<MessageInboxEntry> entries, {
  MessageInboxFilter filter = MessageInboxFilter.all,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  final result = entries.where((entry) {
    final matchesType = switch (filter) {
      MessageInboxFilter.all => true,
      MessageInboxFilter.unread => entry.unreadCount > 0 || entry.manualPending,
      MessageInboxFilter.direct => entry.kind == MessageInboxKind.direct,
      MessageInboxFilter.group => entry.kind == MessageInboxKind.group,
      MessageInboxFilter.channel => entry.kind == MessageInboxKind.channel,
    };
    return matchesType &&
        (needle.isEmpty ||
            entry.title.toLowerCase().contains(needle) ||
            entry.preview.toLowerCase().contains(needle));
  }).toList();
  result.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final byTime = b.lastTime.compareTo(a.lastTime);
    return byTime == 0 ? a.key.compareTo(b.key) : byTime;
  });
  return result;
}
