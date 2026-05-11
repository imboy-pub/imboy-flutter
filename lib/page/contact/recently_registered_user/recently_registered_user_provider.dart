import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 新注册用户状态类
class RecentlyRegisteredUserState {
  final int page;
  final int size;
  final List<PeopleModel> peopleList;
  final String kwd;

  const RecentlyRegisteredUserState({
    this.page = 1,
    this.size = 50,
    this.peopleList = const [],
    this.kwd = '',
  });

  RecentlyRegisteredUserState copyWith({
    int? page,
    int? size,
    List<PeopleModel>? peopleList,
    String? kwd,
  }) {
    return RecentlyRegisteredUserState(
      page: page ?? this.page,
      size: size ?? this.size,
      peopleList: peopleList ?? this.peopleList,
      kwd: kwd ?? this.kwd,
    );
  }
}

/// 新注册用户状态通知器
class RecentlyRegisteredUserNotifier
    extends Notifier<RecentlyRegisteredUserState> {
  @override
  RecentlyRegisteredUserState build() {
    return const RecentlyRegisteredUserState();
  }

  /// 获取新注册用户列表
  Future<List<PeopleModel>> page({
    int page = 1,
    int size = 10,
    String? kind,
    String? kwd,
    bool onRefresh = false,
  }) async {
    final currentPage = page > 1 ? page : 1;

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      String msg = t.tipConnectDesc;
      EasyLoading.showError(' $msg        ');
      return [];
    }

    iPrint("RecentlyRegisteredUserPage_page ; onRefresh $onRefresh;");
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    Map<String, dynamic>? payload = await userApi.ftsRecentlyUser(
      page: currentPage,
      size: size,
      keyword: kwd ?? '',
    );

    if (payload == null) {
      return [];
    }

    ContactRepo repo = ContactRepo();
    List<PeopleModel> list = [];
    for (var json in (payload['list'] as List)) {
      PeopleModel model = PeopleModel.fromJson(json);
      await repo.update({
        'id': json['id'],
        ContactRepo.isFriend: json['is_friend'],
        ContactRepo.nickname: json['nickname'],
        ContactRepo.avatar: json['avatar'],
        ContactRepo.sign: json['sign'],
        ContactRepo.gender: json['gender'],
        ContactRepo.region: json['region'],
      });
      list.add(model);
    }

    return list;
  }

  /// 初始化数据
  Future<void> initData() async {
    final list = await page(page: 1, size: state.size, kwd: state.kwd);

    if (list.isNotEmpty) {
      state = state.copyWith(peopleList: list, page: 2);
    }
  }

  /// 更新搜索关键词
  void updateKwd(String kwd) {
    state = state.copyWith(kwd: kwd);
  }
}

/// 新注册用户 Provider
final recentlyRegisteredUserApi =
    NotifierProvider<
      RecentlyRegisteredUserNotifier,
      RecentlyRegisteredUserState
    >(RecentlyRegisteredUserNotifier.new);
