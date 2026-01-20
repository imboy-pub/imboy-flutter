import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'contact_tag_list_provider.g.dart';

/// ContactTagList 模块的状态
class ContactTagListState {
  final List<UserTagModel> items;
  final int page;
  final int size;
  final String kwd;
  final bool isLoading;

  const ContactTagListState({
    this.items = const [],
    this.page = 1,
    this.size = 10,
    this.kwd = '',
    this.isLoading = false,
  });

  ContactTagListState copyWith({
    List<UserTagModel>? items,
    int? page,
    int? size,
    String? kwd,
    bool? isLoading,
  }) {
    return ContactTagListState(
      items: items ?? this.items,
      page: page ?? this.page,
      size: size ?? this.size,
      kwd: kwd ?? this.kwd,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class ContactTagListNotifier extends _$ContactTagListNotifier {
  @override
  ContactTagListState build() {
    return const ContactTagListState();
  }

  /// 分页获取标签列表
  Future<List<UserTagModel>> page({
    int page = 1,
    int size = 10,
    String? kwd,
    bool onRefresh = false,
  }) async {
    List<UserTagModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserTagRepo();

    // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
    String scene = 'friend';
    if (onRefresh == false) {
      list = await _pageOnLocal(repo, size, offset, kwd);
      iPrint("UserTagRepo_page logic ${list.length}");
      // 第一页为空的时候继续往下走
      if (!(page == 1 && list.isEmpty)) {
        return list;
      }
    }

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return list;
    }
    iPrint("UserTagRepo_page logic ; onRefresh $onRefresh;  ${list.length}");
    Map<String, dynamic>? payload = await UserTagApi().page(
      page: page,
      size: size,
      kwd: kwd ?? '',
      scene: scene,
    );
    if (payload == null) {
      return [];
    }

    for (var json in payload['list']) {
      json['user_id'] = json['user_id'] ?? UserRepoLocal.to.currentUid;
      // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
      json[UserTagRepo.scene] = 2;
      UserTagModel model = UserTagModel.fromJson(json);
      await repo.save(json);
      list.add(model);
    }
    return list;
  }

  /// 从本地数据库分页获取标签
  Future<List<UserTagModel>> _pageOnLocal(
    UserTagRepo repo,
    int size,
    int offset,
    String? kwd,
  ) async {
    String where = "${UserTagRepo.userId} = ? and ${UserTagRepo.scene} = 2";
    List<Object?> whereArgs = [UserRepoLocal.to.currentUid];
    String? orderBy;
    if (strNoEmpty(kwd)) {
      where = "$where and ${UserTagRepo.name} like '%$kwd%'";
    }
    return await repo.page(
      limit: size,
      offset: offset,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  /// 搜索标签
  Future<List<dynamic>> doSearch(String query) async {
    iPrint("user_collect_s_doSearch ${query.toString()}");
    state = state.copyWith(page: 1);
    var list = await page(
      page: state.page,
      size: state.size,
      kwd: query.toString(),
    );
    if (list.isNotEmpty) {
      state = state.copyWith(page: state.page + 1);
    }
    state = state.copyWith(items: list);
    return list;
  }

  /// 删除标签
  Future<bool> deleteTag({
    required String scene,
    required int tagId,
    required String tagName,
  }) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    bool res2 = await UserTagApi().deleteTag(
      scene: scene,
      tagName: tagName,
    );
    if (res2 == false) {
      return false;
    }
    await UserTagRepo().delete(tagId);
    await replaceObjectTag(scene: scene, oldName: tagName, newName: '');

    final newItems = List<UserTagModel>.from(state.items);
    final index = newItems.indexWhere((e) => e.tagId == tagId);
    if (index > -1) {
      newItems.removeAt(index);
      state = state.copyWith(items: newItems);
    }
    return true;
  }

  /// 替换对象的标签
  Future<int?> replaceObjectTag({
    required String scene,
    required String oldName,
    required String newName,
  }) async {
    if (newName.isNotEmpty && newName.endsWith(',') == false) {
      newName = "$newName,";
    }
    if (scene == 'friend') {
      String sql =
          "UPDATE ${ContactRepo.tableName} SET ${ContactRepo.tag} = REPLACE(${ContactRepo.tag}, '$oldName,', '$newName') WHERE 1 = 1;";
      return await SqliteService.to.execute(sql);
    } else if (scene == 'collect') {
      String sql =
          "UPDATE ${UserCollectRepo.tableName} SET ${UserCollectRepo.tag} = REPLACE(${UserCollectRepo.tag}, '$oldName,', '$newName,') WHERE 1 = 1;";
      return await SqliteService.to.execute(sql);
    }
    return null;
  }

  /// 替换标签的副标题
  Future<int?> replaceTagSubtitle({
    required UserTagModel tag,
    required String oldName,
    required String newName,
  }) async {
    if (newName.isNotEmpty && newName.endsWith(',') == false) {
      newName = "$newName,";
    }
    String old = '${tag.subtitle},';
    String sql =
        "UPDATE ${UserTagRepo.tableName} SET ${UserTagRepo.subtitle} = REPLACE('$old}', '$oldName,', '$newName') WHERE ${UserTagRepo.userId} = '${UserRepoLocal.to.currentUid}' and ${UserTagRepo.tagId} = ${tag.tagId};";
    return await SqliteService.to.execute(sql);
  }

  /// 更新标签
  void updateTag(UserTagModel? tag) {
    if (tag == null) return;
    final newItems = List<UserTagModel>.from(state.items);
    final index = newItems.indexWhere((e) => e.tagId == tag.tagId);
    if (index > -1) {
      newItems[index] = tag;
      state = state.copyWith(items: newItems);
    }
  }

  /// 加载初始数据
  Future<void> loadData() async {
    state = state.copyWith(page: 1);
    var list = await page(page: state.page, size: state.size, kwd: state.kwd);
    if (list.isNotEmpty) {
      state = state.copyWith(items: list, page: state.page + 1);
    }
  }

  /// 加载更多数据
  Future<void> loadMore() async {
    var list = await page(page: state.page, size: state.size, kwd: state.kwd);
    if (list.isNotEmpty) {
      state = state.copyWith(
        items: [...state.items, ...list],
        page: state.page + 1,
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    state = state.copyWith(page: 1);
    var list = await page(
      page: state.page,
      size: state.size * 200,
      kwd: state.kwd,
      onRefresh: true,
    );
    if (list.isNotEmpty) {
      state = state.copyWith(items: list, page: state.page + 1);
    }
  }
}
