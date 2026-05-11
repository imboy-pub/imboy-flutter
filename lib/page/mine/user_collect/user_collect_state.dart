import 'package:flutter/widgets.dart';

/// UserCollect 页面状态
/// 包含分页、搜索、加载状态等字段
class UserCollectState {
  /// 筛选面板是否展开
  bool kindActive = false;

  /// 列表数据
  List<dynamic> items = [];

  /// 标签列表 Widget（用于筛选）
  List<Widget> tagItems = [];

  /// 当前页码（从1开始）
  int page = 1;

  /// 每页大小
  int size = 10;

  /// 被收藏的资源种类： all | 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息 7 个人名片
  String kind = 'all'; // all 1-10 recent_use
  final String recentUse = 'recent_use';

  /// 搜索关键词
  String kwd = '';

  /// 搜索框左侧/右侧自定义控件
  Widget? searchLeading;
  Iterable<Widget>? searchTrailing;

  /// 搜索输入控制器
  TextEditingController searchController = TextEditingController();

  // 新增状态字段（用于防止重复请求和分页判断）
  /// 是否正在加载（load more / initial load）
  bool isLoading = false;

  /// 是否正在下拉刷新
  bool isRefreshing = false;

  /// 是否还有更多数据可加载
  bool hasMore = true;

  /// 正在进行删除的项集合，用于防止重复提交
  Set<String> removingIds = <String>{};

  UserCollectState() {
    ///Initialize variables
  }

  /// 创建状态副本
  UserCollectState copyWith({
    bool? kindActive,
    List<dynamic>? items,
    List<Widget>? tagItems,
    int? page,
    int? size,
    String? kind,
    String? kwd,
    Widget? searchLeading,
    Iterable<Widget>? searchTrailing,
    TextEditingController? searchController,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    Set<String>? removingIds,
  }) {
    return UserCollectState()
      ..kindActive = kindActive ?? this.kindActive
      ..items = items ?? this.items
      ..tagItems = tagItems ?? this.tagItems
      ..page = page ?? this.page
      ..size = size ?? this.size
      ..kind = kind ?? this.kind
      ..kwd = kwd ?? this.kwd
      ..searchLeading = searchLeading ?? this.searchLeading
      ..searchTrailing = searchTrailing ?? this.searchTrailing
      ..searchController = searchController ?? this.searchController
      ..isLoading = isLoading ?? this.isLoading
      ..isRefreshing = isRefreshing ?? this.isRefreshing
      ..hasMore = hasMore ?? this.hasMore
      ..removingIds = removingIds ?? this.removingIds;
  }
}
