import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

part 'message_search_provider.g.dart';

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

/// 消息搜索 Provider
@riverpod
class MessageSearchNotifier extends _$MessageSearchNotifier {
  static const int _maxHistoryCount = 20;
  static const String _messageSearchHistoryKey = 'message_search_history';
  static Future<void> _historyWrites = Future.value();
  static int _pendingHistoryWrites = 0;

  Timer? _debounceTimer;
  bool? _localSearchSource;
  int _searchGeneration = 0;
  bool _disposed = false;

  @override
  MessageSearchState build() {
    _disposed = false;
    UserRepoLocal.to.addAuthListener(_onAuthChanged);
    ref.onDispose(() {
      _disposed = true;
      _debounceTimer?.cancel();
      _searchGeneration++;
      UserRepoLocal.to.removeAuthListener(_onAuthChanged);
    });
    // build() 内禁止读写 state（此时 provider 尚未初始化），
    // 直接把历史记录算好作为初始状态返回。
    if (_pendingHistoryWrites > 0) {
      _reloadHistoryAfterWrites();
      return const MessageSearchState();
    }
    return MessageSearchState(searchHistory: _loadSearchHistory());
  }

  void _onAuthChanged() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _searchGeneration++;
    _localSearchSource = null;
    state = const MessageSearchState();
    if (!UserRepoLocal.to.isAuthTransitioning) _reloadHistoryAfterWrites();
  }

  void _reloadHistoryAfterWrites() {
    final session = UserRepoLocal.to;
    final generation = session.sessionGeneration;
    final key = _historyKey();
    if (key == null) return;
    _historyWrites.then((_) {
      if (!_disposed &&
          session.isCurrentSession(generation) &&
          _historyKey() == key) {
        state = state.copyWith(searchHistory: _loadSearchHistory());
      }
    });
  }

  String? _historyKey() {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    if (uid.isEmpty || session.isAuthTransitioning) return null;
    final scope = jsonEncode([Env().apiBaseUrl, uid]);
    return '${_messageSearchHistoryKey}_v2_${sha256.convert(utf8.encode(scope))}';
  }

  List<String> _loadSearchHistory() {
    try {
      final key = _historyKey();
      return key == null ? [] : StorageService.to.getStringList(key) ?? [];
    } on Exception {
      return [];
    }
  }

  /// 设置搜索范围（当前会话）
  void setSearchScope(String? conversationUk3, String? conversationTitle) {
    _searchGeneration++;
    _localSearchSource = null;
    state = state.copyWith(
      conversationUk3: conversationUk3,
      conversationTitle: conversationTitle,
      isLoading: false,
      isSearching: false,
    );
  }

  /// 清除搜索范围（切换到全局搜索）
  void clearSearchScope() {
    _searchGeneration++;
    _localSearchSource = null;
    state = state.copyWith(
      conversationUk3: null,
      conversationTitle: null,
      isLoading: false,
      isSearching: false,
    );
  }

  Future<void> _updateHistory(List<String> Function(List<String>) update) {
    final session = UserRepoLocal.to;
    final key = _historyKey();
    final generation = session.sessionGeneration;
    if (key == null) return Future.value();
    bool isCurrent() =>
        !_disposed &&
        session.isCurrentSession(generation) &&
        _historyKey() == key;
    _pendingHistoryWrites++;
    final operation = _historyWrites
        .then((_) async {
          if (!isCurrent()) return;
          final previous = List<String>.of(
            StorageService.to.getStringList(key) ?? [],
          );
          final history = update(List.of(previous));
          await StorageService.to.persistPreference(
            () => StorageService.to.setList(key, history),
          );
          if (isCurrent()) {
            state = state.copyWith(searchHistory: history);
          } else {
            await StorageService.to.persistPreference(
              () => StorageService.to.setList(key, previous),
            );
          }
        })
        .whenComplete(() => _pendingHistoryWrites--);
    _historyWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value();
    return _updateHistory((history) {
      history.remove(trimmed);
      history.insert(0, trimmed);
      if (history.length > _maxHistoryCount) {
        history.removeRange(_maxHistoryCount, history.length);
      }
      return history;
    });
  }

  Future<void> removeFromHistory(String query) => _updateHistory((history) {
    history.remove(query);
    return history;
  });

  Future<void> clearHistory() => _updateHistory((_) => []);

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
    final requestGeneration = ++_searchGeneration;
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final sessionGeneration = session.sessionGeneration;
    bool isCurrent() =>
        !_disposed &&
        requestGeneration == _searchGeneration &&
        session.currentUid == uid &&
        session.isCurrentSession(sessionGeneration) &&
        !session.isAuthTransitioning;
    if (!loadMore) _localSearchSource = null;

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
      final localResults = _localSearchSource == false
          ? null
          : await _searchLocal(
              effectiveQuery,
              page: page,
              isCurrent: isCurrent,
            );
      if (!isCurrent()) return;
      if (localResults != null) {
        _localSearchSource = true;
        _applySearchResults(
          localResults,
          loadMore: loadMore,
          page: page,
          isCurrent: isCurrent,
        );
        if (!loadMore) await addToHistory(effectiveQuery);
        return;
      }
      if (loadMore && _localSearchSource == true) {
        throw Exception('Local search failed while loading more');
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

      if (!isCurrent()) return;
      if (response != null) {
        _localSearchSource = false;
        _applySearchResults(
          response,
          loadMore: loadMore,
          page: page,
          isCurrent: isCurrent,
        );
        if (!loadMore) await addToHistory(effectiveQuery);
      } else {
        state = state.copyWith(
          isLoading: false,
          isSearching: false,
          errorMessage: t.common.searchFailedRetry,
          searchDisabled: false,
        );
      }
    } on FtsFeatureDisabledException {
      if (!isCurrent()) return;
      // 后端按策略关掉了消息搜索（E2EE 模式），不是故障。
      // 文案统一走 i18n，不再用异常里那句硬编码中文。
      state = state.copyWith(
        isLoading: false,
        isSearching: false,
        errorMessage: t.common.searchDisabledByEncryption,
        searchDisabled: true,
      );
    } on Exception catch (e) {
      if (!isCurrent()) return;
      iPrint('[MessageSearch] 搜索消息失败: $e');
      state = state.copyWith(
        isLoading: false,
        isSearching: false,
        errorMessage: t.common.searchFailedRetry,
        searchDisabled: false,
      );
    }
  }

  /// 本地 FTS 搜索
  ///
  /// 返回 null 表示 FTS 不可用或查询失败，应降级到服务端
  Future<MessageSearchResponse?> _searchLocal(
    String query, {
    int page = 1,
    required bool Function() isCurrent,
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
          type: state.selectedType,
          startTime: state.getStartTimeStamp(),
          endTime: state.getEndTimeStamp(),
          throwOnError: true,
          isCurrent: isCurrent,
          limit: page * limit,
        );
      } else {
        // 全局搜索
        ftsResults = await ftsRepo.searchAll(
          query: query,
          type: state.selectedType,
          startTime: state.getStartTimeStamp(),
          endTime: state.getEndTimeStamp(),
          throwOnError: true,
          isCurrent: isCurrent,
          limit: page * limit,
        );
      }

      if (!isCurrent()) return null;
      if (ftsResults.isEmpty) {
        return page > 1 ? MessageSearchResponse(items: [], total: 0) : null;
      }
      ftsResults = ftsResults.skip((page - 1) * limit).toList();
      if (ftsResults.isEmpty) {
        return MessageSearchResponse(items: [], total: 0);
      }

      // FTS 表只存 (id, conversation_uk3, text_content)，缺少 from/to/created_at。
      // 需要回查消息表补全元数据，否则 UI 会显示 "Loading..." 和 "1970-01-01"。
      final db = SqliteService.to;
      final items = <MessageSearchResult>[];

      for (final fts in ftsResults) {
        if (!isCurrent()) return null;
        // 从 conversationUk3 前缀推断消息表和类型
        final uk3 = fts.conversationUk3;
        final isC2G = uk3.startsWith('C2G_');
        final msgType = isC2G ? 'C2G' : 'C2C';
        final tableName = isC2G ? 'msg_c2g' : 'msg_c2c';

        final rows = await db.rawQuery(
          'SELECT CAST(from_id AS TEXT) AS from_id, CAST(to_id AS TEXT) AS to_id, created_at FROM $tableName WHERE id = ? LIMIT 1',
          [fts.id],
          false,
          5000,
          true,
        );
        if (!isCurrent()) return null;
        if (rows.isNotEmpty) {
          final row = rows.first;
          items.add(
            MessageSearchResult(
              id: fts.id,
              content: fts.snippet,
              fromId: '${row['from_id'] ?? ''}',
              toId: '${row['to_id'] ?? ''}',
              type: msgType,
              createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
            ),
          );
        } else {
          // FTS 索引里有但消息表里没有（可能已删除），跳过
          continue;
        }
      }

      if (items.isEmpty) return null;

      return MessageSearchResponse(items: items, total: items.length);
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
    required bool Function() isCurrent,
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
    _preloadContacts(response.items, isCurrent);
  }

  /// 预加载联系人信息
  Future<void> _preloadContacts(
    List<MessageSearchResult> results,
    bool Function() isCurrent,
  ) async {
    final uids = <String>{};
    for (final result in results) {
      if (result.fromId.isNotEmpty) uids.add(result.fromId);
      if (result.toId.isNotEmpty) uids.add(result.toId);
    }

    for (final uid in uids) {
      if (!isCurrent()) return;
      if (state.getCachedContact(uid) == null) {
        try {
          final contact = await ContactRepo().findByUid(uid);
          if (!isCurrent()) return;
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
    _searchGeneration++;
    _localSearchSource = null;
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
    _searchGeneration++;
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
