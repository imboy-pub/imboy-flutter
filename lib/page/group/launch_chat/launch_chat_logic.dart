import 'package:azlistview/azlistview.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/provider/group_member_provider.dart';
import 'package:imboy/store/provider/group_provider.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';

import 'launch_chat_state.dart';

class LaunchChatLogic extends GetxController {
  final state = LaunchChatState();

  void resetData() {
    state.selects.value = [];
    state.selectsTips.value = '';
    for (ContactModel i in state.items) {
      i.selected.value = false;
    }
  }

  void listFriend() async {
    var list = await (Get.find<ContactLogic>()).listFriend(false);
    handleList(list);
  }

  void handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        state.currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = '#';
      }
    }
    state.currIndexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);
    state.items.value = list;
  }

  Future<GroupModel?> groupAdd(List<ContactModel> items) async {
    if (items.isEmpty) {
      return null;
    }
    List<String> memberUserIds = [];
    for (var item in items) {
      memberUserIds.add(item.peerId);
    }
    Map<String, dynamic>? payload =
        await GroupProvider().groupAdd(memberUserIds: memberUserIds);
    if (payload != null) {
      GroupModel m = await GroupRepo().save('', payload['group']);
      GroupMemberRepo gmRepo = GroupMemberRepo();
      List<dynamic> memberList = payload['member_list'] ?? [];
      for (var json in memberList) {
        gmRepo.save(json as Map<String, dynamic>);
      }
      if (m.title.isEmpty) {
        m.computeTitle =
            await Get.find<GroupListLogic>().computeTitle(m.groupId);
      }
      return m;
    }
    return null;
  }

  Future<bool> joinGroup(String gid, List<ContactModel> items) async {
    if (items.isEmpty) {
      return false;
    }
    List<String> memberUserIds = [];
    for (var item in items) {
      memberUserIds.add(item.peerId);
    }
    Map<String, dynamic>? payload = await GroupMemberProvider().join(
      gid: gid,
      memberUserIds: memberUserIds,
    );
    if (payload != null) {
      GroupRepo gRepo = GroupRepo();
      GroupModel? g = await gRepo.findById(gid);
      GroupMemberRepo gmRepo = GroupMemberRepo();
      int sum = payload['user_id_sum'] ?? 0;
      List<dynamic> memberList = payload['member_list'] ?? [];
      Map<String, dynamic> gData = {
        GroupRepo.memberCount: g!.memberCount + memberList.length,
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
      gRepo.update(gid, gData);
      for (var json in memberList) {
        gmRepo.save(json as Map<String, dynamic>);
      }
      return true;
    }
    return false;
  }

  Future<bool> leaveGroup(String gid, List<GroupMemberModel> items) async {
    if (items.isEmpty) {
      return false;
    }
    List<String> memberUserIds = [];
    for (var item in items) {
      memberUserIds.add(item.userId);
    }
    Map<String, dynamic>? payload = await GroupMemberProvider()
        .leave(gid: gid, memberUserIds: memberUserIds);
    if (payload != null) {
      GroupRepo gRepo = GroupRepo();
      GroupModel? g = await gRepo.findById(gid);
      GroupMemberRepo gmRepo = GroupMemberRepo();
      int sum = payload['user_id_sum'] ?? 0;
      List<dynamic> memberList = payload['member_list'] ?? [];
      Map<String, dynamic> gData = {
        GroupRepo.memberCount: g!.memberCount - memberList.length,
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
      gRepo.update(gid, gData);
      for (var userId in memberUserIds) {
        gmRepo.delete(gid, userId);
      }
      return true;
    }
    return false;
  }
}
