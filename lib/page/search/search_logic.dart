import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'search_state.dart';

class SearchLogic extends GetxController {
  final state = SearchState();

  // 防抖定时器
  Timer? _debounceTimer;
  // 搜索缓存
  final Map<String, List<Message>> _searchCache = {};
  // 取消标记
  bool _isCancelled = false;

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
      return;
    }

    _isCancelled = false;

    if (!loadMore) {
      state.resetSearch();
      state.currentQuery.value = effectiveQuery;
      state.isLoading.value = true;
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
        state.errorMessage.value = 'searchNoFound'.tr;
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
        state.errorMessage.value = 'searchError'.tr;
        debugPrint('Search error: $e');
      }
    } finally {
      state.isLoading.value = false;
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

      // 构建查询条件
      String where = "1=1";
      List<Object?> whereArgs = [];

      // 基础文本搜索
      where = "$where AND (json_extract(payload, '\$.text') LIKE ? OR json_extract(payload, '\$.quote_text') LIKE ? OR json_extract(payload, '\$.title') LIKE ?)";
      final likePattern = "%${query.trim()}%";
      whereArgs.addAll([likePattern, likePattern, likePattern]);

      // 会话过滤
      if (strNoEmpty(conversationUk3)) {
        where = "$where AND conversation_uk3 = ?";
        whereArgs.add(conversationUk3);
      }

      // 消息类型过滤
      if (messageType != null && messageType != 'all') {
        where = "$where AND type = ?";
        whereArgs.add(messageType);
      }

      // 发送者过滤
      if (sender != null && sender != 'all') {
        if (sender == 'me') {
          where = "$where AND from_id = ?";
          whereArgs.add(UserRepoLocal.to.currentUid);
        } else {
          where = "$where AND from_id != ?";
          whereArgs.add(UserRepoLocal.to.currentUid);
        }
      }

      // 时间范围过滤
      DateTime now = DateTime.now();
      DateTime? filterStartDate;
      DateTime? filterEndDate;

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

      // 自定义日期范围
      if (startDate != null) filterStartDate = startDate;
      if (endDate != null) filterEndDate = endDate;

      if (filterStartDate != null) {
        where = "$where AND created_at >= ?";
        whereArgs.add(filterStartDate.millisecondsSinceEpoch);
      }

      if (filterEndDate != null) {
        where = "$where AND created_at <= ?";
        whereArgs.add(filterEndDate.millisecondsSinceEpoch);
      }

      // 创建临时消息仓库来执行高级查询
      var tempRepo = MessageRepo(tableName: MessageRepo.getTableName(type));
      List<MessageModel> tempResults = await tempRepo.page(
        page: page,
        size: size,
        kwd: query.trim(),
        conversationUk3: conversationUk3,
        orderBy: "created_at DESC",
      );

      if (tempResults.isEmpty) return [];

      List<Message> results = [];
      for (final msg in tempResults) {
        // 应用额外的过滤器
        bool matchesFilter = true;

        // 消息类型过滤
        if (messageType != null && messageType != 'all') {
          if (msg.type != messageType) {
            matchesFilter = false;
          }
        }

        // 发送者过滤
        if (sender != null && sender != 'all') {
          if (sender == 'me' && msg.fromId != UserRepoLocal.to.currentUid) {
            matchesFilter = false;
          } else if (sender == 'other' && msg.fromId == UserRepoLocal.to.currentUid) {
            matchesFilter = false;
          }
        }

        // 时间范围过滤
        if (filterStartDate != null && msg.createdAt != null) {
          DateTime msgDateTime;
          if (msg.createdAt is int) {
            msgDateTime = DateTime.fromMillisecondsSinceEpoch(msg.createdAt as int);
          } else if (msg.createdAt is DateTime) {
            msgDateTime = msg.createdAt as DateTime;
          } else {
            msgDateTime = DateTime.now(); // 默认值
          }
          if (msgDateTime.isBefore(filterStartDate)) {
            matchesFilter = false;
          }
        }

        if (filterEndDate != null && msg.createdAt != null) {
          DateTime msgDateTime;
          if (msg.createdAt is int) {
            msgDateTime = DateTime.fromMillisecondsSinceEpoch(msg.createdAt as int);
          } else if (msg.createdAt is DateTime) {
            msgDateTime = msg.createdAt as DateTime;
          } else {
            msgDateTime = DateTime.now(); // 默认值
          }
          if (msgDateTime.isAfter(filterEndDate)) {
            matchesFilter = false;
          }
        }

        if (matchesFilter) {
          results.add(await msg.toTypeMessage());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Advanced search error: $e');
      return [];
    }
  }

  // 原始搜索方法（保持向后兼容）
  Future<List<Message>> search({
    required String type,
    int page = 1,
    int size = 100,
    String? kwd,
    String? conversationUk3,
  }) async {
    if (kwd == null || kwd.trim().isEmpty) return [];

    var repo = MessageRepo(tableName: MessageRepo.getTableName(type));
    String? orderBy;

    List<MessageModel> list2 = await repo.page(
      page: page,
      size: size,
      kwd: kwd,
      conversationUk3: conversationUk3,
      orderBy: orderBy,
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
