import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show IsTypingIndicator;
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TypingIndicatorWidget extends ConsumerStatefulWidget {
  final String conversationUk3;
  final String peerId;
  final String peerTitle;

  const TypingIndicatorWidget({
    super.key,
    required this.conversationUk3,
    required this.peerId,
    required this.peerTitle,
  });

  @override
  ConsumerState<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends ConsumerState<TypingIndicatorWidget> {
  bool _isTyping = false;
  Timer? _hideTimer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppEventBus.on<MessageTypingEvent>().listen((event) {
      if (!mounted) return;
      
      // 过滤非当前会话的事件
      if (event.conversationUk3 != widget.conversationUk3) return;
      
      // 过滤自己的输入事件（虽然一般不会收到自己的）
      if (event.typierId == UserRepoLocal.to.currentUid) return;

      if (event.status == TypingStatus.start) {
        _showTyping();
      } else {
        _hideTyping();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showTyping() {
    if (!_isTyping) {
      setState(() {
        _isTyping = true;
      });
    }

    // 重置隐藏定时器
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _hideTyping();
      }
    });
  }

  void _hideTyping() {
    if (_isTyping) {
      setState(() {
        _isTyping = false;
      });
    }
    _hideTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTyping) return const SizedBox.shrink();

    final themeNotifier = ref.watch(themeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeNotifier.getThemeColor('chatBubbleIncoming'),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IsTypingIndicator(
              color: isDark ? Colors.white70 : Colors.black54,
              size: 6,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.peerTitle} 正在输入...',
            style: TextStyle(
              color: themeNotifier.getThemeColor('textSecondary'),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
