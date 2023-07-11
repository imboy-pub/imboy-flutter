import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_tag_relation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';

import 'contact_tag_state.dart';

class ContactTagLogic extends GetxController {
  final ContactTagState state = ContactTagState();

  Future<List<UserTagModel>> page(
      {int page = 1, int size = 10, String? kind, String? kwd}) async {
    List<UserTagModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserTagRepo();

    // TODO kwd search 2023-06-14 23:33:09
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();

    /*
    if (res == ConnectivityResult.none) {
      String where = '${UserCollectRepo.userId}=?';
      List<Object?> whereArgs = [UserRepoLocal.to.currentUid];
      String? orderBy;
      if (kind == state.recentUse) {
        orderBy = "${UserCollectRepo.updatedAt} desc";
        where = "$where and ${UserCollectRepo.updatedAt} > 0";
      } else if (int.tryParse(kind!) != null) {
        where = "$where and ${UserCollectRepo.kind}=?";
        whereArgs.add(kind);
      }
      if (strNoEmpty(kwd)) {
        where =
        "$where and (${UserCollectRepo.source} like '%$kwd%' or ${UserCollectRepo.remark} like '%$kwd%' or ${UserCollectRepo.info} like '%$kwd%')";
      }
      list = await repo.page(
        limit: size,
        offset: offset,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
    }
    */
    iPrint("user_collect_s ${list.length}");
    if (list.isNotEmpty) {
      return list;
    }

    Map<String, dynamic>? payload = await UserTagProvider().page(
        page: page,
        size:size,
        kwd:kwd ?? '',
        scene: 'friend');
    if (payload == null) {
      return [];
    }

    for (var json in payload['list']) {
      json['user_id'] = json['user_id'] ?? UserRepoLocal.to.currentUid;
    // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
      json[UserTagRelationRepo.scene] = 2;
      UserTagModel model = UserTagModel.fromJson(json);
      await repo.save(json);
      list.add(model);
    }
    return list;
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
    await UserTagRepo().update({
      UserTagRepo.tagId: tagId,
      UserTagRepo.name: tagName,
    });
    return true;
  }

  Future<int?> replaceObjectTag({required String scene, required String oldName, required String newName}) async {
    if (newName.isNotEmpty && newName.endsWith(',') == false) {
      newName = "$newName,";
    }
    if (scene == 'friend') {
      String sql = "UPDATE ${ContactRepo.tableName} SET ${ContactRepo.tag} = REPLACE(${ContactRepo.tag}, '$oldName,', '$newName') WHERE 1 = 1;";
      return await SqliteService.to.execute(sql);
    } else if (scene == 'collect') {
      String sql = "UPDATE ${UserCollectRepo.tableName} SET ${UserCollectRepo.tag} = REPLACE(${UserCollectRepo.tag}, '${oldName},', '${newName},') WHERE 1 = 1;";
      return await SqliteService.to.execute(sql);
    }

  }
}
