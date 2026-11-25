import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart'
    show RenderProxyBox, PaintingContext, ScrollDirection;
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/page/chat/chat/utils/message_status_icon_rules.dart';
import 'package:imboy/page/chat/widget/message_bubble_style.dart'
    as bubble_style;
import 'package:imboy/plugins/registry/message_type_registry.dart';

part 'chat_reading_restore.dart';
part 'chat_message_list_items.dart';

/// 聊天消息列表组件（性能优化版）
/// 移除 Dismissible 和 AnimatedBuilder 以提升滚动性能
///
/// 使用方式：
/// ```dart
/// ChatMessageList(
///   messages: messages,
///   currentUserId: currentUserId,
///   onMessageLongPress: (message) { ... },
///   onMessageDoubleTap: (message) { ... },
///   onMessageTap: (message) { ... },
/// )
/// ```
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.onMessageLongPress,
    required this.onMessageDoubleTap,
    this.onMessageTap,
    this.messageContentBuilder,
    this.messageStatusBuilder,
    this.messageItemWrapper,
    this.scrollController,
    this.onEndReached,
    this.onStartReached,
    this.messageTypeRegistry,
    this.targetMsgId,
    this.targetMessageKey,
    this.preserveReadingPosition = false,
    this.readingSessionKey,
    this.initialReadingAnchor,
    this.onReadingAnchor,
    this.onReadingUserInput,
    this.onReadingRestoreComplete,
    this.onNewMessages,
    this.isCurrent,
  });

  final List<Message> messages;
  final String currentUserId;
  final void Function(Message) onMessageLongPress;
  final void Function(Message) onMessageDoubleTap;
  final void Function(Message)? onMessageTap;
  final Widget? Function(BuildContext, Message, int)? messageContentBuilder;
  final Widget? Function(BuildContext, Message)? messageStatusBuilder;
  final Widget Function(BuildContext, Message, Widget)? messageItemWrapper;
  final ScrollController? scrollController;
  final Future<void> Function()? onEndReached;
  final Future<void> Function()? onStartReached;
  final MessageTypeRegistry? messageTypeRegistry;
  final String? targetMsgId;
  final Key? targetMessageKey;

  final bool preserveReadingPosition;
  final Object? readingSessionKey;
  final ({String id, double y})? initialReadingAnchor;
  final void Function(({String id, double y})?)? onReadingAnchor;
  final VoidCallback? onReadingUserInput;
  final VoidCallback? onReadingRestoreComplete;
  final void Function(List<Message>, bool wasNearBottom)? onNewMessages;
  final bool Function()? isCurrent;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _deferredIds = <String>{};
  int _revision = 0;
  final _viewportKey = GlobalKey();
  final _rowKeys = <String, GlobalKey>{};
  // PERF03-C（uxfix-batch1，属主裁决）：消息内容 widget 按 (message 同一实例)
  // 记忆化。发送/收信会让 chatProvider 全量 notify → 本列表 build → 每个可见
  // 项都重新跑 messageContentBuilder → GptMarkdown 重新解析+重排版，实测
  // echo-paint p95=380ms（perf03-sendleg-20261116）。这里缓存 builder 产物，
  // 未变消息返回同一 widget 实例——Element.update 走 identical 快路径，
  // 跳过该子树的 rebuild+layout；新消息只构建自己。消息对象以 provider 浅拷贝
  // 传递（syncMessagesToState → toList），未变项跨帧保持同一实例，命中率稳定。
  final _contentCache = <String, ({Message message, Widget? content})>{};
  _ScreenReadingAnchor? _screenAnchor;
  ({String id, double y})? _savedAnchor;
  int _savedAttempts = 0;
  final _savedOffsets = <int>{};
  var _layoutScheduled = false, _restoringAnchor = false;
  int _corrections = 0;
  // Lazy rows can remeasure after a correction; bound retries against oscillation.
  static const _maxCorrections = 3;

  @override
  void initState() {
    super.initState();
    _savedAnchor = widget.initialReadingAnchor;
    if (widget.preserveReadingPosition) {
      widget.scrollController?.addListener(_readingOffsetChanged);
    }
  }

  @override
  void dispose() {
    if (widget.preserveReadingPosition) {
      widget.scrollController?.removeListener(_readingOffsetChanged);
    }
    _rowKeys.clear();
    _screenAnchor = null;
    super.dispose();
  }

  void _resetScreenAnchor() {
    _screenAnchor = null;
    _corrections = 0;
  }

  void _readingOffsetChanged() {
    if (_restoringAnchor || !widget.preserveReadingPosition) return;
    _resetScreenAnchor();
    _scheduleReadingLayout();
  }

  bool _readingScroll(ScrollNotification event) {
    if (event.depth != 0 || _restoringAnchor) return false;
    if (event is UserScrollNotification &&
            event.direction != ScrollDirection.idle ||
        event is ScrollStartNotification && event.dragDetails != null ||
        event is ScrollUpdateNotification && event.dragDetails != null) {
      widget.onReadingUserInput?.call();
      _savedAnchor = null;
    }
    if (event is ScrollStartNotification || event is ScrollUpdateNotification) {
      _resetScreenAnchor();
    }
    if (event is ScrollEndNotification) _scheduleReadingLayout();
    return false;
  }

  ScrollController? _idleHistory() {
    final controller = widget.scrollController;
    if (!mounted ||
        !widget.preserveReadingPosition ||
        widget.isCurrent?.call() == false ||
        controller == null ||
        controller.positions.length != 1) {
      return null;
    }
    final position = controller.position;
    if (!position.hasContentDimensions ||
        position.outOfRange ||
        position.isScrollingNotifier.value ||
        position.pixels - position.minScrollExtent <= 100) {
      return null;
    }
    return controller;
  }

  RenderBox? _rowBox(String id) {
    final box = _rowKeys[id]?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  _ScreenReadingAnchor? _captureScreenAnchor(ScrollController controller) {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return null;
    }
    final rect = viewport.localToGlobal(Offset.zero) & viewport.size;
    String? id;
    double? y;
    for (final candidate in _rowKeys.keys) {
      final box = _rowBox(candidate);
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top < rect.bottom &&
          top + box.size.height > rect.top &&
          (y == null || top < y)) {
        id = candidate;
        y = top;
      }
    }
    return id == null
        ? null
        : (
            id: id,
            y: y!,
            pixels: controller.offset,
            session: widget.readingSessionKey,
            revision: _revision,
            controller: controller,
          );
  }

  void _scheduleReadingLayout() {
    if (!mounted || !widget.preserveReadingPosition || _layoutScheduled) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (!mounted) return;
      _rowKeys.removeWhere((_, key) => key.currentContext == null);
      if (_savedAnchor != null && _restoreSavedAnchor()) return;
      final controller = _idleHistory();
      if (controller == null) {
        _resetScreenAnchor();
        final positions = widget.scrollController?.positions;
        final position = positions != null && positions.length == 1
            ? positions.single
            : null;
        if (_savedAnchor == null &&
            position != null &&
            position.hasContentDimensions &&
            !position.isScrollingNotifier.value &&
            position.pixels - position.minScrollExtent <= 100) {
          widget.onReadingAnchor?.call(null);
        }
        return;
      }
      final anchor = _screenAnchor;
      if (anchor != null && _restoreScreenAnchor(anchor, controller)) return;
      _screenAnchor = _captureScreenAnchor(controller);
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (_screenAnchor != null && viewport is RenderBox && viewport.attached) {
        widget.onReadingAnchor?.call((
          id: _screenAnchor!.id,
          y: _screenAnchor!.y - viewport.localToGlobal(Offset.zero).dy,
        ));
      }
      _corrections = 0;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncReadingController(ChatMessageList oldWidget) {
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.preserveReadingPosition != widget.preserveReadingPosition) {
      if (oldWidget.preserveReadingPosition) {
        oldWidget.scrollController?.removeListener(_readingOffsetChanged);
      }
      if (widget.preserveReadingPosition) {
        widget.scrollController?.addListener(_readingOffsetChanged);
      }
      _resetScreenAnchor();
    }
    if (!widget.preserveReadingPosition) {
      _rowKeys.clear();
      return;
    }
    final liveRowIds = widget.messages.map((m) => m.id).toSet();
    _rowKeys.removeWhere((id, _) => !liveRowIds.contains(id));
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncReadingController(oldWidget);
    if (oldWidget.initialReadingAnchor != null &&
        widget.initialReadingAnchor == null) {
      _savedAnchor = null;
    }
    if (oldWidget.readingSessionKey != widget.readingSessionKey) {
      _revision++;
      _savedAnchor = widget.initialReadingAnchor;
      _savedAttempts = 0;
      _savedOffsets.clear();
      _deferredIds.clear();
      // 会话切换：内容缓存一并失效，避免跨会话复用旧气泡。
      _contentCache.clear();
      _resetScreenAnchor();
      _rowKeys.clear();
      return;
    }
    // PERF03-C：只保留当前会话仍存活的消息缓存，防止长会话驻留内存。
    final liveMessageIds = widget.messages.map((m) => m.id).toSet();
    _contentCache.removeWhere((id, _) => !liveMessageIds.contains(id));
    if (!widget.preserveReadingPosition) return;
    final liveIds = widget.messages.map((m) => m.id).toSet();
    _deferredIds.removeWhere((id) => !liveIds.contains(id));
    if (oldWidget.messages.isEmpty) return;
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    final nearBottom =
        controller.position.pixels - controller.position.minScrollExtent <= 100;
    final oldIds = oldWidget.messages.map((m) => m.id).toSet();
    // OBS-SYN03-SETTLEDROP：防跳窗口只吞「不早于既有最新行的头部新增」
    // （真正的新消息）。被误置到最新端的更旧消息（如 WS 补投的未读积压
    // 旧消息）不得进 _deferredIds——否则用户在历史深处阅读时整块隐藏，
    // settle 后渲染列表缺一整块真实历史（模型计数完好）。
    final previousNewestAt = oldWidget.messages.first.createdAt;
    final added = widget.messages
        .takeWhile((m) => !oldIds.contains(m.id))
        .where((m) {
          final created = m.createdAt;
          return previousNewestAt == null ||
              created == null ||
              !created.isBefore(previousNewestAt);
        })
        .toList();
    final releasing = _deferredIds.isNotEmpty && nearBottom;
    final ownMessage = added.any((m) => m.authorId == widget.currentUserId);
    if (nearBottom || ownMessage) {
      _deferredIds.clear();
      _resetScreenAnchor();
    } else {
      // Keep the actually visible history rows in place even when an incoming
      // item is taller than the lazy viewport/cache. The canonical list stays
      // complete; existing rows still receive current ACK/revoke/delete data.
      _deferredIds.addAll(added.map((m) => m.id));
    }
    if (added.isEmpty && !releasing) return;
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _revision ||
          widget.isCurrent?.call() == false) {
        return;
      }
      final currentIds = widget.messages.map((m) => m.id).toSet();
      widget.onNewMessages?.call(
        added.where((m) => currentIds.contains(m.id)).toList(),
        nearBottom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.preserveReadingPosition
        ? widget.messages.where((m) => !_deferredIds.contains(m.id)).toList()
        : widget.messages;
    final list = _ChatPaginationListener(
      onOlder: widget.onEndReached,
      onNewer: widget.onStartReached,
      child: ListView.builder(
        controller: widget.scrollController,
        reverse: true,
        scrollCacheExtent: const ScrollCacheExtent.pixels(500.0),
        // 移除定高 itemExtent 以支持自适应内容高度，避免滚动跳动
        physics: const BouncingScrollPhysics(),
        itemCount: messages.length,
        findChildIndexCallback: widget.preserveReadingPosition
            ? (key) {
                if (key is! ValueKey<String>) return null;
                final index = messages.indexWhere((m) => m.id == key.value);
                return index < 0 ? null : index;
              }
            : null,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isMe = message.authorId == widget.currentUserId;

          // 如果是目标消息，绑定 GlobalKey
          Key? itemKey;
          if (widget.targetMsgId != null && message.id == widget.targetMsgId) {
            itemKey = widget.targetMessageKey;
          }

          // PERF03-C：未变消息复用同一内容 widget 实例（identical 命中），
          // 跳过 GptMarkdown 等重内容的重新解析与排版；消息对象更换实例
          // （状态回执/撤回/编辑）时才重新构建。
          final cachedContent = _contentCache[message.id];
          final Widget? messageContent;
          if (message is CustomMessage &&
              message.metadata?['msg_type'] == MessageType.quote &&
              widget.messageContentBuilder == null) {
            messageContent = CustomMessageBuilder(
              type: message.metadata?['type']?.toString() ?? 'C2C',
              message: message,
              messages: widget.messages,
              registry: widget.messageTypeRegistry,
            );
          } else if (cachedContent != null &&
              identical(cachedContent.message, message)) {
            messageContent = cachedContent.content;
          } else {
            messageContent = widget.messageContentBuilder?.call(
              context,
              message,
              index,
            );
            _contentCache[message.id] = (
              message: message,
              content: messageContent,
            );
          }

          final child = _MessageItem(
            key: itemKey,
            message: message,
            isMe: isMe,
            messageTypeRegistry: widget.messageTypeRegistry,
            messageContent: messageContent,
            statusProvided: widget.messageStatusBuilder != null,
            status: isMe
                ? widget.messageStatusBuilder?.call(context, message)
                : null,
            onTap: () => widget.onMessageTap?.call(message),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onMessageLongPress(message);
            },
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              widget.onMessageDoubleTap(message);
            },
          );
          final item =
              widget.messageItemWrapper?.call(context, message, child) ?? child;
          if (!widget.preserveReadingPosition) return item;
          return KeyedSubtree(
            key: ValueKey(message.id),
            child: _ReadingLayoutProbe(
              key: _rowKeys.putIfAbsent(message.id, GlobalKey.new),
              onLayout: _scheduleReadingLayout,
              child: item,
            ),
          );
        },
      ),
    );
    if (!widget.preserveReadingPosition) return list;
    return Listener(
      onPointerSignal: (_) {
        if (!_restoringAnchor) {
          _savedAnchor = null;
          widget.onReadingUserInput?.call();
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _readingScroll,
        child: _ReadingLayoutProbe(
          key: _viewportKey,
          onLayout: _scheduleReadingLayout,
          child: list,
        ),
      ),
    );
  }
}

// 消息项/气泡子树 widget 在 part chat_message_list_items.dart。

class _ChatPaginationListener extends StatefulWidget {
  const _ChatPaginationListener({
    required this.child,
    this.onOlder,
    this.onNewer,
  });
  final Widget child;
  final Future<void> Function()? onOlder, onNewer;
  @override
  State<_ChatPaginationListener> createState() =>
      _ChatPaginationListenerState();
}

class _ChatPaginationListenerState extends State<_ChatPaginationListener> {
  bool _busy = false, _scheduled = false;

  Future<void> _dispatch(Future<void> Function()? callback) async {
    if (_busy || callback == null || !mounted) return;
    _busy = true;
    try {
      await callback();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'chat pagination',
        ),
      );
    } finally {
      _busy = false;
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 ||
        event is! ScrollEndNotification ||
        event.metrics.axis != Axis.vertical ||
        event.metrics.outOfRange) {
      return false;
    }
    if (event.metrics.extentAfter <= AppSpacing.xxxLarge) {
      unawaited(_dispatch(widget.onOlder));
    } else if (event.metrics.extentBefore <= AppSpacing.xxxLarge) {
      unawaited(_dispatch(widget.onNewer));
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification event) {
    if (event.depth != 0 ||
        event.metrics.axis != Axis.vertical ||
        event.metrics.maxScrollExtent > 0 ||
        _busy ||
        _scheduled ||
        widget.onOlder == null) {
      return false;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_dispatch(widget.onOlder));
    });
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      );
}

typedef _ScreenReadingAnchor = ({
  String id,
  double y,
  double pixels,
  Object? session,
  int revision,
  ScrollController controller,
});

/// Layout hooks use the last settled screen snapshot, never newly moved parent
/// coordinates as the old position. Both viewport and visible-row reflow notify.
class _ReadingLayoutProbe extends SingleChildRenderObjectWidget {
  const _ReadingLayoutProbe({
    super.key,
    required this.onLayout,
    required super.child,
  });
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ReadingLayoutBox(onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ReadingLayoutBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
    renderObject.markNeedsLayout();
  }
}

class _ReadingLayoutBox extends RenderProxyBox {
  _ReadingLayoutBox(this.onLayout);
  VoidCallback onLayout;
  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // A parent can move an otherwise unchanged child without relaying it out.
    onLayout();
  }
}
