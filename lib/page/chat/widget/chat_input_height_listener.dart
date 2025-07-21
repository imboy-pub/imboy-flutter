import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 用于监听 child（比如 ChatInput）高度变化，并自动同步到 obs 变量
class ChatInputHeightListener extends StatefulWidget {
  final Widget child;
  final RxDouble composerHeight;

  const ChatInputHeightListener({
    super.key,
    required this.child,
    required this.composerHeight,
  });

  @override
  State<ChatInputHeightListener> createState() => _ChatInputHeightListenerState();
}

class _ChatInputHeightListenerState extends State<ChatInputHeightListener> {
  final _key = GlobalKey();
  double _lastHeight = 52.0; // 默认高度，和 ChatInput 的默认高度一致

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
  }

  @override
  void didUpdateWidget(covariant ChatInputHeightListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
  }

  void _notifyHeight() {
    final ctx = _key.currentContext;
    if (ctx != null) {
      final height = ctx.size?.height ?? 0;
      if (height != _lastHeight) {
        _lastHeight = height;
        widget.composerHeight.value = height;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Container(
          key: _key,
          child: widget.child,
        ),
      ),
    );
  }
}