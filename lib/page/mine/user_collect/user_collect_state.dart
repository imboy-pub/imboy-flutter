import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// UserCollect 页面状态
/// 包含分页、搜索、加载状态等字段
class UserCollectState {
  /// 筛选面板是否展开
  RxBool kindActive = false.obs;

  /// 列表数据
  RxList items = [].obs;

  /// 标签列表 Widget（用于筛选）
  Rx<List<Widget>> tagItems = Rx([]);

  /// 当前页码（从1开始）
  int page = 1;

  /// 每页大小
  int size = 10;

  /// 被收藏的资源种类： all | 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息 7 个人名片
  String kind = 'all'; // all 1-10 recent_use
  final String recentUse = 'recent_use';

  /// 搜索关键词
  Rx<String> kwd = ''.obs;

  /// 搜索框左侧/右侧自定义控件
  Rx<Widget>? searchLeading;
  Rx<Iterable<Widget>>? searchTrailing;

  /// 搜索输入控制器
  TextEditingController searchController = TextEditingController();

  // 新增状态字段（用于防止重复请求和分页判断）
  /// 是否正在加载（load more / initial load）
  RxBool isLoading = false.obs;

  /// 是否正在下拉刷新
  RxBool isRefreshing = false.obs;

  /// 是否还有更多数据可加载
  RxBool hasMore = true.obs;

  UserCollectState() {
    ///Initialize variables
  }
}