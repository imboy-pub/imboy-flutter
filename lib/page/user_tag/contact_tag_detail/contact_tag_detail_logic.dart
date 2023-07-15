import 'package:azlistview/azlistview.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact_logic.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';
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
    bool res = await (UserTagProvider()).removeRelation(
      tagId: tagId,
      scene: scene,
      objectId: objectId,
    );
    if (res) {
      ContactRepo().removeTag(peerId: objectId, tagName: tagName);
    }
    return res;
  }

  Future<bool> setObject({
    required String scene,
    required int tagId,
    required String tagName,
    required RxList<ContactModel> selectedContact, // 标签重新选择的联系人列表
    required List<ContactModel> tagContactList, // 标签之前选择的联系人列表
  }) async {
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
    if (res) {
      await UserTagRepo().update({
        UserTagRepo.tagId: tagId,
        UserTagRepo.refererTime: selectedContact.length,
      });
      List<String> oldObjectIds = [];
      // 处理处理移除情况
      for (var e in tagContactList) {
        oldObjectIds.add(e.peerId);
        if (!objectIds.contains(e.peerId)) {
          ContactRepo().removeTag(peerId: e.peerId, tagName: tagName);
          e.tag = e.tag.replaceAll("$tagName,", '');
          replaceContactList(e);
        }
      }

      // 新增的情况
      for (var e in selectedContact) {
        if (!oldObjectIds.contains(e.peerId)) {
          ContactRepo().addTag(peerId: e.peerId, tagName: tagName);
          e.tag = "$tagName,${e.tag}";
          replaceContactList(e);
        }
      }
    }
    return res;
  }

  replaceContactList(ContactModel e) {
    final index = Get.find<ContactLogic>()
        .contactList
        .indexWhere((e2) => e2.peerId == e.peerId);
    if (index > -1) {
      Get.find<ContactLogic>().contactList.replaceRange(index, index + 1, [e]);
    }
  }
}
