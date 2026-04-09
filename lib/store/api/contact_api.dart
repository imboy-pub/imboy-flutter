import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactApi extends HttpClient {
  Future<List<dynamic>> listFriend() async {
    IMBoyHttpResponse resp = await get(API.friendList);
    // debugPrint("> on Api/listFriend resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return [];
    }
    return resp.payload["friend"];
  }

  /// 同步非好友联系人信息
  Future<ContactModel?> syncByUid(String uid) async {
    IMBoyHttpResponse resp = await get(
      API.userShow,
      queryParameters: {"id": uid},
    );
    ContactModel? ct;
    if (kDebugMode) {
      debugPrint("> on Api/syncByUid resp: ok=${resp.ok}");
    }
    if (resp.ok && resp.payload.isNotEmpty) {
      try {
        await (ContactRepo()).save(resp.payload);
        ct = ContactModel.fromMap(resp.payload);
      } on Exception catch (e) {
        if (kDebugMode) {
          debugPrint("> on Api/syncByUid error: $e");
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          "> on Api/syncByUid failed: ${resp.error?.message ?? 'Unknown error'}",
        );
      }
    }
    return ct;
  }

  /// 删除联系人
  Future<bool> changeRemark(String uid, String remark) async {
    IMBoyHttpResponse resp = await post(
      API.friendChangeRemark,
      data: {'uid': uid, 'remark': remark},
    );
    if (kDebugMode) {
      debugPrint("> on changeRemark resp: ok=${resp.ok}");
    }
    return resp.ok;
  }

  /// 删除联系人
  Future<bool> deleteContact(String uid) async {
    IMBoyHttpResponse resp = await post(API.deleteFriend, data: {'uid': uid});
    if (kDebugMode) {
      debugPrint("> on deleteContact resp: ok=${resp.ok}");
    }
    return resp.ok;
  }
}
