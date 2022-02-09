import 'package:dio/dio.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/helper/http/http_response.dart';

class UserProvider extends HttpClient {
  Future<String> refreshtoken(String refreshtoken) async {
    HttpResponse resp = await post(
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
