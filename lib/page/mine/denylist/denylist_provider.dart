import 'package:azlistview/azlistview.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/api/denylist_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'denylist_provider.g.dart';

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
      String tag = pinyin.substring(0, 1).toUpperCase();
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
    state = state.copyWith(isLoading: true);
    try {
      var list = await DenylistNotifier.page(page: page, size: size);
      handleList(list);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 获取黑名单列表（静态方法，供外部调用）
  static Future<List<DenylistModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
  }) async {
    List<DenylistModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserDenylistRepo();
    if (onRefresh == false) {
      list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await DenylistApi().page(
      page: page,
      size: size,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      json[ContactRepo.isFriend] = 1;
      // checkIsFriend = true 的时候，保留旧的 isFriend 值
      DenylistModel model = DenylistModel.fromJson(json);
      await repo.insert(model);
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
  Future<bool> removeDenylist(String peerId) async {
    try {
      DenylistApi api = DenylistApi();
      UserDenylistRepo repo = UserDenylistRepo();
      bool res = await api.remove(deniedUserUid: peerId);
      if (res) {
        await repo.deleteForUid(peerId);
        // 显示联系人
        await ContactRepo().update({
          ContactRepo.userId: UserRepoLocal.to.currentUid,
          ContactRepo.peerId: peerId,
          ContactRepo.isFriend: 1,
        });
        // 显示会话
        await ConversationRepo().updateByPeerId('C2C', peerId, {
          ConversationRepo.isShow: 1,
        });

        // 从列表中移除
        final newItems = List<DenylistModel>.from(state.items);
        newItems.removeWhere((e) => e.deniedUid == peerId);
        state = state.copyWith(items: newItems);
      }
      return res;
    } catch (e) {
      return false;
    }
  }

  /// 添加到黑名单
  Future<bool> addDenylist(DenylistModel model) async {
    DenylistApi api = DenylistApi();
    UserDenylistRepo repo = UserDenylistRepo();

    Map? payload = await api.add(deniedUserUid: model.deniedUid);
    bool res = payload == null ? false : true;
    if (res) {
      model.createdAt = payload['created_at'] ?? DateTimeHelper.millisecond();
      await repo.insert(model);
      // 隐藏联系人
      await ContactRepo().update({
        ContactRepo.userId: UserRepoLocal.to.currentUid,
        ContactRepo.peerId: model.deniedUid,
        ContactRepo.isFriend: 0,
      });
      // 隐藏会话
      await ConversationRepo().updateByPeerId('C2C', model.deniedUid, {
        ConversationRepo.isShow: 0,
      });
    }
    return res;
  }

  /// 刷新数据（需要 GetX 的 ContactLogic，暂时保留）
  Future<void> refreshData() async {
    // 刷新黑名单列表
    var list2 = await page(page: 1, size: 1000);
    handleList(list2);
  }
}
