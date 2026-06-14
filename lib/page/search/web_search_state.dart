/// 搜索结果类型
enum SearchItemType { conversation, message, contact, group }

/// 搜索结果项
class SearchItem {
  final SearchItemType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? avatar;
  final String? highlightText;
  final Map<String, dynamic>? metadata;

  const SearchItem({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.avatar,
    this.highlightText,
    this.metadata,
  });
}

/// 搜索状态
class WebSearchState {
  final bool isLoading;
  final String query;
  final List<SearchItem> results;
  final List<String> recentSearches;
  final String? error;
  final bool showRecent;

  const WebSearchState({
    this.isLoading = false,
    this.query = '',
    this.results = const [],
    this.recentSearches = const [],
    this.error,
    this.showRecent = true,
  });

  WebSearchState copyWith({
    bool? isLoading,
    String? query,
    List<SearchItem>? results,
    List<String>? recentSearches,
    String? error,
    bool? showRecent,
  }) {
    return WebSearchState(
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      error: error ?? this.error,
      showRecent: showRecent ?? this.showRecent,
    );
  }
}
