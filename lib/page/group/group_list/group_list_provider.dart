import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/group_model.dart';

part 'group_list_provider.g.dart';

/// 群组列表状态
class GroupListState {
  final List<GroupModel> groupList;
  final int page;
  final int size;
  final String attr;
  final bool isSearch;
  final bool isLoading;

  const GroupListState({
    this.groupList = const [],
    this.page = 1,
    this.size = 1000,
    this.attr = 'all',
    this.isSearch = false,
    this.isLoading = false,
  });

  GroupListState copyWith({
    List<GroupModel>? groupList,
    int? page,
    int? size,
    String? attr,
    bool? isSearch,
    bool? isLoading,
  }) {
    return GroupListState(
      groupList: groupList ?? this.groupList,
      page: page ?? this.page,
      size: size ?? this.size,
      attr: attr ?? this.attr,
      isSearch: isSearch ?? this.isSearch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 群组列表 Notifier
@Riverpod(keepAlive: true)
class GroupListNotifier extends _$GroupListNotifier {
  @override
  GroupListState build() {
    return const GroupListState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 设置群组列表
  void setGroupList(List<GroupModel> list) {
    state = state.copyWith(groupList: list);
  }

  /// 设置当前筛选属性：owner/join/manager
  void setAttr(String attr) {
    state = state.copyWith(attr: attr, page: 1, groupList: []);
  }

  /// 设置页码
  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  /// 增加页码
  void incrementPage() {
    state = state.copyWith(page: state.page + 1);
  }

  /// 重置状态
  void reset() {
    state = const GroupListState();
  }
}
