import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ApplyFriendLogic extends GetxController {
  // 聊天、朋友圈、运动数据等
  // role 可能的值 all justchat
  RxString role = "all".obs;

  RxBool visibilityLook = true.obs;

  //  不让他（她）看
  RxBool donotlethimlook = false.obs;

  // 不看他（她）
  RxBool donotlookhim = false.obs;

  void setRole(String role) {
    // debugPrint("> on ApplyFriendLogic/setRole1 ${this.role.value} = ${role}");
    this.role.value = role;
    update([this.role]);

    // debugPrint("> on ApplyFriendLogic/setRole2 ${this.role.value} = ${role}");
  }

  /// 申请成为好友
  Future<void> apply({
    required String to,
    required String nickname,
    required String avatar,
    required Map<String, dynamic> payload,
  }) async {
    payload["msg_type"] = "apply_friend";
    int createdAt = DateTimeHelper.currentTimeMillis();
    Map<String, dynamic> msg = {
      "to": to,
      "payload": json.encode(payload),
      "created_at": createdAt,
    };

    EasyLoading.show(
      status: '正在发送...'.tr,
    );

    IMBoyHttpResponse resp = await HttpClient.client.post(
      "$API_BASE_URL${API.addFriend}",
      data: msg,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    if (resp.ok) {
      Map<String, dynamic> saveData = {
        "uid": UserRepoLocal.to.currentUid,
        NewFriendRepo.from: UserRepoLocal.to.currentUid,
        NewFriendRepo.to: to,
        "nickname": nickname,
        "avatar": avatar,
        "msg": payload["from"]["msg"] ?? "",
        "payload": json.encode(payload),
        "status": NewFriendStatus.waiting_for_validation.index,
        "create_time": createdAt,
      };
      // debugPrint("> on receivedAddFriend ${saveData.toString()}");
      (NewFriendRepo()).save(saveData);
      EasyLoading.showSuccess("已发送".tr);
      Get.close(2);
    } else {
      EasyLoading.showError("网络故障，请重试！".tr);
    }
  }
}
