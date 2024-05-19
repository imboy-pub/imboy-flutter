import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

import 'package:imboy/page/personal_info/widget/more_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';

import 'personal_info_state.dart';

class PersonalInfoLogic extends GetxController {
  final state = PersonalInfoState();
  final HttpClient httpclient = Get.put(HttpClient.client);

  RxString genderTitle = "".obs;
  RxString sign = "".obs;
  RxString region = "".obs;

  Future<bool> changeInfo(Map data) async {
    IMBoyHttpResponse resp = await httpclient.put(API.userUpdate, data: data);
    return resp.ok;
  }

  labelOnPressed(String label) {
    if (label == 'more') {
      Get.to(
        () => const MoreView(),
        transition: Transition.rightToLeft,
        popGesture: true, // 右滑，返回上一页
      );
    } else if (label == "user_qrcode") {
      Get.to(
        () => UserQrCodePage(),
        transition: Transition.rightToLeft,
        popGesture: true, // 右滑，返回上一页
      );
    }
  }
}
