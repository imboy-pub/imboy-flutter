import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/theme/default/app_colors.dart';

part 'message_scroll_provider.g.dart';

/// 消息滚动状态
class MessageScrollState {
  final bool isScrolling;
  final bool isAtBottom;
  final double scrollPosition;
  final String? highlightedMessageId;

  MessageScrollState({
    this.isScrolling = false,
    this.isAtBottom = true,
    this.scrollPosition = 0.0,
    this.highlightedMessageId,
  });

  MessageScrollState copyWith({
    bool? isScrolling,
    bool? isAtBottom,
    double? scrollPosition,
    String? highlightedMessageId,
  }) {
    return MessageScrollState(
      isScrolling: isScrolling ?? this.isScrolling,
      isAtBottom: isAtBottom ?? this.isAtBottom,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      highlightedMessageId: highlightedMessageId ?? this.highlightedMessageId,
    );
  }
}

/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果
@riverpod
class MessageScrollManager extends _$MessageScrollManager {
  final ScrollController scrollController = ScrollController();

  // 消息位置缓存 {conversationId: {messageId: offset}}
  final Map<String, Map<String, double>> _messagePositions = {};

  // 自动滚动定时器
  Timer? _autoScrollTimer;

  // 滚动配置
  static const Duration _scrollDuration = Duration(milliseconds: 300);
  static const Duration _autoScrollDelay = Duration(milliseconds: 100);
  static const double _scrollThreshold = 100.0; // 距离底部多少算"在底部"

  // 是否已释放标志
  bool _isDisposed = false;

  @override
  MessageScrollState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _autoScrollTimer?.cancel();
      scrollController.dispose();
    });

    // 初始化滚动监听器
    _initScrollListener();

    return MessageScrollState();
  }

  /// 初始化滚动监听器
  void _initScrollListener() {
    scrollController.addListener(() {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;

      state = state.copyWith(
        scrollPosition: currentScroll,
        isAtBottom: maxScroll - currentScroll <= _scrollThreshold,
      );

      // 检测滚动状态
      if (state.isScrolling && !scrollController.position.hasPixels) {
        state = state.copyWith(isScrolling: false);
      }
    });
  }

  /// 滚动到底部
  Future<void> scrollToBottom({bool animated = true}) async {
    // 检查是否已释放或 ScrollController 无效
    if (_isDisposed || !scrollController.hasClients) return;

    state = state.copyWith(isScrolling: true);

    if (animated) {
      await scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: _scrollDuration,
        curve: Curves.easeInOut,
      );
    } else {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }

    // 再次检查，防止异步操作期间被释放
    if (!_isDisposed) {
      state = state.copyWith(isAtBottom: true, isScrolling: false);
    }
  }

  /// 滚动到指定消息（优化版）
  Future<void> scrollToMessage(
    String conversationId,
    String messageId, {
    bool animated = true,
    double offset = 80.0, // 增加默认偏移，避免消息被顶部栏遮挡
    bool highlight = true, // 是否高亮消息
    Duration? duration, // 自定义动画时长
  }) async {
    // 检查是否已释放或 ScrollController 无效
    if (_isDisposed || !scrollController.hasClients) {
      iPrint('ScrollController无效，无法滚动');
      return;
    }

    state = state.copyWith(isScrolling: true);
    final scrollDuration = duration ?? _scrollDuration;

    // 首先尝试从缓存获取位置
    var position = _getMessagePosition(conversationId, messageId);

    // 如果缓存中没有位置，尝试通过事件系统获取
    if (position == null) {
      iPrint('缓存中未找到消息位置，尝试通过事件系统获取');
      position = await _getMessagePositionFromUI(messageId);
    }

    if (position == null) {
      state = state.copyWith(isScrolling: false);
      iPrint('无法获取消息位置');
      return;
    }

    // 再次检查是否已释放或无效（防止异步操作期间被释放）
    if (_isDisposed || !scrollController.hasClients) {
      state = state.copyWith(isScrolling: false);
      iPrint('ScrollController已失效');
      return;
    }

    // 计算目标位置，考虑偏移量
    final targetPosition = (position - offset).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );

    if (animated) {
      // 使用更平滑的动画曲线
      await scrollController.animateTo(
        targetPosition,
        duration: scrollDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      scrollController.jumpTo(targetPosition);
    }

    // 更新滚动状态
    if (!_isDisposed) {
      state = state.copyWith(isScrolling: false);
    }

    // 延迟后高亮消息，确保滚动完成
    if (highlight && !_isDisposed) {
      _autoScrollTimer?.cancel(); // 取消之前的定时器
      _autoScrollTimer = Timer(_autoScrollDelay, () {
        if (!_isDisposed) {
          highlightMessage(messageId);
        }
      });
    }

    iPrint('滚动到消息完成');
  }

  /// 从UI层获取消息位置
  Future<double?> _getMessagePositionFromUI(String messageId) async {
    try {
      // 这里可以通过GlobalKey或者其他方式获取消息的实际位置
      // 暂时返回null，让调用方使用降级方案
      return null;
    } catch (e) {
      iPrint('从UI获取消息位置失败: ${e.runtimeType}');
      return null;
    }
  }

  /// 滚动到指定位置
  Future<void> scrollToPosition(double position, {bool animated = true}) async {
    // 检查是否已释放或 ScrollController 无效
    if (_isDisposed || !scrollController.hasClients) return;

    state = state.copyWith(isScrolling: true);

    if (animated) {
      await scrollController.animateTo(
        position,
        duration: _scrollDuration,
        curve: Curves.easeInOut,
      );
    } else {
      scrollController.jumpTo(position);
    }

    // 更新滚动状态
    if (!_isDisposed) {
      state = state.copyWith(isScrolling: false);
    }
  }

  /// 缓存消息位置（优化版）
  void cacheMessagePosition(
    String conversationId,
    String messageId,
    double position,
  ) {
    if (!_messagePositions.containsKey(conversationId)) {
      _messagePositions[conversationId] = {};
    }

    _messagePositions[conversationId]![messageId] = position;

    // 限制缓存大小，避免内存过大
    final conversationCache = _messagePositions[conversationId]!;
    if (conversationCache.length > 500) {
      // 最多缓存500个消息位置
      final keys = conversationCache.keys.toList();
      // 移除最旧的100个位置
      for (int i = 0; i < 100 && i < keys.length; i++) {
        conversationCache.remove(keys[i]);
      }
    }
  }

  /// 批量缓存消息位置
  void cacheMessagePositions(
    String conversationId,
    Map<String, double> positions,
  ) {
    if (!_messagePositions.containsKey(conversationId)) {
      _messagePositions[conversationId] = {};
    }

    _messagePositions[conversationId]!.addAll(positions);
  }

  /// 获取消息位置
  double? _getMessagePosition(String conversationId, String messageId) {
    return _messagePositions[conversationId]?[messageId];
  }

  /// 清除会话的消息位置缓存
  void clearMessagePositions(String conversationId) {
    _messagePositions.remove(conversationId);
  }

  /// 清除所有消息位置缓存
  void clearAllMessagePositions() {
    _messagePositions.clear();
  }

  /// 高亮消息（优化版）
  void highlightMessage(String messageId) {
    if (_isDisposed) return;
    _triggerHighlightAnimation(messageId);
    iPrint('触发消息高亮');
  }

  /// 触发高亮动画
  void _triggerHighlightAnimation(String messageId) {
    if (_isDisposed) return;

    // 更新高亮状态
    state = state.copyWith(highlightedMessageId: messageId);

    // 设置定时器取消高亮
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!_isDisposed) {
        _cancelHighlight(messageId);
      }
    });
  }

  /// 取消高亮
  void _cancelHighlight(String messageId) {
    if (state.highlightedMessageId == messageId) {
      state = state.copyWith(highlightedMessageId: null);
      iPrint('取消消息高亮');
    }
  }

  /// 检查消息是否被高亮
  bool isMessageHighlighted(String messageId) {
    return state.highlightedMessageId == messageId;
  }

  /// 处理新消息到达时的滚动逻辑（优化版）
  void handleNewMessage(String conversationId, Message message) {
    // 如果当前在底部，自动滚动到新消息
    if (state.isAtBottom) {
      scrollToBottom(animated: true);
    }

    // 缓存新消息位置（优化位置估算）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        // 更精确的位置估算
        final maxScroll = scrollController.position.maxScrollExtent;
        final estimatedPosition = maxScroll + 80.0; // 更合理的偏移量
        cacheMessagePosition(conversationId, message.id, estimatedPosition);

        // 更新附近消息的位置缓存
        _updateNearbyMessagePositions(
          conversationId,
          message.id,
          estimatedPosition,
        );
      }
    });
  }

  /// 更新附近消息的位置缓存
  void _updateNearbyMessagePositions(
    String conversationId,
    String messageId,
    double position,
  ) {
    // 为附近的消息更新位置缓存，提高定位准确性
    final conversationCache = _messagePositions[conversationId];
    if (conversationCache != null) {
      // 这里可以根据实际需要更新附近消息的位置
      // 暂时简单更新当前消息的位置
      conversationCache[messageId] = position;
    }
  }

  /// 处理消息删除时的滚动逻辑
  void handleMessageDelete(String conversationId, String messageId) {
    // 移除消息位置缓存
    _messagePositions[conversationId]?.remove(messageId);
  }

  /// 获取滚动位置信息
  Map<String, dynamic> getScrollInfo() {
    return {
      'isScrolling': state.isScrolling,
      'isAtBottom': state.isAtBottom,
      'scrollPosition': state.scrollPosition,
      'maxScrollExtent': scrollController.hasClients
          ? scrollController.position.maxScrollExtent
          : 0.0,
    };
  }
}

/// 回到底部按钮组件
class ScrollToBottomButton extends ConsumerWidget {
  const ScrollToBottomButton({
    super.key,
    required this.conversationId,
    this.unreadCount = 0,
  });

  final String conversationId;
  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageScrollManagerProvider);
    final manager = ref.read(messageScrollManagerProvider.notifier);

    // 如果在底部或没有新消息，不显示按钮
    if (state.isAtBottom && unreadCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 16,
      child: AnimatedOpacity(
        opacity: state.isScrolling ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                manager.scrollToBottom(animated: true);
                // 清除未读计数
                // MessageReadManager.to.markConversationAsRead(conversationId);
              },
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.getIosRed(
                              Theme.of(context).brightness,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 消息位置监听器组件
class MessagePositionListener extends ConsumerWidget {
  const MessagePositionListener({
    super.key,
    required this.conversationId,
    required this.messages,
    required this.child,
  });

  final String conversationId;
  final List<Message> messages;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _updateMessagePositions(ref);
        }
        return false;
      },
      child: child,
    );
  }

  /// 更新消息位置
  void _updateMessagePositions(WidgetRef ref) {
    final manager = ref.read(messageScrollManagerProvider.notifier);
    if (!manager.scrollController.hasClients) return;

    final positions = <String, double>{};

    // 这里应该根据实际渲染的消息位置来更新
    // 由于需要获取每个消息的渲染位置，这里只是示例
    // 实际实现需要配合 SliverMultiBoxAdaptor 或其他方式

    manager.cacheMessagePositions(conversationId, positions);
  }
}
