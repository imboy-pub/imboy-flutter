import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactProvider extends HttpClient {
  Future<List<dynamic>> listFriend() async {
    IMBoyHttpResponse resp = await get(
      API.friendList,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    // debugPrint("> on Provider/listFriend resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return [];
    }
    return resp.payload["friend"];
  }

  /// 同步非好友联系人信息
  Future<ContactModel> syncByUid(String uid) async {
    IMBoyHttpResponse resp = await get(
      API.userShow,
      queryParameters: {"id": uid},
      options: Options(
        contentType: "application/x-www-form-urlencoded",
      ),
    );
    ContactModel? ct;
    debugPrint("> on Provider/syncByUid resp: ${resp.payload.toString()}");
    if (resp.ok) {
      (ContactRepo()).save(resp.payload);
      ct = ContactModel.fromMap(resp.payload);
    }
    return ct!;
  }

  /// 删除联系人
  Future<bool> changeRemark(String uid, String remark) async {
    IMBoyHttpResponse resp = await post(
      API.friendChangeRemark,
      data: {
        'uid': uid,
        'remark': remark,
      },
    );
    debugPrint(
        "> on deleteContact resp: ${resp.ok}, ${resp.payload.toString()}");
    return resp.ok;
  }

  /// 删除联系人
  Future<bool> deleteContact(String uid) async {
    IMBoyHttpResponse resp = await post(
      API.deleteFriend,
      data: {'uid': uid},
    );
    debugPrint(
        "> on deleteContact resp: ${resp.ok}, ${resp.payload.toString()}");
    return resp.ok;
  }
}
