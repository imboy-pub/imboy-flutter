import 'package:flutter/widgets.dart';

import 'message_inbox_entry.dart';

/// A render seam for the generated optional-channel factory. The core message
/// page imports no channel implementation and still builds when it is removed.
class MessageInboxChannelData {
  const MessageInboxChannelData({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.refresh,
  });

  final List<MessageInboxEntry> entries;
  final bool isLoading;
  final Object? error;
  final Future<void> Function()? refresh;
}

class MessageInboxChannelHost extends InheritedWidget {
  const MessageInboxChannelHost({
    super.key,
    required this.builder,
    required super.child,
  });

  final Widget Function(BuildContext, MessageInboxChannelData) builder;

  static MessageInboxChannelHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MessageInboxChannelHost>();

  @override
  bool updateShouldNotify(MessageInboxChannelHost oldWidget) =>
      builder != oldWidget.builder;
}
