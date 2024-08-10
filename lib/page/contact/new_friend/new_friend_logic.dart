import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class NewFriendLogic extends GetxController {
  FocusNode searchF = FocusNode();
  TextEditingController searchC = TextEditingController();
  String searchKwd = '';

  final BottomNavigationLogic bottomLogic = Get.find<BottomNavigationLogic>();

  RxList<dynamic> items = [].obs;

  Future<List<NewFriendModel>> listNewFriend(String uid) async {
    return await (NewFriendRepo()).listNewFriend(uid, 10000);
  }

  /// 收到添加朋友
  /// Received add a friend
  Future<void> receivedAddFriend(Map data) async {
    debugPrint("CLIENT_ACK,S2C,${data['id']},$deviceId");
    // {id: afc_7b4v1b_kybqdp, type: S2C,
    // from: 7b4v1b,
    // to: kybqdp,
    // payload: {"from":{"source":"qrcode","msg":"我是 nick leeyi👍🏻👍🏻就","remark":"leeyi101","role":"all","donotlookhim":false,"donotlethimlook":true},"to":{},
    // "msg_type":"apply_as_a_friend"},
    // created_at: 1656169854526,
    // server_ts: 1656429104415}

    String uid = UserRepoLocal.to.currentUid;
    String from = data["from"] ?? "";
    String to = data["to"] ?? "";
    var payload = data["payload"] ?? {};
    if (payload is String) {
      payload = json.decode(payload);
    }
    Map<String, dynamic> saveData = {
      "uid": uid,
      NewFriendRepo.from: from,
      NewFriendRepo.to: to,
      NewFriendRepo.nickname: payload["from"]["nickname"] ?? "",
      NewFriendRepo.avatar: payload["from"]["avatar"] ?? "",
      NewFriendRepo.msg: payload["from"]["msg"] ?? "",
      NewFriendRepo.payload: json.encode(payload),
      NewFriendRepo.status: NewFriendStatus.waiting_for_validation.index,
      NewFriendRepo.createdAt: DateTimeHelper.utc(),
    };
    debugPrint("> on receivedAddFriend ${saveData.toString()}");
    (NewFriendRepo()).save(saveData);
    replaceItems(NewFriendModel.fromJson(saveData));
    bottomLogic.newFriendRemindCounter.add(from);
    bottomLogic.update([bottomLogic.newFriendRemindCounter]);
    WebSocketService.to.sendMessage("CLIENT_ACK,S2C,${data['id']},$deviceId");
  }

  /// 确认添加朋友，对端消息通知
  Future<void> receivedConfirmFriend(bool ack, Map data) async {
    debugPrint(
        "CLIENT_ACK,S2C,${data['id']},$deviceId  data:${data.toString()}");
    String from = data["from"];
    String to = data["to"];
    NewFriendRepo repo = NewFriendRepo();
    // 服务端对调了 from to，离线消息需要对调
    NewFriendModel? obj = await repo.findByFromTo(to, from);
    if (obj != null) {
      obj.status = NewFriendStatus.added.index;
      repo.update({
        // 服务端对调了 from to，离线消息需要对调
        "from": to,
        "to": from,
        "status": obj.status,
      });
      replaceItems(obj);
    }
    if (ack) {
      WebSocketService.to.sendMessage("CLIENT_ACK,S2C,${data['id']},$deviceId");
    }
  }

  /// 删除好友申请记录
  Future<int> delete(String from, String to) async {
    int res = await (NewFriendRepo()).delete(from, to);
    final index = items.indexWhere((e) => e.uk == from + to);
    items.removeAt(index);
    update([items]);
    return res;
  }

  /// 替换好友申请记录
  void replaceItems(NewFriendModel obj) {
    final index = items.indexWhere((e) => e.uk == obj.uk);
    debugPrint("CLIENT_ACK replaceItems $index ${obj.toString()}");
    if (index > -1) {
      items.setRange(index, index + 1, [obj]);
    } else {
      items.insert(0, obj);
    }
    update([items]);
  }

  Future<List> userSearch({
    int page = 1,
    int size = 10,
    String? kwd,
  }) async {
    searchKwd = kwd ?? '';
    Map<String, dynamic>? payload = await UserProvider().userSearch(
      page: page,
      size: size,
      keyword: kwd ?? '',
    );
    iPrint("NewFriendLogic_userSearch ${payload.toString()};");
    if (payload?['list'] == null) {
      return [];
    }
    List<PeopleModel> list = [];
    for (var vo in payload?['list']) {
      list.add(PeopleModel.fromJson(vo));
    }
    return list;
  }

  Widget doBuildUserSearchResults(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(child: Text('user_not_exist'.tr));
    }
    PeopleModel model = items[0];
    if (model.id == UserRepoLocal.to.currentUid) {
      EasyLoading.showInfo('can_not_add_yourself_friend'.tr);
    } else {
      return n.ListTile(
        leading: Avatar(
          imgUri: model.avatar,
          width: 56,
          height: 56,
        ),
        title: Text('${model.title}($searchKwd)'),
        subtitle: n.Row([
          genderIcon(model.gender),
          const Space(width: 10),
          if (model.region.isNotEmpty)
            Text(model.region),
        ]),
        trailing: Container(
          width: 80,
          alignment: Alignment.centerRight,
          child: (model.isFriend ?? false) ? Text('added'.tr) : Text('button_add'.tr),
        ),
        onTap: () {
          Get.to(
            () => PeopleInfoPage(
              id: model.id,
              scene: 'user_search',
            ),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      );
    }

    if (strNoEmpty(model.id)) {
      return n.Padding(
        top: 10,
        child: n.ListTile(
          leading: Container(
            width: 48, // 设置方块的宽度
            height: 48, // 设置方块的高度
            decoration: BoxDecoration(
              // 背景
              color: Colors.green,
              // 设置四周圆角 角度
              borderRadius: const BorderRadius.all(Radius.circular(6.0)),
              // 设置四周边框
              border: Border.all(width: 1, color: Colors.green),
            ), // 背景颜色为绿色
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 40,
            ),
          ),
          title: n.Row([
            Text('search'.tr),
            Text(
              searchKwd,
              style: const TextStyle(color: Colors.green),
            ),
          ]),
          onTap: () {},
        ),
      );
    } else {
      return Center(child: Text('user_not_exist'.tr));
    }
  }
}
