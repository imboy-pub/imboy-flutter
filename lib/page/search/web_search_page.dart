/// Web 端全局搜索页面 - WhatsApp Web 风格
///
/// 功能：
/// - 全局消息搜索
/// - 联系人搜索
/// - 群组搜索
/// - 搜索历史记录
library;

import 'dart:async';

import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'web_search_state.dart';
import 'web_search_result_tile.dart';
import 'search_result_expiry.dart';

part 'web_search_sources.dart';

@visibleForTesting
String searchMessageRoute(String conversationId, String? type) =>
    '/chat/$conversationId${type == 'C2G' ? '?type=C2G' : ''}';

enum WebMessageSearchFailure { unavailable, disabled }

class _WebSearchHistoryChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}

@visibleForTesting
void resetWebSearchHistoryQueueForTest() {
  if (_WebSearchPageState._pendingHistoryWrites != 0) {
    throw StateError('Cannot reset history queue with pending writes');
  }
  _WebSearchPageState._historyWrites = Future<void>.value();
}

@visibleForTesting
Future<(List<SearchItem>, WebMessageSearchFailure?)> runWebMessageSearch(
  Future<List<SearchItem>> Function() search,
) async {
  try {
    return (await search(), null);
  } on FtsFeatureDisabledException {
    return (<SearchItem>[], WebMessageSearchFailure.disabled);
  } catch (_) {
    return (<SearchItem>[], WebMessageSearchFailure.unavailable);
  }
}

/// Web 全局搜索页面
class WebSearchPage extends ConsumerStatefulWidget {
  /// 初始搜索关键词
  final String? initialQuery;

  /// 搜索范围（可选）
  final String? scope; // 'all', 'messages', 'contacts', 'groups'

  @visibleForTesting
  final Future<List<SearchItem>> Function(String)? messageSearchForTest;
  @visibleForTesting
  final Future<List<SearchItem>> Function(String)? otherSearchForTest;
  @visibleForTesting
  final Listenable? authChangesForTest;
  @visibleForTesting
  final Future<void> Function(Future<void> Function())? persistHistoryForTest;
  @visibleForTesting
  final bool Function()? authTransitioningForTest;

  const WebSearchPage({
    super.key,
    this.initialQuery,
    this.scope,
    this.messageSearchForTest,
    this.otherSearchForTest,
    this.authChangesForTest,
    this.persistHistoryForTest,
    this.authTransitioningForTest,
  });

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

class _WebSearchPageState extends ConsumerState<WebSearchPage>
    with _WebSearchSources {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  @override
  ScrollController get _searchScrollController => _scrollController;

  Timer? _debounceTimer;
  late final SearchResultExpiry _resultExpiry;
  @override
  WebSearchState _state = const WebSearchState();
  @override
  int _searchGeneration = 0;
  int _visibilityGeneration = 0;
  static Future<void> _historyWrites = Future.value();
  static int _pendingHistoryWrites = 0;
  static final _historyChanges = _WebSearchHistoryChanges();

  @override
  void initState() {
    super.initState();
    _resultExpiry = SearchResultExpiry(
      _removeExpiredResults,
      onResume: () => unawaited(_refreshResultFacts()),
    );
    _historyChanges.addListener(_reloadHistoryAfterWrites);
    if (widget.authChangesForTest case final changes?) {
      changes.addListener(_onAuthChanged);
    } else {
      UserRepoLocal.to.addAuthListener(_onAuthChanged);
    }

    // 设置初始搜索词
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }

    // 加载最近搜索记录
    _reloadHistoryAfterWrites();

    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resultExpiry.dispose();
    _historyChanges.removeListener(_reloadHistoryAfterWrites);
    if (widget.authChangesForTest case final changes?) {
      changes.removeListener(_onAuthChanged);
    } else {
      UserRepoLocal.to.removeAuthListener(_onAuthChanged);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _resultExpiry.cancel();
    _debounceTimer?.cancel();
    _searchGeneration++;
    _searchController.clear();
    setState(() {
      _state = const WebSearchState();
      _sourceFailures.clear();
      _retryingSources.clear();
      _authSearchBlocked = false;
    });
    _reloadHistoryAfterWrites();
  }

  @visibleForTesting
  Future<void> runSearchForTest(String query) => _performSearch(query);

  @visibleForTesting
  bool get historyWritesPendingForTest => _pendingHistoryWrites > 0;

  @visibleForTesting
  Future<void> get historyWritesForTest => _historyWrites;

  /// 加载最近搜索记录
  @visibleForTesting
  static String? historyKeyForScope(String endpoint, String uid) {
    if (uid.isEmpty) return null;
    return 'web_search_history_v2_${sha256.convert(utf8.encode(jsonEncode([endpoint, uid])))}';
  }

  String? _historyKey() {
    final user = UserRepoLocal.to;
    if (_isAuthTransitioning) return null;
    return historyKeyForScope(Env().apiBaseUrl, user.currentUid);
  }

  @override
  bool get _isAuthTransitioning =>
      widget.authTransitioningForTest?.call() ??
      UserRepoLocal.to.isAuthTransitioning;

  List<String> _loadRecentSearches() {
    try {
      final key = _historyKey();
      return key == null ? [] : StorageService.to.getStringList(key) ?? [];
    } on Exception {
      return [];
    }
  }

  void _reloadHistoryAfterWrites() {
    final user = UserRepoLocal.to;
    final generation = user.sessionGeneration;
    final key = _historyKey();
    if (key == null) return;
    void load() {
      if (!mounted ||
          !user.isCurrentSession(generation) ||
          _historyKey() != key) {
        return;
      }
      setState(
        () => _state = _state.copyWith(recentSearches: _loadRecentSearches()),
      );
    }

    if (_pendingHistoryWrites == 0) {
      load();
    } else {
      _historyWrites.then((_) => load());
    }
  }

  /// 防抖搜索
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _searchGeneration++;

    if (query.trim().isEmpty) {
      _resultExpiry.cancel();
      setState(() {
        _state = WebSearchState(recentSearches: _state.recentSearches);
        _sourceFailures.clear();
        _retryingSources.clear();
        _authSearchBlocked = false;
      });
      return;
    }

    setState(() {
      _state = WebSearchState(
        query: query,
        results: _state.results,
        recentSearches: _state.recentSearches,
        showRecent: false,
        isLoading: true,
      );
      _sourceFailures.clear();
      _retryingSources.clear();
      _authSearchBlocked = false;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// 执行搜索
  @override
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    _debounceTimer?.cancel();
    final generation = ++_searchGeneration;
    if (_isAuthTransitioning) {
      setState(() {
        _state = WebSearchState(
          query: query,
          recentSearches: _state.recentSearches,
          results: [],
          isLoading: false,
          showRecent: false,
        );
        _sourceFailures
          ..clear()
          ..[SearchItemType.message] = WebMessageSearchFailure.unavailable;
        _retryingSources.clear();
        _authSearchBlocked = true;
      });
      return;
    }
    setState(() {
      _state = WebSearchState(
        query: query,
        results: _state.results,
        recentSearches: _state.recentSearches,
        isLoading: true,
        showRecent: false,
      );
      _sourceFailures.clear();
      _retryingSources.clear();
      _authSearchBlocked = false;
    });
    final user = UserRepoLocal.to;
    final session = user.sessionGeneration;
    final uid = user.currentUid;
    final endpoint = Env().apiBaseUrl;
    bool current() =>
        mounted &&
        generation == _searchGeneration &&
        user.currentUid == uid &&
        Env().apiBaseUrl == endpoint &&
        user.isCurrentSession(session) &&
        !_isAuthTransitioning;

    try {
      final responses = await Future.wait(
        _searchesFor(query).entries.map(
          (entry) async => (entry.key, await runWebMessageSearch(entry.value)),
        ),
      );
      if (!current()) return;
      setState(() {
        _sourceFailures.clear();
        final results = <SearchItem>[];
        for (final (source, (items, failure)) in responses) {
          results.addAll(items);
          if (failure != null) _sourceFailures[source] = failure;
        }
        _state = _state.copyWith(results: results, isLoading: false);
      });
      _removeExpiredResults();

      // 保存搜索记录
      _saveSearchHistory(query);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Search error: ${e.runtimeType}');
      if (!current()) return;
      setState(() {
        _state = _state.copyWith(isLoading: false, error: t.common.searchError);
      });
    }
  }

  /// 保存搜索记录
  Future<void> _saveSearchHistory(String query) async {
    try {
      await _updateHistory((history) {
        history.remove(query);
        history.insert(0, query);
        if (history.length > 20) history.removeRange(20, history.length);
        return history;
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('保存搜索历史失败: ${e.runtimeType}');
    }
  }

  /// 清除搜索记录
  Future<void> _clearSearchHistory() async {
    try {
      await _updateHistory((_) => []);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('清除搜索历史失败: ${e.runtimeType}');
    }
  }

  Future<void> _updateHistory(List<String> Function(List<String>) update) {
    final user = UserRepoLocal.to;
    final key = _historyKey();
    final generation = user.sessionGeneration;
    if (key == null) return Future.value();
    bool current() =>
        mounted && user.isCurrentSession(generation) && _historyKey() == key;
    Future<void> persist(List<String> history) {
      Future<void> write() async {
        await StorageService.to.persistPreference(
          () => StorageService.to.setList(key, history),
        );
      }

      return widget.persistHistoryForTest?.call(write) ?? write();
    }

    _pendingHistoryWrites++;
    final operation = _historyWrites
        .then((_) async {
          if (!current()) return;
          final previous = List<String>.of(
            StorageService.to.getStringList(key) ?? [],
          );
          final history = update(List.of(previous));
          await persist(history);
          if (current()) {
            setState(() => _state = _state.copyWith(recentSearches: history));
          } else {
            await persist(previous);
          }
        })
        .whenComplete(() {
          _pendingHistoryWrites--;
          _historyChanges.changed();
        });
    _historyWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.chatWebSurfaceDarkest : AppColors.lightSurface,
      child: Column(
        children: [
          // 搜索栏
          _buildSearchBar(isDark),

          // 搜索内容
          Expanded(
            child: _state.isLoading
                ? _buildLoadingState(isDark)
                : _state.showRecent
                ? _buildRecentSearches(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: AppSpacing.allMedium,
      color: isDark
          ? AppColors.chatWebBackgroundDark
          : AppColors.chatWebBackgroundLight,
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(
              CupertinoIcons.back,
              color: isDark
                  ? AppColors.chatWebSecondaryDark
                  : AppColors.chatWebSecondaryLight,
            ),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.pop(),
          ),

          // 搜索输入框
          Expanded(
            child: TextField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: context.textStyle(
                FontSizeType.subheadline,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: t.common.search,
                hintStyle: context.textStyle(
                  FontSizeType.subheadline,
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.chatWebSurfaceDark
                    : AppColors.lightSurface,
                border: OutlineInputBorder(borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          CupertinoIcons.clear,
                          color: isDark
                              ? AppColors.chatWebSecondaryDark
                              : AppColors.chatWebSecondaryLight,
                          size: 18,
                        ),
                        tooltip: t.common.clear,
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.allMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            AppSpacing.verticalRegular,
            Text(
              t.common.search,
              style: context.textStyle(
                FontSizeType.normal,
                color: isDark
                    ? AppColors.chatWebSecondaryDark
                    : AppColors.chatWebSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建最近搜索
  Widget _buildRecentSearches(bool isDark) {
    if (_state.recentSearches.isEmpty) {
      return NoDataView(
        text: t.common.searchChatContent,
        icon: CupertinoIcons.search,
        iconSize: 64,
        iconColor: isDark
            ? AppColors.chatWebDividerDark
            : AppColors.chatWebDividerLight,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.common.searchHistory,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.chatWebSecondaryDark
                        : AppColors.chatWebSecondaryLight,
                  ),
                ),
              ),
              CupertinoButton(
                onPressed: _clearSearchHistory,
                child: Text(
                  t.common.clear,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.chatWebBrand,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 搜索记录列表
        Expanded(
          child: ListView.builder(
            itemCount: _state.recentSearches.length,
            itemBuilder: (context, index) {
              final search = _state.recentSearches[index];
              return ListTile(
                leading: Icon(
                  CupertinoIcons.clock,
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                ),
                title: Text(
                  search,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    CupertinoIcons.arrow_up_left,
                    color: isDark
                        ? AppColors.chatWebSecondaryDark
                        : AppColors.chatWebSecondaryLight,
                    size: 18,
                  ),
                  tooltip: t.main.fillIn,
                  onPressed: () {
                    _searchController.text = search;
                    _onSearchChanged(search);
                  },
                ),
                onTap: () {
                  _searchController.text = search;
                  // 必须显式退出「最近搜索」态：此前只调 _performSearch，
                  // showRecent 仍为 true，结果被最近搜索区遮蔽——
                  // 用户点最近搜索词表现为「点了没反应」。
                  setState(() {
                    _state = _state.copyWith(showRecent: false);
                  });
                  _performSearch(search);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 处理结果项点击
  @override
  Future<void> _onItemTap(SearchItem item) async {
    if (_isAuthTransitioning) return;
    final user = UserRepoLocal.to;
    final uid = user.currentUid;
    final session = user.sessionGeneration;
    final generation = _searchGeneration;
    if (!_isVisibleMessage(item, DateTimeHelper.millisecond())) {
      _removeExpiredResults();
      return;
    }
    if (item.message case final message?) {
      final current = await ref
          .read(ftsApiProvider)
          .refreshResultVisibility(message);
      if (!mounted ||
          _isAuthTransitioning ||
          user.currentUid != uid ||
          !user.isCurrentSession(session) ||
          generation != _searchGeneration) {
        return;
      }
      if (!_applyMessageVisibility(item, current)) return;
    }
    if (!mounted) return;
    switch (item.type) {
      case SearchItemType.conversation:
        await context.push(
          Uri(
            path: '/chat/${item.id}',
            queryParameters: {
              'type': item.metadata?['type']?.toString() ?? 'C2C',
            },
          ).toString(),
        );
      case SearchItemType.message:
        // 跳转到消息详情
        if (item.metadata?['conversationId'] != null) {
          await context.push(
            searchMessageRoute(
              item.metadata!['conversationId'] as String,
              item.metadata?['type'] as String?,
            ),
          );
        }
      case SearchItemType.contact:
        // 资料页路由注册在 /contact 子树下：/contact/people/:id（与
        // contact_page 的跳转一致）。此前推 /people_info/:id 不存在，
        // 点联系人结果无反应。
        await context.push('/contact/people/${item.id}');
      case SearchItemType.group:
        // 群聊点击进入会话，统一走 /chat/:peerId?type=C2G
        await context.push('/chat/${item.id}?type=C2G');
    }
    if (mounted &&
        !_isAuthTransitioning &&
        user.currentUid == uid &&
        user.isCurrentSession(session) &&
        generation == _searchGeneration) {
      await _refreshResultFacts();
    }
  }

  Future<void> _refreshResultFacts() async {
    if (!mounted || _isAuthTransitioning) return;
    _removeExpiredResults();
    if (_state.isLoading) return;
    final user = UserRepoLocal.to;
    final uid = user.currentUid;
    final session = user.sessionGeneration;
    final search = _searchGeneration;
    final refresh = ++_visibilityGeneration;
    final snapshot = List<SearchItem>.of(_state.results);
    for (final item in snapshot) {
      final message = item.message;
      if (message == null) continue;
      final current = await ref
          .read(ftsApiProvider)
          .refreshResultVisibility(message);
      if (!mounted ||
          _isAuthTransitioning ||
          user.currentUid != uid ||
          !user.isCurrentSession(session) ||
          search != _searchGeneration ||
          refresh != _visibilityGeneration) {
        return;
      }
      _applyMessageVisibility(item, current);
    }
  }

  bool _applyMessageVisibility(SearchItem item, MessageSearchResult? current) {
    // 只替换仍在展示的同一结果，不能复活已被计时器清掉的项目。
    final index = _state.results.indexWhere(
      (result) => identical(result, item),
    );
    if (index < 0) return false;
    final results = List<SearchItem>.of(_state.results);
    SearchItem? updated;
    if (current == null ||
        !current.isVisibleAt(
          DateTimeHelper.millisecond(),
          UserRepoLocal.to.currentUid,
        )) {
      results.removeAt(index);
    } else {
      updated = SearchItem(
        type: item.type,
        id: item.id,
        title: item.title,
        subtitle: current.content,
        avatar: item.avatar,
        highlightText: item.highlightText,
        metadata: item.metadata,
        message: current,
      );
      results[index] = updated;
    }
    setState(() => _state = _state.copyWith(results: results));
    _removeExpiredResults();
    return updated != null && _state.results.contains(updated);
  }

  bool _isVisibleMessage(SearchItem item, int nowMs) {
    if (item.type != SearchItemType.message) return true;
    return item.message?.isVisibleAt(nowMs, UserRepoLocal.to.currentUid) ??
        true;
  }

  @override
  void _removeExpiredResults() {
    if (!mounted || _isAuthTransitioning) return;
    final nowMs = DateTimeHelper.millisecond();
    final remaining = _state.results
        .where((item) => _isVisibleMessage(item, nowMs))
        .toList();
    if (remaining.length != _state.results.length) {
      setState(() => _state = _state.copyWith(results: remaining));
    }
    _resultExpiry.schedule(
      remaining
          .where((item) => item.type == SearchItemType.message)
          .map(
            (item) => item.message?.expiresAtMs(UserRepoLocal.to.currentUid),
          ),
    );
  }
}
