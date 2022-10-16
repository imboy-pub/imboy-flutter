import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

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
