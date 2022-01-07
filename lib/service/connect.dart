import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';

class ConnectService extends GetConnect {
  @override
  void onInit() {
    // add your local storage here to load for every request
    // var token = LocalStorage.readToken(); //1.base_url
    var token = StorageService.to.getString(Keys.tokenKey); //1.base_url
    debugPrint(">>> on ConnectService/onInit/0 ${token}");
    httpClient.baseUrl = API_BASE_URL; //2.
    httpClient.defaultContentType = "application/json";
    httpClient.timeout = Duration(seconds: 8);
    httpClient.addResponseModifier((Request request, Response response) async {
      print(response.body);
    });
    httpClient.addRequestModifier((Request request) async {
      // add request here
      return request;
    });

    var headers = {'Authorization': "Bearer $token"};
    httpClient.addAuthenticator((Request request) async {
      request.headers.addAll(headers);
      return request;
    });

    super.onInit();
  }
}
