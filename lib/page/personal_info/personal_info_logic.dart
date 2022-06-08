import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/personal_info/more_view.dart';

import 'personal_info_state.dart';

class PersonalInfoLogic extends GetxController {
  final state = PersonalInfoState();
  final HttpClient httpclient = Get.put(HttpClient.client);

  RxString genderTitle = "".obs;
  RxString sign = "".obs;
  RxString region = "".obs;

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<bool> changeInfo(Map data) async {
    HttpResponse result = await httpclient.put(API.userUpdate, data: data);
    debugPrint(
        ">>> on changeInfo:${result.ok} ${result.payload.toString()}, data: ${data.toString()}");
    return result.ok;
  }

  labelOnPressed(String label) {
    if (label == "more") {
      Get.to(MoreView());
    }
  }
}
