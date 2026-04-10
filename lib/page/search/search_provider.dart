import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/service/storage.dart';

part 'search_provider.g.dart';

/// Search 模块的数据状态
@immutable
class SearchDataState {
  // 搜索结果
  final List<Message> searchResults;
  final bool isLoading;
  final String currentQuery;
  final int currentPage;
  final bool hasMore;
  final String errorMessage;

  // 联系人信息缓存
  final Map<String, ContactModel> contactCache;

  // 搜索状态优化
  final bool isSearching;
  final bool showSkeleton;
  final int searchProgress;

  // 搜索历史
  final List<String> searchHistory;
  final List<String> searchSuggestions;

  // 搜索过滤器
  final String selectedMessageType;
  final String selectedTimeRange;
  final String selectedSender;
  final DateTime? startDate;
  final DateTime? endDate;

  // 搜索统计
  final int totalResults;
  final Map<String, int> typeDistribution;

  const SearchDataState({
    this.searchResults = const [],
    this.isLoading = false,
    this.currentQuery = '',
    this.currentPage = 1,
    this.hasMore = true,
    this.errorMessage = '',
    this.contactCache = const {},
    this.isSearching = false,
    this.showSkeleton = false,
    this.searchProgress = 0,
    this.searchHistory = const [],
    this.searchSuggestions = const [],
    this.selectedMessageType = 'all',
    this.selectedTimeRange = 'all',
    this.selectedSender = 'all',
    this.startDate,
    this.endDate,
    this.totalResults = 0,
    this.typeDistribution = const {},
  });

  SearchDataState copyWith({
    List<Message>? searchResults,
    bool? isLoading,
    String? currentQuery,
    int? currentPage,
    bool? hasMore,
    String? errorMessage,
    Map<String, ContactModel>? contactCache,
    bool? isSearching,
    bool? showSkeleton,
    int? searchProgress,
    List<String>? searchHistory,
    List<String>? searchSuggestions,
    String? selectedMessageType,
    String? selectedTimeRange,
    String? selectedSender,
    DateTime? startDate,
    DateTime? endDate,
    int? totalResults,
    Map<String, int>? typeDistribution,
  }) {
    return SearchDataState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      currentQuery: currentQuery ?? this.currentQuery,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      contactCache: contactCache ?? this.contactCache,
      isSearching: isSearching ?? this.isSearching,
      showSkeleton: showSkeleton ?? this.showSkeleton,
      searchProgress: searchProgress ?? this.searchProgress,
      searchHistory: searchHistory ?? this.searchHistory,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      selectedMessageType: selectedMessageType ?? this.selectedMessageType,
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      selectedSender: selectedSender ?? this.selectedSender,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalResults: totalResults ?? this.totalResults,
      typeDistribution: typeDistribution ?? this.typeDistribution,
    );
  }

  SearchDataState resetSearch() {
    return SearchDataState(
      searchResults: [],
      currentPage: 1,
      hasMore: true,
      errorMessage: '',
      totalResults: 0,
      typeDistribution: {},
      contactCache: contactCache,
      searchHistory: searchHistory,
      searchSuggestions: searchSuggestions,
      selectedMessageType: selectedMessageType,
      selectedTimeRange: selectedTimeRange,
      selectedSender: selectedSender,
      startDate: startDate,
      endDate: endDate,
    );
  }

  SearchDataState resetFilters() {
    return copyWith(
      selectedMessageType: 'all',
      selectedTimeRange: 'all',
      selectedSender: 'all',
      startDate: null,
      endDate: null,
    );
  }

  bool hasActiveFilters() {
    return selectedMessageType != 'all' ||
        selectedTimeRange != 'all' ||
        selectedSender != 'all' ||
        startDate != null ||
        endDate != null;
  }

  String getEffectiveQuery() {
    return currentQuery.trim();
  }

  bool hasSearchHistory() {
    return searchHistory.isNotEmpty;
  }

  SearchDataState cacheContact(String uid, ContactModel contact) {
    final newCache = Map<String, ContactModel>.from(contactCache);
    newCache[uid] = contact;
    if (newCache.length > 100) {
      newCache.remove(newCache.keys.first);
    }
    return copyWith(contactCache: newCache);
  }

  ContactModel? getCachedContact(String uid) {
    return contactCache[uid];
  }

  SearchDataState clearContactCache() {
    return copyWith(contactCache: {});
  }
}

/// Search Provider - 使用 @riverpod 注解
@riverpod
class SearchNotifier extends _$SearchNotifier {
  static const int _maxHistoryCount = 20;
  static const String _chatSearchHistoryKey = 'chat_search_history';

  Timer? _debounceTimer;
  final Map<String, List<Message>> _searchCache = {};

  @override
  SearchDataState build() {
    _loadSearchHistory();
    return const SearchDataState();
  }

  void _loadSearchHistory() {
    try {
      final history =
          StorageService.to.getStringList(_chatSearchHistoryKey) ?? [];
      state = state.copyWith(searchHistory: history);
    } on Exception {
      state = state.copyWith(searchHistory: []);
    }
  }

  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final List<String> history = List.from(state.searchHistory);
    history.remove(query);
    history.insert(0, query.trim());

    if (history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    await StorageService.to.setList(_chatSearchHistoryKey, history);
    state = state.copyWith(searchHistory: history);
  }

  Future<void> clearHistory() async {
    await StorageService.to.remove(_chatSearchHistoryKey);
    state = state.copyWith(searchHistory: []);
  }

  void updateSearchSuggestions(String query) {
    if (query.trim().length < 2) {
      state = state.copyWith(searchSuggestions: []);
      return;
    }

    final List<String> history = List.from(state.searchHistory);
    final List<String> suggestions = [];

    for (final item in history) {
      if (item.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item);
        if (suggestions.length >= 5) break;
      }
    }

    state = state.copyWith(searchSuggestions: suggestions);
  }

  List<String> getSearchHistory() {
    try {
      return StorageService.to.getStringList(_chatSearchHistoryKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  void resetSearch() {
    state = state.resetSearch();
  }

  void resetFilters() {
    state = state.resetFilters();
  }

  void cacheContact(String uid, ContactModel contact) {
    state = state.cacheContact(uid, contact);
  }

  ContactModel? getCachedContact(String uid) {
    return state.getCachedContact(uid);
  }

  void clearContactCache() {
    state = state.clearContactCache();
  }

  void updateSearchProgress(int progress) {
    state = state.copyWith(searchProgress: progress);
  }

  void startSearching() {
    state = state.copyWith(
      isSearching: true,
      showSkeleton: true,
      searchProgress: 0,
    );
  }

  void stopSearching() {
    state = state.copyWith(
      isSearching: false,
      showSkeleton: false,
      searchProgress: 100,
    );
  }

  void cancelSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(isLoading: false);
  }

  void updateSearchResults(List<Message> results, {bool loadMore = false}) {
    if (loadMore) {
      state = state.copyWith(
        searchResults: [...state.searchResults, ...results],
        hasMore: results.length >= 20,
        currentPage: state.currentPage + 1,
      );
    } else {
      state = state.copyWith(
        searchResults: results,
        hasMore: results.length >= 20,
        totalResults: results.length,
        currentPage: state.currentPage + 1,
      );
    }
  }

  void updateTypeDistribution(List<Message> results) {
    final distribution = <String, int>{};
    for (final message in results) {
      final type = message.runtimeType.toString();
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    state = state.copyWith(typeDistribution: distribution);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void clearCache() {
    _searchCache.clear();
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setCurrentQuery(String query) {
    state = state.copyWith(currentQuery: query);
  }
}
