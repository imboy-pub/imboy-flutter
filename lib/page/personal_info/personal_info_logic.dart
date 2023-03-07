import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/personal_info/more_view.dart';
import 'package:imboy/page/uqrcode/uqrcode_view.dart';

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
    if (label == "more") {
      Navigator.push(
        Get.context!,
        CupertinoPageRoute( // 右滑，返回上一页
          builder: (_) => const MoreView(),
        ),
      );
    } else if (label == "user_qrcode") {
      Navigator.push(
        Get.context!,
        CupertinoPageRoute( // 右滑，返回上一页
          builder: (_) => UqrcodePage(),
        ),
      );
    }

  }
}
