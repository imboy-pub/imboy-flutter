import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/api/group_discovery_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 群组发现列表项（group_discovery_handler 返回的公开群卡片）
class GroupDiscoveryItem {
  final int id;
  final String title;
  final String avatar;
  final String introduction;
  final int memberCount;

  const GroupDiscoveryItem({
    required this.id,
    required this.title,
    required this.avatar,
    required this.introduction,
    required this.memberCount,
  });

  factory GroupDiscoveryItem.fromJson(Map<String, dynamic> json) {
    return GroupDiscoveryItem(
      // TSID：http 层大整数已转 String，parseModelInt 兼容两种形态
      id: parseModelInt(json['id']),
      title: json['title'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      introduction: json['introduction'] as String? ?? '',
      memberCount: parseModelInt(json['member_count']),
    );
  }
}

/// 公开群分类项
class GroupDiscoveryCategory {
  final int id;
  final String name;

  const GroupDiscoveryCategory({required this.id, required this.name});

  factory GroupDiscoveryCategory.fromJson(Map<String, dynamic> json) {
    return GroupDiscoveryCategory(
      id: parseModelInt(json['id']),
      name: json['name'] as String? ?? '',
    );
  }
}

/// 群组发现页状态
class GroupDiscoveryState {
  final int page;
  final int size;
  final List<GroupDiscoveryItem> list;
  final String keyword;
  final int? categoryId;
  final String sort;
  final List<GroupDiscoveryCategory> categories;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const GroupDiscoveryState({
    this.page = 1,
    this.size = 10,
    this.list = const [],
    this.keyword = '',
    this.categoryId,
    this.sort = 'popular',
    this.categories = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  GroupDiscoveryState copyWith({
    int? page,
    int? size,
    List<GroupDiscoveryItem>? list,
    String? keyword,
    int? categoryId,
    bool clearCategory = false,
    String? sort,
    List<GroupDiscoveryCategory>? categories,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return GroupDiscoveryState(
      page: page ?? this.page,
      size: size ?? this.size,
      list: list ?? this.list,
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 群组发现通知器
///
/// 有关键词走 search（FTS），否则走 discover（统计排序）；
/// 切换分类/排序/关键词都会重置到第 1 页。
class GroupDiscoveryNotifier extends Notifier<GroupDiscoveryState> {
  @override
  GroupDiscoveryState build() {
    return const GroupDiscoveryState();
  }

  Future<List<GroupDiscoveryItem>?> _fetch({required int page}) async {
    final api = ref.read(groupDiscoveryApiProvider);
    final Map<String, dynamic>? payload;
    if (state.keyword.trim().isNotEmpty) {
      payload = await api.search(
        state.keyword.trim(),
        page: page,
        size: state.size,
        categoryId: state.categoryId,
      );
    } else {
      payload = await api.discover(
        page: page,
        size: state.size,
        categoryId: state.categoryId,
        sort: state.sort,
      );
    }
    if (payload == null) {
      return null;
    }
    return [
      for (final json in (payload['list'] as List? ?? []))
        GroupDiscoveryItem.fromJson(Map<String, dynamic>.from(json as Map)),
    ];
  }

  /// 首屏加载（含分类列表拉取，失败不阻塞主列表）
  Future<void> initData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    if (state.categories.isEmpty) {
      final rawCategories = await ref
          .read(groupDiscoveryApiProvider)
          .categories();
      state = state.copyWith(
        categories: [
          for (final json in rawCategories)
            GroupDiscoveryCategory.fromJson(json),
        ],
      );
    }
    final list = await _fetch(page: 1);
    if (list == null) {
      state = state.copyWith(isLoading: false, error: 'load_failed');
      return;
    }
    state = state.copyWith(
      isLoading: false,
      list: list,
      page: 2,
      hasMore: list.length >= state.size,
    );
  }

  Future<void> refresh() => initData();

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    final more = await _fetch(page: state.page);
    if (more == null) {
      // 追加失败不清空已有列表，保留 hasMore 供下次触底重试
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    state = state.copyWith(
      isLoadingMore: false,
      list: [...state.list, ...more],
      page: state.page + 1,
      hasMore: more.length >= state.size,
    );
  }

  /// 更新搜索关键词（debounce 由页面层负责）
  Future<void> updateKeyword(String keyword) async {
    state = state.copyWith(keyword: keyword, page: 1);
    await initData();
  }

  /// 切换分类（null = 全部）
  Future<void> selectCategory(int? categoryId) async {
    if (categoryId == state.categoryId) return;
    state = state.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
      page: 1,
    );
    await initData();
  }

  /// 切换排序（popular/newest）
  Future<void> updateSort(String sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort, page: 1);
    await initData();
  }
}

final groupDiscoveryProvider =
    NotifierProvider<GroupDiscoveryNotifier, GroupDiscoveryState>(
      GroupDiscoveryNotifier.new,
    );
