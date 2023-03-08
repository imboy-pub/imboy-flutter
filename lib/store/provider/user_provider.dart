import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/passport/passport_view.dart';

class UserProvider extends HttpClient {
  Future<Map<String, dynamic>> turnCredential() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return {};
    }
    IMBoyHttpResponse resp = await get(
      API.turnCredential,
    );
    if (!resp.ok) {
      return {};
    }
    return resp.payload;
  }

  Future<String> refreshAccessToken(String refreshtoken) async {
    if (strEmpty(refreshtoken)) {
      Get.to(PassportPage());
    }
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return "";
    }
    IMBoyHttpResponse resp = await post(
      API.refreshtoken,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
        headers: {
          Keys.refreshtokenKey: refreshtoken,
        },
      ),
    );
    if (!resp.ok) {
      return "";
    }
    return resp.payload["token"];
  }
}
