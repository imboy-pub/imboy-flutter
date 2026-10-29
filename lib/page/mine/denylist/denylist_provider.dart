import 'package:azlistview/azlistview.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/api/denylist_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'denylist_provider.g.dart';

enum DenylistMutationResult { success, unknown, partial, sessionChanged }

/// Denylist 模块的状态
class DenylistState {
  final List<DenylistModel> items;
  final Set<String> currIndexBarData;
  final bool isLoading;

  const DenylistState({
    this.items = const [],
    this.currIndexBarData = const {},
    this.isLoading = false,
  });

  DenylistState copyWith({
    List<DenylistModel>? items,
    Set<String>? currIndexBarData,
    bool? isLoading,
  }) {
    return DenylistState(
      items: items ?? this.items,
      currIndexBarData: currIndexBarData ?? this.currIndexBarData,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class DenylistNotifier extends _$DenylistNotifier {
  @override
  DenylistState build() {
    return const DenylistState();
  }

  /// 处理黑名单列表数据
  void handleList(List<DenylistModel> list) {
    final indexData = <String>{};

    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      // pinyin 为空（title 空/纯空白/纯符号）时 substring(0,1) 会抛 RangeError，
      // 归入 "#" 分组避免整个黑名单列表构建崩溃。
      String tag = pinyin.isNotEmpty
          ? pinyin.substring(0, 1).toUpperCase()
          : "#";
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        indexData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    indexData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);

    state = state.copyWith(items: list, currIndexBarData: indexData);
  }

  /// 加载黑名单列表
  Future<void> loadData({int page = 1, int size = 1000}) async {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    final generation = user.sessionGeneration;
    bool current() =>
        ref.mounted &&
        account.isNotEmpty &&
        user.currentUid == account &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    if (!current()) return;
    state = state.copyWith(isLoading: true);
    try {
      var list = await DenylistNotifier.page(page: page, size: size);
      if (current()) handleList(list);
    } finally {
      if (current()) state = state.copyWith(isLoading: false);
    }
  }

  /// 获取黑名单列表（静态方法，供外部调用）
  static Future<List<DenylistModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
  }) async {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    final generation = user.sessionGeneration;
    bool current() =>
        account.isNotEmpty &&
        user.currentUid == account &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    if (!current()) return [];
    List<DenylistModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserDenylistRepo();
    if (onRefresh == false) {
      list = await repo.page(limit: size, offset: offset);
      if (!current()) return [];
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await DenylistApi().page(
      page: page,
      size: size,
    );
    if (!current()) return [];
    if (payload == null) {
      return [];
    }
    for (var json in IMBoyHttpResponse.payloadList(payload)) {
      json[ContactRepo.isFriend] = 1;
      // checkIsFriend = true 的时候，保留旧的 isFriend 值
      DenylistModel model = DenylistModel.fromJson(json);
      await repo.insert(model, account: account);
      if (!current()) return [];
      list.add(model);
    }
    return list;
  }

  /// 检查用户是否在黑名单中
  static Future<bool> inDenylist(String uid) async {
    int count = await (UserDenylistRepo().inDenylist(uid));
    return count > 0 ? true : false;
  }

  /// 移除黑名单
  Future<DenylistMutationResult> removeDenylist(String peerId) async {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    final generation = user.sessionGeneration;
    bool current() =>
        ref.mounted &&
        account.isNotEmpty &&
        user.currentUid == account &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    if (!current()) return DenylistMutationResult.sessionChanged;
    var serverApplied = false;
    try {
      DenylistApi api = DenylistApi();
      UserDenylistRepo repo = UserDenylistRepo();
      final response = await api.remove(deniedUserUid: peerId);
      final res = response.applied;
      if (!current()) return DenylistMutationResult.sessionChanged;
      if (res) {
        serverApplied = true;
        await repo.deleteForUid(peerId, account: account);
        if (!current()) return DenylistMutationResult.sessionChanged;
        // 显示联系人
        await ContactRepo().update({
          ContactRepo.userId: account,
          ContactRepo.peerId: peerId,
          ContactRepo.isFriend: 1,
        }, account: account);
        if (!current()) return DenylistMutationResult.sessionChanged;
        // 显示会话
        await ConversationRepo().updateByPeerId('C2C', peerId, {
          ConversationRepo.isShow: 1,
        }, account: account);
        if (!current()) return DenylistMutationResult.sessionChanged;

        // 从列表中移除
        final newItems = List<DenylistModel>.from(state.items);
        newItems.removeWhere((e) => e.deniedUid.toString() == peerId);
        state = state.copyWith(items: newItems);
      }
      return res
          ? DenylistMutationResult.success
          : DenylistMutationResult.unknown;
    } catch (_) {
      if (!current()) return DenylistMutationResult.sessionChanged;
      return serverApplied
          ? DenylistMutationResult.partial
          : DenylistMutationResult.unknown;
    }
  }

  /// 添加到黑名单
  Future<DenylistMutationResult> addDenylist(DenylistModel model) async {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    final generation = user.sessionGeneration;
    bool current() =>
        ref.mounted &&
        account.isNotEmpty &&
        user.currentUid == account &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    if (!current()) return DenylistMutationResult.sessionChanged;
    DenylistApi api = DenylistApi();
    UserDenylistRepo repo = UserDenylistRepo();

    var serverApplied = false;
    try {
      final response = await api.add(deniedUserUid: model.deniedUid.toString());
      if (!current()) return DenylistMutationResult.sessionChanged;
      final payload = response.payload;
      final res = response.applied;
      if (res) {
        serverApplied = true;
        model.createdAt =
            IMBoyHttpResponse.payloadInt(payload, 'created_at') ??
            DateTimeHelper.millisecond();
        await repo.insert(model, account: account);
        if (!current()) return DenylistMutationResult.sessionChanged;
        // 隐藏联系人
        await ContactRepo().update({
          ContactRepo.userId: account,
          ContactRepo.peerId: model.deniedUid,
          ContactRepo.isFriend: 0,
        }, account: account);
        if (!current()) return DenylistMutationResult.sessionChanged;
        // 隐藏会话
        await ConversationRepo().updateByPeerId(
          'C2C',
          model.deniedUid.toString(),
          {ConversationRepo.isShow: 0},
          account: account,
        );
        if (!current()) return DenylistMutationResult.sessionChanged;
      }
      return res
          ? DenylistMutationResult.success
          : DenylistMutationResult.unknown;
    } catch (_) {
      if (!current()) return DenylistMutationResult.sessionChanged;
      return serverApplied
          ? DenylistMutationResult.partial
          : DenylistMutationResult.unknown;
    }
  }

  /// 刷新黑名单数据
  Future<void> refreshData() async {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    final generation = user.sessionGeneration;
    // 刷新黑名单列表
    var list2 = await page(page: 1, size: 1000);
    if (ref.mounted &&
        account.isNotEmpty &&
        user.currentUid == account &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning) {
      handleList(list2);
    }
  }
}
