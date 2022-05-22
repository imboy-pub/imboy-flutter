import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactProvider extends HttpClient {
  Future<List<ContactModel>> listFriend() async {
    HttpResponse resp = await get(
      API.friendList,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    // debugPrint(">>> on Provider/listFriend resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return [];
    }
    List<dynamic> dataMap = resp.payload["friend"];
    int len = dataMap.length;

    // debugPrint(">>> on Provider/listFriend dm: ${dataMap.toString()}");
    List<ContactModel> friend = [];
    var repo = ContactRepo();

    for (int i = 0; i < len; i++) {
      Map<String, dynamic> json = dataMap[i];
      json["is_friend"] = 1;
      ContactModel model = ContactModel.fromJson(json);
      friend.insert(0, model);
      repo.save(dataMap[i]);
    }
    return friend;
  }

  Future<ContactModel> syncByUid(String uid) async {
    HttpResponse resp = await get(
      API.userShow,
      queryParameters: {"id": uid},
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    ContactModel? ct = null;
    debugPrint(">>> on Provider/syncByUid resp: ${resp.payload.toString()}");
    if (resp.ok) {
      (ContactRepo()).save(resp.payload);
      ct = ContactModel.fromJson(resp.payload);
    }
    return ct!;
  }
}
