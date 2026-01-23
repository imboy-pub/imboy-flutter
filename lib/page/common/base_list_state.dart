/// 基础列表状态类
///
/// 统一 Provider 的状态字段，减少重复代码
/// 所有列表类型的 Provider 都应该基于此类扩展
///
/// 使用示例：
/// ```dart
/// class ContactState extends BaseListState<ContactModel> {
///   const ContactState({
///     super.dataList,
///     super.isLoading,
///     super.error,
///     super.page,
///     super.size,
///   });
/// }
/// ```
class BaseListState<T> {
  /// 数据列表
  final List<T> dataList;

  /// 加载状态
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 当前页码
  final int page;

  /// 每页大小
  final int size;

  /// 是否有更多数据
  final bool hasMore;

  const BaseListState({
    this.dataList = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.size = 20,
    this.hasMore = true,
  });

  /// 复制并更新状态
  BaseListState<T> copyWith({
    List<T>? dataList,
    bool? isLoading,
    String? error,
    int? page,
    int? size,
    bool? hasMore,
  }) {
    return BaseListState<T>(
      dataList: dataList ?? this.dataList,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      page: page ?? this.page,
      size: size ?? this.size,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// 是否为空
  bool get isEmpty => dataList.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => dataList.isNotEmpty;

  /// 数据数量
  int get length => dataList.length;

  /// 是否在加载中
  bool get isBusy => isLoading;

  /// 是否有错误
  bool get hasError => error != null;

  /// 清空错误
  BaseListState<T> clearError() => copyWith(error: null);

  /// 重置状态
  BaseListState<T> reset() => const BaseListState();

  @override
  String toString() {
    return 'BaseListState{dataList.length: ${dataList.length}, isLoading: $isLoading, page: $page, hasMore: $hasMore}';
  }
}
