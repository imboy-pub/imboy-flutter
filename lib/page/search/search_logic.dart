import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'search_state.dart';
import 'package:imboy/i18n/strings.g.dart';

class SearchLogic extends GetxController {
  final state = SearchState();

  // 防抖定时器
  Timer? _debounceTimer;
  // 搜索缓存
  final Map<String, List<Message>> _searchCache = {};
  // 取消标记
  bool _isCancelled = false;
  // 联系人仓库
  final ContactRepo _contactRepo = ContactRepo();

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  // 防抖搜索
  void debouncedSearch(String query, {
    String? conversationUk3,
    String type = 'C2C',
    bool useCache = true,
  }) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      state.resetSearch();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch(
        query: query,
        conversationUk3: conversationUk3,
        type: type,
        useCache: useCache,
      );
    });
  }

  // 预加载联系人信息 - 优化版本，支持错误处理和降级
  Future<void> _preloadContacts(List<Message> messages) async {
    final Set<String> authorIds = messages.map((msg) => msg.authorId).toSet();
    
    // 使用 Future.wait 并行处理，但限制并发数避免过多请求
    final futures = <Future<void>>[];
    final batchSize = 3; // 限制并发数
    
    for (final authorId in authorIds) {
      if (state.getCachedContact(authorId) == null) {
        futures.add(_loadContactWithFallback(authorId));
        
        // 批量处理，避免过多并发
        if (futures.length >= batchSize) {
          await Future.wait(futures, eagerError: false);
          futures.clear();
        }
      }
    }
    
    // 处理剩余的请求
    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
    }
  }

  // 加载联系人信息，包含降级处理
  Future<void> _loadContactWithFallback(String authorId) async {
    try {
      final contact = await _contactRepo.findByUid(authorId);
      if (contact != null) {
        state.cacheContact(authorId, contact);
      }
    } catch (e) {
      debugPrint('预加载联系人失败: $authorId, $e');
      
      // 如果是加密相关错误，创建一个基础联系人对象
      if (e.toString().contains('Invalid padding') || 
          e.toString().contains('decrypt')) {
        final fallbackContact = ContactModel(
          peerId: authorId,
          nickname: 'User_${authorId.substring(0, 8)}', // 显示部分ID作为昵称
          avatar: '', // 使用默认头像
        );
        state.cacheContact(authorId, fallbackContact);
        debugPrint('使用降级联系人信息: $authorId');
      }
    }
  }

  // 安全的联系人预加载，不影响搜索结果展示
  Future<void> _preloadContactsSafely(List<Message> messages) async {
    // 不等待预加载完成，让搜索结果先显示
    unawaited(_preloadContacts(messages));
  }

  // 辅助函数：不等待 Future 完成
  void unawaited(Future<void> future) {
    // 故意不等待 future 完成
  }

  // 执行搜索
  Future<void> performSearch({
    required String query,
    String? conversationUk3,
    String type = 'C2C',
    bool useCache = true,
    bool loadMore = false,
  }) async {
    if (query.trim().isEmpty) return;

    final effectiveQuery = query.trim();
    final cacheKey = _generateCacheKey(effectiveQuery, conversationUk3, type);

    // 检查缓存
    if (useCache && !loadMore && _searchCache.containsKey(cacheKey)) {
      state.searchResults.value = _searchCache[cacheKey]!;
      state.currentQuery.value = effectiveQuery;
      await state.addToHistory(effectiveQuery);
      // 预加载联系人信息
      await _preloadContacts(state.searchResults);
      return;
    }

    _isCancelled = false;

    if (!loadMore) {
      state.resetSearch();
      state.currentQuery.value = effectiveQuery;
      state.isLoading.value = true;
      state.startSearching();
      state.errorMessage.value = '';
    }

    try {
      List<Message> results;

      // 使用优化的搜索方法
      if (state.hasActiveFilters()) {
        // 使用高级搜索（带过滤器）
        results = await advancedSearch(
          query: effectiveQuery,
          conversationUk3: conversationUk3,
          type: type,
          messageType: state.selectedMessageType.value,
          timeRange: state.selectedTimeRange.value,
          sender: state.selectedSender.value,
          startDate: state.startDate.value,
          endDate: state.endDate.value,
          page: state.currentPage.value,
          size: 20,
        );
      } else {
        // 使用基础搜索
        results = await search(
          type: type,
          page: state.currentPage.value,
          size: 20,
          kwd: effectiveQuery,
          conversationUk3: conversationUk3,
        );
      }

      if (_isCancelled) return;

      // 预加载联系人信息（独立处理，不影响搜索结果）
      _preloadContactsSafely(results);

      if (loadMore) {
        state.searchResults.addAll(results);
      } else {
        state.searchResults.value = results;
        await state.addToHistory(effectiveQuery);
      }

      // 更新分页状态
      state.hasMore.value = results.length >= 20;
      if (!loadMore) {
        state.totalResults.value = results.length;
        _updateTypeDistribution(results);
      }

      if (results.isEmpty && !loadMore) {
        state.errorMessage.value = t.searchNoFound;
      }

      // 缓存结果
      if (useCache && !loadMore) {
        _searchCache[cacheKey] = results;
        // 限制缓存大小
        if (_searchCache.length > 20) {
          _searchCache.remove(_searchCache.keys.first);
        }
      }

      state.currentPage.value++;
    } catch (e) {
      if (!_isCancelled) {
        state.errorMessage.value = t.searchError;
        debugPrint('Search error: $e');
        
        // 如果是网络相关错误，可以提供用户友好的提示
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Connection')) {
          state.errorMessage.value = '网络连接异常，请检查网络后重试';
        }
      }
    } finally {
      state.isLoading.value = false;
      state.stopSearching();
    }
  }

  // 取消搜索
  void cancelSearch() {
    _isCancelled = true;
    _debounceTimer?.cancel();
    state.isLoading.value = false;
  }

  // 加载更多结果
  Future<void> loadMoreResults({
    String? conversationUk3,
    String type = 'C2C',
  }) async {
    if (state.isLoading.value || !state.hasMore.value) return;

    await performSearch(
      query: state.currentQuery.value,
      conversationUk3: conversationUk3,
      type: type,
      useCache: false,
      loadMore: true,
    );
  }

  // 生成缓存键
  String _generateCacheKey(String query, String? conversationUk3, String type) {
    return '${query}_${conversationUk3 ?? "all"}_$type';
  }

  // 更新类型分布统计
  void _updateTypeDistribution(List<Message> results) {
    final distribution = <String, int>{};
    for (final message in results) {
      // 暂时使用字符串表示，后续可根据实际 Message 结构调整
      final type = message.runtimeType.toString();
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    state.typeDistribution.value = distribution;
  }

  // 清空缓存
  void clearCache() {
    _searchCache.clear();
  }

  // 获取搜索建议
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().length < 2) return [];

    // 更新搜索建议
    state.updateSearchSuggestions(query.trim());
    return state.searchSuggestions;
  }

  // 高级搜索 - 带过滤器
  Future<List<Message>> advancedSearch({
    required String query,
    String? conversationUk3,
    String type = 'C2C',
    String? messageType,
    String? timeRange,
    String? sender,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int size = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // 处理时间范围
      DateTime now = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond());
      DateTime? filterStartDate = startDate;
      DateTime? filterEndDate = endDate;

      if (timeRange != null) {
        switch (timeRange) {
          case 'today':
            filterStartDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterStartDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterStartDate = now.subtract(const Duration(days: 30));
            break;
        }
      }

      // 处理发送者
      String? senderId;
      bool needFilterOther = false;
      if (sender != null && sender != 'all') {
        if (sender == 'me') {
          senderId = UserRepoLocal.to.currentUid;
        } else if (sender == 'other') {
          needFilterOther = true;
        }
      }

      var repo = MessageRepo(tableName: MessageRepo.getTableName(type));

      // 使用 page 方法进行搜索，支持高级过滤
      List<MessageModel> models = await repo.page(
        kwd: query,
        conversationUk3: conversationUk3,
        page: page,
        size: size,
        messageTypes: (messageType != null && messageType != 'all') ? [messageType] : null,
        senderId: senderId,
        startDate: filterStartDate,
        endDate: filterEndDate,
      );

      List<Message> results = [];
      for (final msg in models) {
        // 额外的 Dart 侧过滤（处理 'other' 发送者）
        if (needFilterOther && msg.fromId == UserRepoLocal.to.currentUid) {
          continue;
        }

        results.add(await msg.toTypeMessage());
      }

      return results;
    } catch (e) {
      debugPrint('Advanced search error: $e');
      return [];
    }
  }

  // 原始搜索方法（使用 FTS 优化）
  Future<List<Message>> search({
    required String type,
    int page = 1,
    int size = 100,
    String? kwd,
    String? conversationUk3,
  }) async {
    if (kwd == null || kwd.trim().isEmpty) return [];

    var repo = MessageRepo(tableName: MessageRepo.getTableName(type));

    // 使用 FTS 全文搜索
    List<MessageModel> list2 = await repo.page(
      kwd: kwd,
      conversationUk3: conversationUk3,
      page: page,
      size: size,
    );

    if (list2.isEmpty) return [];

    List<Message> list = [];
    for (int i = 0; i < list2.length; i++) {
      MessageModel msg = list2[i];
      list.add(await msg.toTypeMessage());
    }
    return list;
  }
}
