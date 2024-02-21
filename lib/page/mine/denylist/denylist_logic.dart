import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/provider/denylist_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:lpinyin/lpinyin.dart';

class DenylistLogic extends GetxController {
  FocusNode searchF = FocusNode();
  TextEditingController searchC = TextEditingController();

  // final ContactLogic contactLogic = Get.put(ContactLogic());
  // final BottomNavigationLogic bottomLogic = Get.find<BottomNavigationLogic>();

  RxList<DenylistModel> items = RxList<DenylistModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;

  void handleList(List<DenylistModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    currIndexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);

    //
    items.value = list;
  }

  static Future<List<DenylistModel>> page(
      {int page = 1, int size = 10, bool onRefresh = false}) async {
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
    Map<String, dynamic>? payload = await DenylistProvider().page(
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

  static Future<bool> inDenylist(String uid) async {
    int count = await (UserDenylistRepo().inDenylist(uid));
    return count > 0 ? true : false;
  }

  Future<bool> removeDenylist(String peerId) async {
    DenylistProvider api = DenylistProvider();
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
      await refreshData();
    }
    return res;
  }

  Future<bool> addDenylist(DenylistModel model) async {
    DenylistProvider api = DenylistProvider();
    UserDenylistRepo repo = UserDenylistRepo();

    Map? payload = await api.add(deniedUserUid: model.deniedUid);
    bool res = payload == null ? false : true;
    if (res) {
      model.createdAt = payload['created_at'] ?? DateTimeHelper.utc();
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
      await refreshData();
    }
    return res;
  }

  Future<void> refreshData() async {
    // 刷新联系人列表
    var list = await Get.find<ContactLogic>().listFriend(false);
    Get.find<ContactLogic>().handleList(list);

    // 刷新会话列表
    await Get.find<ConversationLogic>().conversationsList();

    // 刷新黑名单列表
    var list2 = await page(page: 1, size: 1000);
    handleList(list2);
  }
}
