import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/service/storage.dart';

part 'message_search_provider.g.dart';

/// 消息搜索数据状态
@immutable
class MessageSearchState {
  // 搜索结果
  final List<MessageSearchResult> searchResults;
  final bool isLoading;
  final String currentQuery;
  final int currentPage;
  final bool hasMore;
  final String errorMessage;
  final int totalResults;

  // 联系人信息缓存
  final Map<String, ContactModel> contactCache;

  // 会话信息缓存
  final Map<String, ConversationModel> conversationCache;

  // 搜索状态
  final bool isSearching;

  // 搜索历史
  final List<String> searchHistory;

  // 搜索过滤器
  final String selectedType; // all, C2C, C2G
  final String selectedTimeRange; // all, today, week, month
  final DateTime? startDate;
  final DateTime? endDate;

  // 搜索范围：全局搜索或当前会话
  final String? conversationUk3;
  final String? conversationTitle;

  const MessageSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.currentQuery = '',
    this.currentPage = 1,
    this.hasMore = true,
    this.errorMessage = '',
    this.totalResults = 0,
    this.contactCache = const {},
    this.conversationCache = const {},
    this.isSearching = false,
    this.searchHistory = const [],
    this.selectedType = 'all',
    this.selectedTimeRange = 'all',
    this.startDate,
    this.endDate,
    this.conversationUk3,
    this.conversationTitle,
  });

  MessageSearchState copyWith({
    List<MessageSearchResult>? searchResults,
    bool? isLoading,
    String? currentQuery,
    int? currentPage,
    bool? hasMore,
    String? errorMessage,
    int? totalResults,
    Map<String, ContactModel>? contactCache,
    Map<String, ConversationModel>? conversationCache,
    bool? isSearching,
    List<String>? searchHistory,
    String? selectedType,
    String? selectedTimeRange,
    DateTime? startDate,
    DateTime? endDate,
    String? conversationUk3,
    String? conversationTitle,
  }) {
    return MessageSearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      currentQuery: currentQuery ?? this.currentQuery,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      totalResults: totalResults ?? this.totalResults,
      contactCache: contactCache ?? this.contactCache,
      conversationCache: conversationCache ?? this.conversationCache,
      isSearching: isSearching ?? this.isSearching,
      searchHistory: searchHistory ?? this.searchHistory,
      selectedType: selectedType ?? this.selectedType,
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      conversationUk3: conversationUk3 ?? this.conversationUk3,
      conversationTitle: conversationTitle ?? this.conversationTitle,
    );
  }

  MessageSearchState resetSearch() {
    return copyWith(
      searchResults: [],
      currentPage: 1,
      hasMore: true,
      errorMessage: '',
      totalResults: 0,
      isSearching: false,
    );
  }

  MessageSearchState resetFilters() {
    return copyWith(
      selectedType: 'all',
      selectedTimeRange: 'all',
      startDate: null,
      endDate: null,
    );
  }

  bool hasActiveFilters() {
    return selectedType != 'all' ||
        selectedTimeRange != 'all' ||
        startDate != null ||
        endDate != null;
  }

  /// 获取时间范围的时间戳
  int? getStartTimeStamp() {
    if (startDate != null) {
      return startDate!.millisecondsSinceEpoch;
    }
    if (selectedTimeRange == 'today') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    }
    if (selectedTimeRange == 'week') {
      final now = DateTime.now();
      return now.subtract(Duration(days: 7)).millisecondsSinceEpoch;
    }
    if (selectedTimeRange == 'month') {
      final now = DateTime.now();
      return DateTime(now.year, now.month - 1, now.day).millisecondsSinceEpoch;
    }
    return null;
  }

  int? getEndTimeStamp() {
    if (endDate != null) {
      return endDate!.millisecondsSinceEpoch;
    }
    return null;
  }

  MessageSearchState cacheContact(String uid, ContactModel contact) {
    final newCache = Map<String, ContactModel>.from(contactCache);
    newCache[uid] = contact;
    // 限制缓存大小，使用 FIFO 淘汰策略。
    // 对于搜索场景，缓存条目生命周期短且命中率差异不大，FIFO 足够。
    if (newCache.length > 100) {
      newCache.remove(newCache.keys.first);
    }
    return copyWith(contactCache: newCache);
  }

  ContactModel? getCachedContact(String uid) {
    return contactCache[uid];
  }

  MessageSearchState cacheConversation(String uk3, ConversationModel conv) {
    final newCache = Map<String, ConversationModel>.from(conversationCache);
    newCache[uk3] = conv;
    // FIFO 淘汰策略，理由同 cacheContact
    if (newCache.length > 50) {
      newCache.remove(newCache.keys.first);
    }
    return copyWith(conversationCache: newCache);
  }

  ConversationModel? getCachedConversation(String uk3) {
    return conversationCache[uk3];
  }
}

/// 消息搜索 Provider
@riverpod
class MessageSearchNotifier extends _$MessageSearchNotifier {
  static const int _maxHistoryCount = 20;
  static const String _messageSearchHistoryKey = 'message_search_history';

  Timer? _debounceTimer;

  @override
  MessageSearchState build() {
    _loadSearchHistory();
    return const MessageSearchState();
  }

  void _loadSearchHistory() {
    try {
      final history =
          StorageService.to.getStringList(_messageSearchHistoryKey) ?? [];
      state = state.copyWith(searchHistory: history);
    } on Exception {
      state = state.copyWith(searchHistory: []);
    }
  }

  /// 设置搜索范围（当前会话）
  void setSearchScope(String? conversationUk3, String? conversationTitle) {
    state = state.copyWith(
      conversationUk3: conversationUk3,
      conversationTitle: conversationTitle,
    );
  }

  /// 清除搜索范围（切换到全局搜索）
  void clearSearchScope() {
    state = state.copyWith(conversationUk3: null, conversationTitle: null);
  }

  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final List<String> history = List.from(state.searchHistory);
    history.remove(query);
    history.insert(0, query.trim());

    if (history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    await StorageService.to.setList(_messageSearchHistoryKey, history);
    state = state.copyWith(searchHistory: history);
  }

  Future<void> removeFromHistory(String query) async {
    final List<String> history = List.from(state.searchHistory);
    history.remove(query);

    await StorageService.to.setList(_messageSearchHistoryKey, history);
    state = state.copyWith(searchHistory: history);
  }

  Future<void> clearHistory() async {
    await StorageService.to.remove(_messageSearchHistoryKey);
    state = state.copyWith(searchHistory: []);
  }

  /// 防抖搜索
  void debouncedSearch(String query, {int debounceMs = 300}) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      resetSearch();
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      performSearch(query: query);
    });
  }

  /// 执行搜索（优先本地 FTS，降级到服务端 API）
  Future<void> performSearch({
    required String query,
    bool loadMore = false,
  }) async {
    if (query.trim().isEmpty) return;

    final effectiveQuery = query.trim();

    // 设置搜索状态
    state = state.copyWith(
      currentQuery: effectiveQuery,
      isLoading: true,
      isSearching: true,
      errorMessage: '',
    );

    try {
      int page = loadMore ? state.currentPage + 1 : 1;

      // 优先尝试本地 FTS 搜索
      final localResults = await _searchLocal(effectiveQuery, page: page);
      if (localResults != null) {
        _applySearchResults(localResults, loadMore: loadMore, page: page);
        if (!loadMore) await addToHistory(effectiveQuery);
        return;
      }

      // 本地 FTS 无结果或不可用，降级到服务端 API
      MessageSearchResponse? response;

      if (state.conversationUk3 != null && state.conversationUk3!.isNotEmpty) {
        response = await FtsApi.to.searchConversationMessages(
          keyword: effectiveQuery,
          conversationUk3: state.conversationUk3!,
          page: page,
          size: 20,
        );
      } else {
        response = await FtsApi.to.searchMessages(
          keyword: effectiveQuery,
          page: page,
          size: 20,
          type: state.selectedType,
          startTime: state.getStartTimeStamp(),
          endTime: state.getEndTimeStamp(),
        );
      }

      if (response != null) {
        _applySearchResults(response, loadMore: loadMore, page: page);
        if (!loadMore) await addToHistory(effectiveQuery);
      } else {
        state = state.copyWith(
          isLoading: false,
          isSearching: false,
          errorMessage: '搜索失败，请重试',
        );
      }
    } on Exception {
      state = state.copyWith(
        isLoading: false,
        isSearching: false,
        errorMessage: '搜索失败，请重试',
      );
    }
  }

  /// 本地 FTS 搜索
  ///
  /// 返回 null 表示 FTS 不可用或查询失败，应降级到服务端
  Future<MessageSearchResponse?> _searchLocal(
    String query, {
    int page = 1,
  }) async {
    try {
      final ftsRepo = MessageFtsRepo();
      final limit = 20;

      List<FtsSearchResult> ftsResults;

      if (state.conversationUk3 != null && state.conversationUk3!.isNotEmpty) {
        // 会话内搜索
        ftsResults = await ftsRepo.searchAll(
          query: query,
          conversationUk3: state.conversationUk3,
          limit: limit,
        );
      } else {
        // 全局搜索
        ftsResults = await ftsRepo.searchAll(
          query: query,
          limit: limit,
        );
      }

      if (ftsResults.isEmpty) return null;

      // 转换为 MessageSearchResult
      final items = ftsResults.map((fts) {
        return MessageSearchResult(
          id: fts.id,
          content: fts.snippet,
          fromId: '',
          toId: '',
          type: '',
          createdAt: 0,
        );
      }).toList();

      return MessageSearchResponse(
        items: items,
        total: items.length,
      );
    } on Exception {
      // FTS 查询失败，降级到服务端
      return null;
    }
  }

  /// 应用搜索结果到状态
  void _applySearchResults(
    MessageSearchResponse response, {
    required bool loadMore,
    required int page,
  }) {
    if (loadMore) {
      state = state.copyWith(
        searchResults: [...state.searchResults, ...response.items],
        currentPage: page,
        hasMore: response.items.length >= 20,
        totalResults: state.totalResults + response.items.length,
        isLoading: false,
        isSearching: false,
      );
    } else {
      state = state.copyWith(
        searchResults: response.items,
        currentPage: page,
        hasMore: response.items.length >= 20,
        totalResults: response.total,
        isLoading: false,
        isSearching: false,
      );
    }

    // 预加载联系人信息
    _preloadContacts(response.items);
  }

  /// 预加载联系人信息
  Future<void> _preloadContacts(List<MessageSearchResult> results) async {
    final uids = <String>{};
    for (final result in results) {
      if (result.fromId.isNotEmpty) uids.add(result.fromId);
      if (result.toId.isNotEmpty) uids.add(result.toId);
    }

    for (final uid in uids) {
      if (state.getCachedContact(uid) == null) {
        try {
          final contact = await ContactRepo().findByUid(uid);
          if (contact != null) {
            state = state.cacheContact(uid, contact);
          }
        } on Exception {
          // 忽略错误
        }
      }
    }
  }

  /// 加载更多结果
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await performSearch(query: state.currentQuery, loadMore: true);
  }

  /// 重置搜索
  void resetSearch() {
    _debounceTimer?.cancel();
    state = state.resetSearch();
  }

  /// 重置过滤器
  void resetFilters() {
    state = state.resetFilters();
    if (state.currentQuery.isNotEmpty) {
      performSearch(query: state.currentQuery);
    }
  }

  /// 设置类型过滤器
  void setTypeFilter(String type) {
    state = state.copyWith(selectedType: type);
    if (state.currentQuery.isNotEmpty) {
      performSearch(query: state.currentQuery);
    }
  }

  /// 设置时间范围过滤器
  void setTimeRangeFilter(String timeRange) {
    state = state.copyWith(
      selectedTimeRange: timeRange,
      startDate: null,
      endDate: null,
    );
    if (state.currentQuery.isNotEmpty) {
      performSearch(query: state.currentQuery);
    }
  }

  /// 设置自定义时间范围
  void setCustomDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      selectedTimeRange: 'custom',
      startDate: start,
      endDate: end,
    );
    if (state.currentQuery.isNotEmpty) {
      performSearch(query: state.currentQuery);
    }
  }

  void cancelSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(isLoading: false, isSearching: false);
  }

  /// 缓存联系人信息（公开方法）
  void cacheContact(String uid, ContactModel contact) {
    state = state.cacheContact(uid, contact);
  }

  /// 缓存会话信息
  Future<void> cacheConversationInfo(String uk3) async {
    if (state.getCachedConversation(uk3) != null) return;

    try {
      final parts = uk3.split('_');
      if (parts.length >= 3) {
        final type = parts[0];
        final peerId = parts.sublist(1).join('_');
        final conv = await ConversationRepo().findByPeerId(type, peerId);
        if (conv != null) {
          state = state.cacheConversation(uk3, conv);
        }
      }
    } on Exception {
      // 忽略错误
    }
  }
}
