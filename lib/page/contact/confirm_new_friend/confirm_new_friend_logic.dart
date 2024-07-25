import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/env.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';

import '../../contact/contact/contact_logic.dart';
import '../new_friend/new_friend_logic.dart';

class ConfirmNewFriendLogic extends GetxController {
  // 聊天、朋友圈、运动数据等
  // role 可能的值 all just_chat
  RxString role = "all".obs;

  RxBool visibilityLook = true.obs;

  //  不让他（她）看
  RxBool donotlethimlook = false.obs;

  // 不看他（她）
  RxBool donotlookhim = false.obs;

  Rx<String> peerTag = ''.obs;

  final ContactLogic contactLogic = Get.find();
  final NewFriendLogic newFriendLogic = Get.find();
  final BottomNavigationLogic bottomNavigationLogic = Get.find();

  void setRole(String role) {
    // debugPrint("> on ConfirmNewFriendLogic/setRole1 ${this.role.value} = ${role}");
    this.role.value = role;
    update([this.role]);
    // debugPrint("> on ConfirmNewFriendLogic/setRole2 ${this.role.value} = ${role}");
  }

  /// 确认申请成为好友
  Future<void> confirm(
    String from,
    String to,
    Map<String, dynamic> payload,
  ) async {
    payload["msg_type"] = "apply_friend_confirm";
    Map<String, dynamic> msg = {
      "from": from,
      "to": to,
      "payload": json.encode(payload),
    };

    EasyLoading.show(
      status: 'sending'.tr,
    );
    IMBoyHttpResponse resp = await HttpClient.client.post(
      "${Env.apiBaseUrl}${API.confirmFriend}",
      data: msg,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    if (resp.ok) {
      EasyLoading.showSuccess('sent'.tr);
      // 修正好友申请状态
      newFriendLogic.receivedConfirmFriend(false, {
        "from": to,
        "to": from,
      });
      // 存储好友信息
      contactLogic.receivedConfirmFriend(resp.payload);
      Future.delayed(const Duration(seconds: 1), () {
        // 重新计算"新的好友提醒计数器"
        // debugPrint("> on countNewFriendRemindCounter $from");
        bottomNavigationLogic.newFriendRemindCounter.remove(from);
        bottomNavigationLogic.update([
          bottomNavigationLogic.newFriendRemindCounter,
        ]);
      });
      Get.back(times: 1);
    } else {
      EasyLoading.showError('network_failure_try_again'.tr);
    }
  }
}
