import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactApi extends HttpClient {
  Future<List<dynamic>> listFriend() async {
    IMBoyHttpResponse resp = await get(API.friendList);
    // [DIAG #19] API 层：响应形状与 friend 数组长度
    final payload = resp.payload;
    final friendRaw = (payload is Map) ? payload['friend'] : null;
    debugPrint(
      "> [DIAG #19] ContactApi.listFriend resp.ok=${resp.ok} "
      "payload.isMap=${payload is Map} "
      "payload.keys=${payload is Map ? payload.keys.toList() : null} "
      "friend.isList=${friendRaw is List} "
      "friend.length=${friendRaw is List ? friendRaw.length : -1}",
    );
    if (!resp.ok) {
      return [];
    }
    if (friendRaw is! List) {
      debugPrint(
        "> [DIAG #19] ContactApi.listFriend friend is NOT a List — returning []",
      );
      return [];
    }
    return friendRaw;
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
    if (resp.ok && resp.payload.isNotEmpty == true) {
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
