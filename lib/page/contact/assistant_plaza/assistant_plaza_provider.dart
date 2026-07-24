import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/api/agent_api.dart';
import 'package:imboy/store/model/people_model.dart';

/// 助手广场状态
class AssistantPlazaState {
  final int page;
  final int size;
  final List<PeopleModel> list;
  final String kwd;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const AssistantPlazaState({
    this.page = 1,
    this.size = 10,
    this.list = const [],
    this.kwd = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  AssistantPlazaState copyWith({
    int? page,
    int? size,
    List<PeopleModel>? list,
    String? kwd,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return AssistantPlazaState(
      page: page ?? this.page,
      size: size ?? this.size,
      list: list ?? this.list,
      kwd: kwd ?? this.kwd,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 助手广场状态通知器
///
/// 数据源 GET /api/v1/agent/list，每项精简卡片 {id, name, avatar, description}；
/// 广场内均为 AI 助手（接口不返回 account_type），故 accountType 固定 1。
class AssistantPlazaNotifier extends Notifier<AssistantPlazaState> {
  @override
  AssistantPlazaState build() {
    return const AssistantPlazaState();
  }

  /// 拉取一页；返回 null 表示请求失败（区别于空列表）
  Future<List<PeopleModel>?> _fetch({required int page}) async {
    final payload = await ref
        .read(agentApiProvider)
        .agentList(page: page, size: state.size, kwd: state.kwd);
    if (payload == null) {
      return null;
    }
    return [
      for (final json in (payload['list'] as List? ?? []))
        PeopleModel(
          id: (json as Map<String, dynamic>)['id'] as int? ?? 0,
          account: '',
          nickname: json['name'] as String? ?? '',
          avatar: json['avatar'] as String? ?? '',
          sign: json['description'] as String? ?? '',
          accountType: 1,
        ),
    ];
  }

  /// 首屏加载
  Future<void> initData() async {
    state = state.copyWith(isLoading: true, clearError: true);
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

  /// 下拉刷新（page=1 替换列表）
  Future<void> refresh() => initData();

  /// 上拉加载更多（触底追加）
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

  /// 更新搜索关键词并重查（debounce 由页面层负责）
  Future<void> updateKwd(String kwd) async {
    state = state.copyWith(kwd: kwd, page: 1);
    await initData();
  }
}

/// 助手广场 Provider
final assistantPlazaProvider =
    NotifierProvider<AssistantPlazaNotifier, AssistantPlazaState>(
      AssistantPlazaNotifier.new,
    );
