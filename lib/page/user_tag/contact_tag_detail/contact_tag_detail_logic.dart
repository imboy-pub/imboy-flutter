import 'package:azlistview/azlistview.dart';
import 'package:get/get.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import 'contact_tag_detail_state.dart';

class ContactTagDetailLogic extends GetxController {
  final ContactTagDetailState state = ContactTagDetailState();

  void handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        // ignore: invalid_use_of_protected_member
        state.currIndexBarData.value.add(tag);
      } else {
        list[i].nameIndex = '#';
      }
    }
    // ignore: invalid_use_of_protected_member
    state.currIndexBarData.value.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);
    //
    state.contactList.value = list;
  }

  pageRelation(
    bool onRefresh, {
    required int tagId,
    int page = 1,
    int size = 10,
    String? kwd,
  }) async {
    List<ContactModel> contact = [];
    // var repo = UserTagRelationRepo();
    // if (onRefresh == false) {
    //   // contact = await repo.list();
    // }
    // if (contact.isNotEmpty) {
    //   return contact;
    // }
    Map<String, dynamic>? resp = await (UserTagProvider()).pageRelation(
        tagId: tagId, page: 1, size: 1000, scene: 'friend', kwd: kwd);
    List<dynamic> items = resp?['list'] ?? [];
    for (var json in items) {
      // ContactModel model = await repo.save(json);
      ContactModel model = ContactModel.fromJson(json);
      iPrint("pageRelation item ${model.toJson().toString()} ");
      if (model.isFriend == 1) {
        contact.insert(0, model);
      }
    }
    return contact;
  }

  Future<List<dynamic>> doSearch(
      {required bool onRefresh,
      required String query,
      required int tagId}) async {
    iPrint("user_collect_s_doSearch ${query.toString()}");

    state.page = 1;
    var list = await pageRelation(
      onRefresh,
      tagId: tagId,
      page: state.page,
      size: state.size,
      kwd: query.toString(),
    );
    if (list.isNotEmpty) {
      state.page += 1;
    }
    handleList(list);
    return list;
  }

  Future<bool> removeRelation(
      {required int tagId,
      required String objectId,
      required String tagName,
      required String scene}) async {
    // return true;
    bool res = await (UserTagProvider())
        .removeRelation(tagId: tagId, scene: scene, objectId: objectId);
    if (res) {
      ContactRepo().remoteTag(peerId: objectId, tagName: tagName);
    }
    return res;
  }

  Future<bool> setObject(
      {required String scene,
      required int tagId,
      required String tagName,
      required RxList<ContactModel> selectedContact}) async {
    List<String> objectIds = [];
    for (var e in selectedContact) {
      objectIds.add(e.peerId);
    }
    bool res = await (UserTagProvider()).setRelation(
      tagId: tagId,
      tagName: tagName,
      scene: scene,
      objectIds: objectIds,
    );
    // if (res) {
    //   ContactRepo().remoteTag(peerId: objectId, tagName: tagName);
    // }
    return res;
  }
}
