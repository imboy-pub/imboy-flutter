import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

/// 分页信息类
class _PageInfo {
  int currentPage;
  bool hasMore;
  int totalMessages;
  DateTime? lastLoadTime;
  
  _PageInfo({
    required this.currentPage,
    required this.hasMore,
    required this.totalMessages,
    this.lastLoadTime,
  });
}

/// 消息加载管理器
/// 处理消息的预加载、缓存和分页加载逻辑
class MessageLoadingManager extends GetxController {
  static MessageLoadingManager get to => Get.find();
  
  // 消息缓存 {conversationId: List<Message>}
  final Map<String, List<Message>> _messageCache = {};
  
  // 预加载队列 {conversationId: Timer}
  final Map<String, Timer> _preloadTimers = {};
  
  // 加载状态 {conversationId: isLoading}
  final Map<String, bool> _loadingStates = {};
  
  // 分页信息 {conversationId: pageInfo}
  final Map<String, _PageInfo> _pageInfo = {};
  
  // 可观察值
  final RxBool isLoading = false.obs;
  final RxDouble loadingProgress = 0.0.obs;
  final RxString loadingMessage = ''.obs;
  
  // 预加载配置
  static const int _preloadThreshold = 5; // 距离底部多少条消息时预加载
  static const int _pageSize = 20; // 每页消息数量
  static const Duration _preloadDelay = Duration(milliseconds: 500); // 预加载延迟
  
  /// 获取会话的消息缓存
  List<Message> getCachedMessages(String conversationId) {
    return _messageCache[conversationId] ?? [];
  }
  
  /// 缓存消息
  void cacheMessages(String conversationId, List<Message> messages) {
    _messageCache[conversationId] = messages;
    
    // 更新分页信息
    final pageInfo = _pageInfo[conversationId];
    if (pageInfo != null) {
      pageInfo.totalMessages = messages.length;
      pageInfo.lastLoadTime = DateTime.now();
    } else {
      _pageInfo[conversationId] = _PageInfo(
        currentPage: 1,
        hasMore: true,
        totalMessages: messages.length,
        lastLoadTime: DateTime.now(),
      );
    }
  }
  
  /// 添加新消息到缓存
  void addMessageToCache(String conversationId, Message message) {
    if (!_messageCache.containsKey(conversationId)) {
      _messageCache[conversationId] = [];
    }
    
    // 避免重复添加
    if (!_messageCache[conversationId]!.any((m) => m.id == message.id)) {
      _messageCache[conversationId]!.add(message);
      
      // 更新总数
      final pageInfo = _pageInfo[conversationId];
      if (pageInfo != null) {
        pageInfo.totalMessages = _messageCache[conversationId]!.length;
      }
    }
  }
  
  /// 从缓存中移除消息
  void removeMessageFromCache(String conversationId, String messageId) {
    _messageCache[conversationId]?.removeWhere((m) => m.id == messageId);
    
    // 更新总数
    final pageInfo = _pageInfo[conversationId];
    if (pageInfo != null) {
      pageInfo.totalMessages = _messageCache[conversationId]?.length ?? 0;
    }
  }
  
  /// 检查是否需要预加载
  bool shouldPreload(String conversationId, int visibleMessageCount) {
    final cachedMessages = _messageCache[conversationId] ?? [];
    final pageInfo = _pageInfo[conversationId];
    
    // 如果没有更多数据或者正在加载，不需要预加载
    if (pageInfo == null || !pageInfo.hasMore || _loadingStates[conversationId] == true) {
      return false;
    }
    
    // 如果缓存的消息数量不足，需要预加载
    return cachedMessages.length - visibleMessageCount <= _preloadThreshold;
  }
  
  /// 预加载消息
  Future<void> preloadMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction,
  ) async {
    // 取消之前的预加载定时器
    _preloadTimers[conversationId]?.cancel();
    
    // 设置新的预加载定时器
    _preloadTimers[conversationId] = Timer(_preloadDelay, () async {
      if (_loadingStates[conversationId] == true) return;
      
      final pageInfo = _pageInfo[conversationId];
      if (pageInfo == null || !pageInfo.hasMore) return;
      
      await loadMoreMessages(conversationId, loadFunction);
    });
  }
  
  /// 加载更多消息
  Future<List<Message>> loadMoreMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction, {
    bool showLoading = true,
  }) async {
    if (_loadingStates[conversationId] == true) {
      return [];
    }
    
    _loadingStates[conversationId] = true;
    isLoading.value = true;
    
    if (showLoading) {
      loadingMessage.value = '加载更多消息...';
      loadingProgress.value = 0.0;
    }
    
    try {
      final pageInfo = _pageInfo[conversationId] ?? _PageInfo(
        currentPage: 0,
        hasMore: true,
        totalMessages: 0,
      );
      
      if (showLoading) {
        loadingProgress.value = 0.3;
      }
      
      final newMessages = await loadFunction(
        pageInfo.currentPage + 1,
        _pageSize,
      );
      
      if (showLoading) {
        loadingProgress.value = 0.8;
      }
      
      if (newMessages.isEmpty) {
        pageInfo.hasMore = false;
      } else {
        pageInfo.currentPage++;
        pageInfo.lastLoadTime = DateTime.now();
        
        // 添加到缓存
        if (!_messageCache.containsKey(conversationId)) {
          _messageCache[conversationId] = [];
        }
        
        // 避免重复添加
        final existingIds = _messageCache[conversationId]!.map((m) => m.id).toSet();
        final uniqueMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();
        
        _messageCache[conversationId]!.addAll(uniqueMessages);
        pageInfo.totalMessages = _messageCache[conversationId]!.length;
      }
      
      if (showLoading) {
        loadingProgress.value = 1.0;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      return newMessages;
    } catch (e) {
      debugPrint('加载消息失败: $e');
      rethrow;
    } finally {
      _loadingStates[conversationId] = false;
      isLoading.value = false;
      loadingProgress.value = 0.0;
      loadingMessage.value = '';
    }
  }
  
  /// 刷新消息
  Future<List<Message>> refreshMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction,
  ) async {
    // 清空缓存
    _messageCache[conversationId]?.clear();
    _pageInfo[conversationId] = _PageInfo(
      currentPage: 0,
      hasMore: true,
      totalMessages: 0,
    );
    
    // 重新加载
    return loadMoreMessages(conversationId, loadFunction, showLoading: true);
  }
  
  /// 搜索消息
  List<Message> searchMessages(String conversationId, String query) {
    final messages = _messageCache[conversationId] ?? [];
    
    if (query.trim().isEmpty) {
      return messages;
    }
    
    final lowerQuery = query.toLowerCase();
    return messages.where((message) {
      if (message is TextMessage) {
        return message.text.toLowerCase().contains(lowerQuery);
      }
      return false;
    }).toList();
  }
  
  /// 获取消息位置
  int getMessageIndex(String conversationId, String messageId) {
    final messages = _messageCache[conversationId] ?? [];
    return messages.indexWhere((m) => m.id == messageId);
  }
  
  /// 检查是否有更多消息
  bool hasMoreMessages(String conversationId) {
    return _pageInfo[conversationId]?.hasMore ?? true;
  }
  
  /// 获取加载状态
  bool getIsLoading(String conversationId) {
    return _loadingStates[conversationId] ?? false;
  }
  
  /// 清理会话缓存
  void clearConversationCache(String conversationId) {
    _messageCache.remove(conversationId);
    _pageInfo.remove(conversationId);
    _preloadTimers[conversationId]?.cancel();
    _preloadTimers.remove(conversationId);
    _loadingStates.remove(conversationId);
  }
  
  /// 清理所有缓存
  void clearAllCache() {
    _messageCache.clear();
    _pageInfo.clear();
    _preloadTimers.forEach((_, timer) => timer.cancel());
    _preloadTimers.clear();
    _loadingStates.clear();
  }
  
  @override
  void onClose() {
    _preloadTimers.forEach((_, timer) => timer.cancel());
    super.onClose();
  }
}

/// 消息加载指示器组件
class MessageLoadingIndicator extends StatelessWidget {
  const MessageLoadingIndicator({
    super.key,
    required this.conversationId,
  });
  
  final String conversationId;
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<MessageLoadingManager>(
      init: MessageLoadingManager.to,
      builder: (controller) {
        if (!controller.getIsLoading(conversationId)) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: controller.loadingProgress.value > 0 
                          ? controller.loadingProgress.value 
                          : null,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.loadingMessage.value.isNotEmpty
                          ? controller.loadingMessage.value
                          : '加载中...',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.loadingProgress.value > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.loadingProgress.value,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 消息预加载触发器组件
class MessagePreloadTrigger extends StatelessWidget {
  const MessagePreloadTrigger({
    super.key,
    required this.conversationId,
    required this.visibleMessageCount,
    required this.loadFunction,
    required this.child,
  });
  
  final String conversationId;
  final int visibleMessageCount;
  final Future<List<Message>> Function(int page, int size) loadFunction;
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 检查是否需要预加载
          if (MessageLoadingManager.to.shouldPreload(conversationId, visibleMessageCount)) {
            MessageLoadingManager.to.preloadMessages(conversationId, loadFunction);
          }
        }
        return false;
      },
      child: child,
    );
  }
}