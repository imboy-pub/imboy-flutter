import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

part 'group_list_provider.g.dart';

/// 群组列表状态
class GroupListState {
  final List<GroupModel> groupList;
  final int page;
  final int size;
  final String attr;
  final bool isSearch;
  final bool isLoading;
  final bool loadFailed;

  const GroupListState({
    this.groupList = const [],
    this.page = 1,
    this.size = 1000,
    this.attr = 'all',
    this.isSearch = false,
    this.isLoading = false,
    this.loadFailed = false,
  });

  GroupListState copyWith({
    List<GroupModel>? groupList,
    int? page,
    int? size,
    String? attr,
    bool? isSearch,
    bool? isLoading,
    bool? loadFailed,
  }) {
    return GroupListState(
      groupList: groupList ?? this.groupList,
      page: page ?? this.page,
      size: size ?? this.size,
      attr: attr ?? this.attr,
      isSearch: isSearch ?? this.isSearch,
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
    );
  }
}

/// 群组列表 Notifier
@Riverpod(keepAlive: true)
class GroupListNotifier extends _$GroupListNotifier {
  String? _ownerUid;
  int? _sessionGeneration;
  bool? _authTransitioning;
  int _requestGeneration = 0;

  @override
  GroupListState build() {
    final user = UserRepoLocal.to;
    _ownerUid = user.currentUid;
    _sessionGeneration = user.sessionGeneration;
    _authTransitioning = user.isAuthTransitioning;
    user.addAuthListener(_onAuthChanged);
    ref.onDispose(() => user.removeAuthListener(_onAuthChanged));
    return const GroupListState();
  }

  void _ensureOwner() {
    final user = UserRepoLocal.to;
    if (_ownerUid == user.currentUid &&
        _sessionGeneration == user.sessionGeneration &&
        _authTransitioning == user.isAuthTransitioning) {
      return;
    }
    _ownerUid = user.currentUid;
    _sessionGeneration = user.sessionGeneration;
    _authTransitioning = user.isAuthTransitioning;
    _requestGeneration++;
    state = const GroupListState();
  }

  void _onAuthChanged() {
    if (ref.mounted) _ensureOwner();
  }

  /// 请求票据在所有页面实例间共享，并绑定账号与会话。
  ({int request, String uid, int session, String attr})? beginLoad() {
    _ensureOwner();
    if (UserRepoLocal.to.isAuthTransitioning) return null;
    final token = (
      request: ++_requestGeneration,
      uid: UserRepoLocal.to.currentUid,
      session: UserRepoLocal.to.sessionGeneration,
      attr: state.attr,
    );
    state = state.copyWith(isLoading: true);
    return token;
  }

  bool isCurrentLoad(
    ({int request, String uid, int session, String attr}) token,
  ) {
    final user = UserRepoLocal.to;
    return ref.mounted &&
        !user.isAuthTransitioning &&
        user.currentUid == token.uid &&
        user.sessionGeneration == token.session &&
        _ownerUid == token.uid &&
        _sessionGeneration == token.session &&
        _requestGeneration == token.request &&
        state.attr == token.attr;
  }

  void finishLoad(
    ({int request, String uid, int session, String attr}) token, {
    List<GroupModel>? groups,
    bool failed = false,
  }) {
    if (!isCurrentLoad(token)) return;
    state = state.copyWith(
      groupList: groups,
      page: failed ? state.page : 2,
      isLoading: false,
      loadFailed: failed,
    );
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
    _ensureOwner();
    _requestGeneration++;
    state = state.copyWith(
      attr: attr,
      page: 1,
      groupList: [],
      isLoading: false,
      loadFailed: false,
    );
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
    _requestGeneration++;
    state = const GroupListState();
  }
}
