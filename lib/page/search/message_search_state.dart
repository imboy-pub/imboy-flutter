import 'package:flutter/foundation.dart' show immutable;
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 消息搜索数据状态
@immutable
class MessageSearchState {
  static const Object _unchanged = Object();
  // 搜索结果
  final List<MessageSearchResult> searchResults;
  final bool isLoading;
  final String currentQuery;
  final int currentPage;
  final bool hasMore;
  final String errorMessage;

  /// 搜索被后端策略禁用（E2EE 模式下服务端读不到明文，无法做全文搜索）。
  /// 与 errorMessage 分开，是因为这不是"出错"而是"用不了"——
  /// 重试多少次都不会成功，UI 不该给重试按钮（QA#7）。
  final bool searchDisabled;
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
    this.searchDisabled = false,
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
    bool? searchDisabled,
    int? totalResults,
    Map<String, ContactModel>? contactCache,
    Map<String, ConversationModel>? conversationCache,
    bool? isSearching,
    List<String>? searchHistory,
    String? selectedType,
    String? selectedTimeRange,
    Object? startDate = _unchanged,
    Object? endDate = _unchanged,
    Object? conversationUk3 = _unchanged,
    Object? conversationTitle = _unchanged,
  }) {
    return MessageSearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      currentQuery: currentQuery ?? this.currentQuery,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      searchDisabled: searchDisabled ?? this.searchDisabled,
      totalResults: totalResults ?? this.totalResults,
      contactCache: contactCache ?? this.contactCache,
      conversationCache: conversationCache ?? this.conversationCache,
      isSearching: isSearching ?? this.isSearching,
      searchHistory: searchHistory ?? this.searchHistory,
      selectedType: selectedType ?? this.selectedType,
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      startDate: identical(startDate, _unchanged)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, _unchanged)
          ? this.endDate
          : endDate as DateTime?,
      conversationUk3: identical(conversationUk3, _unchanged)
          ? this.conversationUk3
          : conversationUk3 as String?,
      conversationTitle: identical(conversationTitle, _unchanged)
          ? this.conversationTitle
          : conversationTitle as String?,
    );
  }

  MessageSearchState resetSearch() {
    return copyWith(
      // 必须清 currentQuery：UI 靠它是否非空渲染筛选栏、内容区也靠它切历史/空态；
      // 不清的话点筛选 chips 会用旧词重发搜索（BUG#130）。
      currentQuery: '',
      searchResults: [],
      currentPage: 1,
      hasMore: true,
      errorMessage: '',
      totalResults: 0,
      isLoading: false,
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
