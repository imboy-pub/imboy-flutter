import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';

import 'contact_tag_list_state.dart';

class ContactTagListLogic extends GetxController {
  final ContactTagListState state = ContactTagListState();

  Future<List<UserTagModel>> page({
    int page = 1,
    int size = 10,
    String? kind,
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
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      String msg = 'tip_connect_desc'.tr;
      EasyLoading.showError(' $msg        ');
      return [];
    }
    iPrint("UserTagRepo_page logic ; onRefresh $onRefresh;  ${list.length}");
    Map<String, dynamic>? payload = await UserTagProvider().page(
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
      // where =
      //     "$where and (${UserTagRepo.name} like '%$kwd%' or ${UserTagRepo.subtitle} like '%$kwd%')";
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

  Future<List<dynamic>> doSearch(query) async {
    iPrint("user_collect_s_doSearch ${query.toString()}");
    state.page = 1;
    var list = await page(
      page: state.page,
      size: state.size,
      kwd: query.toString(),
    );
    if (list.isNotEmpty) {
      state.page += 1;
    }
    state.items.value = list;
    return list;
  }

  Future<bool> deleteTag({
    required String scene,
    required int tagId,
    required String tagName,
  }) async {
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      return false;
    }
    bool res2 = await UserTagProvider().deleteTag(
      scene: scene,
      tagName: tagName,
    );
    if (res2 == false) {
      return false;
    }
    await UserTagRepo().delete(tagId);
    await replaceObjectTag(scene: scene, oldName: tagName, newName: '');

    final index = state.items.indexWhere((e) => e.tagId == tagId);
    if (index > -1) {
      state.items.removeAt(index);
    }
    return true;
  }

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

  void updateTag(UserTagModel? tag) {
    final index = Get.find<ContactTagListLogic>()
        .state
        .items
        .indexWhere((e) => e.tagId == tag?.tagId);
    if (index > -1) {
      Get.find<ContactTagListLogic>()
          .state
          .items
          .setRange(index, index + 1, [tag]);
    }
  }
}
