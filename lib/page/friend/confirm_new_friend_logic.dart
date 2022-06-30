import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact_logic.dart';

import 'new_friend_logic.dart';

class ConfirmNewFriendLogic extends GetxController {
  // 聊天、朋友圈、运动数据等
  // role 可能的值 all justchat
  RxString role = "all".obs;

  RxBool visibilityLook = true.obs;
  //  不让他（她）看
  RxBool donotlethimlook = false.obs;
  // 不看他（她）
  RxBool donotlookhim = false.obs;

  final ContactLogic ctlogic = Get.find();
  final NewFriendLogic nflogic = Get.find();

  void setRole(String role) {
    // debugPrint(">>> on ConfirmNewFriendLogic/setRole1 ${this.role.value} = ${role}");
    this.role.value = role;
    update([this.role]);
    // debugPrint(">>> on ConfirmNewFriendLogic/setRole2 ${this.role.value} = ${role}");
  }

  /// 确认申请成为好友
  Future<void> confirm(
      String from, String to, Map<String, dynamic> payload) async {
    payload["msg_type"] = "apply_friend_confirm";
    Map<String, dynamic> msg = {
      "from": from,
      "to": to,
      "payload": json.encode(payload),
    };

    EasyLoading.show(
      status: '正在发送...'.tr,
    );
    IMBoyHttpResponse resp = await HttpClient.client.post(
      "$API_BASE_URL${API.confirmfriend}",
      data: msg,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    if (resp.ok) {
      EasyLoading.showSuccess("已发送".tr);
      // 修正好友申请状态
      nflogic.receivedConfirFriend(false, {
        "from": from,
        "to": to,
      });
      // 存储好友信息
      ctlogic.receivedConfirFriend(resp.payload);
      Get.close(1);
    } else {
      EasyLoading.showError("网络故障，请重试！".tr);
    }
  }
}
