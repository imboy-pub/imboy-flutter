import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

import 'message_search_state.dart';
import 'search_result_expiry.dart';

export 'message_search_state.dart';

part 'message_search_provider.g.dart';

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
  SearchResultExpiry? _resultExpiry;
  int _visibilityGeneration = 0;

  int get searchGeneration => _searchGeneration;

  @override
  MessageSearchState build() {
    _disposed = false;
    _resultExpiry = SearchResultExpiry(
      removeExpiredResults,
      onResume: () => unawaited(refreshVisibleResults()),
    );
    UserRepoLocal.to.addAuthListener(_onAuthChanged);
    ref.onDispose(() {
      _disposed = true;
      _debounceTimer?.cancel();
      _resultExpiry?.dispose();
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
    _resultExpiry?.cancel();
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

      // 仅本地 FTS 不可用或查询失败时降级；成功的空结果已在上面返回。
      MessageSearchResponse? response;
      while (true) {
        if (state.conversationUk3 != null &&
            state.conversationUk3!.isNotEmpty) {
          response = await ref
              .read(ftsApiProvider)
              .searchConversationMessages(
                keyword: effectiveQuery,
                conversationUk3: state.conversationUk3!,
                page: page,
                size: 20,
              );
        } else {
          response = await ref
              .read(ftsApiProvider)
              .searchMessages(
                keyword: effectiveQuery,
                page: page,
                size: 20,
                type: state.selectedType,
                startTime: state.getStartTimeStamp(),
                endTime: state.getEndTimeStamp(),
              );
        }
        if (!isCurrent()) return;
        if (response == null ||
            response.items.isNotEmpty ||
            response.sourceItemCount < 20) {
          break;
        }
        // 客户端到期过滤可能清空满页；继续既有远端分页，不能用空态
        // 隐藏后续仍有效的命中。每次 await 后保留取消/账号栅栏。
        page++;
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
        return MessageSearchResponse(items: [], total: 0);
      }
      // 到期/删除会让可见列表收缩，旧 offset 会跨过尚未展示的下一条。
      // 保持现有前缀查询上限，只排除本次搜索已展示的业务消息。
      final seen = page > 1
          ? state.searchResults.map((item) => '${item.type}:${item.id}').toSet()
          : <String>{};
      ftsResults = ftsResults
          .where((item) {
            final type = item.conversationUk3.startsWith('C2G_')
                ? 'C2G'
                : 'C2C';
            return !seen.contains('$type:${item.id}');
          })
          .take(limit)
          .toList();
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
          'SELECT CAST(from_id AS TEXT) AS from_id, CAST(to_id AS TEXT) AS to_id, created_at, payload, msg_type, status, is_author FROM $tableName WHERE id = ? LIMIT 1',
          [fts.id],
          false,
          5000,
          true,
        );
        if (!isCurrent()) return null;
        if (rows.isNotEmpty) {
          final row = rows.first;
          final payload = parseModelJsonMap(row['payload']);
          if (payload == null) continue;
          items.add(
            MessageSearchResult(
              id: fts.id,
              content: fts.snippet,
              fromId: '${row['from_id'] ?? ''}',
              toId: '${row['to_id'] ?? ''}',
              type: msgType,
              createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
              payload: payload,
              msgType: parseModelNullableString(row['msg_type']),
              status: row['status'] == null
                  ? null
                  : parseModelInt(row['status']),
              isAuthor: row['is_author'] == null
                  ? null
                  : parseModelInt(row['is_author']),
              localRowObserved: true,
            ),
          );
        } else {
          // FTS 索引里有但消息表里没有（可能已删除），跳过
          continue;
        }
      }

      // 回查期间删除/到期也是有效的本地空结果，不能用远端旧副本复活。
      return MessageSearchResponse(
        items: items,
        total: items.length,
        sourceItemCount: ftsResults.length,
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
    required bool Function() isCurrent,
  }) {
    final uid = UserRepoLocal.to.currentUid;
    final nowMs = DateTimeHelper.millisecond();
    final items = response.items
        .where((item) => item.isVisibleAt(nowMs, uid))
        .toList();
    final removed = response.items.length - items.length;
    if (loadMore) {
      state = state.copyWith(
        searchResults: [...state.searchResults, ...items],
        currentPage: page,
        hasMore: response.sourceItemCount >= 20,
        totalResults: state.totalResults + items.length,
        isLoading: false,
        isSearching: false,
      );
    } else {
      state = state.copyWith(
        searchResults: items,
        currentPage: page,
        hasMore: response.sourceItemCount >= 20,
        totalResults: response.total > removed ? response.total - removed : 0,
        isLoading: false,
        isSearching: false,
      );
    }

    // 预加载联系人信息
    removeExpiredResults();
    _preloadContacts(items, isCurrent);
  }

  /// 计时器、恢复前台及点击前共用；只剔除已知到期内容，不触发新的搜索。
  void removeExpiredResults() {
    if (_disposed) return;
    final uid = UserRepoLocal.to.currentUid;
    final nowMs = DateTimeHelper.millisecond();
    final items = state.searchResults
        .where((item) => item.isVisibleAt(nowMs, uid))
        .toList();
    final removed = state.searchResults.length - items.length;
    if (removed > 0) {
      state = state.copyWith(
        searchResults: items,
        totalResults: state.totalResults > removed
            ? state.totalResults - removed
            : 0,
      );
    }
    _resultExpiry?.schedule(items.map((item) => item.expiresAtMs(uid)));
  }

  void removeResult(String id) {
    if (_disposed) return;
    final remaining = state.searchResults
        .where((item) => item.id != id)
        .toList();
    final removed = state.searchResults.length - remaining.length;
    state = state.copyWith(
      searchResults: remaining,
      totalResults: state.totalResults > removed
          ? state.totalResults - removed
          : 0,
    );
    removeExpiredResults();
  }

  /// 搜索时尚未读的消息可能在聊天页/后台开始计时，恢复展示时重读本机事实。
  Future<void> refreshVisibleResults() async {
    if (_disposed) return;
    removeExpiredResults();
    final snapshot = List<MessageSearchResult>.of(state.searchResults);
    if (snapshot.isEmpty) return;
    final request = _searchGeneration;
    final refresh = ++_visibilityGeneration;
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool current() =>
        !_disposed &&
        request == _searchGeneration &&
        refresh == _visibilityGeneration &&
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isAuthTransitioning;
    final refreshed = <MessageSearchResult>[];
    for (final item in snapshot) {
      if (!current()) return;
      final resolved = await ref
          .read(ftsApiProvider)
          .refreshResultVisibility(item);
      if (!current()) return;
      if (resolved != null) refreshed.add(resolved);
    }
    // 同期计时器已剔除的条目不能被较早发起的回查重新加回。
    final present = state.searchResults
        .map((item) => '${item.type}:${item.id}')
        .toSet();
    final items = refreshed
        .where((item) => present.contains('${item.type}:${item.id}'))
        .toList();
    final removed = state.searchResults.length - items.length;
    state = state.copyWith(
      searchResults: items,
      totalResults: state.totalResults > removed
          ? state.totalResults - removed
          : 0,
    );
    removeExpiredResults();
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
    _resultExpiry?.cancel();
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
