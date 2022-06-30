import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class NewFriendLogic extends GetxController {
  FocusNode searchF = FocusNode();
  TextEditingController searchC = TextEditingController();

  RxList<dynamic> items = [].obs;

  Future<List<NewFriendModel>> listNewFriend(String uid) async {
    return await (NewFriendRepo()).listNewFriend(uid);
  }

  /// 收到添加好友
  /// Received add a friend
  static Future<void> receivedAddFriend(Map data) async {
    String did = await DeviceExt.did;
    debugPrint("CLIENT_ACK,S2C,${data['id']},$did");
    // {id: af_7b4v1b_kybqdp, type: S2C,
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
      "from": from,
      "to": to,
      "nickname": payload["from"]["nickname"] ?? "",
      "avatar": payload["from"]["avatar"] ?? "",
      "msg": payload["from"]["msg"] ?? "",
      "payload": json.encode(payload),
      "status": NewFriendStatus.waiting_for_validation.index,
      "create_time":
          data["created_at"] ?? DateTime.now().millisecondsSinceEpoch,
    };
    debugPrint(">>> on receivedAddFriend ${saveData.toString()}");
    (NewFriendRepo()).save(saveData);
    WSService.to.sendMessage("CLIENT_ACK,S2C,${data['id']},$did");
  }
}
